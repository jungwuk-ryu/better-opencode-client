# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Іконка застосунку BOC" width="112">
</p>

Віддалений OpenCode без прив'язки до робочого столу.

BOC — це кросплатформний Flutter-клієнт для віддаленого використання OpenCode з iOS, Android, macOS і Windows. Він спроєктований навколо сумісності з OpenCode `1.4.3` і зосереджений на роботі, яка справді потрібна, коли ви не біля основної робочої станції: підключення до сервера, відновлення workspace, відстеження sessions, відповіді на запити, перегляд context і запуск shell-команди за потреби.

Маєте широкий екран?

![Багатопанельний workspace BOC](assets/readme/multi-pane.png)

BOC може розгортатися в багатопанельний командний центр для моніторингу sessions, Review, файлів, context, виводу shell і паралельної активності workspace.

## Чому BOC

- **Remote-first workflow**: зберігайте сервери OpenCode, перевіряйте стан підключення і швидко повертайтеся до потрібного workspace.
- **Mobile-native керування**: зручна для дотику навігація, компактні layouts, голосове введення, вкладення файлів, сповіщення і дії однією рукою.
- **Workspace рівня desktop**: широкі екрани отримують split panes, side panels, списки sessions, поверхні Review і деталі context без тісного мобільного вигляду.
- **Живий операційний feedback**: вивід shell, очікувані питання, permissions, todos, використання context і активність session залишаються видимими під час роботи.
- **Передбачуване керування серверами**: записи серверів легко переглядати, оновлювати, редагувати, видаляти і повторно підключати.

## Основні можливості

- Керуйте кількома віддаленими серверами OpenCode з простого домашнього екрана.
- Перевіряйте стан і сумісність сервера перед входом у workspace.
- Переглядайте проєкти та sessions, включно з нещодавніми prompts і активними child sessions.
- Спілкуйтеся з sessions OpenCode за допомогою slash commands, вкладень, вибору моделі й controls reasoning.
- Відповідайте на очікувані питання і permission requests, не втрачаючи місця в розмові.
- Переглядайте використання context, файли, review diffs, inbox items, todos і shell-активність в окремих панелях.
- Запускайте terminal tabs, коли керованого UI недостатньо.
- Використовуйте адаптивні layouts на телефонах, планшетах, ноутбуках і desktop-дисплеях.

## Сумісність

BOC орієнтується на OpenCode `1.4.3`. Поточна release-prep валідація фокусується на connection probing, завантаженні workspace/session, chat, shell і terminal flows, очікуваних питаннях, permission requests, панелях review/files/context і адаптивних багатопанельних layouts.

Підтримувані клієнтські платформи:

- iOS
- Android
- macOS
- Windows

Сервер OpenCode і далі працює віддалено; BOC — це клієнтська поверхня для підключення до нього, а не заміна самого сервера.

## Вимоги

- Flutter з Dart SDK, сумісним із `^3.11.1`
- Доступний сервер OpenCode `1.4.3`
- Platform toolchains для цілей, які ви плануєте запускати: iOS, Android, macOS або Windows

## Початок роботи

```bash
flutter pub get
flutter run
```

Потім додайте свій сервер OpenCode з домашнього екрана, підтвердьте успішний connection probe і відкрийте workspace.

Для запуску на конкретному пристрої:

```bash
flutter devices
flutter run -d <device-id>
```

## Розробка

Використовуйте ті самі перевірки, що й CI проєкту:

```bash
flutter analyze
flutter test
```

## Статус проєкту

BOC готується до release. Поточний фокус — стабільність, передбачуваний cross-platform UX і сумісність із підтримуваною версією OpenCode.
