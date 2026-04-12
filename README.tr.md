# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="BOC uygulama simgesi" width="112">
</p>

Masanıza bağlı kalmadan uzaktan OpenCode kullanın.

BOC, OpenCode'u iOS, Android, macOS ve Windows üzerinden uzaktan kullanmak için geliştirilmiş çapraz platform bir Flutter istemcisidir. OpenCode `1.4.3` uyumluluğu etrafında tasarlanmıştır ve ana iş istasyonunuzdan uzaktayken gerçekten ihtiyaç duyduğunuz işlere odaklanır: sunucuya bağlanma, workspace'e devam etme, session'ları izleme, istekleri yanıtlama, context'i inceleme ve gerektiğinde shell komutu çalıştırma.

Geniş ekranınız var mı?

![BOC çok panelli workspace](assets/readme/multi-pane.png)

BOC; session izleme, Review, dosyalar, context, shell çıktısı ve paralel workspace etkinliği için çok panelli bir komuta merkezine genişleyebilir.

## Neden BOC

- **Remote-first workflow**: OpenCode sunucularını kaydedin, bağlantı durumunu kontrol edin ve doğru workspace'e hızla geri dönün.
- **Mobil-native kontroller**: dokunmaya uygun gezinme, kompakt layout'lar, ses girişi, dosya ekleri, bildirimler ve tek elle işlemler.
- **Masaüstü düzeyinde workspace**: geniş ekranlar split panes, side panels, session listeleri, Review yüzeyleri ve context ayrıntılarını sıkışık bir mobil görünüm olmadan sunar.
- **Canlı operasyonel geri bildirim**: shell çıktısı, bekleyen sorular, permissions, todos, context kullanımı ve session etkinliği iş çalışırken görünür kalır.
- **Öngörülebilir sunucu yönetimi**: sunucu kayıtlarını taramak, yenilemek, düzenlemek, silmek ve yeniden bağlamak kolaydır.

## Temel özellikler

- Basit bir ana ekrandan birden fazla uzak OpenCode sunucusunu yönetin.
- Workspace'e girmeden önce sunucu sağlığını ve uyumluluğunu probe edin.
- Son prompt'lar ve aktif child sessions dahil project ve sessions arasında gezinin.
- Slash commands, ekler, model seçimi ve reasoning kontrolleriyle OpenCode sessions ile sohbet edin.
- Konuşmadaki yerinizi kaybetmeden bekleyen soruları ve permission requests'i yanıtlayın.
- Özel panellerden context kullanımı, dosyalar, review diffs, inbox öğeleri, todos ve shell etkinliğini inceleyin.
- Rehberli UI yeterli olmadığında terminal tab'ları çalıştırın.
- Telefonlar, tabletler, laptoplar ve masaüstü ekranlarda adaptive layout'lar kullanın.

## Uyumluluk

BOC, OpenCode `1.4.3` sürümünü hedefler. Mevcut release-prep doğrulaması connection probing, workspace/session loading, chat, shell ve terminal flows, bekleyen sorular, permission requests, review/files/context panelleri ve adaptive çok panelli layout'lara odaklanır.

Desteklenen istemci platformları:

- iOS
- Android
- macOS
- Windows

OpenCode sunucusu hâlâ uzakta çalışır; BOC ona bağlanmak için istemci yüzeyidir, sunucunun yerine geçmez.

## Gereksinimler

- `^3.11.1` ile uyumlu Dart SDK içeren Flutter
- Erişilebilir bir OpenCode `1.4.3` sunucusu
- Çalıştırmayı planladığınız hedefler için platform toolchain'leri: iOS, Android, macOS veya Windows

## Başlarken

```bash
flutter pub get
flutter run
```

Ardından ana ekrandan OpenCode sunucunuzu ekleyin, connection probe'un geçtiğini doğrulayın ve bir workspace açın.

Belirli bir cihazda çalıştırmak için:

```bash
flutter devices
flutter run -d <device-id>
```

## Geliştirme

Proje CI ile aynı kontrolleri kullanın:

```bash
flutter analyze
flutter test
```

## Proje durumu

BOC release için hazırlanıyor. Şu an odak noktası kararlılık, öngörülebilir çapraz platform UX ve desteklenen OpenCode sürümüyle uyumluluktur.
