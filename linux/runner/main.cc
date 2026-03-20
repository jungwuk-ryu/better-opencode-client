#include "my_application.h"

#include <errno.h>
#include <glib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

#include <X11/Xlib.h>

namespace {

GPid g_headless_display_pid = 0;

bool can_open_display(const gchar* display_name) {
  Display* dpy = XOpenDisplay(display_name);
  if (dpy == nullptr) {
    return false;
  }

  XCloseDisplay(dpy);
  return true;
}

bool wait_for_display_ready(const gchar* display_name) {
  constexpr useconds_t kProbeIntervalMicros = 50 * 1000;
  constexpr gint kProbeAttempts = 60;

  for (gint attempt = 0; attempt < kProbeAttempts; ++attempt) {
    if (can_open_display(display_name)) {
      return true;
    }

    g_usleep(kProbeIntervalMicros);
  }

  return false;
}

void cleanup_headless_display() {
  if (g_headless_display_pid == 0) {
    return;
  }

  kill(g_headless_display_pid, SIGTERM);

  int status = 0;
  while (waitpid(g_headless_display_pid, &status, 0) == -1 && errno == EINTR) {
  }

  g_spawn_close_pid(g_headless_display_pid);
  g_headless_display_pid = 0;
}

void handle_exit_signal(int signal_number) {
  cleanup_headless_display();
  signal(signal_number, SIG_DFL);
  raise(signal_number);
}

void install_signal_handlers() {
  signal(SIGINT, handle_exit_signal);
  signal(SIGTERM, handle_exit_signal);
  signal(SIGHUP, handle_exit_signal);
}

void ensure_headless_display() {
  const gchar* display = g_getenv("DISPLAY");
  if (display != nullptr && display[0] != '\0') {
    return;
  }

  const gchar* wayland_display = g_getenv("WAYLAND_DISPLAY");
  if (wayland_display != nullptr && wayland_display[0] != '\0') {
    return;
  }

  if (g_file_test("/tmp/.X11-unix/X99", G_FILE_TEST_EXISTS)) {
    const char* const reuse_display = ":99";
    if (can_open_display(reuse_display)) {
      g_setenv("DISPLAY", reuse_display, TRUE);
      return;
    }
  }

  const gint display_number = 1000 + (getpid() % 1000);
  g_autofree gchar* headless_display =
      g_strdup_printf(":%d", display_number);

  g_autofree gchar* xvfb_path = g_find_program_in_path("Xvfb");
  if (xvfb_path == nullptr) {
    return;
  }

  gchar* argv[] = {xvfb_path, headless_display,
                   const_cast<gchar*>("-screen"), const_cast<gchar*>("0"),
                   const_cast<gchar*>("1280x720x24"),
                   const_cast<gchar*>("-nolisten"),
                   const_cast<gchar*>("tcp"), nullptr};
  g_autoptr(GError) error = nullptr;
  const gboolean spawned = g_spawn_async(
      nullptr, argv, nullptr,
      static_cast<GSpawnFlags>(G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD |
                               G_SPAWN_STDOUT_TO_DEV_NULL |
                               G_SPAWN_STDERR_TO_DEV_NULL),
      nullptr, nullptr, &g_headless_display_pid, &error);
  if (!spawned || error != nullptr || g_headless_display_pid == 0) {
    g_headless_display_pid = 0;
    return;
  }

  if (!wait_for_display_ready(headless_display)) {
    cleanup_headless_display();
    return;
  }

  g_setenv("DISPLAY", headless_display, TRUE);
}

}

int main(int argc, char** argv) {
  atexit(cleanup_headless_display);
  install_signal_handlers();
  ensure_headless_display();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
