# الحالة والحدود — flutter_native_widget

> آخر تحديث: 2026-10-31 · التفاصيل الكاملة للخطة في [`PLAN.md`](PLAN.md)

## الخلاصة في 4 سطور

- الباكدج **شغّالة على Android و iOS**، واتجرّبت على emulator و simulator بـ 13 widget.
- أي widget **شكلها صعب تتعمل**، بس مش كل حاجة بنفس الطريقة: فيه حاجات بتترسم native وبتتحرك لوحدها، وفيه حاجات بتترسم بـ Flutter كصورة.
- اللي **مش هينفع خالص** هو حدود المنصة نفسها (أنيميشن حر، scroll على iOS، كتابة نص، تحديث كل ثانية لأي حاجة غير الساعة والعدّاد). أي باكدج تانية عندها نفس الحدود دي.
- اللي **لسه فاضل**: التجربة على iPhone حقيقي (العدّاد بالثواني والـ Lock screen)، والنشر على pub.dev (جاهز، مستني الـ license ولينك الـ repo).

---

## 1. اللي خلص ✅

### الباكدج

| الجزء | فيه إيه |
|---|---|
| DSL | `NWColumn` `NWRow` `NWStack` `NWBox` `NWSpacer` `NWText` `NWRichText` `NWImage` `NWIcon` `NWProgress` (خطّي ودايري) `NWClock` `NWAnalogClock` `NWDateText` `NWTimer` `NWButton` `NWIf` `NWRepeat` `NWList` |
| Style | ألوان light/dark، `NWGradient`، borders، radius، padding، 5 أوزان خط، italic، أرقام monospaced، **خطوط مخصصة** (`.ttf`/`.otf`) |
| أيقونات النظام | `NWIcon(Icons.x)`: Material على Android (vector drawable للأيقونة بس، مش الفونت كله)، SF Symbol على iOS |
| قوائم بتعمل scroll | `NWList`: scroll حقيقي على Android 12+، والعناصر بتتداس native |
| Widget بيتظبط من المستخدم | `NWOption`: Configure activity على Android، و Edit widget على iOS 17+. والأبليكيشن يحفظ لكل اختيار بـ `saveForCity(...)` |
| تحديث من النت والأبليكيشن مقفول | `NWRefresh(url:, values:)`: الـ download native (Kotlin وجوه الـ extension على iOS)، كل 15 دقيقة على الأقل |
| Lock screen (iOS) | `NWSize.circular` / `rectangular` / `inline` + `circularLayout`… (بتتسكب على Android) |
| Data | حقول typed: string، int، double، bool، DateTime، image. الـ API بيتولّد لوحده (`CounterWidget.save(count: 5)`) |
| Actions من غير فتح الأبليكيشن | increment، decrement، toggle، set، cycle (بتشتغل native من غير Dart) |
| Callbacks بـ Dart | `@WidgetCallback` بيشتغل في الـ background لما المستخدم يدوس زرار |
| Timeline | تحفظ قيم لمواعيد جاية والـ widget يتغيّر لوحده (مواقيت صلاة، مواعيد، عدّاد، ألبوم صور) |
| صور بـ Flutter | `render<Field>()`: أي Flutter widget بيترسم PNG ويتحط في الـ widget |
| فتح الأبليكيشن | `NWAction.openApp('/route')` + `FlutterNativeWidget.launches` |
| Generator | `build_runner` بيولّد Dart + Kotlin + RemoteViews XML + SwiftUI + App Intents |
| CLI | `init` (بيعمل الـ Widget Extension في Xcode لوحده)، `sync`، `doctor`، `clean` |
| اختبارات | 52 في الـ generator (منهم golden tests لكل الكود المتولّد) + 4 في الـ runtime، كلها ناجحة |
| CI | `.github/workflows/ci.yml`: tests + format + analyze + بيتأكد إن الكود المتولّد محدّث + build للمثال على Android و iOS |

### اتجرّب على أجهزة

