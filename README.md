# flutter_native_widget

باكدج بتخلّيك تعمل **Home Screen Widgets لأندرويد و iOS وانت بتكتب Dart بس**.
`build_runner` بيولّد الكود الـ native كله (RemoteViews + Kotlin على أندرويد، و
WidgetKit + SwiftUI على iOS)، والـ CLI بيظبط المشروعين من غير ما تفتح Xcode.

| الفولدر | فيه إيه |
|---|---|
| [`packages/flutter_native_widget`](packages/flutter_native_widget/README.md) | الـ DSL (`NWColumn`, `NWText`, `NWAnalogClock`…) والـ runtime فوق `home_widget` |
| [`packages/flutter_native_widget_gen`](packages/flutter_native_widget_gen/README.md) | الـ generator والـ CLI (`init` / `sync` / `doctor` / `clean`) |
| [`example`](example/lib/widgets.dart) | 9 widgets: ساعة، Watch face (analog + digital)، Counter، مهام، مواقيت الصلاة، عدّاد تنازلي، مشغّل موسيقى، Quick actions، chart مرسوم بـ Flutter |
| [`PLAN.md`](PLAN.md) | الخطة والحالة |
| [`STATUS.md`](STATUS.md) | اللي خلص واللي لسه، وينفع تعمل إيه وإيه اللي مش هينفع |
| [`docs/EVALUATION.md`](docs/EVALUATION.md) | تقييم الباكدجات الموجودة (Phase 0) |

## تشغيل المثال

```bash
cd example
dart run build_runner build
flutter run
```

## الاختبارات

```bash
cd packages/flutter_native_widget_gen && dart test
cd packages/flutter_native_widget && flutter test
```
