# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC App-Symbol" width="112">
</p>

OpenCode remote nutzen, ohne am Schreibtisch festzusitzen.

BOC ist ein plattformübergreifender Flutter-Client, mit dem du OpenCode remote von iOS, Android, macOS und Windows aus verwenden kannst. Er ist auf Kompatibilität mit OpenCode `1.4.3` ausgelegt und konzentriert sich auf die Arbeit, die du wirklich brauchst, wenn du nicht an deiner Haupt-Workstation sitzt: Server verbinden, Workspace fortsetzen, Sessions verfolgen, Anfragen beantworten, Context prüfen und bei Bedarf einen Shell-Befehl ausführen.

Hast du einen breiten Bildschirm?

![BOC Multi-Pane Workspace](assets/readme/multi-pane.png)

BOC kann sich zu einer Multi-Pane-Kommandozentrale für Session-Monitoring, Review, Dateien, Context, Shell-Ausgabe und parallele Workspace-Aktivität ausweiten.

## Warum BOC

- **Remote-first Workflow**: OpenCode-Server speichern, Verbindungsstatus prüfen und schnell in den richtigen Workspace zurückkehren.
- **Mobile-native Steuerung**: touchfreundliche Navigation, kompakte Layouts, Spracheingabe, Dateianhänge, Benachrichtigungen und Einhandaktionen.
- **Desktop-tauglicher Workspace**: breite Bildschirme erhalten Split Panes, Side Panels, Session-Listen, Review-Flächen und Context-Details, ohne wie eine gequetschte Mobilansicht zu wirken.
- **Live-Feedback zur Arbeit**: Shell-Ausgabe, ausstehende Fragen, Berechtigungen, Todos, Context-Nutzung und Session-Aktivität bleiben während laufender Arbeit sichtbar.
- **Vorhersehbare Serververwaltung**: Servereinträge lassen sich einfach überblicken, aktualisieren, bearbeiten, löschen und erneut verbinden.

## Kernfunktionen

- Mehrere entfernte OpenCode-Server über einen einfachen Startbildschirm verwalten.
- Serverzustand und Kompatibilität prüfen, bevor du einen Workspace öffnest.
- Projekte und Sessions durchsuchen, einschließlich aktueller Prompts und aktiver Child Sessions.
- Mit OpenCode-Sessions über Slash Commands, Anhänge, Modellauswahl und Reasoning-Steuerung chatten.
- Ausstehende Fragen und Berechtigungsanfragen beantworten, ohne die Stelle im Gespräch zu verlieren.
- Context-Nutzung, Dateien, Review-Diffs, Inbox-Einträge, Todos und Shell-Aktivität in eigenen Panels prüfen.
- Terminal-Tabs öffnen, wenn die geführte UI nicht ausreicht.
- Adaptive Layouts auf Smartphones, Tablets, Laptops und Desktop-Displays nutzen.

## Kompatibilität

BOC zielt auf OpenCode `1.4.3`. Die aktuelle Release-Prep-Validierung konzentriert sich auf Verbindungsprüfung, Workspace-/Session-Laden, Chat, Shell- und Terminal-Flows, ausstehende Fragen, Berechtigungsanfragen, Review-/Files-/Context-Panels und adaptive Multi-Pane-Layouts.

Unterstützte Client-Plattformen:

- iOS
- Android
- macOS
- Windows

Der OpenCode-Server läuft weiterhin remote; BOC ist die Client-Oberfläche zur Verbindung mit ihm und kein Ersatz für den Server selbst.

## Anforderungen

- Flutter mit einem Dart SDK, das mit `^3.11.1` kompatibel ist
- Ein erreichbarer OpenCode `1.4.3` Server
- Platform-Toolchains für deine Zielplattformen: iOS, Android, macOS oder Windows

## Erste Schritte

```bash
flutter pub get
flutter run
```

Füge danach deinen OpenCode-Server auf dem Startbildschirm hinzu, bestätige die erfolgreiche Verbindungsprüfung und öffne einen Workspace.

Für bestimmte Geräte:

```bash
flutter devices
flutter run -d <device-id>
```

## Entwicklung

Nutze dieselben Checks wie die Projekt-CI:

```bash
flutter analyze
flutter test
```

## Projektstatus

BOC wird für den Release vorbereitet. Der Fokus liegt aktuell auf Stabilität, vorhersehbarer plattformübergreifender UX und Kompatibilität mit der unterstützten OpenCode-Version.
