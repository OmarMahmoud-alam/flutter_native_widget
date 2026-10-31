# flutter_native_widget — خطة المشروع

> الاسم مؤقت (لازم نتأكد إنه مش محجوز على pub.dev قبل النشر).

---

## 1. الهدف

باكدج Flutter تخلّي المطوّر يعمل **Home Screen Widgets لـ Android و iOS وهو بيكتب Dart بس**،
والباكدج تتكفّل بكل الباقي:

- **توليد الكود الـ native كله** (Kotlin/XML لأندرويد، Swift/SwiftUI لـ iOS) بـ `build_runner`.
- **ربط المشاريع الـ native** (Manifest، Gradle، Xcode target، App Groups) بـ CLI مرة واحدة.
- **Runtime** في Dart: تحديث الداتا، إعادة رسم الـ widget، استقبال الضغطات والتفاعل.

### تجربة المطوّر المستهدفة

```bash
flutter pub add flutter_native_widget
flutter pub add dev:build_runner dev:flutter_native_widget_gen
dart run flutter_native_widget_gen init      # مرة واحدة: يجهّز android/ و ios/
dart run build_runner build              # كل ما يغيّر الـ widgets
flutter run
```

**ولا سطر Swift أو Kotlin يكتبه المطوّر بإيده.**

### اللي لازم يتعمل بالباكدج (Use cases مرجعية)

كل widget هنا بيختبر قدرة معيّنة في الباكدج. الـ example app هيبقى فيه كلهم، وكل واحد منهم
بيبقى **acceptance test** للمرحلة اللي بيتعمل فيها.

#### الأساسية (لازم تشتغل في 0.1.0)

| # | Widget | بيختبر إيه | Android | iOS | Phase |
|---|---|---|---|---|---|
| 1 | **ساعة حيّة** (رقمي + تاريخ) | Live primitives — بتتحرك والأبليكيشن مقفول | ✅ `TextClock` | ✅ Timeline كل دقيقة / `.timer` | 3–4 |
| 2 | **Counter تفاعلي** (زرار + / −) | زرار في الـ widget بيغيّر الداتا من غير فتح الأبليكيشن | ✅ | ✅ iOS 17+ | 3–4 |
| 3 | **قائمة مهام** | Lists + deep link لعنصر معيّن + checkbox يعلّم المهمة | ✅ (checkbox من API 31) | ✅ iOS 17+ | 3–4 |
| 4 | **مواقيت الصلاة** | **Timeline**: الأبليكيشن يحفظ جدول مواعيد مستقبلية، والـ widget يعرض "الصلاة الجاية" + عدّاد تنازلي من غير ما الأبليكيشن يشتغل | ✅ AlarmManager | ✅ Timeline entries | 3–4 |
| 5 | **عدّاد تنازلي لحدث** (امتحان، سفر) | `Timer` primitive (countdown) + تغيير الشكل لما يخلص | ✅ `Chronometer` (API 24+) | ✅ `.timer` | 3–4 |
| 6 | **مشغّل موسيقى** | زراير تحكم (play/pause/next) + صورة الألبوم من النت + حالة بتتغيّر من الأبليكيشن | ✅ | ✅ iOS 17+ | 3–4 |
| 7 | **Quick actions** (4 أزرار اختصارات) | أكتر من deep link في نفس الـ widget | ✅ | ✅ (`Link` في medium/large) | 3–4 |

#### المتقدّمة (Snapshot / إعدادات / أماكن تانية)

| # | Widget | بيختبر إيه | Android | iOS | Phase |
|---|---|---|---|---|---|
| 8 | **طقس بـ chart** | Snapshot: chart مرسوم بـ Flutter كصورة + داتا نصّية مربوطة native | ✅ | ✅ (التحديث من الأبليكيشن بس) | 6 |
| 9 | **أسهم / عملات** | Snapshot + تحديث دوري (WorkManager / background fetch) | ✅ | ⚠️ محدود بميزانية iOS | 6 |
| 10 | **ألبوم صور** | صور من storage الأبليكيشن + تبديل الصورة كل فترة بـ timeline | ✅ | ✅ | 6 |
| 11 | **طقس قابل للإعداد** | Widget configuration: المستخدم يختار المدينة لما يضيف الـ widget | ✅ Configure Activity | ✅ `AppIntentConfiguration` | 7 |
| 12 | **Lock screen / StandBy** | أحجام وأماكن تانية (accessory families على iOS) | ➖ | ✅ iOS 16+ | 7 |

#### متطلبات عامة لازم تبان في كل الأمثلة

