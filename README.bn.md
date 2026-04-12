# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC অ্যাপ আইকন" width="112">
</p>

ডেস্কে আটকে না থেকেও দূর থেকে OpenCode ব্যবহার করুন।

BOC হলো iOS, Android, macOS এবং Windows থেকে দূরবর্তীভাবে OpenCode ব্যবহারের জন্য একটি cross-platform Flutter client। এটি OpenCode `1.4.3` compatibility মাথায় রেখে তৈরি, এবং আপনি প্রধান workstation থেকে দূরে থাকলে যে কাজগুলো সত্যিই দরকার সেগুলোর উপর ফোকাস করে: server connect করা, workspace resume করা, sessions follow করা, requests-এর উত্তর দেওয়া, context inspect করা, এবং প্রয়োজনে shell command চালানো।

আপনার কি wide screen আছে?

![BOC multi-pane workspace](assets/readme/multi-pane.png)

BOC session monitoring, Review, files, context, shell output এবং parallel workspace activity-এর জন্য একটি multi-pane command center হিসেবে বিস্তৃত হতে পারে।

## কেন BOC

- **Remote-first workflow**: OpenCode servers সংরক্ষণ করুন, connection status দেখুন, এবং দ্রুত সঠিক workspace-এ ফিরে যান।
- **Mobile-native controls**: touch-friendly navigation, compact layouts, voice input, file attachments, notifications এবং one-hand actions।
- **Desktop-grade workspace**: wide screen-এ split panes, side panels, session lists, Review surfaces এবং context details পাওয়া যায়, কিন্তু UI cramped mobile view হয়ে যায় না।
- **Live operational feedback**: কাজ চলাকালীন shell output, pending questions, permissions, todos, context usage এবং session activity দৃশ্যমান থাকে।
- **Predictable server management**: server entries scan, refresh, edit, delete এবং reconnect করা সহজ।

## মূল বৈশিষ্ট্য

- সহজ home screen থেকে একাধিক remote OpenCode server পরিচালনা করুন।
- workspace-এ ঢোকার আগে server health এবং compatibility probe করুন।
- recent prompts এবং active child sessions সহ projects এবং sessions browse করুন।
- slash commands, attachments, model selection এবং reasoning controls ব্যবহার করে OpenCode sessions-এর সাথে chat করুন।
- conversation-এ নিজের জায়গা না হারিয়ে pending questions এবং permission requests-এর উত্তর দিন।
- dedicated panes থেকে context usage, files, review diffs, inbox items, todos এবং shell activity inspect করুন।
- guided UI যথেষ্ট না হলে terminal tabs চালান।
- phones, tablets, laptops এবং desktop displays-এ adaptive layouts ব্যবহার করুন।

## সামঞ্জস্যতা

BOC OpenCode `1.4.3` লক্ষ্য করে। বর্তমান release-prep validation connection probing, workspace/session loading, chat, shell এবং terminal flows, pending questions, permission requests, review/files/context panes এবং adaptive multi-pane layouts-এর উপর ফোকাস করে।

সমর্থিত client platforms:

- iOS
- Android
- macOS
- Windows

OpenCode server এখনও remote-এ চলে; BOC হলো সেটির সাথে সংযোগের client surface, server নিজেই নয়।

## প্রয়োজনীয়তা

- `^3.11.1` compatible Dart SDK সহ Flutter
- পৌঁছানো যায় এমন OpenCode `1.4.3` server
- আপনি যে targets চালাতে চান তার platform toolchains: iOS, Android, macOS অথবা Windows

## শুরু করা

```bash
flutter pub get
flutter run
```

এরপর home screen থেকে আপনার OpenCode server যোগ করুন, connection probe pass করছে নিশ্চিত করুন, এবং workspace খুলুন।

নির্দিষ্ট device-এ চালানোর জন্য:

```bash
flutter devices
flutter run -d <device-id>
```

## ডেভেলপমেন্ট

project CI-এর মতো একই checks ব্যবহার করুন:

```bash
flutter analyze
flutter test
```

## প্রকল্পের অবস্থা

BOC release-এর জন্য প্রস্তুত হচ্ছে। এখন ফোকাস stability, predictable cross-platform UX, এবং supported OpenCode version-এর compatibility।