| الحاجة | Android 15 | iOS 27 |
|---|---|---|
| ساعة رقمية + تاريخ بيتحركوا لوحدهم | ✅ | ✅ |
| Watch face (analog + digital + gradient) | ✅ بعقرب ثواني | ✅ من غير عقرب ثواني (حد من iOS) |
| أزرار + / − من غير فتح الأبليكيشن | ✅ | ✅ |
| Callback بـ Dart في الـ background | ✅ | ✅ |
| Timeline (مواقيت الصلاة بتتنقل لوحدها) | ✅ | ✅ |
| عدّاد تنازلي يتحول لـ "It's time!" | ✅ | ✅ |
| Chart مرسوم بـ Flutter كصورة | ✅ | ✅ |
| ألبوم صور بيتغير لوحده (صور في الـ timeline) | ✅ | ✅ |
| Lock screen widgets | — (مفيش على Android) | ⚠️ بتتبني، بس ماتجرّبتش على الشاشة: الـ simulator مابيفتحش تخصيص الـ Lock screen |
| فتح route معيّن من الـ widget | ✅ | ✅ |
| `NWTimer` بيعد كل ثانية | ✅ | ⚠️ محتاج iPhone حقيقي |
| حلقات progress + أيقونات + rich text + خط مخصص (`Activity`) | ✅ | ✅ |
| قايمة بتعمل scroll، ودوسة على عنصر بتعلّمه ✓ (`News`) | ✅ scroll لحد العنصر العاشر | ✅ العناصر اللي تكفي من فوق |
| تحميل الأخبار من النت لوحده (`News`) | ⚠️ الـ DNS بتاع الـ emulator كان بايظ؛ الكود اتجرّب لحد ما الطلب بيتبعت | ✅ عناوين حقيقية من dummyjson |
| كل نسخة باختيار مختلف (`Weather`) | ✅ Configure activity: اخترت الإسكندرية فظهر اللي الأبليكيشن حفظه لها | ✅ Edit widget: اخترت لندن فحمّل طقسها (11°C) |

---

## 2. اللي لسه ❌

| الحاجة | النوع | ليه مهمة |
|---|---|---|
| تجربة `NWTimer` على iPhone حقيقي | تجربة | الـ simulator مابيحرّكوش ثانية بثانية |
| تحميل من النت على Android على جهاز شغّال | تجربة | اتجرّب على iOS؛ الـ emulator كان الـ DNS بتاعه بايظ |
| تجربة Lock screen widgets على iPhone | تجربة | اتعملت، بس الـ simulator مابيسمحش بإضافتها |
| قوايم على Android أقدم من 12 | ميزة | بتظهر كعمود من غير scroll؛ الـ scroll محتاج `RemoteViewsService` |
| عدد عناصر متغيّر | ميزة | لازم تحدد أقصى عدد وقت الـ build (`NWList(count: 10)`) |
| Flavors / أكتر من target في iOS | تجربة | `init` اتجرّب على مشروع Flutter عادي بس |
| مشروع فيه Widget Extension معمول يدوي قبل كده | تجربة | `init` بيعمل extension اسمه `FNWWidgets` جنبه، مش بيدمج فيه |
| النشر على pub.dev | بنية | الأسامي فاضية والـ CHANGELOG جاهز. ناقص: LICENSE ولينك الـ repo (قرارك)، وبعدين `dart pub publish` |

---

## 3. هل هتشتغل لو عملت widget شكلها صعب؟

**أيوه**، بس اختار الطريقة حسب الجزء ده من الـ widget **بيتغير إمتى**:

| الطريقة | بتستخدمها لـ | بتتحرك لوحدها؟ | أمثلة |
|---|---|---|---|
| **Native DSL** | layout، نصوص، ألوان، gradients، borders، ساعات، أزرار | ✅ الساعة والتاريخ والعدّاد | Watch face، Counter، Now Playing |
| **صورة بـ Flutter** (`NWField.image`) | أي شكل الـ DSL مايقدرش يرسمه | ❌ ثابتة لحد ما ترسمها تاني | Charts، `CustomPaint`، ظلال، blur، خطوط مخصصة، أشكال غريبة |
| **Timeline** | قيم بتتغير في مواعيد معروفة | ✅ في المواعيد اللي حددتها | مواقيت صلاة، جدول محاضرات، ألبوم بيتغير كل ساعة |

والأحسن إنك **تخلط بينهم**: خلفية أو chart كصورة، وفوقها نص وساعة وأزرار native.

### أمثلة

