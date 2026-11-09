# Ripple Tank – محاكي حوض الأمواج

محاكي فيزيائي للأمواج مبني بـ Flutter وDart. يشتغل على **Android وiPhone والويب**.

المحاكاة حقيقية: شبكة 180×180 تُحسب فيها معادلة الموجة بطريقة الفروق المحدودة:

```
u_next = (2·u − u_prev + c²·∇²u) · damping
```

---

## 1) أول تشغيل (مرة وحدة بس)

تحتاج Flutter بإصدار **3.27 أو أحدث** (`flutter --version`).

```bash
cd ripple_tank
flutter create --org com.muhaymin --project-name ripple_tank --platforms android,ios,web .
flutter pub get
```

أمر `flutter create .` يولّد مجلدات android وios وweb فقط، وما يغيّر ملفات `lib/` ولا `test/`.

## 2) أوامر التحقق

```bash
flutter analyze
flutter test
flutter run            # على جهاز أندرويد موصول أو محاكي
```

## 3) استخراج APK لأندرويد

```bash
flutter build apk --release
```

الملف يطلع هنا: `build/app/outputs/flutter-apk/app-release.apk`

## 4) التجربة على الآيفون

- **بدون ماك (الأسهل):** شغّل
  ```bash
  flutter build web --release
  ```
  بعدها ارفع مجلد `build/web` على أي استضافة مجانية (Netlify Drop أو GitHub Pages)، وافتح الرابط من Safari بالآيفون. ومن زر المشاركة اختار «إضافة إلى الشاشة الرئيسية» حتى يصير مثل التطبيق.
- **كتطبيق iOS حقيقي:** تحتاج Mac عليه Xcode. افتح `ios/Runner.xcworkspace`، واختار حساب Apple بقسم Signing، ووصّل الآيفون، وبعدها شغّل `flutter run`.

---

## الخصائص

| القسم | الوظائف |
|---|---|
| مصادر الأمواج | نقطي، خطي (موجات مستوية)، مزدوج، متعدد الأقطاب. تصدر تلقائياً وباستمرار، وتكمل الإصدار حتى أثناء التحريك |
| العوائق | صندوق صلب، جدار، شق مفرد، شق مزدوج، مرآة مكافئة (تعكس وتركّز في البؤرة) |
| الأوساط | وسط مستطيل، عدسة محدبة، منشور. لكل وسط معامل سرعة مستقل (n = 1/v) |
| القياسات | مجسات بألوان مختلفة: لكل مجس رقم وموقع، والسعة الحالية وأعلى سعة، وسجل آخر 100 قراءة، ورسم بياني مباشر، وزر حذف |
| العرض | 2D، و3D بشبكة 60×60 (التدوير بالسحب والتكبير بإصبعين) |
| الحركة | تشغيل وإيقاف (الإيقاف يحافظ على الحالة)، وسرعة المحاكاة، والتردد، والتخميد، وسرعة الموجة |
| الألوان | سماوي، أخضر، تباين عالٍ، مع سطوع من 50% إلى 300% |
| الأدوات | تحريك، تموّج يدوي، إضافة مصدر، رسم عائق، رسم وسط، مجس، نص |
| التجارب | الشق المزدوج، العدسة المحدبة، انكسار المنشور، المرآة المكافئة |
| الملفات | مشهد جديد، الإعدادات الافتراضية، حفظ وفتح المشاهد (JSON محلياً)، نسخ ولصق JSON |
| الواجهة | عربية RTL مع المصطلحات الإنجليزية، تصميم داكن سماوي، تدعم الوضعين العمودي والأفقي |

### طريقة الاستخدام

- **رسم عائق أو وسط:** من زر «عائق» أو «وسط» بشريط الأدوات اختار النوع، وبعدها اسحب على المساحة، أو المس مرة وحدة حتى ينضاف بالحجم الافتراضي.
- **تعديل عنصر:** بأداة «تحريك» المس العنصر، فتظهر لوحة الخصائص (الحجم، الزاوية، عرض الشق، البعد البؤري، معامل السرعة…).
- **الحلقات النابضة حول المصدر:** تنحسب من طور المحرك وطوله الموجي، فتطابق قمم الموجة الحقيقية وما تحل محل المحاكاة.

## هيكل المشروع

```
lib/
  main.dart, app.dart
  models/        wave_source, wave_probe, obstacle_object, medium_object, text_annotation
  engine/        wave_simulation_engine (المحرك)، wave_physics (المعادلات)
  rendering/     wave_2d_painter, wave_3d_painter, overlay_painter, probe_painter
  controllers/   simulation_controller
  screens/       home_screen
  widgets/       simulation_canvas, control_panel, source_controls, properties_panel,
                 probe_card, simulation_toolbar, menu_bar, labeled_slider
  services/      scene_storage_service
  utils/         constants, geometry
test/
  wave_simulation_engine_test.dart, simulation_controller_test.dart
```

## ملاحظات الأداء

- المحرك منفصل عن الواجهة. الإطارات تنبلّغ عبر `ValueNotifier` وتعيد رسم مساحة المحاكاة فقط، ولا يُستدعى `setState` في كل خطوة.
- حلقة الإطارات تعتمد على `Ticker`، وعدد الخطوات يُحسب من الزمن الفعلي، فالسرعة نفسها على شاشات 60Hz و120Hz.
- مخازن `Float32List` تُعاد استخدامها. الصورة القديمة تتحرّر (`dispose`) عند وصول الجديدة، ولا تبدأ صورة جديدة قبل ما تكمل السابقة.
- ما استخدمت Isolate: حجم الحساب (180×180) صغير ويُنجز بأقل من ميلي ثانية لكل خطوة، ونسخ الحقل كل إطار بين الـ Isolates يكلّف أكثر مما يوفّر، وكمان الـ Isolate ما يشتغل على الويب.

## المكتبات

| المكتبة | الإصدار |
|---|---|
| flutter_localizations (SDK) | — |
| shared_preferences | ^2.3.2 |
| flutter_lints (dev) | ^5.0.0 |
| flutter_test (SDK) | — |