- **عربي + RTL** في الكود المولّد على المنصتين.
- **Dark mode** (ألوان بتتغيّر مع ثيم النظام).
- **أحجام متعددة** لنفس الـ widget (small / medium / large) بـ layout مختلف لكل حجم.
- **Fallback واضح** على الأنظمة القديمة (زرار iOS < 17 يفتح الأبليكيشن بدل ما يتجاهل الضغطة).

---

## 2. ليه الـ widget لازم يبقى native مش Flutter؟

### 2.1 الـ widget مش جوه الأبليكيشن بتاعك

لما المستخدم يحط widget على الشاشة الرئيسية، اللي بيرسمه **مش الأبليكيشن بتاعك**،
ده الـ **Launcher** على أندرويد أو **SpringBoard** على iOS — يعني أبليكيشن تاني خالص تبع النظام.
الأبليكيشن بتاعك ممكن يكون مقفول خالص، والـ widget لسه ظاهر وشغّال.

عشان كده النظام مبيقبلش منك "كود يشتغل"، بيقبل **وصف للشكل** بصيغة هو فاهمها وبيرسمها بنفسه:

**أندرويد — `RemoteViews`:**
- الأبليكيشن بيبعت للـ Launcher **وصف** للـ views (مش views حقيقية).
- الوصف ده مسموح فيه بس **قائمة محددة** من الـ views (`TextView`, `ImageView`, `LinearLayout`, `Button`, `TextClock`…).
  أي view مش في القائمة — زي `FlutterView` — النظام **بيرفضه**.
- حتى Jetpack Glance بيتحوّل لـ `RemoteViews` في الآخر.

**iOS — WidgetKit:**
- الـ widget بيشتغل في **Widget Extension** — process منفصل، مش الأبليكيشن.
- الـ extension بيشتغل ثواني يجهّز الشكل بـ **SwiftUI** وبعدين النظام بيقفله. الشكل بيترسم من snapshot، مش live.
- حد الذاكرة حوالي **30MB**. الـ Flutter engine لوحده (Dart VM + rendering engine) محتاج أكتر من كده، وفوق كده محتاج يفضل شغّال عشان يرسم كل frame — والـ extension مش بيفضل شغّال.
- حتى SwiftUI جوه الـ widget محدود: مفيش UIKit views، مفيش scroll، ومفيش animations حرة.

### 2.2 طب Flutter ليه دور؟

الدور الوحيد الممكن لـ Flutter في الشاشة الرئيسية إنه **يرسم صورة** (Snapshot) جوه الأبليكيشن،
والـ widget الـ native يعرضها. الصورة ثابتة: مبتتحركش، ومبتتحدّثش غير لما الأبليكيشن يرسمها من جديد.

### 2.3 فـ الباكدج بتحل المشكلة إزاي؟

كلمة "native" هنا عن **الناتج** مش عن اللي المطوّر بيكتبه:

```
المطوّر بيكتب Dart (DSL)  ──build_runner──►  الباكدج بتولّد Kotlin/XML + Swift/SwiftUI
```

المطوّر عمره ما يشوف الكود الـ native أو يعدّله. ده نفس الأسلوب اللي `json_serializable` و `freezed`
بيعملوه في Dart — بس هنا الناتج native بدل Dart.

### 2.4 حدود المنصات (الحقايق اللي التصميم مبني عليها)

| الحقيقة | التأثير على التصميم |
|---|---|
| الـ widget بيترسم بواسطة **النظام** مش Flutter engine. iOS widget extension مفيهوش Flutter أصلًا (وليه حد ذاكرة ~30MB). | مستحيل نشغّل Flutter widget "حي" على الشاشة الرئيسية ← لازم نولّد UI native أو نعرض صورة. |
| iOS: الـ UI لازم **SwiftUI** (WidgetKit). | الـ generator يطلّع SwiftUI. |
| Android: الـ UI لازم **RemoteViews** (XML) — Glance بيترجم لـ RemoteViews في الآخر. | نولّد **RemoteViews XML + Kotlin** مباشرة (من غير ما نجبر المطوّر على Compose). |
| التحديثات مخنوقة: Android `updatePeriodMillis` ≥ 30 دقيقة، WorkManager ≥ 15 دقيقة. iOS ميزانية reloads محدودة يوميًا. | أي حاجة بتتغيّر بالثانية/الدقيقة لازم تبقى **مكوّن بيتحرك لوحده** (ساعة/timer). |
| **ساعة حيّة**: Android عنده `TextClock` و `Chronometer` في RemoteViews بيتحركوا لوحدهم. iOS عنده `Text(date, style: .timer/.relative)` بيتحرك لوحده + Timeline entries كل دقيقة. | الساعة تبقى **primitive** مولّد، مش صورة. ⚠️ ساعة analog بعقرب ثواني على iOS مش ممكنة. |
| الداتا بين الأبليكيشن والـ widget: Android `SharedPreferences`، iOS **App Group** (`UserDefaults(suiteName:)` + shared container للصور). | Runtime موحّد بيكتب في المكانين. |
| تفاعل من غير فتح الأبليكيشن: Android كامل (Broadcast → Dart في background isolate). iOS 17+ فقط عبر **App Intents**. | Counter التفاعلي: Android كامل، iOS 17+، وأقل من كده الضغطة تفتح الأبليكيشن. |
| إنشاء Widget Extension في iOS = تعديل `project.pbxproj` + target + entitlements. App Group لازم يتسجّل في حساب Apple Developer. | CLI يعدّل الـ pbxproj؛ تسجيل الـ App Group يتعمل بـ Automatic Signing (أو خطوة يدوية موثّقة). |

