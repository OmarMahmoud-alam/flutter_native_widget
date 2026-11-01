# Example

A full app with 18 widgets (counter, weather, music player, prayer times,
tasks, clocks, …) lives in the repository:
[example/](https://github.com/OmarMahmoud-alam/flutter_native_widget/tree/main/example).
Screenshots and how each one was made:
[flutter-native-widget.vercel.app/examples](https://flutter-native-widget.vercel.app/examples).

The smallest widget, a counter:

```dart
// lib/widgets.dart
import 'package:flutter_native_widget/flutter_native_widget.dart';

part 'widgets.fnw.dart';

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
// lib/main.dart
import 'package:flutter/material.dart';
import 'home_widgets.g.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeHomeWidgets();
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => CounterWidget.save(count: 5),
          child: const Text('Set the widget to 5'),
        ),
      ),
    ),
  ));
}
```

Run `dart run build_runner build` after editing `widgets.dart`.

The examples below are taken from the example app.

## Tasks: repeated rows and toggles on the home screen

`repeat: 4` makes four fields (`title0`…`title3`); `#` in a key becomes the
row index. Tapping a row flips `done#` natively, without opening the app.

```dart
@HomeScreenWidget(
  displayName: 'Tasks',
  sizes: [NWSize.medium, NWSize.large],
  fields: [
    NWField.string('title', repeat: 4),
    NWField.boolean('done', repeat: 4),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      NWText('Tasks', style: NWTextStyle(size: 15, weight: NWFontWeight.semibold)),
      NWRepeat(
        count: 4,
        spacing: 4,
        child: NWIf(
          condition: NWCondition.notEmpty('title#'),
          child: NWButton(
            action: NWAction.toggle('done#'),
            child: NWRow(spacing: 8, children: [
              NWIf(
                condition: NWCondition.isTrue('done#'),
                child: NWText('☑'),
                orElse: NWText('☐'),
              ),
              NWText('{title#}', maxLines: 1),
            ]),
          ),
        ),
      ),
    ],
  ),
  onTap: NWAction.openApp('/tasks'),
)
class Tasks {}
```

```dart
await TasksWidget.save(
  title: ['Buy bread', 'Call mom', 'Finish the widget package'],
  done: [false, true, false],
);
```

## Music player: a Dart callback that runs in the background

`NWAction.callback('next')` runs the function marked
`@WidgetCallback(widget: 'NowPlaying')` in a background isolate (Android, and
iOS 17+). It reads the widget's data, changes it and saves it.

```dart
NWButton(action: NWAction.callback('previous'), child: NWText('⏮')),
NWButton(action: NWAction.callback('next'), child: NWText('⏭')),
```

```dart
@WidgetCallback(widget: 'NowPlaying')
Future<void> onMusicButton(WidgetEvent event) async {
  const tracks = [('Bohemian Rhapsody', 'Queen'), ('Clair de Lune', 'Debussy')];
  final current = await NowPlayingWidget.read();
  var index = tracks.indexWhere((t) => t.$1 == current.title);
  index = event.name == 'next'
      ? (index + 1) % tracks.length
      : (index - 1 + tracks.length) % tracks.length;
  await NowPlayingWidget.save(title: tracks[index].$1, artist: tracks[index].$2);
}
```

## Prayer times: a timeline the widget follows on its own

The app saves the whole day once. At each entry's time the system switches the
widget to the next prayer, and `NWTimer` counts down to it every second.

```dart
@HomeScreenWidget(
  displayName: 'Prayer times',
  sizes: [NWSize.small, NWSize.medium, NWSize.rectangular, NWSize.inline],
  fields: [
    NWField.string('next', initial: '—'),
    NWField.dateTime('nextAt'),
  ],
  layout: NWColumn(children: [
    NWText('{next}', style: NWTextStyle(size: 26, weight: NWFontWeight.bold)),
    NWTimer(field: 'nextAt', style: NWTextStyle(size: 20, monospacedDigits: true)),
  ]),
  inlineLayout: NWText('🕌 {next}'),
)
class PrayerTimes {}
```

```dart
// prayers: [(name, time), …] for the rest of today
await PrayerTimesWidget.save(next: prayers[0].$1, nextAt: prayers[0].$2);
await PrayerTimesWidget.saveTimeline([
  for (var i = 0; i < prayers.length - 1; i++)
    PrayerTimesTimelineEntry(
      prayers[i].$2,
      next: prayers[i + 1].$1,
      nextAt: prayers[i + 1].$2,
    ),
]);
```

More examples (clocks, weather, news, photo album, activity rings, water
tracker, …) with screenshots:
[flutter-native-widget.vercel.app/examples](https://flutter-native-widget.vercel.app/examples).
