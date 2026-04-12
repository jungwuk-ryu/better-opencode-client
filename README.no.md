# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC appikon" width="112">
</p>

Bruk OpenCode eksternt, uten å sitte fast ved skrivebordet.

BOC er en Flutter-klient på tvers av plattformer for å bruke OpenCode eksternt fra iOS, Android, macOS og Windows. Den er designet rundt kompatibilitet med OpenCode `1.4.3` og fokuserer på arbeidet du faktisk trenger når du er borte fra hovedmaskinen: koble til en server, gjenoppta et workspace, følge sessions, svare på forespørsler, inspisere context og kjøre en shell-kommando ved behov.

Har du en bred skjerm?

![BOC multi-panel workspace](assets/readme/multi-pane.png)

BOC kan utvides til et multi-panel kommandosenter for session-overvåking, Review, filer, context, shell-output og parallell workspace-aktivitet.

## Hvorfor BOC

- **Remote-first workflow**: lagre OpenCode-servere, sjekk tilkoblingsstatus og kom raskt tilbake til riktig workspace.
- **Mobile-native kontroller**: berøringsvennlig navigasjon, kompakte layouter, stemmeinndata, filvedlegg, varsler og enhåndshandlinger.
- **Desktop-grade workspace**: brede skjermer får split panes, side panels, session-lister, Review-flater og context-detaljer uten å bli en trang mobilvisning.
- **Live operasjonell feedback**: shell-output, ventende spørsmål, permissions, todos, context-bruk og session-aktivitet forblir synlige mens arbeidet kjører.
- **Forutsigbar serveradministrasjon**: serveroppføringer er enkle å skanne, oppdatere, redigere, slette og koble til på nytt.

## Kjernefunksjoner

- Administrer flere eksterne OpenCode-servere fra en enkel startskjerm.
- Probe serverens helse og kompatibilitet før du går inn i et workspace.
- Bla gjennom prosjekter og sessions, inkludert nylige prompts og aktive child sessions.
- Chat med OpenCode-sessions med slash commands, vedlegg, modellvalg og reasoning-kontroller.
- Svar på ventende spørsmål og permission requests uten å miste plassen i samtalen.
- Inspiser context-bruk, filer, review diffs, inbox-elementer, todos og shell-aktivitet fra dedikerte paneler.
- Kjør terminal-tabs når en guidet UI ikke er nok.
- Bruk adaptive layouter på telefoner, nettbrett, laptoper og desktop-skjermer.

## Kompatibilitet

BOC retter seg mot OpenCode `1.4.3`. Den nåværende release-prep-valideringen fokuserer på connection probing, workspace/session loading, chat, shell- og terminalflows, ventende spørsmål, permission requests, review/files/context-paneler og adaptive multi-panel layouter.

Støttede klientplattformer:

- iOS
- Android
- macOS
- Windows

OpenCode-serveren kjører fortsatt eksternt; BOC er klientflaten for å koble til den, ikke en erstatning for selve serveren.

## Krav

- Flutter med en Dart SDK kompatibel med `^3.11.1`
- En tilgjengelig OpenCode `1.4.3` server
- Plattform-toolchains for målene du vil kjøre: iOS, Android, macOS eller Windows

## Kom i gang

```bash
flutter pub get
flutter run
```

Legg deretter til OpenCode-serveren din fra startskjermen, bekreft at tilkoblingsproben passerer, og åpne et workspace.

For å kjøre på en bestemt enhet:

```bash
flutter devices
flutter run -d <device-id>
```

## Utvikling

Bruk de samme sjekkene som prosjektets CI:

```bash
flutter analyze
flutter test
```

## Prosjektstatus

BOC forberedes for release. Fokuset nå er stabilitet, forutsigbar cross-platform UX og kompatibilitet med den støttede OpenCode-versjonen.
