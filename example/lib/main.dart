import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_native_widget/flutter_native_widget.dart';
import 'package:home_widget/home_widget.dart';

import 'home_widgets.g.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeHomeWidgets();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_native_widget',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  StreamSubscription<WidgetLaunch>? _launches;
  String _lastLaunch = 'none yet';
  int _count = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The widget's buttons change the count while the app is in the background.
    if (state == AppLifecycleState.resumed) _refreshCount();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterNativeWidget.initialLaunch().then((launch) {
      if (launch != null) _onLaunch(launch);
    });
    _launches = FlutterNativeWidget.launches.listen(_onLaunch);
    _refreshCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launches?.cancel();
    super.dispose();
  }

  void _onLaunch(WidgetLaunch launch) {
    setState(
      () => _lastLaunch = '${launch.widget} → ${launch.route ?? launch.uri}',
    );
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final data = await CounterWidget.read();
    if (mounted) setState(() => _count = data.count ?? 0);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pin(String name) async {
    if (!Platform.isAndroid) {
      _snack('On iOS, long-press the home screen and tap + to add widgets.');
      return;
    }
    final spec = homeWidgetSpecs.firstWhere((s) => s.name == name);
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: spec.androidProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native home screen widgets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Last opened from a widget: $_lastLaunch'),
          const SizedBox(height: 12),
          _Section(
            title: 'Clock',
            subtitle: 'Ticks on its own. Nothing to update.',
            onPin: () => _pin(ClockWidget.name),
          ),
          _Section(
            title: 'Watch face',
            subtitle:
                'Analog + digital on a gradient. Second hand on Android 12+.',
            onPin: () => _pin(WatchFaceWidget.name),
          ),
          _Section(
            title: 'Counter: $_count',
            subtitle: '+ and − on the widget work without opening the app.',
            onPin: () => _pin(CounterWidget.name),
            actions: [
              FilledButton(
                onPressed: () async {
                  await CounterWidget.save(count: _count + 10);
                  await _refreshCount();
                },
                child: const Text('+10 from the app'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await CounterWidget.clear();
                  await _refreshCount();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          _Section(
            title: 'Tasks',
            subtitle: 'Tap a task on the widget to tick it off.',
            onPin: () => _pin(TasksWidget.name),
            actions: [
              FilledButton(
                onPressed: () => TasksWidget.save(
                  title: ['Buy bread', 'Call mom', 'Finish the widget package'],
                  done: [false, true, false],
                ),
                child: const Text('Save 3 tasks'),
              ),
            ],
          ),
          _Section(
            title: 'Prayer times',
            subtitle:
                'Saves today as a timeline; the widget moves on by itself.',
            onPin: () => _pin(PrayerTimesWidget.name),
            actions: [
              FilledButton(
                onPressed: _savePrayerTimes,
                child: const Text('Save today'),
              ),
              OutlinedButton(
                onPressed: _saveDemoPrayerTimes,
                child: const Text('Demo: every minute'),
              ),
            ],
          ),
          _Section(
            title: 'Countdown',
            subtitle:
                'Counts down, then flips to "It\'s time!" via the timeline.',
            onPin: () => _pin(CountdownWidget.name),
            actions: [
              FilledButton(
                onPressed: () => _saveCountdown(const Duration(minutes: 2)),
                child: const Text('In 2 minutes'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _saveCountdown(const Duration(days: 3, hours: 4)),
                child: const Text('In 3 days'),
              ),
            ],
          ),
          _Section(
            title: 'Now Playing',
            subtitle: '▶️/⏸ is native; ⏮/⏭ run Dart in the background.',
            onPin: () => _pin(NowPlayingWidget.name),
            actions: [
              FilledButton(
                onPressed: _saveTrack,
                child: const Text('Play a track'),
              ),
            ],
          ),
          _Section(
            title: 'Quick actions',
            subtitle: 'Four deep links in one widget.',
            onPin: () => _pin(QuickActionsWidget.name),
          ),
          _Section(
            title: 'Steps chart',
            subtitle: 'A Flutter chart rendered into the widget as an image.',
            onPin: () => _pin(StepsWidget.name),
            actions: [
              FilledButton(
                onPressed: _renderChart,
                child: const Text('Render chart'),
              ),
            ],
          ),
          _Section(
            title: 'Activity',
            subtitle: 'Rings, system icons, rich text and a custom font.',
            onPin: () => _pin(ActivityWidget.name),
            actions: [
              FilledButton(
                onPressed: () {
                  final random = Random();
                  ActivityWidget.save(
                    steps: 2000 + random.nextInt(9000),
                    move: random.nextDouble(),
                    exercise: random.nextDouble(),
                  );
                },
                child: const Text('Random day'),
              ),
            ],
          ),
          _Section(
            title: 'News',
            subtitle:
                'Downloads its headlines every 30 minutes with the app '
                'closed. Scrolls on Android 12+.',
            onPin: () => _pin(NewsWidget.name),
            actions: [
              OutlinedButton(
                onPressed: () => NewsWidget.save(
                  title: [for (var i = 1; i <= 10; i++) 'Sample headline $i'],
                ),
                child: const Text('Sample headlines'),
              ),
            ],
          ),
          _Section(
            title: 'Weather',
            subtitle:
                'Each copy shows the city picked for it (Android: when '
                'placed; iOS 17+: Edit widget) and downloads its weather.',
            onPin: () => _pin(WeatherWidget.name),
            actions: [
              OutlinedButton(
                onPressed: () async {
                  // The app can also save data for each choice itself.
                  for (final city in WeatherWidget.cityChoices) {
                    await WeatherWidget.saveForCity(
                      city,
                      temp: '${city.length + 15}',
                      sky: 'Saved by the app',
                      update: false,
                    );
                  }
                  await WeatherWidget.update();
                },
                child: const Text('Save from the app'),
              ),
            ],
          ),
          _Section(
            title: 'Photo album',
            subtitle:
                'Photos rendered once and saved as a timeline; the widget '
                'moves to the next one by itself.',
            onPin: () => _pin(PhotoAlbumWidget.name),
            actions: [
              FilledButton(
                onPressed: () => _saveAlbum(const Duration(hours: 1)),
                child: const Text('Every hour'),
              ),
              OutlinedButton(
                onPressed: () => _saveAlbum(const Duration(minutes: 1)),
                child: const Text('Demo: every minute'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Approximate times for Cairo at the end of October.
  Future<void> _savePrayerTimes() async {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    final prayers = [
      ('الفجر', at(4, 41)),
      ('الظهر', at(11, 39)),
      ('العصر', at(14, 49)),
      ('المغرب', at(17, 13)),
      ('العشاء', at(18, 31)),
      ('الفجر', at(4, 42).add(const Duration(days: 1))),
    ];
    await _savePrayers(prayers);
    _snack('Saved ${prayers.length} entries.');
  }

  /// Every minute a new "prayer", to watch the timeline switch.
  Future<void> _saveDemoPrayerTimes() async {
    final start = DateTime.now();
    final names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    await _savePrayers([
      for (var i = 0; i < names.length; i++)
        (names[i], start.add(Duration(minutes: i + 1))),
    ]);
    _snack('The widget switches prayer every minute.');
  }

  Future<void> _savePrayers(List<(String, DateTime)> prayers) async {
    final now = DateTime.now();
    final upcoming = prayers.where((p) => p.$2.isAfter(now)).toList();
    if (upcoming.isEmpty) return;
    // Now: the first upcoming prayer. At each prayer: the one after it.
    await PrayerTimesWidget.save(
      next: upcoming.first.$1,
      nextAt: upcoming.first.$2,
    );
    await PrayerTimesWidget.saveTimeline([
      for (var i = 0; i < upcoming.length - 1; i++)
        PrayerTimesTimelineEntry(
          upcoming[i].$2,
          next: upcoming[i + 1].$1,
          nextAt: upcoming[i + 1].$2,
        ),
    ]);
  }

  Future<void> _saveCountdown(Duration duration) async {
    final at = DateTime.now().add(duration);
    await CountdownWidget.save(
      event: duration.inDays > 0 ? 'Trip to Alexandria' : 'Tea is ready',
      at: at,
      finished: false,
    );
    await CountdownWidget.saveTimeline([
      CountdownTimelineEntry(at, finished: true),
    ]);
  }

  Future<void> _saveTrack() async {
    await NowPlayingWidget.renderCover(
      const _Cover(color: Colors.deepPurple, label: 'Q'),
      size: const Size(144, 144),
      update: false,
    );
    await NowPlayingWidget.save(
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      playing: true,
    );
  }

  /// Renders each photo to its own file, shows the first now and the rest
  /// through the timeline.
  Future<void> _saveAlbum(Duration every) async {
    const photos = [
      ('Alexandria', '🌊', Colors.blue),
      ('Siwa', '🌴', Colors.green),
      ('Giza', '🐪', Colors.orange),
      ('Sinai', '⛰️', Colors.brown),
      ('Aswan', '⛵', Colors.teal),
      ('Cairo', '🌙', Colors.indigo),
    ];
    final paths = [
      for (final (i, (_, emoji, color)) in photos.indexed)
        await FlutterNativeWidget.renderImage(
          _Photo(emoji: emoji, color: color),
          widget: PhotoAlbumWidget.name,
          field: 'photo$i',
          logicalSize: const Size(360, 360),
        ),
    ];
    final start = DateTime.now();
    await PhotoAlbumWidget.save(
      photo: paths.first,
      caption: photos.first.$1,
      update: false,
    );
    await PhotoAlbumWidget.saveTimeline([
      for (var i = 1; i < photos.length; i++)
        PhotoAlbumTimelineEntry(
          start.add(every * i),
          photo: paths[i],
          caption: photos[i].$1,
        ),
    ]);
    _snack('Saved ${photos.length} photos.');
  }

  Future<void> _renderChart() async {
    final random = Random();
    final steps = [for (var i = 0; i < 7; i++) 3000 + random.nextInt(9000)];
    await StepsWidget.renderChart(
      _StepsChart(steps: steps),
      size: const Size(320, 110),
      update: false,
    );
    await StepsWidget.save(total: steps.reduce((a, b) => a + b).toString());
    _snack('Chart rendered.');
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPin;
  final List<Widget> actions;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.onPin,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...actions,
                TextButton.icon(
                  onPressed: onPin,
                  icon: const Icon(Icons.add_to_home_screen),
                  label: const Text('Add to home screen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Color color;
  final String label;

  const _Cover({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
      ),
      child: Center(
        child: Text(
          label,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontSize: 64,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Stands in for a real photo.
class _Photo extends StatelessWidget {
  final String emoji;
  final MaterialColor color;

  const _Photo({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.shade200, color.shade700],
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 120),
        ),
      ),
    );
  }
}

class _StepsChart extends StatelessWidget {
  final List<int> steps;

  const _StepsChart({required this.steps});

  @override
  Widget build(BuildContext context) {
    final max = steps.reduce((a, b) => a > b ? a : b);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 80 * steps[i] / max,
                      decoration: BoxDecoration(
                        color: i == steps.length - 1
                            ? Colors.orange
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[i],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
