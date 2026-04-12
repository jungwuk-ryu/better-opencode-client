# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="ไอคอนแอป BOC" width="112">
</p>

ใช้ OpenCode จากระยะไกล โดยไม่ต้องติดอยู่กับโต๊ะทำงาน

BOC คือไคลเอนต์ Flutter แบบข้ามแพลตฟอร์มสำหรับใช้ OpenCode จากระยะไกลบน iOS, Android, macOS และ Windows ออกแบบโดยคำนึงถึงความเข้ากันได้กับ OpenCode `1.4.3` และเน้นงานที่คุณต้องใช้จริงเมื่อไม่ได้อยู่หน้าเวิร์กสเตชันหลัก: เชื่อมต่อเซิร์ฟเวอร์, กลับเข้า workspace, ติดตาม sessions, ตอบคำขอ, ตรวจ context และรันคำสั่ง shell เมื่อจำเป็น

มีหน้าจอกว้างหรือไม่?

![workspace แบบหลายพาเนลของ BOC](assets/readme/multi-pane.png)

BOC สามารถขยายเป็นศูนย์ควบคุมแบบหลายพาเนลสำหรับติดตาม sessions, Review, ไฟล์, context, output ของ shell และกิจกรรม workspace แบบขนาน

## ทำไมต้อง BOC

- **เวิร์กโฟลว์ remote-first**: บันทึกเซิร์ฟเวอร์ OpenCode, ตรวจสถานะการเชื่อมต่อ และกลับไปยัง workspace ที่ถูกต้องได้รวดเร็ว
- **การควบคุมแบบ mobile-native**: การนำทางที่เหมาะกับการแตะ, layout แบบ compact, การป้อนเสียง, ไฟล์แนบ, การแจ้งเตือน และการใช้งานมือเดียว
- **workspace ระดับเดสก์ท็อป**: หน้าจอกว้างรองรับ split panes, side panels, รายการ sessions, พื้นที่ Review และรายละเอียด context โดยไม่กลายเป็นมุมมองมือถือที่อัดแน่น
- **ฟีดแบ็กการทำงานแบบสด**: output ของ shell, คำถามที่รออยู่, permissions, todos, การใช้ context และกิจกรรม session ยังมองเห็นได้ระหว่างที่งานทำงานอยู่
- **การจัดการเซิร์ฟเวอร์ที่คาดเดาได้**: รายการเซิร์ฟเวอร์ดูง่าย, refresh ได้, แก้ไขได้, ลบได้ และเชื่อมต่อใหม่ได้

## ฟีเจอร์หลัก

- จัดการเซิร์ฟเวอร์ OpenCode ระยะไกลหลายตัวจากหน้าหลักที่เรียบง่าย
- ตรวจสุขภาพและความเข้ากันได้ของเซิร์ฟเวอร์ก่อนเข้า workspace
- เรียกดู projects และ sessions รวมถึง prompts ล่าสุดและ child sessions ที่ทำงานอยู่
- แชตกับ OpenCode sessions ด้วย slash commands, attachments, การเลือกโมเดล และ reasoning controls
- ตอบคำถามและ permission requests ที่ค้างอยู่โดยไม่เสียตำแหน่งในบทสนทนา
- ตรวจ context usage, ไฟล์, review diffs, รายการ inbox, todos และกิจกรรม shell จากพาเนลเฉพาะ
- รัน terminal tabs เมื่อ UI แบบนำทางยังไม่พอ
- ใช้ layout แบบ adaptive บนโทรศัพท์ แท็บเล็ต แล็ปท็อป และจอเดสก์ท็อป

## ความเข้ากันได้

BOC มีเป้าหมายที่ OpenCode `1.4.3` การตรวจสอบเพื่อเตรียม release ในปัจจุบันเน้น connection probing, การโหลด workspace/session, chat, shell และ terminal flows, คำถามที่รออยู่, permission requests, พาเนล review/files/context และ layout หลายพาเนลแบบ adaptive

แพลตฟอร์มไคลเอนต์ที่รองรับ:

- iOS
- Android
- macOS
- Windows

เซิร์ฟเวอร์ OpenCode ยังคงทำงานจากระยะไกล; BOC เป็นหน้าจอไคลเอนต์สำหรับเชื่อมต่อกับเซิร์ฟเวอร์นั้น ไม่ใช่ตัวแทนของเซิร์ฟเวอร์เอง

## ข้อกำหนด

- Flutter พร้อม Dart SDK ที่เข้ากันได้กับ `^3.11.1`
- เซิร์ฟเวอร์ OpenCode `1.4.3` ที่เข้าถึงได้
- platform toolchains สำหรับเป้าหมายที่คุณต้องการรัน: iOS, Android, macOS หรือ Windows

## เริ่มต้นใช้งาน

```bash
flutter pub get
flutter run
```

จากนั้นเพิ่มเซิร์ฟเวอร์ OpenCode จากหน้าหลัก ยืนยันว่า connection probe ผ่าน แล้วเปิด workspace

สำหรับรันบนอุปกรณ์เฉพาะ:

```bash
flutter devices
flutter run -d <device-id>
```

## การพัฒนา

ใช้การตรวจสอบเดียวกับ CI ของโปรเจกต์:

```bash
flutter analyze
flutter test
```

## สถานะโปรเจกต์

BOC กำลังเตรียมพร้อมสำหรับ release ตอนนี้โฟกัสอยู่ที่ความเสถียร UX ข้ามแพลตฟอร์มที่คาดเดาได้ และความเข้ากันได้กับเวอร์ชัน OpenCode ที่รองรับ
