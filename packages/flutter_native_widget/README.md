# flutter_native_widget

Write Android and iOS **home screen widgets in Dart**. A `build_runner`
generator turns them into real native widgets — RemoteViews on Android,
WidgetKit/SwiftUI on iOS — and wires up both projects for you. You never open
Xcode or write Kotlin/Swift.

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

```dart
await CounterWidget.save(count: 5);   // generated, typed
```

The `+` and `−` buttons change the value **on the home screen, without
starting your app** (Android, and iOS 17+).

## Why native?

The home screen is drawn by the launcher (Android) or SpringBoard (iOS), not by
your app. They only accept a description of the UI in their own format —
`RemoteViews` or SwiftUI in a separate, short-lived extension — so a Flutter
engine cannot run there. This package lets you write that description in Dart
and generates the native code from it. For anything the DSL cannot express,
render a Flutter widget into an image (`NWField.image` + `render<Field>`).

## Setup

```bash
flutter pub add flutter_native_widget
flutter pub add dev:flutter_native_widget_gen dev:build_runner
dart run flutter_native_widget_gen init     # once
```

`init` creates `flutter_native_widget.yaml`, adds the `FNWWidgets` widget
extension target to the Xcode project (build phases, embedding, signing copied
from your app, App Group entitlements) and registers background callbacks in
`AppDelegate.swift`. Android needs no Gradle changes.

1. Declare widgets in any file under `lib/` and add the part directive:

   ```dart
   import 'package:flutter_native_widget/flutter_native_widget.dart';

   part 'widgets.fnw.dart';
   ```

2. Generate (also writes the native code):

   ```bash
   dart run build_runner build      # or: watch
   ```

3. Initialize in `main`:

   ```dart
   import 'home_widgets.g.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await initializeHomeWidgets();
     runApp(const MyApp());
   }
   ```

**iOS signing:** the extension signs like your app. On a real device the App
Group in `flutter_native_widget.yaml` must exist for your team; Xcode's
automatic signing creates it.

## The layout language

Layouts are `const` trees of `NW*` elements. Values that change at runtime come
from **fields**: `{key}` in text, or `field:` parameters.

| Element | What it does |
|---|---|
| `NWColumn`, `NWRow` | Stack children; `mainAxisAlignment` (incl. `spaceBetween`), `crossAxisAlignment` (incl. `stretch`), `spacing`. Rows follow RTL. |
| `NWStack` | Children on top of each other, aligned. |
| `NWBox` | Size, padding, `color` or `gradient`, `borderColor`, `radius`, `expand`. |
| `NWSpacer` | Takes the remaining space. |
| `NWText` | Text with `{field}` placeholders, style, `maxLines`, alignment. |
| `NWRichText` | Text whose `NWSpan`s have their own size, weight, color, italic. |
| `NWImage` | An image file from an image field (e.g. a rendered Flutter widget). |
| `NWIcon` | A Material icon (`Icons.favorite`) on Android, the matching SF Symbol on iOS. |
| `NWProgress` | Progress bar from a number field; `NWProgress.circular` draws a ring. |
| `NWClock` | Digital time, updated by the system. |
| `NWAnalogClock` | Clock face with hands; second hand on Android 12+. |
| `NWDateText` | Today's date (updates at midnight) or a date field, ICU pattern. |
| `NWTimer` | Live countdown/count-up to a dateTime field, ticking every second. |
| `NWButton` | Makes its child tappable with an `NWAction`. |
| `NWIf` | Shows `child` or `orElse` depending on an `NWCondition`. |
| `NWRepeat` | Repeats a child; `#` in keys becomes the index (`{title#}`). |
| `NWList` | Like `NWRepeat`, but scrolls on Android 12+. iOS cannot scroll: it shows the items that fit. |

Reuse parts of a layout with top-level `const` values.

### Fields

