# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC appikon" width="112">
</p>

Brug OpenCode remote, uden at være bundet til skrivebordet.

BOC er en Flutter-klient på tværs af platforme til at bruge OpenCode remote fra iOS, Android, macOS og Windows. Den er designet omkring kompatibilitet med OpenCode `1.4.3` og fokuserer på det arbejde, du faktisk har brug for, når du er væk fra din primære workstation: forbind til en server, genoptag et workspace, følg sessions, besvar anmodninger, inspicér context og kør en shell-kommando ved behov.

Har du en bred skærm?

![BOC multi-panel workspace](assets/readme/multi-pane.png)

BOC kan foldes ud til et multi-panel command center til session-overvågning, Review, filer, context, shell-output og parallel workspace-aktivitet.

## Hvorfor BOC

- **Remote-first workflow**: gem OpenCode-servere, tjek forbindelsesstatus og hop hurtigt tilbage til det rigtige workspace.
- **Mobile-native kontroller**: touchvenlig navigation, kompakte layouts, stemmeinput, filvedhæftninger, notifikationer og enhåndshandlinger.
- **Desktop-grade workspace**: brede skærme får split panes, side panels, sessionslister, Review-flader og context-detaljer uden at blive til en trang mobilvisning.
- **Live operationel feedback**: shell-output, afventende spørgsmål, permissions, todos, context-forbrug og session-aktivitet forbliver synlige, mens arbejdet kører.
- **Forudsigelig serverstyring**: serverposter er nemme at skimme, opdatere, redigere, slette og forbinde igen.

## Kernefunktioner

- Administrer flere remote OpenCode-servere fra en enkel startskærm.
- Probe serverens health og kompatibilitet, før du går ind i et workspace.
- Gennemse projekter og sessions, inklusive seneste prompts og aktive child sessions.
- Chat med OpenCode-sessions med slash commands, vedhæftninger, modelvalg og reasoning-kontroller.
- Besvar afventende spørgsmål og permission requests uden at miste din plads i samtalen.
- Inspicér context-forbrug, filer, review diffs, inbox-elementer, todos og shell-aktivitet fra dedikerede paneler.
- Kør terminal-tabs, når en guidet UI ikke er nok.
- Brug adaptive layouts på telefoner, tablets, laptops og desktop-skærme.

## Kompatibilitet

BOC målretter OpenCode `1.4.3`. Den nuværende release-prep-validering fokuserer på connection probing, workspace/session loading, chat, shell- og terminalflows, afventende spørgsmål, permission requests, review/files/context-paneler og adaptive multi-panel layouts.

Understøttede klientplatforme:

- iOS
- Android
- macOS
- Windows

OpenCode-serveren kører stadig remote; BOC er klientfladen til at forbinde til den, ikke en erstatning for selve serveren.

## Krav

- Flutter med en Dart SDK kompatibel med `^3.11.1`
- En tilgængelig OpenCode `1.4.3` server
- Platform-toolchains til de mål, du vil køre: iOS, Android, macOS eller Windows

## Kom godt i gang

```bash
flutter pub get
flutter run
```

Tilføj derefter din OpenCode-server fra startskærmen, bekræft at connection probe lykkes, og åbn et workspace.

For at køre på en bestemt enhed:

```bash
flutter devices
flutter run -d <device-id>
```

## Udvikling

Brug de samme checks som projektets CI:

```bash
flutter analyze
flutter test
```

## Projektstatus

BOC forberedes til release. Fokus er lige nu stabilitet, forudsigelig cross-platform UX og kompatibilitet med den understøttede OpenCode-version.