| الـ widget | هتشتغل؟ | إزاي |
|---|---|---|
| ساعة analog جنب ساعة digital | ✅ | `NWAnalogClock` + `NWClock` في `NWRow` (موجودة في المثال: `WatchFace`) |
| ساعة analog بشكل مخصص (أرقام روماني، عقارب مزخرفة) | ⚠️ | الـ DSL بيدّيك ألوان وticks بس. شكل مخصص بالكامل = صورة، فالعقارب مش هتتحرك لوحدها؛ تقدر ترسم 60 صورة وتحطهم في timeline كل دقيقة |
| Dashboard فيه chart + أرقام + زرار refresh | ✅ | Chart صورة، الأرقام `NWText`، الزرار `NWAction.callback` بيرسم الـ chart من جديد |
| حلقة progress دايرية (زي Apple Fitness) | ✅ | `NWProgress.circular`، وتقدر تحط كذا حلقة جوه `NWStack` (موجود: `Activity`) |
| رقم كبير جنب وحدة صغيرة (`6240 / 10000`) | ✅ | `NWRichText` بـ `NWSpan` لكل جزء |
| طقس للمدينة اللي المستخدم يختارها | ✅ | `NWOption` + `NWRefresh` (موجود: `Weather`) |
| أخبار بتتحدث لوحدها | ✅ | `NWRefresh` + `NWList` (موجود: `News`) |
| بطاقة بخلفية صورة وظل وزوايا مدورة | ✅ | `NWStack` فيه `NWImage` + `NWBox(radius:)`. الظل نفسه جوه الصورة |
| ألبوم صور بيتغير كل ساعة | ✅ | `NWImage` + timeline (موجود: `PhotoAlbum`) |
| ساعة أو الصلاة الجاية على الـ Lock screen | ✅ iOS | `circularLayout` / `rectangularLayout` / `inlineLayout` (موجود في `Clock` و `PrayerTimes`) |
| مشغّل موسيقى بغلاف وأزرار | ✅ | موجود في المثال (`NowPlaying`) |
| قايمة مهام بتعمل لها ✓ | ✅ | `NWRepeat` أو `NWList` + `NWAction.toggle` (موجود: `Tasks` و `News`)، لحد أقصى عدد بتحدده |
| عدّاد تنازلي بالثواني | ✅ | `NWTimer` (على iOS محتاج تأكيد على جهاز حقيقي) |
| أنيميشن (حاجة بتلف أو بتنبض) | ❌ | حد من المنصة (شوف تحت) |

---

## 4. هل هتشتغل لو عملت widgets تانية أو في مشروع تاني؟

| السيناريو | هتشتغل؟ | ملاحظات |
|---|---|---|
| تزوّد widgets في نفس الأبليكيشن | ✅ | ضيف `@HomeScreenWidget` جديد وشغّل `build_runner`. الـ Xcode project مش بيتعدّل تاني (كل الـ widgets في ملف Swift واحد) |
| تغيّر شكل widget موجودة | ✅ | `build_runner` بيكتب الكود الـ native من جديد |
| مشروع Flutter جديد أو موجود | ✅ | `dart run flutter_native_widget_gen init` مرة واحدة، وبعدها `build_runner` |
| مشروع فيه Widget Extension يدوي | ⚠️ | هيشتغل جنبه، بس مش هيدمج معاه. ماتجرّبش |
| مشروع بـ flavors أو schemes كتير | ⚠️ | ماتجرّبش |
| iOS 16 | ⚠️ | الـ widgets بتظهر، بس الأزرار بتفتح الأبليكيشن بدل ما تشتغل جوه الـ widget (iOS 17+ بس هو اللي بيدعم ده) |
| Android 8–11 | ✅ | كله شغّال ما عدا عقرب الثواني (Android 12+) |
| تغيّر اسم حقل بعد ما نشرت الأبليكيشن | ⚠️ | الداتا القديمة اللي على أجهزة المستخدمين متخزنة بالاسم القديم |

---

## 5. الـ Limitations: اللي مش هينفع يتعمل

### أ. حدود المنصة (مستحيلة في أي باكدج، حتى لو كتبت native بإيدك)