---

## 3. المعمارية

### 3.1 ثلاث طرق رسم (Render modes) + Timeline

الباكدج بيدعم 3 أنواع عناصر، وممكن يتخلطوا في نفس الـ widget (وتحتهم آلية الـ Timeline):

1. **Declarative (DSL → Native)** — الأساس
   مجموعة محدودة من عناصر Dart (Column, Row, Stack, Text, Image, Button, Spacer, Box…)
   الـ generator **بيترجمها** لـ RemoteViews XML و SwiftUI.
   - النصوص والصور مربوطة بمفاتيح داتا (`Bind('temp')`) ← لما الداتا تتغيّر، الـ widget يتحدّث **من غير Flutter خالص**.
   - ده اللي بيخلّي التفاعل والداتا الحيّة ممكنين.

2. **Live primitives** — جزء من الـ DSL
   `Clock`, `DateText`, `Timer` (countdown/count-up) ← بيتولّدوا لمكوّنات النظام اللي بتتحرك لوحدها.

3. **Snapshot (Flutter → صورة)**
   عنصر `FlutterSnapshot(child: AnyFlutterWidget)` ← الأبليكيشن يرسم أي Flutter widget كـ PNG ويحطه في الـ shared storage، والـ widget يعرضه كصورة.
   - للتصاميم المعقّدة (charts، gradients، custom painters).
   - بيتحدّث بس لما الأبليكيشن (أو background isolate على أندرويد) يرسمه من جديد.

**Timeline (داتا مجدولة لقدّام)** — مش نوع رسم، دي طريقة لتغيير الداتا من غير الأبليكيشن:
الأبليكيشن يحفظ **قائمة entries** كل واحدة ليها وقت وداتا (مثلًا مواقيت الصلاة لليوم كله)،
والكود الـ native المولّد يعرض الـ entry المناسبة للوقت الحالي.
- iOS: بتتحوّل لـ `Timeline` entries في الـ `TimelineProvider`.
- Android: الـ Provider يحسب الـ entry الحالية ويحجز `AlarmManager` للـ entry اللي بعدها.

```dart
await PrayerWidgetData.timeline([
  TimelineEntry(at: fajr,  data: PrayerWidgetData(next: 'الظهر', nextAt: dhuhr)),
  TimelineEntry(at: dhuhr, data: PrayerWidgetData(next: 'العصر', nextAt: asr)),
  // ...
]).save();
```

### 3.2 ليه الـ layout لازم يكون `const`

`build_runner` مبيشغّلش كود المطوّر — بيقرأه بالـ analyzer. عشان نقدر نقرأ الـ layout
ونحوّله لكود native، الـ layout بيتكتب كـ **const expression** والـ generator يقيّمه بـ
`ConstantReader`. القيم المتغيّرة كلها بتيجي عن طريق `Bind(...)`.

### 3.3 شكل الـ API

```dart
import 'package:flutter_native_widget/flutter_native_widget.dart';

part 'widgets.fnw.dart';

// 1) ساعة حيّة
@HomeWidget(
  name: 'ClockWidget',
  sizes: [WidgetSize.small, WidgetSize.medium],
  layout: Column(children: [
    Clock(format: 'HH:mm', style: TextStyle(fontSize: 42, weight: 700)),
    DateText(format: 'EEEE d MMMM'),
  ]),
)
class ClockWidget {}

// 2) داتا من الأبليكيشن + تفاعل
@HomeWidget(
  name: 'CounterWidget',
  layout: Column(children: [
    Text(Bind('count', fallback: '0'), style: TextStyle(fontSize: 36)),
    Row(children: [
      Button(label: '−', action: WidgetAction.callback('decrement')),
      Button(label: '+', action: WidgetAction.callback('increment')),
    ]),
  ]),
  onTap: WidgetAction.openApp(route: '/counter'),
)
class CounterWidget {}
```

الـ generator يطلّع `widgets.fnw.dart` فيه API typed:

