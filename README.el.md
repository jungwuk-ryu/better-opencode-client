# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Εικονίδιο εφαρμογής BOC" width="112">
</p>

Απομακρυσμένο OpenCode, χωρίς να είστε κολλημένοι στο γραφείο σας.

Το BOC είναι ένας cross-platform Flutter client για απομακρυσμένη χρήση του OpenCode από iOS, Android, macOS και Windows. Είναι σχεδιασμένο γύρω από συμβατότητα με OpenCode `1.4.3` και εστιάζει στη δουλειά που πραγματικά χρειάζεστε όταν είστε μακριά από τον κύριο σταθμό εργασίας σας: σύνδεση σε server, συνέχιση workspace, παρακολούθηση sessions, απάντηση σε αιτήματα, επιθεώρηση context και εκτέλεση shell command όταν χρειάζεται.

Έχετε μεγάλη οθόνη;

![BOC multi-pane workspace](assets/readme/multi-pane.png)

Το BOC μπορεί να επεκταθεί σε ένα multi-pane command center για παρακολούθηση sessions, Review, αρχεία, context, shell output και παράλληλη δραστηριότητα workspace.

## Γιατί BOC

- **Remote-first workflow**: αποθηκεύστε OpenCode servers, ελέγξτε την κατάσταση σύνδεσης και επιστρέψτε γρήγορα στο σωστό workspace.
- **Mobile-native controls**: touch-friendly navigation, compact layouts, voice input, file attachments, notifications και one-hand actions.
- **Desktop-grade workspace**: οι μεγάλες οθόνες παίρνουν split panes, side panels, session lists, Review surfaces και context details χωρίς να γίνονται στριμωγμένη mobile view.
- **Live operational feedback**: shell output, pending questions, permissions, todos, context usage και session activity παραμένουν ορατά όσο τρέχει η δουλειά.
- **Predictable server management**: τα server entries είναι εύκολο να σαρωθούν, να ανανεωθούν, να επεξεργαστούν, να διαγραφούν και να επανασυνδεθούν.

## Κύρια χαρακτηριστικά

- Διαχειριστείτε πολλούς remote OpenCode servers από μια απλή home screen.
- Ελέγξτε server health και compatibility πριν μπείτε σε workspace.
- Περιηγηθείτε σε projects και sessions, συμπεριλαμβανομένων recent prompts και active child sessions.
- Συνομιλήστε με OpenCode sessions χρησιμοποιώντας slash commands, attachments, model selection και reasoning controls.
- Απαντήστε σε pending questions και permission requests χωρίς να χάσετε τη θέση σας στη συνομιλία.
- Επιθεωρήστε context usage, files, review diffs, inbox items, todos και shell activity από dedicated panes.
- Εκτελέστε terminal tabs όταν ένα guided UI δεν αρκεί.
- Χρησιμοποιήστε adaptive layouts σε phones, tablets, laptops και desktop displays.

## Συμβατότητα

Το BOC στοχεύει OpenCode `1.4.3`. Η τρέχουσα release-prep validation εστιάζει σε connection probing, workspace/session loading, chat, shell και terminal flows, pending questions, permission requests, review/files/context panes και adaptive multi-pane layouts.

Υποστηριζόμενες client platforms:

- iOS
- Android
- macOS
- Windows

Ο OpenCode server εξακολουθεί να τρέχει απομακρυσμένα· το BOC είναι η client surface για σύνδεση σε αυτόν, όχι αντικατάσταση του ίδιου του server.

## Απαιτήσεις

- Flutter με Dart SDK συμβατό με `^3.11.1`
- Προσβάσιμος OpenCode `1.4.3` server
- Platform toolchains για τους στόχους που θέλετε να τρέξετε: iOS, Android, macOS ή Windows

## Ξεκινώντας

```bash
flutter pub get
flutter run
```

Στη συνέχεια προσθέστε τον OpenCode server σας από την home screen, επιβεβαιώστε ότι το connection probe περνά και ανοίξτε ένα workspace.

Για εκτέλεση σε συγκεκριμένη συσκευή:

```bash
flutter devices
flutter run -d <device-id>
```

## Ανάπτυξη

Χρησιμοποιήστε τους ίδιους ελέγχους με το CI του project:

```bash
flutter analyze
flutter test
```

## Κατάσταση project

Το BOC προετοιμάζεται για release. Η τρέχουσα εστίαση είναι σταθερότητα, προβλέψιμο cross-platform UX και συμβατότητα με την υποστηριζόμενη έκδοση OpenCode.
