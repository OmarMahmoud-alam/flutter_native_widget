# Phase 0 — تقييم الباكدجات الموجودة

اتعمل يوم 2026-10-31 على Flutter 3.47.7 / Xcode 27.0 / Dart 3.13.5.

## home_widget_cli 0.4.0+1 + home_widget_generator 0.4.0+1

**اتجرّب فعليًا:** مشروع `flutter create` جديد + widget فيه `HWText` و `HWTimedData`،
وبعدين `dart run home_widget_cli:home_widget generate`، وبعدين
`flutter build ios --simulator` و `flutter build apk`. **الاتنين اتبنوا من غير أي تعديل يدوي.**

ملاحظة: الأمر المكتوب في الـ README (`dart run home_widget_cli generate`) مش شغّال؛ الصح
`dart run home_widget_cli:home_widget generate`.

اللي عمله في المشروع:

| المكان | التغيير |
|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | +189 سطر: target جديد `CounterHomeWidget` (app-extension)، Sources/Frameworks/Resources phases، Embed Foundation Extensions **قبل** Thin Binary (ده بيتفادى مشكلة الـ build cycle المعروفة)، target dependency، build configurations بـ `IPHONEOS_DEPLOYMENT_TARGET = 15.0` و `GENERATE_INFOPLIST_FILE = YES` و `APPLICATION_EXTENSION_API_ONLY = YES` |
| `ios/CounterHomeWidget/` | `Widget.swift` (TimelineProvider + View + data struct)، `WidgetBundle.swift`، `Info.plist` (NSExtensionPointIdentifier بس) |
| `ios/*.entitlements` | App Group للـ Runner والـ extension |
| `ios/Flutter/HomeWidget.xcconfig` | مزامنة رقم النسخة |
| `android/app/build.gradle.kts` | Compose plugin + `buildFeatures.compose` + `glance-appwidget` |
| `AndroidManifest.xml` | `RECEIVE_BOOT_COMPLETED` + intent-filter للـ LAUNCH action. **أعاد تنسيق** أجزاء من الملف مش بتاعته |
| `android/.../CounterHomeWidget*.kt` | Glance widget + receiver |

دروس هناخدها:
- **ترتيب الـ Embed phase قبل Thin Binary** ضروري.
- `containerBackground(for: .widget)` على iOS 17 وإلا الـ widget بيظهر برسالة "Please adopt containerBackground API".
- الـ Timeline بيتحفظ في ملف JSON والـ provider بيرجّع entry لكل وقت مستقبلي بـ `policy: .atEnd`.
- **ميعيدش تنسيق ملفات المستخدم**: احنا هنكتب جوه markers بس.
- Glance بيجبر المشروع على Compose plugin بنسخة Kotlin معيّنة. احنا هنستخدم RemoteViews XML عشان **مفيش أي تعديل على Gradle**.

الناقص (اتأكدنا منه من الكود): مفيش أزرار جوه الـ widget (الـ widget كله بس بـ `widgetUrl`)، مفيش ساعة/timer حي.

## mosaic_widgets 0.3.0

**اتراجع من الكود** (مش مبني على جهاز، لأن الـ Xcode target لازم يتعمل يدوي حسب الـ README).

- بيقرا الـ DSL بإنه يكتب سكريبت في `.dart_tool/hw_gen/runner.dart` ويشغّله بـ `dart run`، والسكريبت يطبع IR JSON.
  ده بيجبر ملفات الـ widgets تبقى Dart صافي (من غير Flutter).
- `MToggleAction`: بيقلب قيمة bool native من غير ما يشغّل Dart ← **هناخد الفكرة ونعمّمها** (increment/decrement/toggle/set).
- `MTimer`: Chronometer على أندرويد و `Text(.timer)` على iOS.
- Android: RemoteViews + Kotlin (نفس اختيارنا).

## القرار

نبني الباكدج (طلب صاحب المشروع)، فوق `home_widget` runtime، بـ:
- RemoteViews على أندرويد (من غير Compose).
- ملف Swift واحد مولّد لكل الـ widgets ← الـ `project.pbxproj` بيتعدّل **مرة واحدة** وقت `init` بس.
- `build_runner` بيولّد الـ Dart والـ native مع بعض.
- أزرار + native actions + ساعة/تاريخ/timer حيين.

الـ issue عند `home_widget` (قرار #0 — المساهمة) **ماتفتحتش**: ده نشر علني باسم صاحب المشروع ومحتاج موافقته.