```dart
// من جوه الأبليكيشن
await CounterWidgetData(count: '5').save();   // يكتب الداتا ويعمل update للـ widget

// callbacks التفاعل (بتشتغل في background isolate)
@pragma('vm:entry-point')
Future<void> onCounterAction(WidgetActionEvent e) async {
  final current = int.parse(await CounterWidgetData.read('count') ?? '0');
  await CounterWidgetData(count: '${e.name == 'increment' ? current + 1 : current - 1}').save();
}

void main() {
  FlutterNativeWidget.initialize(callbacks: {CounterWidget: onCounterAction});
  runApp(const MyApp());
}
```

### 3.4 Data flow

```
┌──────────── Flutter App ────────────┐
│ CounterWidgetData(count: '5').save()│
└───────────────┬─────────────────────┘
                │ home_widget plugin
      ┌─────────┴──────────┐
      ▼                    ▼
 Android                 iOS
 SharedPreferences       App Group UserDefaults
 + AppWidgetManager      + WidgetCenter.reloadTimelines
      │                    │
      ▼                    ▼
 Generated Provider      Generated TimelineProvider
 (RemoteViews XML)       (SwiftUI View)
      │                    │
  ضغطة زرار             ضغطة زرار (iOS 17+)
      │                    │
 BroadcastReceiver       AppIntent
      └────────┬───────────┘
               ▼
   Background Dart isolate → callback المطوّر → save() → update
```

---

## 4. هيكل الريبو

```
flutter_native_widget/                 (melos monorepo)
├── PLAN.md
├── melos.yaml
├── packages/
│   ├── flutter_native_widget/          ← DSL + annotations + CLI (الـ runtime = home_widget)
│   │   ├── lib/
│   │   │   ├── flutter_native_widget.dart
│   │   │   └── src/
│   │   │       ├── dsl/                (Column, Text, Clock, Bind, ...)
│   │   │       ├── annotations.dart    (@HomeWidget, WidgetSize, WidgetAction)
│   │   │       └── runtime/            (wrapper رفيع فوق home_widget: typed save/read، callbacks)
│   │   └── bin/flutter_native_widget.dart   ← CLI (init / sync / doctor / clean)
│   │
│   └── flutter_native_widget_gen/      ← build_runner generator (dev dependency)
│       ├── lib/builder.dart
│       ├── lib/src/
│       │   ├── model/                  (Widget spec tree — IR موحّد)
│       │   ├── reader/                 (const DSL → IR)
│       │   ├── emit/dart/              (typed Data classes)
│       │   ├── emit/android/           (XML layout + widget-info + Provider.kt)
│       │   └── emit/ios/               (SwiftUI View + TimelineProvider + Bundle + Intents)
│       └── build.yaml
│
└── example/                            ← الـ 12 widget المرجعيين
```

**IR (Intermediate Representation):** الـ reader يحوّل الـ DSL لشجرة موحّدة (JSON-serializable)،
وكل emitter (Dart / Android / iOS) بياخد نفس الشجرة. ده بيسهّل الاختبار (golden tests للكود المولّد)
وإضافة منصة أو feature جديدة.

### أين يتكتب الكود المولّد؟

- Dart: `lib/**.fnw.dart` (عادي بـ build_runner).
- Native: الـ generator يطلّع الملفات في `.dart_tool/flutter_native_widget/`، وخطوة sync (جزء من الـ builder أو `dart run flutter_native_widget sync`) تنسخها لـ:
  - `android/app/src/main/kotlin/.../fnw/` + `res/layout/` + `res/xml/`
  - `ios/FNWWidgets/` (الـ widget extension target)
- كل ملف مولّد عليه header `// GENERATED — DO NOT EDIT`، والـ CLI بيمسح الملفات القديمة اللي اتشالت.

---

## 5. الـ CLI

| الأمر | بيعمل إيه |
|---|---|
| `init` | Android: يضيف `<receiver>` لكل widget في الـ Manifest (أو manifest merger من الـ plugin)، deps في Gradle. iOS: ينشئ Widget Extension target في `project.pbxproj`، يضيف App Group entitlements للـ Runner والـ extension، يظبط Embed App Extensions. |
| `sync` | ينسخ الكود المولّد للأماكن الصح ويضيف/يشيل الملفات من الـ Xcode target. |
| `doctor` | يتأكد إن كل حاجة مربوطة (App Group متطابق، الـ target موجود، receivers متسجّلة، minSdk/iOS version). |
| `clean` | يشيل كل اللي الباكدج ضافته. |

