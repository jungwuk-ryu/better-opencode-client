# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="Ikona aplikacji BOC" width="112">
</p>

Zdalny OpenCode, bez przywiązania do biurka.

BOC to wieloplatformowy klient Flutter do zdalnego używania OpenCode na iOS, Androidzie, macOS i Windows. Jest projektowany pod kompatybilność z OpenCode `1.4.3` i skupia się na pracy, której naprawdę potrzebujesz poza główną stacją roboczą: połączenie z serwerem, wznowienie workspace, śledzenie sesji, odpowiadanie na żądania, inspekcja kontekstu i okazjonalne uruchomienie polecenia shell.

Masz szeroki ekran?

![Wielopanelowy workspace BOC](assets/readme/multi-pane.png)

BOC może rozwinąć się w wielopanelowe centrum dowodzenia do monitorowania sesji, Review, plików, kontekstu, wyjścia shell i równoległej aktywności workspace.

## Dlaczego BOC

- **Workflow remote-first**: zapisuj serwery OpenCode, sprawdzaj stan połączenia i szybko wracaj do właściwego workspace.
- **Kontrolki natywne dla urządzeń mobilnych**: nawigacja przyjazna dotykowi, kompaktowe layouty, wejście głosowe, załączniki, powiadomienia i akcje jedną ręką.
- **Workspace klasy desktop**: szerokie ekrany dostają split panes, side panels, listy sesji, powierzchnie Review i szczegóły kontekstu bez ciasnego widoku mobilnego.
- **Informacje operacyjne na żywo**: wyjście shell, oczekujące pytania, uprawnienia, todos, użycie kontekstu i aktywność sesji pozostają widoczne podczas pracy.
- **Przewidywalne zarządzanie serwerami**: wpisy serwerów łatwo przeglądać, odświeżać, edytować, usuwać i ponownie łączyć.

## Główne funkcje

- Zarządzanie wieloma zdalnymi serwerami OpenCode z prostego ekranu startowego.
- Sprawdzanie zdrowia i kompatybilności serwera przed wejściem do workspace.
- Przeglądanie projektów i sesji, w tym ostatnich promptów i aktywnych sesji potomnych.
- Czat z sesjami OpenCode przy użyciu slash commands, załączników, wyboru modelu i kontrolek reasoning.
- Odpowiadanie na oczekujące pytania i żądania uprawnień bez utraty miejsca w rozmowie.
- Inspekcja użycia kontekstu, plików, review diffów, elementów inbox, todos i aktywności shell w dedykowanych panelach.
- Uruchamianie kart terminala, gdy prowadzona UI nie wystarcza.
- Adaptacyjne layouty na telefonach, tabletach, laptopach i monitorach desktopowych.

## Kompatybilność

BOC celuje w OpenCode `1.4.3`. Obecna walidacja przygotowania do release skupia się na connection probing, ładowaniu workspace/sesji, czacie, przepływach shell i terminala, oczekujących pytaniach, żądaniach uprawnień, panelach review/files/context oraz adaptacyjnych layoutach wielopanelowych.

Obsługiwane platformy klienta:

- iOS
- Android
- macOS
- Windows

Serwer OpenCode nadal działa zdalnie; BOC jest powierzchnią klienta do połączenia z nim, a nie zamiennikiem samego serwera.

## Wymagania

- Flutter z Dart SDK kompatybilnym z `^3.11.1`
- Dostępny serwer OpenCode `1.4.3`
- Toolchainy platform dla celów, które chcesz uruchamiać: iOS, Android, macOS lub Windows

## Pierwsze kroki

```bash
flutter pub get
flutter run
```

Następnie dodaj swój serwer OpenCode z ekranu startowego, potwierdź, że probe połączenia przechodzi, i otwórz workspace.

Uruchamianie na konkretnym urządzeniu:

```bash
flutter devices
flutter run -d <device-id>
```

## Rozwój

Użyj tych samych sprawdzeń co CI projektu:

```bash
flutter analyze
flutter test
```

## Status projektu

BOC jest przygotowywany do wydania. Obecny nacisk to stabilność, przewidywalny cross-platform UX i kompatybilność z obsługiwaną wersją OpenCode.
