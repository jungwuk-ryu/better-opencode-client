# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC ikona aplikacije" width="112">
</p>

Remote OpenCode, bez vezivanja za radni sto.

BOC je cross-platform Flutter klijent za korištenje OpenCode-a na daljinu sa iOS-a, Androida, macOS-a i Windowsa. Dizajniran je oko kompatibilnosti sa OpenCode `1.4.3` i fokusira se na posao koji stvarno trebaš kada nisi za glavnom radnom stanicom: povezivanje na server, nastavak workspacea, praćenje sesija, odgovaranje na zahtjeve, pregled contexta i povremeno pokretanje shell komande.

Imaš širok ekran?

![BOC multi-panel workspace](assets/readme/multi-pane.png)

BOC se može proširiti u multi-panel komandni centar za praćenje sesija, Review, fajlove, context, shell output i paralelnu workspace aktivnost.

## Zašto BOC

- **Remote-first workflow**: sačuvaj OpenCode servere, provjeri status konekcije i brzo se vrati u pravi workspace.
- **Mobile-native kontrole**: navigacija prilagođena dodiru, kompaktni layouti, glasovni unos, prilozi, notifikacije i radnje jednom rukom.
- **Desktop-grade workspace**: široki ekrani dobijaju split panes, side panels, liste sesija, Review površine i detalje contexta bez zbijenog mobilnog prikaza.
- **Live operativni feedback**: shell output, pitanja na čekanju, permissions, todos, context usage i aktivnost sesije ostaju vidljivi dok se posao izvršava.
- **Predvidljivo upravljanje serverima**: server unose je lako pregledati, osvježiti, urediti, obrisati i ponovo povezati.

## Ključne funkcije

- Upravljaj s više remote OpenCode servera sa jednostavnog home ekrana.
- Provjeri health i kompatibilnost servera prije ulaska u workspace.
- Pregledaj projekte i sesije, uključujući nedavne promptove i aktivne child sessions.
- Razgovaraj sa OpenCode sesijama koristeći slash commands, priloge, izbor modela i reasoning kontrole.
- Odgovaraj na pitanja i permission requests bez gubljenja mjesta u razgovoru.
- Pregledaj context usage, fajlove, review diffs, inbox stavke, todos i shell aktivnost iz posebnih panela.
- Pokreni terminal tabove kada vođeni UI nije dovoljan.
- Koristi adaptivne layoute na telefonima, tabletima, laptopima i desktop ekranima.

## Kompatibilnost

BOC cilja OpenCode `1.4.3`. Trenutna release-prep validacija fokusira se na connection probing, workspace/session loading, chat, shell i terminal flows, pitanja na čekanju, permission requests, review/files/context panele i adaptivne multi-panel layoute.

Podržane klijentske platforme:

- iOS
- Android
- macOS
- Windows

OpenCode server i dalje radi remote; BOC je klijentska površina za povezivanje s njim, a ne zamjena za sam server.

## Zahtjevi

- Flutter sa Dart SDK kompatibilnim sa `^3.11.1`
- Dostupan OpenCode `1.4.3` server
- Platform toolchains za ciljeve koje planiraš pokrenuti: iOS, Android, macOS ili Windows

## Početak

```bash
flutter pub get
flutter run
```

Zatim dodaj svoj OpenCode server sa home ekrana, potvrdi da connection probe prolazi i otvori workspace.

Za pokretanje na određenom uređaju:

```bash
flutter devices
flutter run -d <device-id>
```

## Razvoj

Koristi iste provjere kao projektni CI:

```bash
flutter analyze
flutter test
```

## Status projekta

BOC se priprema za release. Trenutni fokus su stabilnost, predvidljiv cross-platform UX i kompatibilnost sa podržanom OpenCode verzijom.
