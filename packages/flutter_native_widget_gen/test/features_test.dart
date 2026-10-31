import 'package:flutter_native_widget_gen/src/config.dart';
import 'package:flutter_native_widget_gen/src/emit/android_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/dart_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/ios_emitter.dart';
import 'package:flutter_native_widget_gen/src/ir.dart';
import 'package:test/test.dart';

import 'support.dart';

const _config = ProjectConfig(
  root: '/tmp/app',
  iosAppGroup: 'group.com.example.app',
  iosDeploymentTarget: '16.0',
  androidNamespace: 'com.example.app',
  androidMainActivity: 'com.example.app.MainActivity',
);

/// Stands in for Flutter's `Icons`, which the in-memory DSL cannot import.
const icons = '''
class IconData {
  final int codePoint;
  final String? fontFamily;
  const IconData(this.codePoint, {this.fontFamily});
}
class Icons {
  static const favorite = IconData(0xe25b, fontFamily: 'MaterialIcons');
  static const unknown_thing = IconData(0xe318, fontFamily: 'MaterialIcons');
}
''';

String _swift(WidgetIR w) =>
    emitIos([w], _config)['FNWWidgets/FNWWidgets.swift']!;

String _kotlin(AndroidOutput out) =>
    out.files.entries.firstWhere((e) => e.key.endsWith('.kt')).value;