```dart
fields: [
  NWField.string('title', initial: '—'),
  NWField.integer('count'),
  NWField.decimal('progress'),
  NWField.boolean('done', repeat: 4),   // done0..done3, List<bool> in Dart
  NWField.dateTime('nextAt'),
  NWField.image('cover'),
]
```

For each widget the generator writes a `<Name>Widget` class with `save(...)`,
`read()`, `clear()`, `update()`, `saveTimeline(...)` and, for image fields,
`render<Field>(Widget)`.

### Actions

| Action | Runs | Android | iOS 17+ | iOS 16 |
|---|---|---|---|---|
| `openApp([url or '/route'])` | opens the app | ✅ | ✅ | ✅ |
| `increment`, `decrement`, `toggle`, `set`, `cycle` | **natively**, no Dart | ✅ | ✅ (App Intent) | opens the app, which applies it |
| `callback('name')` | your `@WidgetCallback` in a background isolate | ✅ | ✅ (App Intent) | opens the app, which runs it |

```dart
@WidgetCallback(widget: 'NowPlaying')
Future<void> onMusicButton(WidgetEvent event) async {
  if (event.name == 'next') await NowPlayingWidget.save(title: 'Next song');
}
```

Launches from widgets arrive in `FlutterNativeWidget.launches` and
`FlutterNativeWidget.initialLaunch()` with the widget name and route.

### Timelines

Schedule values ahead of time; the widget switches on its own while the app is
closed — prayer times, calendars, "event finished" states:

```dart
await PrayerTimesWidget.saveTimeline([
  PrayerTimesTimelineEntry(fajr, next: 'الظهر', nextAt: dhuhr),
  PrayerTimesTimelineEntry(dhuhr, next: 'العصر', nextAt: asr),
]);
```

