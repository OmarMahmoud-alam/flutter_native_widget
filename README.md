# flutter_native_widget

[![pub](https://img.shields.io/pub/v/flutter_native_widget?label=flutter_native_widget)](https://pub.dev/packages/flutter_native_widget)
[![pub](https://img.shields.io/pub/v/flutter_native_widget_gen?label=flutter_native_widget_gen)](https://pub.dev/packages/flutter_native_widget_gen)
[![CI](https://github.com/OmarMahmoud-alam/flutter_native_widget/actions/workflows/ci.yml/badge.svg)](https://github.com/OmarMahmoud-alam/flutter_native_widget/actions/workflows/ci.yml)

**اعمل Home Screen Widgets لأندرويد و iOS وانت بتكتب Dart بس.**
مش هتفتح Xcode، ومش هتكتب Kotlin ولا Swift.

🌐 **صفحة المشروع:** [`docs/index.html`](docs/index.html) (فيها كل التفاصيل والأمثلة)

---

## الفكرة في دقيقة

الـ widget اللي على الشاشة الرئيسية **مش بيرسمها الأبليكيشن بتاعك**؛ بيرسمها الـ launcher
على أندرويد و SpringBoard على iOS. وهما مابيقبلوش غير وصف للشكل بلغتهم
(`RemoteViews` على أندرويد، و SwiftUI جوه Widget Extension على iOS)، فـ Flutter
مايقدرش يشتغل هناك.

الباكدج دي بتخلّيك تكتب الوصف ده بـ Dart، و `build_runner` بيحوّله لكود native حقيقي
على المنصتين:

```
widgets.dart  ──build_runner──►  Kotlin + RemoteViews XML   (Android)
   (Dart)                    └─►  SwiftUI + WidgetKit + App Intents (iOS)
                             └─►  Dart API متولّد: CounterWidget.save(count: 5)
```

## مثال كامل

```dart
@HomeScreenWidget(
  displayName: 'Counter',
  fields: [NWField.integer('count')],
  layout: NWColumn(children: [
    NWText('{count}', style: NWTextStyle(size: 44, weight: NWFontWeight.bold)),
    NWRow(spacing: 12, children: [
      NWButton(action: NWAction.decrement('count', min: 0), child: NWText('−')),
      NWButton(action: NWAction.increment('count'), child: NWText('+')),
    ]),
  ]),
)
class Counter {}
```

ومن الأبليكيشن:

```dart
await CounterWidget.save(count: 5);        // متولّد و typed
final data = await CounterWidget.read();   // data.count
```

زراير `+` و `−` بتغيّر الرقم **على الشاشة الرئيسية من غير ما الأبليكيشن يفتح**
(أندرويد، و iOS 17+).

---

## التثبيت (مرة واحدة)

```bash
flutter pub add flutter_native_widget
flutter pub add dev:flutter_native_widget_gen dev:build_runner
dart run flutter_native_widget_gen init
```

`init` بيعمل الآتي لوحده:

- ملف `flutter_native_widget.yaml` للإعدادات.
- Widget Extension اسمه `FNWWidgets` جوه مشروع Xcode (build phases، embedding، signing، App Group).
- تسجيل الـ background callbacks في `AppDelegate.swift`.
- أندرويد مش محتاج أي تعديل في Gradle.

## الاستخدام في 3 خطوات

**1. اكتب الـ widget** في أي ملف تحت `lib/`:

```dart
import 'package:flutter_native_widget/flutter_native_widget.dart';

part 'widgets.fnw.dart';

@HomeScreenWidget(displayName: 'Hello', layout: NWText('Hello 👋'))
class Hello {}
```

**2. ولّد الكود** (Dart + Kotlin + Swift):

```bash
dart run build_runner build     # أو watch
```

**3. ابدأ الـ runtime** في `main`:

```dart
import 'home_widgets.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeHomeWidgets();
  runApp(const MyApp());
}
```

خلاص. شغّل الأبليكيشن وضيف الـ widget من الشاشة الرئيسية.

---

## الباكدج تقدر تعمل إيه؟

| الميزة | إزاي | أندرويد | iOS |
|---|---|:-:|:-:|
| Layout: أعمدة، صفوف، stack، box، gradient، borders | `NWColumn` `NWRow` `NWStack` `NWBox` | ✅ | ✅ |
| نصوص، rich text، خطوط مخصصة، أيقونات النظام | `NWText` `NWRichText` `NWIcon` | ✅ | ✅ |
| ساعة digital و analog بتتحرك لوحدها | `NWClock` `NWAnalogClock` `NWDateText` | ✅ | ✅ |
| عدّاد تنازلي بالثانية | `NWTimer` | ✅ | ✅ |
| Progress bar و حلقات (زي Apple Fitness) | `NWProgress` `NWProgress.circular` | ✅ | ✅ |
| أزرار بتغيّر الداتا من غير فتح الأبليكيشن | `increment` `decrement` `toggle` `set` `cycle` | ✅ | iOS 17+ |
| كود Dart بيشتغل في الـ background لما تدوس زرار | `@WidgetCallback` | ✅ | iOS 17+ |
| قيم بتتغير لوحدها في مواعيد معروفة | `saveTimeline(...)` | ✅ | ✅ |
| أي Flutter widget كصورة (charts، CustomPaint) | `NWField.image` + `render<Field>()` | ✅ | ✅ |
| قوايم بتعمل scroll | `NWList` | Android 12+ | ❌ (حد المنصة) |
| تحميل من النت والأبليكيشن مقفول | `NWRefresh(url:, values:)` | ✅ | ✅ (https) |
| كل نسخة من الـ widget باختيار مختلف (مدينة مثلًا) | `NWOption` | ✅ | iOS 17+ |
| شكل مختلف لكل مقاس | `smallLayout` `mediumLayout` `largeLayout` | ✅ | ✅ |
| Lock Screen و StandBy | `NWSize.circular` `rectangular` `inline` | — | ✅ |
| Dark mode و RTL | `NWColor('#fff', dark: '#000')` | ✅ | ✅ |

---

## المثال: 14 widget جاهزين

كلهم في [`example/lib/widgets.dart`](example/lib/widgets.dart)، والأبليكيشن في
[`example/lib/main.dart`](example/lib/main.dart) فيه زرار لكل واحد.

| # | الـ widget | بيوريك إيه |
|---|---|---|
| 1 | **Clock** | ساعة وتاريخ بيتحركوا لوحدهم + Lock Screen |
| 2 | **Watch face** | ساعة analog و digital على gradient |
| 3 | **Counter** | أزرار `+` / `−` native |
| 4 | **Tasks** | قايمة بـ checkboxes (`NWRepeat` + `toggle`) |
| 5 | **مواقيت الصلاة** | Timeline بتنقل للصلاة الجاية لوحدها |
| 6 | **Countdown** | `NWTimer` بيتحول لـ "It's time!" |
| 7 | **Now Playing** | غلاف صورة + play/pause native + prev/next بـ Dart |
| 8 | **Quick actions** | أكتر من deep link في widget واحدة |
| 9 | **Steps** | Chart مرسوم بـ Flutter كصورة |
| 10 | **Photo album** | صور في timeline بتتغير كل ساعة |
| 11 | **Activity** | حلقات progress، أيقونات، rich text، خط مخصص |
| 12 | **News** | قايمة بتعمل scroll وبتتحدث من النت |
| 13 | **Weather** | المستخدم يختار المدينة، والطقس بيتحمّل native |
| 14 | **Water** 🆕 | شكل مختلف لكل مقاس، حلقة و bar، `set` و `cycle`، `NWCondition.greaterThan` |

```bash
cd example
dart run build_runner build
flutter run
```

على أندرويد استخدم زرار **Add to home screen** في الأبليكيشن. على iOS: دوسة طويلة على
الشاشة الرئيسية ← Edit ← Add Widget ← **Fnw Example**.

---

## الحدود (باختصار)

دي حدود **المنصة نفسها**، وأي باكدج تانية عندها نفس الحدود:

- ❌ مفيش أنيميشن حر، ولا فيديو، ولا GIF.
- ❌ مفيش تحديث كل ثانية غير للساعة والعدّاد.
- ❌ مفيش كتابة نص (TextField) ولا gestures غير الضغطة.
- ❌ مفيش scroll على iOS.
- ⚠️ iOS بيدّي ميزانية تحديثات (~40–70 في اليوم)، فاستخدم timeline.

والـ layout لازم يبقى `const` لأن الـ generator بيقراه وقت الـ build. القيم المتغيرة
بتيجي من الحقول (`{field}`) و `NWIf` و `NWRepeat`.

التفاصيل الكاملة واللي اتجرّب على أجهزة في [`STATUS.md`](STATUS.md).

---

## الـ CLI

```bash
dart run flutter_native_widget_gen init     # تجهيز المشروع مرة واحدة
dart run flutter_native_widget_gen sync     # إعادة كتابة الكود الـ native من آخر build
dart run flutter_native_widget_gen doctor   # يتأكد إن كل حاجة متوصّلة صح
dart run flutter_native_widget_gen clean    # يشيل كل اللي ضافه
```

## هيكل المشروع

| الفولدر | فيه إيه |
|---|---|
| [`packages/flutter_native_widget`](packages/flutter_native_widget/README.md) | الـ DSL (`NWColumn`, `NWText`, `NWAnalogClock`…) والـ runtime فوق `home_widget` — **الـ API reference الكامل هنا** |
| [`packages/flutter_native_widget_gen`](packages/flutter_native_widget_gen/README.md) | الـ generator والـ CLI |
| [`example`](example) | 14 widget شغّالين |
| [`docs/index.html`](docs/index.html) | صفحة الويب للمشروع |
| [`STATUS.md`](STATUS.md) | اللي خلص، اللي لسه، والحدود |
| [`PLAN.md`](PLAN.md) | الخطة |
| [`docs/EVALUATION.md`](docs/EVALUATION.md) | مقارنة بالباكدجات الموجودة |

## الاختبارات

```bash
cd packages/flutter_native_widget_gen && dart test
cd packages/flutter_native_widget && flutter test
```

الـ CI بيشغّل الاختبارات + format + analyze، وبيتأكد إن الكود المتولّد محدّث، وبيعمل
build للمثال على أندرويد و iOS.

## الترخيص

[MIT](LICENSE)
