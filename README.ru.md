# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Иконка приложения BOC" width="112">
</p>

Удаленный OpenCode без привязки к рабочему столу.

BOC — кроссплатформенный Flutter-клиент для удаленного использования OpenCode с iOS, Android, macOS и Windows. Он спроектирован вокруг совместимости с OpenCode `1.4.3` и сосредоточен на задачах, которые действительно нужны вне основной рабочей станции: подключение к серверу, возобновление workspace, отслеживание sessions, ответы на запросы, просмотр context и запуск shell-команд при необходимости.

Есть широкий экран?

![Многопанельный workspace BOC](assets/readme/multi-pane.png)

BOC может развернуться в многопанельный командный центр для мониторинга sessions, Review, файлов, context, вывода shell и параллельной активности workspace.

## Почему BOC

- **Remote-first workflow**: сохраняйте серверы OpenCode, проверяйте состояние подключения и быстро возвращайтесь в нужный workspace.
- **Мобильные нативные элементы управления**: touch-friendly навигация, компактные layout, голосовой ввод, вложения, уведомления и действия одной рукой.
- **Workspace уровня desktop**: широкие экраны получают split panes, side panels, списки sessions, поверхности Review и детали context без ощущения сжатого мобильного вида.
- **Живая операционная обратная связь**: вывод shell, ожидающие вопросы, permissions, todos, использование context и активность session остаются видимыми во время выполнения работы.
- **Предсказуемое управление серверами**: записи серверов легко просматривать, обновлять, редактировать, удалять и подключать заново.

## Основные возможности

- Управление несколькими удаленными серверами OpenCode с простого домашнего экрана.
- Проверка состояния и совместимости сервера перед входом в workspace.
- Просмотр проектов и sessions, включая недавние prompts и активные child sessions.
- Общение с sessions OpenCode через slash commands, вложения, выбор модели и controls reasoning.
- Ответы на ожидающие вопросы и запросы permissions без потери места в разговоре.
- Просмотр использования context, файлов, review diffs, inbox items, todos и активности shell в отдельных панелях.
- Запуск terminal tabs, когда направляемого UI недостаточно.
- Адаптивные layout для телефонов, планшетов, ноутбуков и desktop-дисплеев.

## Совместимость

BOC ориентирован на OpenCode `1.4.3`. Текущая release-prep валидация фокусируется на connection probing, загрузке workspace/session, chat, shell и terminal flows, ожидающих вопросах, permission requests, панелях review/files/context и адаптивных многопанельных layout.

Поддерживаемые клиентские платформы:

- iOS
- Android
- macOS
- Windows

Сервер OpenCode по-прежнему работает удаленно; BOC — это клиентская поверхность для подключения к нему, а не замена самого сервера.

## Требования

- Flutter с Dart SDK, совместимым с `^3.11.1`
- Доступный сервер OpenCode `1.4.3`
- Платформенные toolchains для целевых платформ: iOS, Android, macOS или Windows

## Начало работы

```bash
flutter pub get
flutter run
```

Затем добавьте свой сервер OpenCode на домашнем экране, убедитесь, что probe подключения проходит, и откройте workspace.

Запуск на конкретном устройстве:

```bash
flutter devices
flutter run -d <device-id>
```

## Разработка

Используйте те же проверки, что и CI проекта:

```bash
flutter analyze
flutter test
```

## Статус проекта

BOC готовится к выпуску. Сейчас фокус — стабильность, предсказуемый кроссплатформенный UX и совместимость с поддерживаемой версией OpenCode.
