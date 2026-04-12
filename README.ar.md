# Better OpenCode Client (BOC)

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Deutsch](README.de.md) | [Español](README.es.md) | [Français](README.fr.md) | [Italiano](README.it.md) | [Dansk](README.da.md) | [日本語](README.ja.md) | [Polski](README.pl.md) | [Русский](README.ru.md) | [Bosanski](README.bs.md) | [العربية](README.ar.md) | [Norsk](README.no.md) | [Português (Brasil)](README.pt-BR.md) | [ไทย](README.th.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [বাংলা](README.bn.md) | [Ελληνικά](README.el.md) | [Tiếng Việt](README.vi.md)

<p align="center">
  <img src="assets/readme/app-icon.png" alt="أيقونة تطبيق BOC" width="112">
</p>

استخدم OpenCode عن بُعد من دون أن تبقى ملازمًا لمكتبك.

BOC هو عميل Flutter متعدد المنصات لاستخدام OpenCode عن بُعد من iOS و Android و macOS و Windows. صُمم حول التوافق مع OpenCode `1.4.3` ويركز على العمل الذي تحتاجه فعلاً عندما تكون بعيدًا عن محطة العمل الأساسية: الاتصال بخادم، استئناف workspace، متابعة sessions، الرد على الطلبات، فحص context، وتشغيل أمر shell عند الحاجة.

هل لديك شاشة واسعة؟

![مساحة عمل BOC متعددة اللوحات](assets/readme/multi-pane.png)

يمكن لـ BOC أن يتمدد إلى مركز قيادة متعدد اللوحات لمراقبة sessions و Review والملفات و context ومخرجات shell ونشاط workspace المتوازي.

## لماذا BOC

- **سير عمل remote-first**: احفظ خوادم OpenCode، تحقق من حالة الاتصال، وعد بسرعة إلى workspace الصحيح.
- **عناصر تحكم مناسبة للموبايل**: تنقل مناسب للمس، تخطيطات مدمجة، إدخال صوتي، مرفقات ملفات، إشعارات، وإجراءات بيد واحدة.
- **Workspace بمستوى سطح المكتب**: الشاشات الواسعة تحصل على split panes و side panels وقوائم sessions ومساحات Review وتفاصيل context من دون أن تبدو كواجهة موبايل مزدحمة.
- **تغذية راجعة مباشرة للعمل**: تبقى مخرجات shell والأسئلة المعلقة والأذونات و todos واستخدام context ونشاط session مرئية أثناء تشغيل العمل.
- **إدارة خوادم متوقعة**: من السهل استعراض إدخالات الخوادم وتحديثها وتعديلها وحذفها وإعادة الاتصال بها.

## الميزات الأساسية

- إدارة عدة خوادم OpenCode بعيدة من شاشة رئيسية بسيطة.
- فحص صحة الخادم وتوافقه قبل الدخول إلى workspace.
- تصفح المشاريع و sessions، بما في ذلك prompts الأخيرة و child sessions النشطة.
- الدردشة مع sessions الخاصة بـ OpenCode باستخدام slash commands والمرفقات واختيار النموذج وتحكمات reasoning.
- الرد على الأسئلة المعلقة وطلبات الأذونات من دون فقدان موقعك في المحادثة.
- فحص استخدام context والملفات و review diffs وعناصر inbox و todos ونشاط shell من لوحات مخصصة.
- تشغيل terminal tabs عندما لا تكفي الواجهة الموجهة.
- استخدام تخطيطات تكيفية عبر الهواتف والأجهزة اللوحية واللابتوبات وشاشات سطح المكتب.

## التوافق

يستهدف BOC إصدار OpenCode `1.4.3`. تركز عملية التحقق الحالية لتحضير الإصدار على connection probing وتحميل workspace/session والدردشة وتدفقات shell و terminal والأسئلة المعلقة وطلبات الأذونات ولوحات review/files/context والتخطيطات متعددة اللوحات التكيفية.

منصات العميل المدعومة:

- iOS
- Android
- macOS
- Windows

لا يزال خادم OpenCode يعمل عن بُعد؛ BOC هو واجهة العميل للاتصال به، وليس بديلاً عن الخادم نفسه.

## المتطلبات

- Flutter مع Dart SDK متوافق مع `^3.11.1`
- خادم OpenCode `1.4.3` يمكن الوصول إليه
- أدوات المنصة للأهداف التي تخطط لتشغيلها: iOS أو Android أو macOS أو Windows

## البدء

```bash
flutter pub get
flutter run
```

بعد ذلك أضف خادم OpenCode من الشاشة الرئيسية، وتأكد من نجاح فحص الاتصال، ثم افتح workspace.

للتشغيل على جهاز محدد:

```bash
flutter devices
flutter run -d <device-id>
```

## التطوير

استخدم نفس الفحوصات التي يستخدمها CI للمشروع:

```bash
flutter analyze
flutter test
```

## حالة المشروع

BOC قيد التحضير للإصدار. ينصب التركيز الآن على الاستقرار وتجربة استخدام متوقعة عبر المنصات والتوافق مع إصدار OpenCode المدعوم.