تعديل `project.pbxproj`: نكتب parser/writer صغير بـ Dart (الصيغة OpenStep plist) عشان منعتمدش على Ruby `xcodeproj`. لو طلع معقّد زيادة ← fallback للـ gem (قرار مفتوح #2).

---

## 6. المراحل (Milestones)

كل مرحلة بتنتهي بحاجة **شغّالة على جهاز/محاكي** مش بس كود.

### Phase 0 — دراسة + Spike (أسبوع)
- **تقييم:** نجرّب `home_widget_cli` و `mosaic_widgets` في مشروع تجريبي على الـ 12 use case، ونكتب جدول: إيه اللي اشتغل، إيه الناقص، وإيه اللي اتكسر.
- **Spike:** مشروع Flutter فيه `home_widget` runtime + widget ساعة + counter مكتوبين **native بإيدينا**:
  - ساعة بـ `TextClock` / `Text(.timer)`.
  - Counter بـ **native action** (increment من غير Dart) وكمان بـ callback (Dart في الـ background) عشان نقارن.
- نفتح issue/discussion عند `home_widget` نسأل لو الأزرار والساعة مرحّب بيهم كـ contribution (← قرار #0).
- **✅ Done لما:** الساعة بتتحرك والأبليكيشن مقفول، والـ counter بيتغيّر من الأبليكيشن ومن زرار الـ widget على المنصتين، ومعانا تقرير التقييم.

### Phase 1 — Integration مع `home_widget` runtime
- (كانت "نكتب runtime خاص" — اتلغت بعد قرار #1.)
- نحدّد بالظبط مفاتيح التخزين والـ intents اللي الكود المولّد هيستخدمها عشان يتكلّم مع `home_widget`.
- Receiver الـ native actions (Android) و AppIntent الـ native actions (iOS 17) — دول جزء صغير من الكود المولّد، مش plugin.
- **✅ Done لما:** الكود الـ native بتاع Phase 0 بيكلّم `home_widget` بس، من غير plumbing خاص بينا.

### Phase 2 — DSL + Generator (Dart + IR)
- كل عناصر الـ DSL كـ const classes.
- Reader: const → IR، مع رسائل خطأ واضحة (مثلًا: "Expected a const layout", "Unknown binding key").
- Dart emitter: Data classes typed + registration.
- **✅ Done لما:** unit tests للـ reader + golden tests للـ IR.

### Phase 3 — Android emitter
- IR → `layout/*.xml` + `xml/*_info.xml` + `*Provider.kt`.
- Primitives: `TextClock`, `Chronometer`.
- Buttons → `PendingIntent` → receiver → background callback.
- Sizes → `minWidth/minHeight/targetCellWidth` + responsive layouts (API 31+).
- **✅ Done لما:** الـ widgets الأساسية (1–7) شغّالة على أندرويد من كود مولّد 100%.

### Phase 4 — iOS emitter
- IR → SwiftUI views + `TimelineProvider` + `WidgetBundle`.
- Primitives: `Text(.timer)`, timeline كل دقيقة للساعة.
- Buttons → `AppIntent` (iOS 17+)، وأقل من كده `widgetURL` / `Link`.
- **✅ Done لما:** الـ widgets الأساسية (1–7) شغّالة على iOS من كود مولّد 100%.

### Phase 5 — CLI
- `init / sync / doctor / clean` + pbxproj editor (على نفس أسلوب `home_widget_cli`).
- **✅ Done لما:** مشروع `flutter create` فاضي → 4 أوامر → widgets شغّالة على المنصتين من غير فتح Xcode أو Android Studio (ما عدا اختيار الـ Team للـ signing).

### Phase 6 — Snapshot mode
- `FlutterSnapshot` ← بنستخدم `HomeWidget.renderFlutterWidget` الموجود، والكود المولّد يعرض الصورة كـ Image.
- إعادة الرسم في background على أندرويد (headless engine) — iOS: بس لما الأبليكيشن يفتح أو عن طريق background fetch.
- **✅ Done لما:** widget الطقس بـ chart مرسوم بـ Flutter.

### Phase 7 — Polish & نشر
- Docs + example كامل + CI (golden tests + build للـ example على المنصتين).
- Dark mode، localization/RTL في الكود المولّد، widget configuration (اختيارات المستخدم) لو الوقت سمح.
- نشر `0.1.0` على pub.dev.

---

## 7. الاستفادة من الباكدجات الموجودة

فيه باكدجات بتعمل أجزاء من الفكرة دي (اتراجعت من الكود نفسه، مش بس الـ README):

| الباكدج | الترخيص | عنده | ناقصه |
|---|---|---|---|
| [`home_widget`](https://pub.dev/packages/home_widget) (runtime) | BSD-3 | `saveWidgetData`, `updateWidget`, `scheduleWidgetUpdates`, `registerInteractivityCallback` (Android + iOS 17 AppIntent)، `renderFlutterWidget`، `saveImage`، `getInstalledWidgets`، `requestPinWidget`، configure flow | مفيش UI — لازم تكتب الـ native بإيدك |
| [`home_widget_cli`](https://pub.dev/packages/home_widget_cli) + [`home_widget_generator`](https://pub.dev/packages/home_widget_generator) | BSD-3 | DSL بـ analyzer (const)، **بيعمل الـ Xcode target أوتوماتيك** (pbxproj parser/editor بـ Dart)، signing، flavors، xcconfig، ExportOptions، Glance + Gradle + Manifest، **`HWTimedData`** (Timeline)، lists، localization، fonts، 66 ملف tests | **مفيش أزرار جوه الـ widget** (الضغط على الـ widget كله بس)، **مفيش ساعة/timer حي** |
| [`mosaic_widgets`](https://pub.dev/packages/mosaic_widgets) | MIT | DSL بيتشغّل بـ `dart run` ويطلّع IR JSON → SwiftUI + RemoteViews. أزرار، **`MToggleAction`** (تغيير داتا native من غير Dart)، `MTimer` حي على المنصتين، lock screen، Live Activities، Control Center، `MRaw`، `MAdaptive` | **الـ Xcode target يدوي**، مفيش Timeline، انتشار ضعيف جدًا |

### هناخد إيه من كل واحد

| من | إيه | إزاي |
|---|---|---|
| `home_widget` runtime | التخزين، التحديث، الجدولة، callbacks التفاعل، `renderFlutterWidget` | **dependency مباشرة** ← بيلغي معظم Phase 1 و Phase 6 |
| `home_widget_cli` | الـ pbxproj parser/editor، منطق نسخ الـ signing، xcconfig، flavors، إعداد Glance/Gradle | **مرجع**. الكود ده في `lib/src` (مش public API) فمينفعش نعمله import — لو احتجنا ننقل جزء، ننقله **مع الحفاظ على نص ترخيص BSD-3 واسم صاحبه** |
| `home_widget_generator` | طريقة قراءة الـ DSL بالـ analyzer (نفس فكرتنا — يعني الطريقة مجرّبة)، تصميم `HWTimedData`، الـ validators (أسماء محجوزة في Swift/Kotlin، حدود عدد الأطفال، الأحجام)، استراتيجية الـ tests | مرجع تصميم |
| `mosaic_widgets` | فكرة **Native actions** (`MToggleAction`)، تنفيذ `MTimer` على المنصتين، `MRaw` كـ escape hatch، layout مختلف لكل حجم، ملاحظات حدود المنصات في `DSL_REFERENCE.md` | مرجع تصميم + نقل كود مع نص ترخيص MIT لو احتجنا |

### أهم درس: Native actions

بدل ما كل ضغطة زرار تشغّل Dart engine في الـ background (بطيء وبيستهلك ذاكرة — خطر #6)،
الأفعال البسيطة تتنفّذ **native بالكامل** في الكود المولّد:

```dart
Button(label: '+', action: WidgetAction.increment('count')),   // native، من غير Dart
Button(label: '✓', action: WidgetAction.toggle('done_3')),     // native، من غير Dart
Button(label: '↻', action: WidgetAction.callback('refresh')),  // Dart في الـ background (للحالات المعقّدة بس)
```

أفعال native مقترحة: `increment` / `decrement` / `toggle` / `set` / `cycle` (لفّ على قائمة قيم).
الـ Counter (use case #2) والـ checkbox في قائمة المهام (#3) يشتغلوا كده من غير ما Dart يصحى.

### الاختلاف اللي هيفضل لينا

لو بنينا فوق `home_widget` runtime، الباكدج بتاعتنا هتبقى **generator** زي `home_widget_generator`.
اللي هيميّزنا عنه:
1. **أزرار جوه الـ widget + Native actions.**
2. **Live primitives**: ساعة، تاريخ، timer.
3. **التكامل مع `build_runner`** بدل CLI منفصل للتوليد.
4. **عربي و RTL** كمتطلب أساسي من أول يوم.

⚠️ بند 1 و 2 ممكن صاحب `home_widget` يضيفهم في أي وقت. عشان كده القرار #0 تحت.

---

## 8. المخاطر والقرارات المفتوحة

| # | الموضوع | الخطر / السؤال | المقترح |
|---|---|---|---|
| 0 | **الاتجاه** | نبني باكدج منفصلة، ولا نساهم بالأزرار والساعة في `home_widget_generator` نفسه؟ | يتحسم بعد Phase 0. لو صاحب `home_widget` قابل الـ contributions دي ← نساهم. لو لأ أو عايزين تحكّم كامل ← باكدج منفصلة فوق `home_widget` runtime. |
| 1 | الاعتماد على `home_widget` | نبني runtime خاص بينا ولا نبني فوق `home_widget`؟ | **نبني فوق `home_widget` runtime** (BSD-3، مستقر، أكتر من 2200 like، فيه interactivity على المنصتين). الكود الـ native المولّد يقرا ويكتب بنفس مفاتيح التخزين بتاعته. نكتب runtime خاص بس لو لقينا حاجة مش هتتعمل فوقه. |
| 2 | تعديل `project.pbxproj` | الصيغة معقّدة وأي غلطة بتبوّظ المشروع. | ندرس الـ parser/editor بتاع `home_widget_cli` (مكتوب بـ Dart ومتجرّب) ونمشي على نفس الأسلوب. backup قبل أي تعديل + `doctor`. |
| 3 | App Group / Signing | لازم يتسجّل في Apple Developer؛ مش قابل للأتمتة 100%. | Automatic signing بيعمله غالبًا؛ `doctor` يكشف المشكلة ويقول الخطوة بالظبط. |
| 4 | تفاعل iOS < 17 | مفيش تفاعل من غير فتح الأبليكيشن. | Fallback أوتوماتيك: الزرار يفتح الأبليكيشن بـ deep link فيه الـ action. |
| 5 | الـ DSL محدود | المطوّر هيطلب widgets مش موجودة. | `FlutterSnapshot` كـ escape hatch، والـ IR مصمّم سهل يتوسّع. |
| 6 | Background Dart على أندرويد | استهلاك وقت/ذاكرة تشغيل engine في الـ background. | **Native actions** (`increment`/`toggle`/...) للأفعال البسيطة من غير Dart خالص؛ `callback` بس للحالات المعقّدة. |
| 7 | Snapshot في background على iOS | الـ extension مينفعش يشغّل Flutter. | Snapshot على iOS بيتحدّث بس من الأبليكيشن — موثّق كـ limitation. |
| 8 | الاسم | `flutter_native_widget` ممكن يكون محجوز. | نتأكد على pub.dev في Phase 0. |

---

## 9. معايير النجاح

- مطوّر يقدر يعمل الـ widgets الأساسية (1–7) **من غير ما يكتب أو يفتح ملف native**.
- الساعة بتتحرك والأبليكيشن مقفول.
- تغيير الداتا من الأبليكيشن يظهر في الـ widget في أقل من ثانية.
- زرار الـ widget يغيّر الداتا من غير فتح الأبليكيشن (Android + iOS 17+).
- `build_runner` + `sync` بيطلّعوا نفس الكود دايمًا (deterministic) ومغطّيين بـ golden tests.

---

## 10. الحالة — 2026-10-31

### اتعمل

| المرحلة | الحالة | ملاحظات |
|---|---|---|
| Phase 0 — تقييم | ✅ | [`docs/EVALUATION.md`](docs/EVALUATION.md). `home_widget_cli` اتجرّب واتبنى على المنصتين؛ `mosaic_widgets` اتراجع من الكود. الـ spike اليدوي اتلغى: الـ generator نفسه اتجرّب على الأجهزة. |
| Phase 1 — runtime | ✅ | فوق `home_widget` (قرار #1). |
| Phase 2 — DSL + IR + Dart | ✅ | `build_runner` (3 builders) + رسائل خطأ واضحة. |
| Phase 3 — Android | ✅ | RemoteViews XML + Kotlin، من غير أي تعديل على Gradle. |
| Phase 4 — iOS | ✅ | ملف SwiftUI واحد لكل الـ widgets، فالـ `project.pbxproj` بيتعدّل وقت `init` بس. |
| Phase 5 — CLI | ✅ | `init / sync / doctor / clean` + pbxproj parser/writer بـ Dart بيطلّع صيغة Xcode حرف بحرف. |
| Phase 6 — Snapshot | ✅ | `NWField.image` + `render<Field>()` فوق `renderFlutterWidget`. |
| إضافات | ✅ | `NWAnalogClock` (عقرب ثواني على Android 12+)، `NWGradient`، borders، Native actions، `NWRepeat`، `NWIf`، Lock screen على iOS (`NWSize.circular/rectangular/inline`). |
| إضافات 2 | ✅ | `NWProgress.circular`، `NWIcon`، `NWRichText`، خطوط مخصصة، `NWList`، `NWOption`، `NWRefresh`. |
| CI + goldens | ✅ | `.github/workflows/ci.yml` + `test/golden_test.dart` (23 ملف متولّد). |
| Phase 7 — نشر | ✅ | 0.1.0 على pub.dev للباكدجين، MIT، والـ CI شغّال على GitHub. |

### اتجرّب على أجهزة (Android 15 emulator + iPhone 17 / iOS 27 simulator)

| الحاجة | Android | iOS |
|---|---|---|
| ساعة رقمية + تاريخ بيتحركوا لوحدهم | ✅ | ✅ (timeline كل دقيقة) |
| Watch face: analog + digital + gradient | ✅ بعقرب ثواني بيتحرك | ✅ من غير عقرب ثواني |
| أزرار native (+ / −) من غير فتح الأبليكيشن | ✅ | ✅ (App Intent) |
| Callback بـ Dart في الـ background (⏭) | ✅ | ✅ (أول ضغطة بعد cold start كانت بتتأخر — اتصلّح بـ reload من الـ intent) |
| Timeline (مواقيت الصلاة اتنقلت لوحدها) | ✅ | ✅ الفجر ← الظهر ← العصر ← العشاء في مواعيدها |
| عدّاد تنازلي + تبديل لـ "It's time!" | ✅ | ✅ |
| صورة مرسومة بـ Flutter | ✅ | ✅ |
| ألبوم صور: 6 صور في timeline كل دقيقة | ✅ | ✅ |
| فتح الأبليكيشن بـ route من الـ widget | ✅ (`Tasks → /tasks`) | ✅ (`Counter → /counter`) |
| Clean build | ✅ | ✅ |
| `NWTimer` بيتحرك كل ثانية | ✅ | ⚠️ القيمة صح كل ما الـ widget يترسم، بس الـ simulator مابيحرّكهاش ثانية بثانية — محتاج جهاز حقيقي |

الاختبارات: 52 في الـ generator (reader، emitters، manifest، pbxproj round-trip، إعداد iOS والـ clean)
و 4 في الـ runtime — كلها ناجحة.

### الـ use cases اللي لسه

| # | Widget | الناقص |
|---|---|---|
| 12 | Lock screen / StandBy | اتعمل على iOS، بس ماتجرّبش على الشاشة (الـ simulator مابيفتحش تخصيص الـ Lock screen) |

### فروق عن الخطة الأصلية

- **Android:** RemoteViews XML بدل Glance، عشان مفيش أي تعديل على Gradle أو Compose.
- **iOS:** الـ callback intent اتقسم ملفين (واحد في الـ app فيه `home_widget`، و stand-in في الـ extension)؛
  طريقة الملف المشترك بـ `#if canImport` كانت بتفشل في الـ link حسب ترتيب الـ build.
- **أسماء الـ DSL** بادئة `NW` (مش `Column`/`Text`) عشان متتعارضش مع Flutter في نفس الملف.
- **`renderImage`** بيدّي الـ widget المقاس المطلوب بالظبط (`SizedBox.fromSize`)؛ من غيرها `home_widget`
  بيعمل layout بارتفاع لا نهائي وبيكسر أو يضغط الـ widgets اللي بتاخد مقاس الأب.
- **`NWImage` من غير مقاس** بيملا الـ box اللي فيه على المنصتين: على Android بقى `match_parent`
  (كان `wrap_content` فالـ `centerCrop` ماكانش بيشتغل)، وعلى iOS الصورة الـ `cover` بقت overlay
  على `Color.clear` عشان ماتكبّرش الـ `ZStack` وتزق اللي جنبها برّه الـ widget.
- **`NWRefresh` native مش Dart:** الـ download بيحصل في Kotlin وجوه الـ widget extension، مش في Dart
  في الـ background، لأن iOS مش بيضمن تشغيل الأبليكيشن، وده كمان من غير WorkManager ولا تعديل Gradle.
  على Android: علامة `__tried` قبل كل download، وإعادة المحاولة بعد 5 دقايق لو فشل (من غيرها كانت
  بتعمل loop بيوقّع الـ system_server)، و watchdog 25 ثانية للـ `goAsync`.
- **Android بيرسم `APPWIDGET_UPDATE` بنفسه:** `home_widget` بيبعت الـ ids اللي لقاها، وأحيانًا بترجع فاضية
  من الـ activity، فالـ provider بيدوّر على الـ ids بنفسه.
- **iOS 17 options:** `WidgetBundle` مابيقبلش `if #available`، فبيتولّد bundle لكل نسخة و `main()` بيختار.
- **قرار #0** (نساهم في `home_widget` ولا لأ): الباكدج اتبنت. الـ issue عند `home_widget` ماتفتحتش لأنها نشر علني محتاج موافقتك.

## 11. الخطوة الجاية

1. على iPhone حقيقي: `NWTimer` (التكّة كل ثانية) + إضافة Lock screen widgets.
2. تحميل من النت على Android على جهاز أو emulator الـ DNS بتاعه شغّال.
3. `actions/checkout@v5` في الـ CI (v4 بتستخدم Node 20 القديم).
