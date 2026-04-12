# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Icona dell'app BOC" width="112">
</p>

OpenCode da remoto, senza restare incollato alla scrivania.

BOC è un client Flutter multipiattaforma per usare OpenCode da remoto su iOS, Android, macOS e Windows. È progettato attorno alla compatibilità con OpenCode `1.4.3` e si concentra sul lavoro davvero necessario quando sei lontano dalla workstation principale: connetterti a un server, riprendere un workspace, seguire le sessioni, rispondere alle richieste, ispezionare il contesto ed eseguire qualche comando shell quando serve.

Hai uno schermo ampio?

![Workspace multi-pannello di BOC](assets/readme/multi-pane.png)

BOC può espandersi in un centro di comando multi-pannello per monitoraggio sessioni, Review, file, contesto, output shell e attività parallela del workspace.

## Perché BOC

- **Workflow remote-first**: salva server OpenCode, controlla lo stato della connessione e torna rapidamente al workspace giusto.
- **Controlli mobile-native**: navigazione touch-friendly, layout compatti, input vocale, allegati, notifiche e azioni a una mano.
- **Workspace di livello desktop**: gli schermi ampi ottengono split pane, pannelli laterali, liste sessioni, superfici di Review e dettagli del contesto senza diventare una vista mobile compressa.
- **Feedback operativo live**: output shell, domande in sospeso, permessi, todos, uso del contesto e attività della sessione restano visibili mentre il lavoro è in corso.
- **Gestione server prevedibile**: le voci server sono facili da scansionare, aggiornare, modificare, eliminare e riconnettere.

## Funzionalità principali

- Gestisci più server OpenCode remoti da una semplice schermata home.
- Verifica salute e compatibilità del server prima di entrare in un workspace.
- Sfoglia progetti e sessioni, inclusi prompt recenti e sessioni figlie attive.
- Chatta con sessioni OpenCode usando slash commands, allegati, selezione modello e controlli di reasoning.
- Rispondi a domande e richieste di permesso senza perdere il punto nella conversazione.
- Ispeziona uso del contesto, file, review diff, elementi inbox, todos e attività shell da pannelli dedicati.
- Avvia tab terminale quando una UI guidata non basta.
- Usa layout adattivi su telefoni, tablet, laptop e display desktop.

## Compatibilità

BOC punta a OpenCode `1.4.3`. L'attuale validazione di preparazione release copre probe di connessione, caricamento workspace/sessione, chat, flussi shell e terminale, domande in sospeso, richieste di permesso, pannelli review/files/context e layout multi-pannello adattivi.

Piattaforme client supportate:

- iOS
- Android
- macOS
- Windows

Il server OpenCode continua a girare da remoto; BOC è la superficie client per collegarsi ad esso, non un sostituto del server.

## Requisiti

- Flutter con un Dart SDK compatibile con `^3.11.1`
- Un server OpenCode `1.4.3` raggiungibile
- Toolchain di piattaforma per i target che vuoi eseguire: iOS, Android, macOS o Windows

## Per iniziare

```bash
flutter pub get
flutter run
```

Poi aggiungi il tuo server OpenCode dalla schermata home, conferma che il probe di connessione passi e apri un workspace.

Per eseguire su un dispositivo specifico:

```bash
flutter devices
flutter run -d <device-id>
```

## Sviluppo

Usa gli stessi controlli della CI del progetto:

```bash
flutter analyze
flutter test
```

## Stato del progetto

BOC è in preparazione per il rilascio. Il focus attuale è stabilità, UX cross-platform prevedibile e compatibilità con la versione supportata di OpenCode.