void main() {
  group('NWProgress.circular', () {
    late WidgetIR w;
    setUpAll(
      () async => w = await readWidget('''
@HomeScreenWidget(
  fields: [NWField.decimal('done')],
  layout: NWProgress.circular(field: 'done', size: 60, thickness: 8),
)
class Ring {}
'''),
    );

    test('Android draws two ring shapes filled by level', () {
      final out = emitAndroid([w], _config);
      final ring = out.files.entries.firstWhere(
        (e) => e.key.contains('fnw_ring'),
      );
      expect(ring.value, contains('android:shape="ring"'));
      expect(ring.value, contains('android:innerRadius="22dp"'));
      expect(ring.value, contains('android:useLevel="true"'));
      expect(
        out.files['res/layout/fnw_ring_main.xml'],
        contains('android:progressDrawable="@drawable/fnw_ring'),
      );
    });

    test('iOS trims a circle', () {
      final swift = _swift(w);
      expect(swift, contains('.trim(from: 0, to: FNW.fraction('));
      expect(swift, contains('.frame(width: 60, height: 60)'));
    });

    test('thickness must fit in the ring', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.decimal('done')],
  layout: NWProgress.circular(field: 'done', size: 10, thickness: 6),
)
class A {}
'''),
        contains('thickness'),
      );
    });
  });

  group('NWIcon', () {
    test('Android gets a vector drawable, iOS the SF Symbol', () async {
      final w = await readWidget('''
$icons
@HomeScreenWidget(layout: NWIcon(Icons.favorite, size: 20))
class Heart {}
''');
      final out = emitAndroid([w], _config);
      final drawable = out.files['res/drawable/fnw_icon_favorite.xml']!;
      expect(drawable, contains('<vector'));
      expect(drawable, contains('android:pathData="M'));
      expect(
        out.files['res/layout/fnw_heart_main.xml'],
        contains('android:src="@drawable/fnw_icon_favorite"'),
      );
      expect(_swift(w), contains('Image(systemName: "heart.fill")'));
    });

    test('asks for an SF Symbol it does not know', () async {
      expect(
        await errorOf('''
$icons
@HomeScreenWidget(layout: NWIcon(Icons.unknown_thing))
class A {}
'''),
        contains('sfSymbol:'),
      );
    });
  });

  test('NWRichText styles each span', () async {
    final w = await readWidget('''
@HomeScreenWidget(
  fields: [NWField.integer('steps')],
  layout: NWRichText([
    NWSpan('{steps}', size: 20, weight: NWFontWeight.bold),
    NWSpan(' steps', italic: true),
  ], style: NWTextStyle(size: 12)),
)
class Steps {}
''');
    expect(
      _kotlin(emitAndroid([w], _config)),
      contains('FnwSpan(d.resolve("{steps}"), 20f, true, false'),
    );
    final swift = _swift(w);
    expect(swift, contains('.font(.system(size: 20, weight: .bold))'));
    expect(swift, contains('\n      + Text(verbatim: " steps")'));
    expect(swift, contains('.italic()'));
  });

  test('fonts use a font resource and the Fonts folder', () async {
    final w = await readWidget('''
@HomeScreenWidget(
  layout: NWText('Hi', style: NWTextStyle(font: 'assets/fonts/Cairo-Bold.ttf')),
)
class Hello {}
''');
    expect(w.fonts, {'assets/fonts/Cairo-Bold.ttf'});
    expect(
      emitAndroid([w], _config).files['res/layout/fnw_hello_main.xml'],
      contains('android:fontFamily="@font/fnw_font_cairo_bold"'),
    );
    expect(_swift(w), contains('FNW.font("Cairo-Bold.ttf", size: 14)'));
    expect(
      await errorOf('''
@HomeScreenWidget(layout: NWText('a', style: NWTextStyle(font: 'a.woff')))
class A {}
'''),
      contains('.ttf or .otf'),
    );
  });

  group('NWList', () {
    late WidgetIR w;
    setUpAll(
      () async => w = await readWidget('''
@HomeScreenWidget(
  fields: [NWField.string('title', repeat: 3), NWField.boolean('read', repeat: 3)],
  layout: NWList(
    count: 3,
    child: NWButton(action: NWAction.toggle('read#'), child: NWText('{title#}')),
  ),
)
class Feed {}
'''),
    );

    test('keeps the item template and expands the items', () {
      final list = w.layout;
      expect(list.type, 'list');
      expect(list.children, hasLength(3));
      expect(list.children[2].children.single.prop<String>('text'), '{title2}');
      final template = NodeIR.fromJson((list.props['template'] as Map).cast());
      expect(template.children.single.prop<String>('text'), '{title#}');
    });

    test('Android fills a ListView with an item layout', () {
      final out = emitAndroid([w], _config);
      expect(out.files.keys, contains('res/layout/fnw_feed_main_list0.xml'));
      final kotlin = _kotlin(out);
      expect(kotlin, contains('RemoteViews.RemoteCollectionItems.Builder()'));
      expect(kotlin, contains('mainList0(context, d.at(i))'));
      expect(kotlin, contains('setOnClickFillInIntent'));
      expect(kotlin, contains('.replace("%23", d.index.toString())'));
    });

    test('iOS lays the items out from the top', () {
      expect(_swift(w), contains('.overlay(alignment: .top) {'));
    });

    test('items cannot open the app', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.string('t', repeat: 2)],
  layout: NWList(count: 2, child: NWButton(action: NWAction.openApp(), child: NWText('{t#}'))),
)
class A {}
'''),
        contains('cannot open the app'),
      );
    });
  });

  group('NWOption and NWRefresh', () {
    late WidgetIR w;
    setUpAll(
      () async => w = await readWidget('''
@HomeScreenWidget(
  fields: [NWField.string('temp'), NWField.string('day', repeat: 2)],
  options: [NWOption('city', label: 'City', choices: ['Cairo', 'Giza'], initial: 'Giza')],
  refresh: NWRefresh(
    url: 'https://example.com/w?q={city}',
    every: Duration(hours: 1),
    values: {'temp': 'now.temp', 'day#': 'days.#.name'},
  ),
  layout: NWText('{city}: {temp}'),
)
class Weather {}
'''),
    );

    test('reads choices and expands repeated values', () {
      expect(w.options.single.initial, 'Giza');
      expect(w.initialValues['city'], 'Giza');
      final refresh = w.refresh!;
      expect(refresh.every, 3600);
      expect(refresh.option, 'city');
      expect(refresh.values, {
        'temp': 'now.temp',
        'day0': 'days.0.name',
        'day1': 'days.1.name',
      });
    });

    test('Android adds a configure activity and downloads', () {
      final out = emitAndroid([w], _config);
      expect(
        out.files['res/xml/fnw_weather_info.xml'],
        contains(
          'android:configure="com.example.app.fnw.FnwConfigureActivity"',
        ),
      );
      expect(out.applicationEntries, contains('APPWIDGET_CONFIGURE'));
      expect(out.manifestEntries, contains('android.permission.INTERNET'));
      final kotlin = _kotlin(out);
      expect(kotlin, contains('class FnwConfigureActivity : Activity()'));
      expect(kotlin, contains('Fnw.refresh(this, context, javaClass'));
      expect(kotlin, contains('3600000L'));
    });

    test('iOS 17 gets an App Intent configuration', () {
      final swift = _swift(w);
      expect(swift, contains('enum FNWWeatherCityOption: String, AppEnum'));
      expect(swift, contains('@Parameter(title: "City", default: .c1)'));
      expect(swift, contains('AppIntentConfiguration(kind: kind'));
      expect(swift, contains('FNWWidgetBundle17.main()'));
      expect(swift, contains('await FNW.refresh("Weather", FNWWeatherRefresh'));
    });

    test('Dart can save values for one choice', () {
      final part = emitDartPart(
        LibraryIR(
          uri: 'package:app/widgets.dart',
          widgets: [w],
          callbacks: const [],
        ),
        'widgets.dart',
      );
      expect(part, contains("static const cityChoices = ['Cairo', 'Giza'];"));
      expect(part, contains('static Future<void> saveForCity('));
      expect(part, contains(r"'$key@$choice': value"));
    });

    test('refresh rules', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.string('a')],
  refresh: NWRefresh(url: 'https://x', every: Duration(minutes: 5), values: {'a': 'a'}),
  layout: NWText('{a}'),
)
class A {}
'''),
        contains('at least 15 minutes'),
      );
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.string('a')],
  refresh: NWRefresh(url: 'https://x', values: {'b': 'a'}),
  layout: NWText('{a}'),
)
class A {}
'''),
        contains('`b`'),
      );
    });
  });
}
