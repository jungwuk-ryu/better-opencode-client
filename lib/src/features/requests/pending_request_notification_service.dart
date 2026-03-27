import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class PendingRequestNotificationService {
  Future<void> showPendingRequestNotification({
    required String dedupeKey,
    required String title,
    required String body,
  });
}

final PendingRequestNotificationService
sharedPendingRequestNotificationService =
    LocalPendingRequestNotificationService();

class LocalPendingRequestNotificationService
    implements PendingRequestNotificationService {
  LocalPendingRequestNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _androidChannelId = 'pending_requests';
  static const String _androidChannelName = 'Pending requests';
  static const String _androidChannelDescription =
      'Question and permission requests that need attention.';
  static const String _linuxDefaultActionName =
      'Open better-opencode-client (BOC)';
  static const String _windowsAppName = 'better-opencode-client (BOC)';
  static const String _windowsAppUserModelId = 'com.jungwuk.boc';
  static const String _windowsGuid = '1a37b828-56f3-4e1a-b3bb-4f4c2d7321e2';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _readyFuture;
  bool _permissionsRequested = false;
  bool _notificationPermissionGranted = true;
  int _nextNotificationId = 1;
  final Set<String> _shownKeys = <String>{};

  @override
  Future<void> showPendingRequestNotification({
    required String dedupeKey,
    required String title,
    required String body,
  }) async {
    final normalizedKey = dedupeKey.trim();
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    if (kIsWeb ||
        normalizedKey.isEmpty ||
        normalizedTitle.isEmpty ||
        normalizedBody.isEmpty) {
      return;
    }
    if (!_shownKeys.add(normalizedKey)) {
      return;
    }
    try {
      final ready = await _ensureReady();
      if (!ready) {
        _shownKeys.remove(normalizedKey);
        return;
      }
      await _plugin.show(
        id: _nextNotificationId++,
        title: normalizedTitle,
        body: normalizedBody,
        notificationDetails: _notificationDetails,
        payload: normalizedKey,
      );
    } on MissingPluginException {
      _shownKeys.remove(normalizedKey);
    } on PlatformException {
      _shownKeys.remove(normalizedKey);
    } on UnsupportedError {
      _shownKeys.remove(normalizedKey);
    }
  }

  Future<bool> _ensureReady() async {
    _readyFuture ??= _initializeAndAuthorize();
    return _readyFuture!;
  }

  Future<bool> _initializeAndAuthorize() async {
    try {
      await _plugin.initialize(settings: _initializationSettings);
      return _ensurePermission();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  Future<bool> _ensurePermission() async {
    if (_permissionsRequested) {
      return _notificationPermissionGranted;
    }
    _permissionsRequested = true;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final plugin = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          final granted = await plugin?.requestNotificationsPermission();
          _notificationPermissionGranted = granted ?? true;
          break;
        case TargetPlatform.iOS:
          final plugin = _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
          final granted = await plugin?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          );
          _notificationPermissionGranted = granted ?? true;
          break;
        case TargetPlatform.macOS:
          final plugin = _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >();
          final granted = await plugin?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          );
          _notificationPermissionGranted = granted ?? true;
          break;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          _notificationPermissionGranted = true;
          break;
      }
    } on MissingPluginException {
      _notificationPermissionGranted = false;
    } on PlatformException {
      _notificationPermissionGranted = false;
    } on UnsupportedError {
      _notificationPermissionGranted = false;
    }
    return _notificationPermissionGranted;
  }

  InitializationSettings get _initializationSettings =>
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(
          defaultActionName: _linuxDefaultActionName,
        ),
        windows: WindowsInitializationSettings(
          appName: _windowsAppName,
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsGuid,
        ),
      );

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    ),
    linux: LinuxNotificationDetails(urgency: LinuxNotificationUrgency.critical),
    windows: WindowsNotificationDetails(),
  );
}