| الحد | Android | iOS | الحل البديل |
|---|---|---|---|
| **أنيميشن حر** (حاجة بتلف، بتنبض، transitions) | ❌ | ❌ (فيه transition بسيط بين الـ timeline entries بس) | Timeline بصور مختلفة |
| **تحديث كل ثانية** لأي حاجة | ❌ | ❌ | بس الساعة (`NWClock`) والعدّاد (`NWTimer`) بيتحركوا لوحدهم |
| عقرب ثواني في الساعة analog | ✅ Android 12+ | ❌ | |
| **Scroll** | ✅ في قوائم بس (`NWList`، Android 12+) | ❌ خالص | قسّم على صفحات بأزرار التالي والسابق |
| **كتابة نص** (TextField) | ❌ | ❌ | زرار يفتح الأبليكيشن |
| Gestures غير الضغطة (سحب، ضغطة طويلة، pinch) | ❌ | ❌ | أزرار |
| فيديو أو GIF | ❌ | ❌ | صورة ثابتة أو timeline |
| تشغيل Flutter جوه الـ widget نفسها | ❌ | ❌ | ده سبب وجود الباكدج: بتحوّل الـ Dart لـ native |
| عدد مرات التحديث | مفتوح تقريبًا | بميزانية (~40–70 مرة في اليوم) | Timeline بدل التحديثات الكتير؛ `NWRefresh` كل 15 دقيقة على الأقل |
| تحميل من النت | ✅ | ✅ بس `https` | |
| الذاكرة | RemoteViews فيها حد لحجم الصور | الـ extension ليه ~30MB | صور صغيرة بمقاس الـ widget بالظبط |
| أي View أو رسم custom native | ❌ (RemoteViews بتقبل views معينة بس) | ✅ SwiftUI حر | صورة بـ Flutter |
| ظلال، blur، أشكال بـ path | ❌ native | ✅ native | صورة بـ Flutter |

### ب. حدود الباكدج دلوقتي (ممكن تتعمل بعدين)

| الحد | ليه | ممكن يتحل؟ |
|---|---|---|
| الـ layout لازم يبقى `const` | الـ generator بيقرأه وقت الـ build عشان يحوّله native | ❌ ده أساس الفكرة. القيم المتغيرة تيجي من الحقول و `NWIf` و timeline |
| مفيش if/for عادي ولا functions بترجع nodes | نفس السبب | `NWIf` و `NWRepeat` بدالهم |
| مفيش subclass لـ nodes (`class MyTile extends NWColumn`) | الـ analyzer مابيقراش حاجة غير الـ DSL classes | استخدم `const` top-level variables |
| أقصى عدد عناصر بيتحدد وقت الـ build | `NWRepeat(count:)` / `NWList(count:)` | ممكن: قوايم بعدد مفتوح على Android |
| `NWRefresh` بيقرا JSON بس | المسارات بالنقطة (`items.0.title`) | ممكن: تحويلات (تاريخ، تقريب أرقام) |
| `NWIcon` من Material Icons بس | الـ SF Symbol بيتحدد بجدول أو `sfSymbol:` | ممكن: Cupertino icons |
| ألوان الـ rich text على Android | بتاخد الـ dark/light وقت آخر تحديث | ممكن |
| Lock screen و StandBy | ✅ على iOS (`NWSize.circular` / `rectangular` / `inline`) | Android مفيهوش lock screen widgets |
| شكل مختلف حسب الحجم | ✅ موجود (`smallLayout` / `mediumLayout` / `largeLayout`) | |
| أسماء محجوزة للحقول (`name`، `startsAt`، `update`…) | بتتعارض مع الكود المتولّد | الـ generator بيقولك وقت الـ build |

---

## 6. قاعدة سريعة: أعمل الحتة دي إزاي؟

```
الحتة دي بتتغير كل ثانية أو دقيقة؟
├── أيوه، وهي ساعة أو تاريخ أو عدّاد  → NWClock / NWAnalogClock / NWDateText / NWTimer
├── أيوه، وهي حاجة تانية             → مش هينفع (حد المنصة)، استخدم timeline كل دقيقة
└── لأ
    ├── بتتغير في مواعيد معروفة        → Timeline
    ├── بتتغير لما المستخدم يدوس       → NWAction (native) أو @WidgetCallback (Dart)
    ├── جاية من النت                   → NWRefresh (والأبليكيشن مقفول)
    └── بتتغير لما الأبليكيشن يفتح     → <Name>Widget.save(...)

الـ DSL يقدر يرسمها؟
├── أيوه → native (أخف، بتتظبط مع dark mode والحجم لوحدها)
└── لأ   → NWField.image + render<Field>() بأي Flutter widget
```