Android wakes the widget with `AlarmManager` (exact when allowed, otherwise
within the system's idle windows); iOS uses WidgetKit timeline entries.

Image fields work in timelines too. Render each image to its own file and put
the paths in the entries (a photo album that changes every hour):

```dart
final paths = [
  for (final (i, photo) in photos.indexed)
    await FlutterNativeWidget.renderImage(photo,
        widget: PhotoAlbumWidget.name, field: 'photo$i',
        logicalSize: const Size(360, 360)),
];
await PhotoAlbumWidget.saveTimeline([
  for (var i = 1; i < paths.length; i++)
    PhotoAlbumTimelineEntry(start.add(Duration(hours: i)), photo: paths[i]),
]);
```

### Sizes and themes

`sizes: [NWSize.small, NWSize.medium, NWSize.large]`, with optional
`smallLayout` / `mediumLayout` / `largeLayout`. Every `NWColor` takes a `dark:`
variant. Text and rows follow the device's reading direction.

### Icons, rich text and fonts

```dart
import 'package:flutter/material.dart' show Icons;

NWRow(spacing: 4, children: [
  NWIcon(Icons.local_fire_department, size: 16, color: NWColor('#FF6B00')),
  NWRichText([
    NWSpan('{steps}', size: 20, weight: NWFontWeight.bold),
    NWSpan(' / {goal}', color: NWColor.secondaryLabel),
  ]),
  NWText('Hi', style: NWTextStyle(font: 'assets/fonts/Cairo-Bold.ttf')),
])
```

- **Icons**: Android gets a small vector drawable of each icon used, not the
  whole font. iOS maps about 100 common icons to SF Symbols; for others pass
  `sfSymbol: 'star.fill'` (the generator tells you which).
- **Fonts**: a `.ttf`/`.otf` path relative to the project root. It is copied
  to `res/font` and the iOS widget extension; Android 8+.

### Choices per widget copy

```dart
@HomeScreenWidget(
  fields: [NWField.string('temp')],
  options: [NWOption('city', label: 'City', choices: ['Cairo', 'Giza'])],
  layout: NWText('{city}: {temp}'),
)
class Weather {}

await WeatherWidget.saveForCity('Giza', temp: '31°');
```

The user picks the city when placing the widget on Android (and from
"Reconfigure" on Android 12+), and from "Edit widget" on iOS 17+. Each copy
shows `{city}` and the values saved for its choice.

### Data from the web, with the app closed

```dart
refresh: NWRefresh(
  url: 'https://wttr.in/{city}?format=j1',
  every: Duration(minutes: 30),
  values: {'temp': 'current_condition.0.temp_C'},
),
```

The download runs natively (Kotlin on Android, the widget extension on iOS),
so it works without the Flutter engine. `values` maps fields to dot paths in
the JSON; `'title#': 'items.#.title'` fills a repeated field. With an option
in the URL, each choice is downloaded on its own. The system picks the exact
time: at least every 15 minutes, and iOS allows about 40–70 refreshes a day.
iOS needs `https`. A failed download is retried after 5 minutes.

### Lock Screen (iOS)

`NWSize.circular`, `NWSize.rectangular` and `NWSize.inline` add the widget to
the iOS Lock Screen (and StandBy), with `circularLayout` / `rectangularLayout` /
`inlineLayout`:

```dart
@HomeScreenWidget(
  sizes: [NWSize.small, NWSize.circular, NWSize.inline],
  layout: NWClock(),
  circularLayout: NWAnalogClock(size: 64),
  inlineLayout: NWDateText(pattern: 'EEE d MMM'),
)
class Clock {}
```

The system draws these in one tint, so your colors only change brightness;
`background` and `padding` are not applied.
`inline` shows only the first text of its layout. Android has no Lock Screen
widgets: these sizes are skipped there, and a widget with only these sizes
does not exist on Android.

## Platform notes

| | Android | iOS |
|---|---|---|
| Minimum | API 23 (home_widget) | 16.0 for the extension |
| Live clock / timer | `TextClock`, `Chronometer` | timeline every minute, `Text(.timer)` |
| Analog second hand | Android 12+ | not possible (no animation in widgets) |
| Buttons without opening the app | ✅ | iOS 17+ |
| Updating images in the background | ✅ (callbacks) | only while the app runs |
| Scrolling lists (`NWList`) | Android 12+ | not possible (the items that fit) |
| Choices per copy (`NWOption`) | when placed; Reconfigure on 12+ | iOS 17+ (Edit widget) |
| Downloads (`NWRefresh`) | ✅ | ✅ (https only) |
| Custom fonts | Android 8+ | ✅ |

Widgets cannot animate on either platform, and only `NWList` scrolls (Android).

## CLI

```bash
dart run flutter_native_widget_gen init     # one-time project setup
dart run flutter_native_widget_gen sync     # rewrite native code from the last build
dart run flutter_native_widget_gen doctor   # check the wiring
dart run flutter_native_widget_gen clean    # remove everything it added
```

`init` keeps a copy of the original project file as
`ios/Runner.xcodeproj/project.pbxproj.fnw-backup`.

## What gets generated

| Where | What |
|---|---|
| `lib/**.fnw.dart` | typed widget classes (part files) |
| `lib/home_widgets.g.dart` | specs, callbacks, `initializeHomeWidgets()` |
| `android/app/src/main/kotlin/<namespace>/fnw/FnwWidgets.kt` | providers + runtime |
| `android/app/src/main/res/*/fnw_*` | layouts, widget info, colors, drawables, strings |
| `AndroidManifest.xml` | receivers, between `flutter_native_widget` markers |
| `ios/FNWWidgets/` | SwiftUI widgets, Info.plist, entitlements |
| `ios/Runner/FNWCallbackIntent.swift` | App Intent that runs Dart callbacks |

Commit them like any other source. Nothing outside the markers and these files
is touched.

## Built on

[home_widget](https://pub.dev/packages/home_widget) for storage, updates,
background callbacks and rendering Flutter widgets to images.
