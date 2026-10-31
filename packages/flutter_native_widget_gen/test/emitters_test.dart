import 'package:flutter_native_widget_gen/src/config.dart';
import 'package:flutter_native_widget_gen/src/emit/android_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/dart_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/ios_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/uris.dart';
import 'package:flutter_native_widget_gen/src/ir.dart';
import 'package:flutter_native_widget_gen/src/native_sync.dart';
import 'package:test/test.dart';

import 'support.dart';

const _config = ProjectConfig(
  root: '/tmp/app',
  iosAppGroup: 'group.com.example.app',
  iosDeploymentTarget: '16.0',
  androidNamespace: 'com.example.app',
  androidMainActivity: 'com.example.app.MainActivity',
);

const _counter = '''
@HomeScreenWidget(
  fields: [NWField.integer('count'), NWField.boolean('on')],
  layout: NWColumn(children: [
    NWText('Count: {count}'),
    NWIf(condition: NWCondition.isTrue('on'), child: NWText('ON'), orElse: NWText('OFF')),
    NWButton(child: NWText('+'), action: NWAction.increment('count')),
    NWButton(child: NWText('↻'), action: NWAction.callback('refresh')),
    NWClock(),
  ]),
)
class Counter {}
''';

void main() {
  late WidgetIR counter;

  setUpAll(() async => counter = await readWidget(_counter));

  group('Android', () {
    late AndroidOutput out;
    setUpAll(() => out = emitAndroid([counter], _config));

    test('writes layout, info, resources and Kotlin', () {
      expect(
        out.files.keys,
        containsAll([
          'res/layout/fnw_counter_main.xml',
          'res/xml/fnw_counter_info.xml',
          'res/values/fnw_colors.xml',
          'res/values-night/fnw_colors.xml',
          'res/values/fnw_strings.xml',
          'kotlin/com/example/app/fnw/FnwWidgets.kt',
        ]),
      );
    });

    test('binds dynamic text and actions in Kotlin', () {
      final kotlin = out.files['kotlin/com/example/app/fnw/FnwWidgets.kt']!;
      expect(kotlin, contains('package com.example.app.fnw'));
      expect(
        kotlin,
        contains('class CounterWidgetProvider : HomeWidgetProvider()'),
      );
      expect(kotlin, contains('d.resolve("Count: {count}")'));
      expect(
        kotlin,
        contains(
          'Fnw.native(context, javaClass, "fnw://action?homeWidget&w=Counter&op=inc&k=count&by=1")',
        ),
      );
      expect(
        kotlin,
        contains(
          'Fnw.callback(context, "fnw://callback?homeWidget&w=Counter&n=refresh")',
        ),
      );
      expect(kotlin, contains('import com.example.app.MainActivity'));
    });

    test('uses TextClock and hides the inactive if-branch initially', () {
      final layout = out.files['res/layout/fnw_counter_main.xml']!;
      expect(layout, contains('<TextClock'));
      // `on` starts false, so the `ON` branch container is gone.
      final onIndex = layout.indexOf('android:text="ON"');
      final gone = layout.lastIndexOf('android:visibility="gone"', onIndex);
      expect(gone, greaterThan(0));
      expect(
        layout.substring(gone, onIndex),
        isNot(contains('android:text="OFF"')),
      );
    });

    test('registers a receiver per widget in the manifest', () {
      expect(
        out.applicationEntries,
        contains('com.example.app.fnw.CounterWidgetProvider'),
      );
      expect(out.applicationEntries, contains('@xml/fnw_counter_info'));
      expect(out.applicationEntries, contains('HomeWidgetBackgroundReceiver'));
    });

    test('generates analog clock drawables and gradients', () async {
      final face = await readWidget('''
@HomeScreenWidget(layout: NWBox(
  gradient: NWGradient(colors: [NWColor('#000000'), NWColor('#FFFFFF')], begin: NWAlignment.centerStart, end: NWAlignment.centerEnd),
  child: NWAnalogClock(secondHand: NWColor('#FF8800')),
))
class Face {}
''');
      final files = emitAndroid([face], _config).files;
      expect(
        files.keys,
        containsAll([
          'res/drawable/fnw_analog0_dial.xml',
          'res/drawable/fnw_analog0_hour.xml',
          'res/drawable/fnw_analog0_minute.xml',
          'res/drawable/fnw_analog0_second.xml',
        ]),
      );
      final layout = files['res/layout/fnw_face_main.xml']!;
      expect(
        layout,
        contains('android:hand_second="@drawable/fnw_analog0_second"'),
      );
      final gradient = files.entries
          .firstWhere((e) => e.value.contains('<gradient'))
          .value;
      expect(gradient, contains('android:angle="0"'));
    });
  });

  group('iOS', () {
    late String swift;
    setUpAll(
      () => swift = emitIos([counter], _config)['FNWWidgets/FNWWidgets.swift']!,
    );

    test('declares provider, view, widget and bundle', () {
      expect(swift, contains('struct FNWCounterProvider: TimelineProvider'));
      expect(swift, contains('struct FNWCounterView: View'));
      expect(swift, contains('let kind: String = "Counter"'));
      expect(swift, contains('FNWCounterWidget()'));
      expect(swift, contains('static let appGroup = "group.com.example.app"'));
    });

    test('refreshes every minute for clocks and keeps native actions', () {
      expect(swift, contains('clock: true'));
      expect(
        swift,
        contains(
          'FNWButton(url: URL(string: "fnw://action?homeWidget&w=Counter&op=inc&k=count&by=1")!, kind: .native)',
        ),
      );
      expect(swift, contains('kind: .callback'));
    });

    test('has a stand-in callback intent, the app has the real one', () {
      expect(swift, contains('struct FNWCallbackIntent: AppIntent'));
      expect(swift, isNot(contains('import home_widget')));
      expect(callbackIntentSwift, contains('import home_widget'));
      expect(callbackIntentSwift, contains('ForegroundContinuableIntent'));
      expect(
        callbackIntentSwift,
        contains('WidgetCenter.shared.reloadAllTimelines()'),
        reason: 'redraw after the Dart callback even on a cold start',
      );
    });

    test('key paths keep their backslash', () async {
      final face = await readWidget('''
@HomeScreenWidget(layout: NWAnalogClock(), smallLayout: NWText('s'))
class Face {}
''');
      final source = emitIos([face], _config)['FNWWidgets/FNWWidgets.swift']!;
      expect(source, contains(r'ForEach(0..<12, id: \.self)'));
      expect(source, contains(r'@Environment(\.widgetFamily)'));
    });
  });

  group('Lock Screen', () {
    late WidgetIR clock;
    late WidgetIR lockOnly;
    setUpAll(() async {
      clock = await readWidget('''
@HomeScreenWidget(
  sizes: [NWSize.small, NWSize.circular, NWSize.inline],
  layout: NWClock(),
  circularLayout: NWAnalogClock(size: 64),
)
class Clock {}
''');
      lockOnly = await readWidget('''
@HomeScreenWidget(sizes: [NWSize.rectangular], layout: NWText('hi'))
class Glance {}
''');
    });

    test('iOS declares accessory families without padding or background', () {
      final swift = emitIos([clock], _config)['FNWWidgets/FNWWidgets.swift']!;
      expect(
        swift,
        contains(
          '.supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])',
        ),
      );
      expect(swift, contains('case .accessoryCircular: circular'));
      expect(
        swift,
        contains('.padding(family.fnwIsAccessory ? EdgeInsets() :'),
      );
      expect(swift, contains('family.fnwIsAccessory ? Color.clear :'));
    });

    test('Android keeps home screen sizes and skips lock-only widgets', () {
      final out = emitAndroid([clock, lockOnly], _config);
      expect(out.files.keys, contains('res/xml/fnw_clock_info.xml'));
      expect(
        out.files.keys,
        isNot(contains('res/layout/fnw_clock_circular.xml')),
      );
      expect(out.files.keys.where((k) => k.contains('glance')), isEmpty);
      expect(out.applicationEntries, isNot(contains('Glance')));
    });

    test('the registry has no Android provider for lock-only widgets', () {
      final registry = emitRegistry([
        LibraryIR(
          uri: 'package:app/widgets.dart',
          widgets: [lockOnly],
          callbacks: const [],
        ),
      ], _config);
      expect(registry, contains("name: 'Glance'"));
      expect(registry, isNot(contains('androidProvider')));
    });
  });

  group('Dart', () {
    test('part file has typed save/read and timeline entries', () {
      final part = emitDartPart(
        LibraryIR(
          uri: 'package:app/widgets.dart',
          widgets: [counter],
          callbacks: const [],
        ),
        'widgets.dart',
      );
      expect(part, contains("part of 'widgets.dart';"));
      expect(part, contains('abstract final class CounterWidget'));
      expect(part, contains('static Future<void> save({'));
      expect(part, contains('int? count,'));
      expect(part, contains('class CounterTimelineEntry'));
      expect(part, contains('final DateTime startsAt;'));
    });

    test('registry wires specs, callbacks and the dispatcher', () {
      final registry = emitRegistry([
        LibraryIR(
          uri: 'package:app/widgets.dart',
          widgets: [counter],
          callbacks: const [
            CallbackIR(function: 'onRefresh', widget: 'Counter'),
          ],
        ),
      ], _config);
      expect(registry, contains("import 'package:app/widgets.dart' as i0;"));
      expect(
        registry,
        contains(
          "androidProvider: 'com.example.app.fnw.CounterWidgetProvider'",
        ),
      );
      expect(registry, contains("RegisteredCallback('Counter', i0.onRefresh)"));
      expect(registry, contains("@pragma('vm:entry-point')"));
      expect(registry, contains('Future<void> initializeHomeWidgets()'));
    });
  });

  group('URIs', () {
    test('encode spaces as %20 and keep the home_widget marker', () {
      expect(
        actionUri(
          'W',
          const ActionIR(kind: ActionKind.set, key: 'k', value: 'a b'),
        ),
        'fnw://action?homeWidget&w=W&op=set&k=k&v=a%20b',
      );
      expect(
        actionUri(
          'W',
          const ActionIR(kind: ActionKind.openApp, value: '/tasks'),
        ),
        'fnw://open?homeWidget&w=W&route=%2Ftasks',
      );
      expect(
        actionUri(
          'W',
          const ActionIR(kind: ActionKind.openApp, value: 'myapp://x'),
        ),
        startsWith('myapp://x?homeWidget&'),
      );
    });
  });

  group('manifest', () {
    const manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="app">
        <activity android:name=".MainActivity" />
    </application>
</manifest>
''';

    test('adds the generated blocks once and replaces them on update', () {
      final first = updateManifest(
        manifest,
        '        <receiver a />\n',
        '    <uses-permission b />\n',
      )!;
      expect(first, contains('<receiver a />'));
      expect(
        first.indexOf('<uses-permission b />'),
        lessThan(first.indexOf('<application')),
      );
      final second = updateManifest(
        first,
        '        <receiver c />\n',
        '    <uses-permission b />\n',
      )!;
      expect(second, contains('<receiver c />'));
      expect(second, isNot(contains('<receiver a />')));
      expect(
        updateManifest(
          second,
          '        <receiver c />\n',
          '    <uses-permission b />\n',
        ),
        second,
      );
      expect(removeManifestBlocks(second), manifest);
    });
  });

  test('conditions evaluate like the native code', () {
    const values = {'on': 'true', 'n': '5', 'empty': ''};
    expect(
      evaluateCondition(const ConditionIR(ConditionKind.isTrue, 'on'), values),
      isTrue,
    );
    expect(
      evaluateCondition(
        const ConditionIR(ConditionKind.isEmpty, 'empty'),
        values,
      ),
      isTrue,
    );
    expect(
      evaluateCondition(
        const ConditionIR(ConditionKind.greaterThan, 'n', '4'),
        values,
      ),
      isTrue,
    );
    expect(
      evaluateCondition(
        const ConditionIR(ConditionKind.equals, 'n', '6'),
        values,
      ),
      isFalse,
    );
  });
}
