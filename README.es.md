# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Icono de la app BOC" width="112">
</p>

OpenCode remoto, sin quedarte pegado al escritorio.

BOC es un cliente Flutter multiplataforma para usar OpenCode de forma remota desde iOS, Android, macOS y Windows. Está diseñado alrededor de la compatibilidad con OpenCode `1.4.3` y se centra en el trabajo que realmente necesitas cuando estás lejos de tu estación principal: conectarte a un servidor, reanudar un workspace, seguir sesiones, responder solicitudes, inspeccionar contexto y ejecutar algún comando de shell cuando haga falta.

¿Tienes una pantalla amplia?

![Workspace multipanel de BOC](assets/readme/multi-pane.png)

BOC puede expandirse como un centro de mando multipanel para monitoreo de sesiones, Review, archivos, contexto, salida de shell y actividad paralela del workspace.

## Por qué BOC

- **Flujo remote-first**: guarda servidores OpenCode, revisa el estado de conexión y vuelve rápido al workspace correcto.
- **Controles nativos para móvil**: navegación táctil, layouts compactos, entrada por voz, archivos adjuntos, notificaciones y acciones de una mano.
- **Workspace de nivel escritorio**: las pantallas amplias obtienen paneles divididos, paneles laterales, listas de sesiones, superficies de Review y detalles de contexto sin convertirse en una vista móvil comprimida.
- **Feedback operativo en vivo**: salida de shell, preguntas pendientes, permisos, todos, uso de contexto y actividad de sesión permanecen visibles mientras el trabajo corre.
- **Gestión predecible de servidores**: las entradas de servidor son fáciles de revisar, refrescar, editar, eliminar y reconectar.

## Funciones principales

- Gestiona varios servidores OpenCode remotos desde una pantalla de inicio simple.
- Comprueba salud y compatibilidad del servidor antes de entrar a un workspace.
- Explora proyectos y sesiones, incluidos prompts recientes y sesiones hijas activas.
- Chatea con sesiones OpenCode usando slash commands, adjuntos, selección de modelo y controles de reasoning.
- Responde preguntas pendientes y solicitudes de permisos sin perder tu lugar en la conversación.
- Inspecciona uso de contexto, archivos, review diffs, inbox, todos y actividad de shell desde paneles dedicados.
- Ejecuta pestañas de terminal cuando una UI guiada no sea suficiente.
- Usa layouts adaptativos en teléfonos, tablets, laptops y pantallas de escritorio.

## Compatibilidad

BOC apunta a OpenCode `1.4.3`. La validación actual de preparación de release se centra en el sondeo de conexión, carga de workspaces/sesiones, chat, flujos de shell y terminal, preguntas pendientes, solicitudes de permisos, paneles de review/files/context y layouts adaptativos multipanel.

Plataformas cliente soportadas:

- iOS
- Android
- macOS
- Windows

El servidor OpenCode sigue ejecutándose de forma remota; BOC es la superficie cliente para conectarse a él, no un reemplazo del servidor.

## Requisitos

- Flutter con un Dart SDK compatible con `^3.11.1`
- Un servidor OpenCode `1.4.3` alcanzable
- Toolchains de plataforma para los objetivos que planeas ejecutar: iOS, Android, macOS o Windows

## Primeros pasos

```bash
flutter pub get
flutter run
```

Luego agrega tu servidor OpenCode desde la pantalla de inicio, confirma que el sondeo de conexión pase y abre un workspace.

Para ejecutar en un dispositivo específico:

```bash
flutter devices
flutter run -d <device-id>
```

## Desarrollo

Usa las mismas comprobaciones que la CI del proyecto:

```bash
flutter analyze
flutter test
```

## Estado del proyecto

BOC se está preparando para release. El foco ahora es estabilidad, UX multiplataforma predecible y compatibilidad con la versión soportada de OpenCode.
