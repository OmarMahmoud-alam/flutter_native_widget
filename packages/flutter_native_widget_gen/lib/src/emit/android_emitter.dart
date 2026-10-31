import 'dart:math' as math;

import '../config.dart';
import '../ir.dart';
import 'strings.dart';
import 'uris.dart';

const generatedXmlHeader =
    '<!-- GENERATED CODE - DO NOT MODIFY BY HAND (flutter_native_widget) -->';

/// Native output for Android.
class AndroidOutput {
  /// Path relative to `android/app/src/main` → content.
  final Map<String, String> files;

  /// `<receiver>` entries for inside `<application>`.
  final String applicationEntries;

  /// `<uses-permission>` entries for before `<application>`.
  final String manifestEntries;

  const AndroidOutput(
    this.files,
    this.applicationEntries,
    this.manifestEntries,
  );
}

/// Home screen sizes in dp: `70 × cells − 30`.
const _sizeDp = {
  'small': (110, 110),
  'medium': (250, 110),
  'large': (250, 250),
};

const _sizeCells = {'small': (2, 2), 'medium': (4, 2), 'large': (4, 4)};

/// Size thresholds used to pick a size-specific layout at runtime.
const _sizeBreakpoints = {
  'small': (100, 100),
  'medium': (220, 100),
  'large': (220, 220),
};

const _defaultText = labelColor;

const _systemActions = [
  'android.intent.action.BOOT_COMPLETED',
  'android.intent.action.MY_PACKAGE_REPLACED',
  'android.intent.action.TIME_SET',
  'android.intent.action.TIMEZONE_CHANGED',
  'android.intent.action.LOCALE_CHANGED',
];

/// Lock Screen sizes are iOS only; widgets with nothing else are skipped.
AndroidOutput emitAndroid(List<WidgetIR> widgets, ProjectConfig config) =>
    _AndroidEmitter([
      for (final w in widgets)
        if (w.hasHomeScreen) w.homeScreenOnly,
    ], config).emit();

class _AndroidEmitter {
  final List<WidgetIR> widgets;
  final ProjectConfig config;
  final files = <String, String>{};
  final _colors = <ColorIR, String>{};
  final _drawables = <String, String>{};
  final _analogClocks = <String, int>{};

  _AndroidEmitter(this.widgets, this.config);

  String get _pkg => config.androidPackage;

  AndroidOutput emit() {
    final kotlin = StringBuffer();
    final strings = StringBuffer();
    for (final w in widgets) {
      final snake = snakeCase(w.name);
      final variants = <String, _Variant>{};
      for (final MapEntry(key: variant, value: layout) in w.layouts.entries) {
        final used = variant == 'main'
            ? w.sizes.any((s) => !w.sizeLayouts.containsKey(s))
            : true;
        if (!used) continue;
        final v = _Variant(w, variant, 'fnw_${snake}_$variant');
        files['res/layout/${v.layoutName}.xml'] = _layoutXml(w, layout, v);
        variants[variant] = v;
      }
      files['res/xml/fnw_${snake}_info.xml'] = _infoXml(w, snake);
      files['res/drawable/fnw_${snake}_bg.xml'] = _shape(
        _color(w.background),
        '16dp',
      );
      files['res/drawable-v31/fnw_${snake}_bg.xml'] = _shape(
        _color(w.background),
        '@android:dimen/system_app_widget_background_radius',
      );
      strings.writeln(
        '    <string name="fnw_${snake}_label">${androidText(w.displayName)}</string>',
      );
      strings.writeln(
        '    <string name="fnw_${snake}_description">${androidText(w.description)}</string>',
      );
      kotlin.writeln(_provider(w, variants));
    }

    files['res/values/fnw_strings.xml'] = _resources(strings.toString());
    files['res/values/fnw_colors.xml'] = _resources(_colorEntries(dark: false));
    files['res/values-night/fnw_colors.xml'] = _resources(
      _colorEntries(dark: true),
    );
    files['kotlin/${_pkg.replaceAll('.', '/')}/FnwWidgets.kt'] = _kotlinFile(
      kotlin.toString(),
    );

    return AndroidOutput(files, _applicationEntries(), _manifestEntries());
  }

  // ---------------------------------------------------------------- resources

  String _color(ColorIR color) =>
      _colors.putIfAbsent(color, () => 'fnw_c${_colors.length}');

  /// A shape drawable for a box's color or gradient, border and radius.
  String? _boxDrawable(NodeIR n) {
    final color = n.color('color');
    final gradient = n.props['gradient'] as Map?;
    final border = n.color('borderColor');
    if (color == null && gradient == null && border == null) return null;
    final radius = n.number('radius') ?? 0;
    final body = StringBuffer();
    if (gradient != null) {
      final colors = [
        for (final c in gradient['colors'] as List)
          _color(ColorIR.fromJson((c as Map).cast())),
      ];
      final angle = _gradientAngle(
        gradient['begin'] as String,
        gradient['end'] as String,
      );
      body.writeln('    <gradient');
      body.writeln('        android:type="linear"');
      body.writeln('        android:angle="$angle"');
      body.writeln('        android:startColor="@color/${colors.first}"');
      if (colors.length == 3) {
        body.writeln('        android:centerColor="@color/${colors[1]}"');
      }
      body.writeln('        android:endColor="@color/${colors.last}" />');
    } else if (color != null) {
      body.writeln('    <solid android:color="@color/${_color(color)}" />');
    }
    if (border != null) {
      body.writeln(
        '    <stroke android:width="${num2(n.number('borderWidth') ?? 1)}dp" '
        'android:color="@color/${_color(border)}" />',
      );
    }
    body.writeln('    <corners android:radius="${num2(radius)}dp" />');
    final xml = body.toString();
    return _drawables.putIfAbsent(xml, () {
      final name = 'fnw_bg${_drawables.length}';
      files['res/drawable/$name.xml'] = _shapeXml(xml);
      return name;
    });
  }

  /// A vector drawable of one Material icon, shared by every use of it.
  String _icon(NodeIR n) {
    final name = 'fnw_icon_${n.prop<String>('name').toLowerCase()}';
    files['res/drawable/$name.xml'] =
        '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="${num2(n.number('viewportWidth')!)}"
    android:viewportHeight="${num2(n.number('viewportHeight')!)}">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="${n.prop<String>('path')}" />
</vector>
''';
    return name;
  }

  /// Progress drawable for `NWProgress.circular`: two rings, the top one
  /// drawn by level (0..10000) from twelve o'clock.
  String _ring(NodeIR n) {
    final size = n.number('size')!;
    final thickness = n.number('thickness')!;
    final fill = _color(n.color('color') ?? progressColor);
    final track = _color(n.color('track') ?? progressTrackColor);
    String ring(String color, bool level) =>
        '<shape android:shape="ring" '
        'android:innerRadius="${num2(size / 2 - thickness)}dp" '
        'android:thickness="${num2(thickness)}dp" '
        'android:useLevel="$level"><solid android:color="@color/$color" /></shape>';
    final xml =
        '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        ${ring(track, false)}
    </item>
    <item android:id="@android:id/progress">
        <rotate android:fromDegrees="270" android:toDegrees="270" android:pivotX="50%" android:pivotY="50%">
            ${ring(fill, true)}
        </rotate>
    </item>
</layer-list>
''';
    return _drawables.putIfAbsent(xml, () {
      final name = 'fnw_ring${_drawables.length}';
      files['res/drawable/$name.xml'] = xml;
      return name;
    });
  }

  String _shapeXml(String body) =>
      '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
$body</shape>
''';

  /// Vector drawables for an `AnalogClock`'s face and hands. Hands point to
  /// 12 o'clock from the center; the clock rotates them.
  List<String> _analogDrawables(NodeIR n) {
    final size = num2(n.number('size') ?? 120);
    final face = _color(n.color('face')!);
    final ticks = _color(n.color('ticks')!);
    final hands = _color(n.color('hands')!);
    final borderColor = n.color('border');
    final second = n.color('second');
    final allTicks = n.prop<bool>('allTicks');

    String vector(String paths) =>
        '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${size}dp"
    android:height="${size}dp"
    android:viewportWidth="100"
    android:viewportHeight="100">
$paths</vector>
''';

    String line(String color, double width, String data) =>
        '    <path android:strokeColor="@color/$color" '
        'android:strokeWidth="${num2(width)}" android:strokeLineCap="round" '
        'android:pathData="$data" />\n';

    String circle(double r) =>
        'M${num2(50 - r)},50 a$r,$r 0 1,0 ${num2(2 * r)},0 a$r,$r 0 1,0 -${num2(2 * r)},0';

    final dial = StringBuffer()
      ..write(
        '    <path android:fillColor="@color/$face" android:pathData="${circle(49)}" />\n',
      );
    if (borderColor != null) {
      dial.write(line(_color(borderColor), 2, circle(48)));
    }
    for (var i = 0; i < 12; i++) {
      final quarter = i % 3 == 0;
      if (!quarter && !allTicks) continue;
      final angle = i * 30 * 3.141592653589793 / 180;
      double x(double r) => 50 + r * _sin(angle);
      double y(double r) => 50 - r * _cos(angle);
      final inner = quarter ? 36.0 : 39.0;
      dial.write(
        line(
          ticks,
          quarter ? 3.5 : 2.2,
          'M${x(inner).toStringAsFixed(2)},${y(inner).toStringAsFixed(2)} '
          'L${x(43).toStringAsFixed(2)},${y(43).toStringAsFixed(2)}',
        ),
      );
    }

    final key = [
      size,
      face,
      ticks,
      hands,
      borderColor?.id,
      second?.id,
      allTicks,
    ].join('|');
    final id = _analogClocks.putIfAbsent(key, () => _analogClocks.length);
    final prefix = 'fnw_analog$id';
    files['res/drawable/${prefix}_dial.xml'] = vector(dial.toString());
    files['res/drawable/${prefix}_hour.xml'] = vector(
      line(hands, 5.5, 'M50,50 L50,27'),
    );
    files['res/drawable/${prefix}_minute.xml'] = vector(
      '${line(hands, 3.5, 'M50,50 L50,12')}'
      '    <path android:fillColor="@color/$hands" android:pathData="${circle(3.5)}" />\n',
    );
    final attrs = [
      'android:dial="@drawable/${prefix}_dial"',
      'android:hand_hour="@drawable/${prefix}_hour"',
      'android:hand_minute="@drawable/${prefix}_minute"',
    ];
    if (second != null) {
      final color = _color(second);
      files['res/drawable/${prefix}_second.xml'] = vector(
        '${line(color, 1.4, 'M50,58 L50,9')}'
        '    <path android:fillColor="@color/$color" android:pathData="${circle(2)}" />\n',
      );
      // Android 12+ draws (and ticks) the second hand; older versions ignore it.
      attrs.add('android:hand_second="@drawable/${prefix}_second"');
    }
    return attrs;
  }

  String _shape(String colorName, String radius) =>
      '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/$colorName" />
    <corners android:radius="$radius" />
</shape>
''';

  String _resources(String body) =>
      '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<resources>
$body</resources>
''';

  String _colorEntries({required bool dark}) {
    final b = StringBuffer();
    for (final MapEntry(key: color, value: name) in _colors.entries) {
      b.writeln(
        '    <color name="$name">${dark ? color.dark : color.light}</color>',
      );
    }
    return b.toString();
  }

  String _infoXml(WidgetIR w, String snake) {
    final ordered = [
      'small',
      'medium',
      'large',
    ].where(w.sizes.contains).toList();
    final smallest = ordered.first;
    final largest = ordered.last;
    final (minW, minH) = _sizeDp[smallest]!;
    final (maxW, maxH) = _sizeDp[largest]!;
    final (cellW, cellH) = _sizeCells[smallest]!;
    final initial = w.sizeLayouts.containsKey(smallest) ? smallest : 'main';
    final resize = ordered.length > 1 ? 'horizontal|vertical' : 'none';
    return '''
<?xml version="1.0" encoding="utf-8"?>
$generatedXmlHeader
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="${minW}dp"
    android:minHeight="${minH}dp"
    android:minResizeWidth="${minW}dp"
    android:minResizeHeight="${minH}dp"
    android:maxResizeWidth="${maxW + 60}dp"
    android:maxResizeHeight="${maxH + 60}dp"
    android:targetCellWidth="$cellW"
    android:targetCellHeight="$cellH"
    android:resizeMode="$resize"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/fnw_${snake}_$initial"
    android:previewLayout="@layout/fnw_${snake}_$initial"
    android:description="@string/fnw_${snake}_description"${w.options.isEmpty ? '' : '''
    android:configure="$_pkg.FnwConfigureActivity"
    android:widgetFeatures="reconfigurable|configuration_optional"'''}
    android:widgetCategory="home_screen" />
''';
  }

  // ------------------------------------------------------------------ layouts

  String _layoutXml(WidgetIR w, NodeIR layout, _Variant v) {
    final snake = snakeCase(w.name);
    final p = w.padding;
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln(generatedXmlHeader)
      ..writeln(
        '<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"',
      )
      ..writeln('    android:id="@android:id/background"')
      ..writeln('    android:layout_width="match_parent"')
      ..writeln('    android:layout_height="match_parent"')
      ..writeln('    android:background="@drawable/fnw_${snake}_bg"')
      ..writeln('    android:clipToOutline="true"')
      ..writeln('    android:paddingStart="${num2(p.start)}dp"')
      ..writeln('    android:paddingTop="${num2(p.top)}dp"')
      ..writeln('    android:paddingEnd="${num2(p.end)}dp"')
      ..writeln('    android:paddingBottom="${num2(p.bottom)}dp">');
    _node(out, layout, const _LP.fill(), v, 1);
    out.writeln('</FrameLayout>');
    v.bind.add(
      'v.setOnClickPendingIntent(android.R.id.background, '
      '${_pendingIntent(w, w.onTap)})',
    );
    return out.toString();
  }

  /// Layout of one NWList item (Android 12+).
  String _itemXml(NodeIR template, _Variant v) {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln(generatedXmlHeader)
      ..writeln(
        '<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"',
      )
      ..writeln('    android:layout_width="match_parent"')
      ..writeln('    android:layout_height="wrap_content">');
    _node(out, template, const _LP('match_parent', 'wrap_content'), v, 1);
    out.writeln('</FrameLayout>');
    return out.toString();
  }

  void _node(StringBuffer out, NodeIR n, _LP lp, _Variant v, int depth) {
    final pad = '    ' * depth;
    final attrs = <String>[...lp.attrs()];

    void open(String tag, {bool children = true}) {
      out.writeln('$pad<$tag');
      for (final (i, a) in attrs.indexed) {
        final last = i == attrs.length - 1;
        out.write('$pad    $a');
        out.writeln(last ? (children ? '>' : ' />') : '');
      }
      if (attrs.isEmpty) out.writeln(children ? '$pad>' : '$pad/>');
    }

    void close(String tag) => out.writeln('$pad</$tag>');

    switch (n.type) {
      case 'column':
      case 'row':
        final vertical = n.type == 'column';
        final main = n.prop<String>('main');
        final cross = n.prop<String>('cross');
        attrs.add(
          'android:orientation="${vertical ? 'vertical' : 'horizontal'}"',
        );
        attrs.add('android:gravity="${_linearGravity(vertical, main, cross)}"');
        open('LinearLayout');
        final spacing = n.number('spacing') ?? 0;
        for (final (i, child) in n.children.indexed) {
          if (i > 0 && main == 'spaceBetween') {
            out.writeln(
              '$pad    <FrameLayout android:layout_width="${vertical ? 'wrap_content' : '0dp'}" '
              'android:layout_height="${vertical ? '0dp' : 'wrap_content'}" '
              'android:layout_weight="1" />',
            );
          }
          _node(
            out,
            child,
            _LP.inLinear(
              child,
              vertical: vertical,
              stretch: cross == 'stretch',
              margin: i > 0 ? spacing : 0,
            ),
            v,
            depth + 1,
          );
        }
        close('LinearLayout');
      case 'list':
        open('FrameLayout');
        final inner = '$pad    ';
        // Android 12+: a ListView filled with RemoteCollectionItems.
        final listAttrs = <String>[];
        final listId = v.newId(listAttrs);
        final spacing = n.number('spacing') ?? 0;
        out.writeln('$inner<ListView');
        for (final a in [
          ...listAttrs,
          'android:layout_width="match_parent"',
          'android:layout_height="match_parent"',
          'android:divider="@android:color/transparent"',
          'android:dividerHeight="${num2(spacing)}dp"',
          'android:scrollbars="none"',
          'android:visibility="gone"',
        ]) {
          out.writeln('$inner    $a');
        }
        out.writeln('$inner    />');
        // Older versions: the items in a column, cut off at the bottom.
        final columnAttrs = <String>[];
        final columnId = v.newId(columnAttrs);
        out.writeln('$inner<FrameLayout');
        for (final a in columnAttrs) {
          out.writeln('$inner    $a');
        }
        out.writeln('$inner    android:layout_width="match_parent"');
        out.writeln('$inner    android:layout_height="match_parent">');
        _node(
          out,
          NodeIR('column', {
            'main': 'start',
            'cross': 'stretch',
            'spacing': spacing,
          }, n.children),
          const _LP('match_parent', 'wrap_content'),
          v,
          depth + 2,
        );
        out.writeln('$inner</FrameLayout>');
        close('FrameLayout');

        final item = _Variant(
          v.widget,
          '${v.name}List${v.items.length}',
          '${v.layoutName}_list${v.items.length}',
          item: true,
        );
        files['res/layout/${item.layoutName}.xml'] = _itemXml(
          NodeIR.fromJson((n.props['template'] as Map).cast()),
          item,
        );
        v.items.add(item);
        v.bind.addAll([
          'if (Build.VERSION.SDK_INT >= 31) {',
          '    v.setViewVisibility($listId, View.VISIBLE)',
          '    v.setViewVisibility($columnId, View.GONE)',
          '    val items = RemoteViews.RemoteCollectionItems.Builder()',
          '    for (i in 0 until ${n.prop<int>('count')}) items.addItem(i.toLong(), ${item.name}(context, d.at(i)))',
          '    v.setRemoteAdapter($listId, items.setViewTypeCount(1).build())',
          '    v.setPendingIntentTemplate($listId, Fnw.itemTemplate(context, javaClass))',
          '}',
        ]);
      case 'stack':
        open('FrameLayout');
        final gravity = _alignmentGravity(n.prop<String>('alignment'));
        for (final child in n.children) {
          _node(out, child, _LP.inFrame(child, gravity), v, depth + 1);
        }
        close('FrameLayout');
      case 'box':
        final padding = n.insets('padding');
        if (!padding.isZero) {
          attrs.addAll([
            'android:paddingStart="${num2(padding.start)}dp"',
            'android:paddingTop="${num2(padding.top)}dp"',
            'android:paddingEnd="${num2(padding.end)}dp"',
            'android:paddingBottom="${num2(padding.bottom)}dp"',
          ]);
        }
        final background = _boxDrawable(n);
        if (background != null) {
          attrs.add('android:background="@drawable/$background"');
        }
        if (n.children.isEmpty) {
          open('FrameLayout', children: false);
        } else {
          open('FrameLayout');
          final gravity = _alignmentGravity(n.prop<String>('alignment'));
          _node(
            out,
            n.children.first,
            _LP.inFrame(n.children.first, gravity),
            v,
            depth + 1,
          );
          close('FrameLayout');
        }
      case 'analog':
        attrs.addAll(_analogDrawables(n));
        open('AnalogClock', children: false);
      case 'spacer':
        open('FrameLayout', children: false);
      case 'text':
        final text = n.prop<String>('text');
        final keys = templateKeys(text);
        if (keys.isNotEmpty) {
          final id = v.newId(attrs);
          v.bind.add(
            'v.setTextViewText($id, d.resolve(${kotlinString(text)}))',
          );
        }
        attrs.add(
          'android:text="${androidText(_resolveInitial(text, v.widget))}"',
        );
        attrs.addAll(_textAttrs(n));
        open('TextView', children: false);
      case 'rich':
        final id = v.newId(attrs);
        final spans = [
          for (final (text, style) in n.spans)
            'FnwSpan(d.resolve(${kotlinString(text)}), ${num2(style.size)}f, '
                '${style.font == null && style.weight == 'bold'}, ${style.italic}, '
                '${style.font != null ? 'null' : switch (style.weight) {
                        'light' => '"sans-serif-light"',
                        'medium' || 'semibold' => '"sans-serif-medium"',
                        _ => 'null',
                      }}, R.color.${_color(style.color ?? _defaultText)})',
        ];
        v.bind.add(
          'v.setTextViewText($id, Fnw.spans(context, listOf(${spans.join(', ')})))',
        );
        attrs.add(
          'android:text="${androidText(_resolveInitial(n.spans.map((s) => s.$1).join(), v.widget))}"',
        );
        attrs.addAll(_textAttrs(n));
        open('TextView', children: false);
      case 'clock':
        final seconds = n.prop<bool>('seconds');
        final use24 = n.props['use24Hour'] as bool?;
        final f12 = seconds ? 'h:mm:ss' : 'h:mm';
        final f24 = seconds ? 'HH:mm:ss' : 'HH:mm';
        attrs.add('android:format12Hour="${use24 == true ? f24 : f12}"');
        attrs.add('android:format24Hour="${use24 == false ? f12 : f24}"');
        attrs.addAll(_textAttrs(n));
        open('TextClock', children: false);
      case 'date':
        final pattern = n.prop<String>('pattern');
        final field = n.props['field'] as String?;
        attrs.addAll(_textAttrs(n));
        if (field == null) {
          attrs.add('android:format12Hour="${androidText(pattern)}"');
          attrs.add('android:format24Hour="${androidText(pattern)}"');
          open('TextClock', children: false);
        } else {
          final id = v.newId(attrs);
          v.bind.add(
            'v.setTextViewText($id, Fnw.formatDate(d.date(${kotlinString(field)}), '
            '${kotlinString(pattern)}))',
          );
          open('TextView', children: false);
        }
      case 'timer':
        final id = v.newId(attrs);
        attrs.addAll(_textAttrs(n));
        v.bind.add(
          'Fnw.timer(v, $id, d.date(${kotlinString(n.prop<String>('field'))}))',
        );
        open('Chronometer', children: false);
      case 'image':
        final id = v.newId(attrs);
        attrs.add(
          'android:scaleType="${switch (n.prop<String>('fit')) {
            'contain' => 'fitCenter',
            'fill' => 'fitXY',
            _ => 'centerCrop',
          }}"',
        );
        v.bind.add(
          'Fnw.image(v, $id, d.value(${kotlinString(n.prop<String>('field'))}))',
        );
        open('ImageView', children: false);
      case 'icon':
        attrs.add('android:src="@drawable/${_icon(n)}"');
        attrs.add('android:scaleType="fitCenter"');
        attrs.add(
          'android:tint="@color/${_color(n.color('color') ?? labelColor)}"',
        );
        open('ImageView', children: false);
      case 'progress':
        final id = v.newId(attrs);
        attrs.add('style="?android:attr/progressBarStyleHorizontal"');
        attrs.add('android:max="1000"');
        final color = n.color('color');
        final track = n.color('track');
        if (n.props['size'] != null) {
          attrs.add('android:progressDrawable="@drawable/${_ring(n)}"');
        } else {
          if (color != null) {
            attrs.add('android:progressTint="@color/${_color(color)}"');
          }
          if (track != null) {
            attrs.add(
              'android:progressBackgroundTint="@color/${_color(track)}"',
            );
          }
        }
        v.bind.add(
          'Fnw.progress(v, $id, d.number(${kotlinString(n.prop<String>('field'))}), '
          '${n.number('max')})',
        );
        open('ProgressBar', children: false);
      case 'button':
        final id = v.newId(attrs);
        if (v.item) {
          // `%23` is the encoded `#` of the item's keys.
          v.bind.add(
            'v.setOnClickFillInIntent($id, Fnw.fillIn('
            '${kotlinString(actionUri(v.widget.name, n.action))}.replace("%23", d.index.toString())))',
          );
        } else {
          v.bind.add(
            'v.setOnClickPendingIntent($id, ${_pendingIntent(v.widget, n.action)})',
          );
        }
        open('FrameLayout');
        _node(
          out,
          n.children.first,
          lp.forChild(n.children.first),
          v,
          depth + 1,
        );
        close('FrameLayout');
      case 'if':
        open('FrameLayout');
        final c = n.condition;
        final check =
            'd.check(${kotlinString(c.kind.name)}, ${kotlinString(c.key)}, '
            '${c.value == null ? 'null' : kotlinString(c.value!)})';
        final cond = 'c${v.nextCondition()}';
        v.bind.add('val $cond = $check');
        // Each branch sits in its own container whose visibility is toggled,
        // so the branch itself keeps any id it needs.
        final branchLp = lp.forChild(n.thenNode);
        for (final (i, branch) in n.children.indexed) {
          final containerAttrs = <String>[];
          final id = v.newId(containerAttrs);
          v.bind.add(
            'v.setViewVisibility($id, if (${i == 0 ? cond : '!$cond'}) '
            'View.VISIBLE else View.GONE)',
          );
          // The XML is also the picker preview and the first frame, so show
          // the branch that matches the initial values.
          final visibleInitially =
              evaluateCondition(c, v.widget.initialValues) == (i == 0);
          if (!visibleInitially) {
            containerAttrs.add('android:visibility="gone"');
          }
          final containerLp = _LP(
            branchLp.width,
            branchLp.height,
          ).withExtra(containerAttrs);
          final innerPad = '    ' * (depth + 1);
          out.writeln('$innerPad<FrameLayout');
          for (final a in containerAttrs) {
            out.writeln('$innerPad    $a');
          }
          out.writeln(
            '$innerPad    android:layout_width="${containerLp.width}"',
          );
          out.writeln(
            '$innerPad    android:layout_height="${containerLp.height}">',
          );
          _node(out, branch, containerLp.forChild(branch), v, depth + 2);
          out.writeln('$innerPad</FrameLayout>');
        }
        close('FrameLayout');
      default:
        throw StateError('Unknown node type ${n.type}');
    }
  }

  List<String> _textAttrs(NodeIR n) {
    final style = n.style;
    final attrs = <String>[
      'android:textSize="${num2(style.size)}sp"',
      'android:textColor="@color/${_color(style.color ?? _defaultText)}"',
      'android:includeFontPadding="false"',
    ];
    final font = style.font;
    final bold = font == null && style.weight == 'bold';
    final styles = [if (bold) 'bold', if (style.italic) 'italic'];
    if (styles.isNotEmpty) attrs.add('android:textStyle="${styles.join('|')}"');
    if (font != null) {
      attrs.add('android:fontFamily="@font/${androidFontName(font)}"');
    } else {
      switch (style.weight) {
        case 'light':
          attrs.add('android:fontFamily="sans-serif-light"');
        case 'medium':
        case 'semibold':
          attrs.add('android:fontFamily="sans-serif-medium"');
      }
    }
    if (style.monospacedDigits) {
      attrs.add('android:fontFeatureSettings="tnum"');
    }
    final maxLines = n.props['maxLines'] as int?;
    if (maxLines != null) {
      attrs.add('android:maxLines="$maxLines"');
      attrs.add('android:ellipsize="end"');
    }
    final align = n.props['align'] as String? ?? 'start';
    attrs.add(
      'android:gravity="${switch (align) {
        'center' => 'center_horizontal',
        'end' => 'end',
        _ => 'start',
      }}"',
    );
    return attrs;
  }

  String _resolveInitial(String template, WidgetIR w) {
    final initial = w.initialValues;
    return template.replaceAllMapped(
      templatePattern,
      (m) => initial[m.group(1)] ?? '',
    );
  }

  String _pendingIntent(WidgetIR w, ActionIR action) {
    final uri = kotlinString(actionUri(w.name, action));
    return switch (action.kind) {
      ActionKind.openApp => 'Fnw.open(context, $uri)',
      ActionKind.callback => 'Fnw.callback(context, $uri)',
      _ => 'Fnw.native(context, javaClass, $uri)',
    };
  }

  // ------------------------------------------------------------------- kotlin

  String _provider(WidgetIR w, Map<String, _Variant> variants) {
    final cls = '${w.name}WidgetProvider';
    final b = StringBuffer();
    b.writeln('class $cls : HomeWidgetProvider() {');
    b.writeln('    override fun onUpdate(');
    b.writeln('        context: Context,');
    b.writeln('        appWidgetManager: AppWidgetManager,');
    b.writeln('        appWidgetIds: IntArray,');
    b.writeln('        widgetData: SharedPreferences,');
    b.writeln('    ) {');
    b.writeln(
      '        val d = FnwData(widgetData, NAME, INITIAL, options = OPTIONS)',
    );
    b.writeln('        for (id in appWidgetIds) {');
    b.writeln(
      '            appWidgetManager.updateAppWidget(id, views(context, d.forWidget(id), '
      'appWidgetManager.getAppWidgetOptions(id)))',
    );
    b.writeln('        }');
    if (w.refresh != null) {
      b.writeln(
        '        Fnw.refresh(this, context, javaClass, NAME, REFRESH, '
        'appWidgetIds.map { d.forWidget(it) })',
      );
    }
    b.writeln(
      '        Fnw.schedule(context, javaClass, nextRefresh(context, d))',
    );
    b.writeln('    }\n');
    b.writeln('    override fun onAppWidgetOptionsChanged(');
    b.writeln('        context: Context,');
    b.writeln('        appWidgetManager: AppWidgetManager,');
    b.writeln('        appWidgetId: Int,');
    b.writeln('        newOptions: Bundle,');
    b.writeln('    ) {');
    b.writeln(
      '        val d = FnwData(Fnw.prefs(context), NAME, INITIAL, id = appWidgetId, options = OPTIONS)',
    );
    b.writeln(
      '        appWidgetManager.updateAppWidget(appWidgetId, views(context, d, newOptions))',
    );
    b.writeln('    }\n');
    if (w.options.isNotEmpty) {
      b.writeln(
        '    override fun onDeleted(context: Context, appWidgetIds: IntArray) {',
      );
      b.writeln('        Fnw.forget(context, NAME, appWidgetIds)');
      b.writeln('    }\n');
    }
    b.writeln('    override fun onReceive(context: Context, intent: Intent) {');
    b.writeln(
      '        if (Fnw.applyAction(context, intent, NAME, INITIAL) || '
      'Fnw.applyItem(context, intent, NAME, INITIAL) || Fnw.isRefresh(intent)) {',
    );
    b.writeln(
      '            val manager = AppWidgetManager.getInstance(context)',
    );
    b.writeln(
      '            val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))',
    );
    b.writeln(
      '            onUpdate(context, manager, ids, Fnw.prefs(context))',
    );
    b.writeln('            return');
    b.writeln('        }');
    b.writeln('        super.onReceive(context, intent)');
    b.writeln('    }\n');

    // Next moment the content changes on its own.
    final timers = w.timerFields;
    b.writeln(
      '    private fun nextRefresh(context: Context, d: FnwData): Long? = listOfNotNull(',
    );
    b.writeln('        d.nextChange,');
    if (w.refresh != null) {
      b.writeln('        Fnw.nextDownload(context, NAME, REFRESH),');
    }
    for (final f in timers) {
      b.writeln('        d.date(${kotlinString(f)})?.takeIf { it > d.now },');
    }
    b.writeln('    ).minOrNull()\n');

    // Layout selection.
    b.writeln(
      '    private fun views(context: Context, d: FnwData, options: Bundle?): RemoteViews {',
    );
    final sizes = ['small', 'medium', 'large'].where(w.sizes.contains).toList();
    String variantFor(String size) =>
        w.sizeLayouts.containsKey(size) ? size : 'main';
    if (variants.length == 1) {
      b.writeln('        return ${variants.keys.single}(context, d)');
    } else {
      b.writeln('        if (Build.VERSION.SDK_INT >= 31) {');
      b.writeln('            return RemoteViews(mapOf(');
      for (final size in sizes) {
        final (bw, bh) = _sizeBreakpoints[size]!;
        b.writeln(
          '                SizeF(${bw}f, ${bh}f) to ${variantFor(size)}(context, d),',
        );
      }
      b.writeln('            ))');
      b.writeln('        }');
      b.writeln(
        '        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0',
      );
      b.writeln(
        '        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0',
      );
      // Largest first; the smallest size is the fallback below.
      for (final size in sizes.skip(1).toList().reversed) {
        final (bw, bh) = _sizeBreakpoints[size]!;
        b.writeln(
          '        if (width >= $bw && height >= $bh) return ${variantFor(size)}(context, d)',
        );
      }
      b.writeln('        return ${variantFor(sizes.first)}(context, d)');
    }
    b.writeln('    }\n');

    for (final v in [
      for (final v in variants.values) ...[v, ...v.items],
    ]) {
      b.writeln(
        '    private fun ${v.name}(context: Context, d: FnwData): RemoteViews {',
      );
      b.writeln(
        '        val v = RemoteViews(context.packageName, R.layout.${v.layoutName})',
      );
      for (final line in v.bind) {
        b.writeln('        $line');
      }
      b.writeln('        return v');
      b.writeln('    }\n');
    }

    b.writeln('    companion object {');
    b.writeln('        const val NAME = ${kotlinString(w.name)}');
    b.writeln(
      '        val OPTIONS = listOf<String>(${w.options.map((o) => kotlinString(o.key)).join(', ')})',
    );
    final refresh = w.refresh;
    if (refresh != null) {
      String map(Map<String, String> m) => m.isEmpty
          ? 'emptyMap()'
          : 'mapOf(${m.entries.map((e) => '${kotlinString(e.key)} to ${kotlinString(e.value)}').join(', ')})';
      b.writeln(
        '        internal val REFRESH = FnwRefresh(${kotlinString(refresh.url)}, ${refresh.every * 1000}L, '
        '${map(refresh.values)}, ${map(refresh.headers)}, '
        '${refresh.option == null ? 'null' : kotlinString(refresh.option!)})',
      );
    }
    b.writeln('        val INITIAL = mapOf<String, String>(');
    for (final MapEntry(:key, :value) in w.initialValues.entries) {
      b.writeln('            ${kotlinString(key)} to ${kotlinString(value)},');
    }
    b.writeln('        )');
    b.writeln('    }');
    b.writeln('}');
    return b.toString();
  }

  String _kotlinFile(String providers) {
    final namespace = config.androidNamespace;
    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by flutter_native_widget_gen from your @HomeScreenWidget classes.
@file:Suppress("unused", "UNUSED_VARIABLE", "RedundantSuppression")

package $_pkg

import android.app.Activity
import android.app.AlarmManager
import android.app.AlertDialog
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import ${config.androidMainActivity}
import $namespace.R

/** Values of one widget: stored values, overridden by the active timeline entry. */
internal class FnwData(
    private val prefs: SharedPreferences,
    private val widget: String,
    private val initial: Map<String, String>,
    val now: Long = System.currentTimeMillis(),
    /** The NWList item these values are for; `#` in keys becomes it. */
    val index: Int = 0,
    /** The widget instance, whose NWOption choices apply. */
    val id: Int = 0,
    private val options: List<String> = emptyList(),
) {
    private val all: Map<String, *> = prefs.all
    private val timeline: List<Pair<Long, Map<String, String>>> =
        Fnw.parseTimeline(all["fnw.\$widget.__timeline"]?.toString())
    private val overlay: Map<String, String> =
        timeline.lastOrNull { it.first <= now }?.second ?: emptyMap()
    private val chosen: Map<String, String> = options.associateWith {
        all["fnw.\$widget.@\$id.\$it"]?.toString() ?: initial[it] ?: ""
    }

    /** When the next timeline entry takes over, if any. */
    val nextChange: Long? = timeline.firstOrNull { it.first > now }?.first

    fun value(key: String): String {
        val k = key.replace("#", index.toString())
        chosen[k]?.let { return it }
        // Values saved for this instance's choice win over shared ones.
        for (choice in chosen.values) {
            (overlay["\$k@\$choice"] ?: all["fnw.\$widget.\$k@\$choice"]?.toString())?.let { return it }
        }
        return overlay[k] ?: all["fnw.\$widget.\$k"]?.toString() ?: initial[k] ?: ""
    }

    fun at(index: Int) = FnwData(prefs, widget, initial, now, index, id, options)

    fun forWidget(id: Int) = FnwData(prefs, widget, initial, now, index, id, options)

    fun resolve(template: String): String =
        Fnw.FIELD.replace(template) { value(it.groupValues[1]) }

    fun number(key: String): Double = value(key).toDoubleOrNull() ?: 0.0

    fun date(key: String): Long? = value(key).toLongOrNull()

    fun check(kind: String, key: String, arg: String?): Boolean = when (kind) {
        "isTrue" -> value(key) == "true"
        "isFalse" -> value(key) != "true"
        "isEmpty" -> value(key).isEmpty()
        "notEmpty" -> value(key).isNotEmpty()
        "equals" -> value(key) == arg
        "greaterThan" -> number(key) > (arg?.toDoubleOrNull() ?: 0.0)
        else -> false
    }
}

internal class FnwSpan(
    val text: String,
    val size: Float,
    val bold: Boolean,
    val italic: Boolean,
    val family: String?,
    val color: Int,
)

internal class FnwRefresh(
    val url: String,
    val every: Long,
    val values: Map<String, String>,
    val headers: Map<String, String>,
    val option: String?,
)

internal object Fnw {
    const val ACTION = "$_pkg.ACTION"
    const val TICK = "$_pkg.TICK"
    val FIELD = Regex("\\\\{([A-Za-z_][A-Za-z0-9_#]*)\\\\}")
    private val SYSTEM = setOf(
${[for (final a in _systemActions) '        ${kotlinString(a)},'].join('\n')}
    )

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    /**
     * Redraw requests: our alarms, system events, and update requests from
     * the app, whose widget ids may come back empty when looked up from
     * the app's activity; the provider looks them up itself.
     */
    fun isRefresh(intent: Intent): Boolean =
        intent.action == TICK ||
            intent.action in SYSTEM ||
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE

    fun parseTimeline(json: String?): List<Pair<Long, Map<String, String>>> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val entry = array.getJSONObject(i)
                val values = entry.optJSONObject("v") ?: JSONObject()
                entry.getLong("t") to values.keys().asSequence().associateWith { values.getString(it) }
            }.sortedBy { it.first }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun flags(): Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun open(context: Context, url: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(url))

    fun callback(context: Context, url: String): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(url))

    const val ITEM = "$_pkg.ITEM"

    /** Click template of NWList items; each item fills in its action URL. */
    fun itemTemplate(context: Context, provider: Class<*>): PendingIntent {
        val intent = Intent(context, provider).setAction(ITEM)
        val mutable = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(
            context, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT or mutable,
        )
    }

    fun fillIn(url: String): Intent = Intent().setData(Uri.parse(url))

    /** Runs a tapped NWList item's action: callbacks go to Dart. */
    fun applyItem(context: Context, intent: Intent, widget: String, initial: Map<String, String>): Boolean {
        if (intent.action != ITEM) return false
        val uri = intent.data ?: return true
        if (uri.host == "callback") {
            HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
            return false
        }
        return applyAction(context, Intent(ACTION, uri), widget, initial)
    }

    fun native(context: Context, provider: Class<*>, url: String): PendingIntent {
        val intent = Intent(context, provider).setAction(ACTION).setData(Uri.parse(url))
        return PendingIntent.getBroadcast(context, 0, intent, flags())
    }

    /** Applies a native action (increment, toggle, ...) without starting Dart. */
    fun applyAction(context: Context, intent: Intent, widget: String, initial: Map<String, String>): Boolean {
        if (intent.action != ACTION) return false
        val uri = intent.data ?: return true
        val key = uri.getQueryParameter("k") ?: return true
        val prefs = prefs(context)
        val storageKey = "fnw.\$widget.\$key"
        val current = prefs.all[storageKey]?.toString() ?: initial[key] ?: ""
        val next = when (uri.getQueryParameter("op")) {
            "inc", "dec" -> {
                val by = uri.getQueryParameter("by")?.toIntOrNull() ?: 1
                val base = current.toIntOrNull() ?: current.toDoubleOrNull()?.toInt() ?: 0
                var n = if (uri.getQueryParameter("op") == "inc") base + by else base - by
                uri.getQueryParameter("min")?.toIntOrNull()?.let { if (n < it) n = it }
                uri.getQueryParameter("max")?.toIntOrNull()?.let { if (n > it) n = it }
                n.toString()
            }
            "toggle" -> if (current == "true") "false" else "true"
            "set" -> uri.getQueryParameter("v") ?: ""
            "cycle" -> {
                val array = JSONArray(uri.getQueryParameter("vs") ?: "[]")
                val values = (0 until array.length()).map { array.getString(it) }
                if (values.isEmpty()) current else values[(values.indexOf(current) + 1) % values.size]
            }
            else -> current
        }
        prefs.edit().putString(storageKey, next).commit()
        return true
    }

    /** Wait before retrying a download that failed. */
    private const val RETRY = 5 * 60_000L

    /**
     * Downloads NWRefresh data that is due, once per NWOption choice the
     * placed widgets use, then redraws. Runs off the main thread.
     */
    fun refresh(
        receiver: BroadcastReceiver,
        context: Context,
        provider: Class<*>,
        widget: String,
        spec: FnwRefresh,
        instances: List<FnwData>,
    ) {
        val prefs = prefs(context)
        val all = prefs.all
        fun stamp(key: String) = all[key]?.toString()?.toLongOrNull() ?: 0L
        val now = System.currentTimeMillis()
        val due = instances
            .map { d -> (spec.option?.let { "@" + d.value(it) } ?: "") to d.resolve(spec.url) }
            .distinct()
            .filter { (suffix, _) ->
                now - stamp("fnw.\$widget.__fetched\$suffix") >= spec.every - 60_000 &&
                    now - stamp("fnw.\$widget.__tried\$suffix") >= RETRY
            }
        if (due.isEmpty()) return
        // Marked before downloading: redraws meanwhile, or a failure, must
        // not start the same download again right away.
        val tried = prefs.edit()
        for ((suffix, _) in due) tried.putString("fnw.\$widget.__tried\$suffix", now.toString())
        tried.commit()
        val pending = receiver.goAsync()
        // A DNS lookup can hang past the socket timeouts; never hold the
        // broadcast longer than the system allows.
        val finished = AtomicBoolean(false)
        val finish = { if (finished.compareAndSet(false, true)) pending.finish() }
        Handler(Looper.getMainLooper()).postDelayed(finish, 25_000)
        Thread {
            try {
                val editor = prefs.edit()
                var saved = false
                for ((suffix, url) in due) {
                    val json = download(url, spec.headers) ?: continue
                    for ((key, path) in spec.values) {
                        lookup(json, path)?.let { editor.putString("fnw.\$widget.\$key\$suffix", it) }
                    }
                    editor.putString("fnw.\$widget.__fetched\$suffix", now.toString())
                    saved = true
                }
                if (saved) {
                    editor.commit()
                    context.sendBroadcast(Intent(context, provider).setAction(TICK))
                }
            } finally {
                finish()
            }
        }.start()
    }

    /** When the next download (or retry) is due. */
    fun nextDownload(context: Context, widget: String, spec: FnwRefresh): Long {
        val all = prefs(context).all
        fun stamp(key: String) = all[key]?.toString()?.toLongOrNull() ?: 0L
        val prefix = "fnw.\$widget.__tried"
        val choices = all.keys.filter { it.startsWith(prefix) }.map { it.removePrefix(prefix) }
        if (choices.isEmpty()) return System.currentTimeMillis() + spec.every
        return choices.minOf {
            maxOf(stamp("fnw.\$widget.__fetched\$it") + spec.every, stamp("\$prefix\$it") + RETRY)
        }
    }

    private fun download(url: String, headers: Map<String, String>): Any? = try {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }
        if (connection.responseCode >= 300) {
            Log.w("FNW", "NWRefresh \$url: HTTP \${connection.responseCode}")
            null
        } else {
            JSONTokener(connection.inputStream.bufferedReader().use { it.readText() }).nextValue()
        }
    } catch (e: Exception) {
        Log.w("FNW", "NWRefresh \$url failed", e)
        null
    }

    /** `items.0.title` in parsed JSON, as text. */
    private fun lookup(json: Any?, path: String): String? {
        var current = json
        for (part in path.split('.')) {
            current = when (current) {
                is JSONObject -> current.opt(part)
                is JSONArray -> part.toIntOrNull()?.let { current.opt(it) }
                else -> null
            }
        }
        return if (current == null || current == JSONObject.NULL) null else current.toString()
    }

    /** Drops the NWOption choices of removed widget instances. */
    fun forget(context: Context, widget: String, ids: IntArray) {
        val prefs = prefs(context)
        val editor = prefs.edit()
        for (id in ids) {
            prefs.all.keys.filter { it.startsWith("fnw.\$widget.@\$id.") }.forEach(editor::remove)
        }
        editor.apply()
    }

    fun formatDate(millis: Long?, pattern: String): String =
        millis?.let { SimpleDateFormat(pattern, Locale.getDefault()).format(Date(it)) } ?: ""

    fun timer(views: RemoteViews, id: Int, target: Long?) {
        if (target == null) {
            views.setChronometer(id, SystemClock.elapsedRealtime(), null, false)
            return
        }
        val now = System.currentTimeMillis()
        views.setChronometer(id, SystemClock.elapsedRealtime() + (target - now), null, true)
        if (Build.VERSION.SDK_INT >= 24) views.setChronometerCountDown(id, target > now)
    }

    /** Styled text for `NWRichText`. Colors follow the theme at update time. */
    fun spans(context: Context, spans: List<FnwSpan>): CharSequence {
        val text = SpannableStringBuilder()
        for (span in spans) {
            val start = text.length
            text.append(span.text)
            val end = text.length
            if (start == end) continue
            val flags = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            text.setSpan(AbsoluteSizeSpan(span.size.toInt(), true), start, end, flags)
            text.setSpan(ForegroundColorSpan(context.getColor(span.color)), start, end, flags)
            val style = when {
                span.bold && span.italic -> Typeface.BOLD_ITALIC
                span.bold -> Typeface.BOLD
                span.italic -> Typeface.ITALIC
                else -> null
            }
            style?.let { text.setSpan(StyleSpan(it), start, end, flags) }
            span.family?.let { text.setSpan(TypefaceSpan(it), start, end, flags) }
        }
        return text
    }

    fun progress(views: RemoteViews, id: Int, value: Double, max: Double) {
        val fraction = if (max <= 0.0) 0.0 else (value / max).coerceIn(0.0, 1.0)
        views.setProgressBar(id, 1000, (fraction * 1000).toInt(), false)
    }

    fun image(views: RemoteViews, id: Int, path: String) {
        val bitmap = if (path.isEmpty()) null else try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / sample > 800 || bounds.outHeight / sample > 800) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        } catch (e: Exception) {
            null
        }
        if (bitmap == null) {
            views.setViewVisibility(id, View.GONE)
        } else {
            views.setImageViewBitmap(id, bitmap)
            views.setViewVisibility(id, View.VISIBLE)
        }
    }

    /** Wakes [provider] up at [at] to redraw (timeline entries, timers). */
    fun schedule(context: Context, provider: Class<*>, at: Long?) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = PendingIntent.getBroadcast(
            context, 1, Intent(context, provider).setAction(TICK), flags(),
        )
        if (at == null) {
            alarms.cancel(intent)
            return
        }
        if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms()) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC, at, intent)
        } else {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC, at, intent)
        }
    }
}

${_configureActivity()}
$providers''';
  }

  /// The activity that asks for a widget's NWOptions, one dialog each.
  String _configureActivity() {
    final configurable = widgets.where((w) => w.options.isNotEmpty).toList();
    if (configurable.isEmpty) return '';
    final specs = StringBuffer();
    for (final w in configurable) {
      specs.writeln(
        '    ${kotlinString(config.androidProviderClass(w.name))} to (${kotlinString(w.name)} to listOf(',
      );
      for (final o in w.options) {
        specs.writeln(
          '        FnwOption(${kotlinString(o.key)}, ${kotlinString(o.label)}, '
          'arrayOf(${o.choices.map(kotlinString).join(', ')}), ${kotlinString(o.initial)}),',
        );
      }
      specs.writeln('    )),');
    }
    return '''
internal class FnwOption(
    val key: String,
    val label: String,
    val choices: Array<String>,
    val initial: String,
)

/** Provider class → widget name and its options. */
internal val FNW_OPTIONS = mapOf<String, Pair<String, List<FnwOption>>>(
$specs)

/** Asks for each NWOption of a widget being placed or reconfigured. */
class FnwConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider
        val spec = provider?.let { FNW_OPTIONS[it.className] }
        if (provider == null || spec == null) {
            finish()
            return
        }
        ask(provider, spec.first, spec.second, 0)
    }

    private fun ask(provider: ComponentName, widget: String, options: List<FnwOption>, index: Int) {
        if (index == options.size) {
            sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .setComponent(provider)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId)),
            )
            setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            finish()
            return
        }
        val option = options[index]
        val prefs = Fnw.prefs(this)
        val key = "fnw.\$widget.@\$widgetId.\${option.key}"
        val current = prefs.all[key]?.toString() ?: option.initial
        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val theme = if (night) {
            android.R.style.Theme_DeviceDefault_Dialog_Alert
        } else {
            android.R.style.Theme_DeviceDefault_Light_Dialog_Alert
        }
        AlertDialog.Builder(this, theme)
            .setTitle(option.label)
            .setSingleChoiceItems(option.choices, option.choices.indexOf(current)) { dialog, which ->
                prefs.edit().putString(key, option.choices[which]).commit()
                dialog.dismiss()
                ask(provider, widget, options, index + 1)
            }
            .setOnCancelListener { finish() }
            .show()
    }
}
''';
  }

  String _applicationEntries() {
    final b = StringBuffer();
    for (final w in widgets) {
      final snake = snakeCase(w.name);
      b.writeln('        <receiver');
      b.writeln(
        '            android:name="${config.androidProviderClass(w.name)}"',
      );
      b.writeln('            android:exported="false"');
      b.writeln('            android:label="@string/fnw_${snake}_label">');
      b.writeln('            <intent-filter>');
      b.writeln(
        '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />',
      );
      for (final a in _systemActions) {
        b.writeln('                <action android:name="$a" />');
      }
      b.writeln('            </intent-filter>');
      b.writeln('            <meta-data');
      b.writeln('                android:name="android.appwidget.provider"');
      b.writeln('                android:resource="@xml/fnw_${snake}_info" />');
      b.writeln('        </receiver>');
    }
    if (widgets.any((w) => w.options.isNotEmpty)) {
      b.writeln('        <activity');
      b.writeln('            android:name="$_pkg.FnwConfigureActivity"');
      b.writeln('            android:exported="true"');
      b.writeln('            android:excludeFromRecents="true"');
      b.writeln('            android:taskAffinity=""');
      b.writeln(
        '            android:theme="@android:style/Theme.Translucent.NoTitleBar">',
      );
      b.writeln('            <intent-filter>');
      b.writeln(
        '                <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />',
      );
      b.writeln('            </intent-filter>');
      b.writeln('        </activity>');
    }
    b.writeln('        <receiver');
    b.writeln(
      '            android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver"',
    );
    b.writeln('            android:exported="false">');
    b.writeln('            <intent-filter>');
    b.writeln(
      '                <action android:name="es.antonborri.home_widget.action.BACKGROUND" />',
    );
    b.writeln('            </intent-filter>');
    b.writeln('        </receiver>');
    return b.toString();
  }

  String _manifestEntries() => [
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n',
    if (widgets.any((w) => w.refresh != null))
      '    <uses-permission android:name="android.permission.INTERNET" />\n',
  ].join();
}

/// One layout file of a widget and the Kotlin that fills it.
class _Variant {
  final WidgetIR widget;
  final String name;
  final String layoutName;
  final bind = <String>[];

  /// An NWList item, bound with the item's data (`d.at(i)`).
  final bool item;

  /// The NWList items inside this layout.
  final items = <_Variant>[];
  var _ids = 0;
  var _conditions = 0;

  _Variant(this.widget, this.name, this.layoutName, {this.item = false});

  /// Adds an `android:id` to [attrs] and returns its Kotlin reference.
  String newId(List<String> attrs) {
    final name = 'fnw_v${_ids++}';
    attrs.insert(0, 'android:id="@+id/$name"');
    return 'R.id.$name';
  }

  int nextCondition() => _conditions++;
}

/// Layout parameters of a view inside its parent.
class _LP {
  final String width;
  final String height;
  final int? weight;
  final String? gravity;
  final double marginStart;
  final double marginTop;
  final List<String> extra;

  const _LP(
    this.width,
    this.height, {
    this.weight,
    this.gravity,
    this.marginStart = 0,
    this.marginTop = 0,
    this.extra = const [],
  });

  const _LP.fill() : this('match_parent', 'match_parent');

  static String? _fixed(NodeIR n, String dim) {
    final value = n.type == 'analog' ? n.number('size') : n.number(dim);
    return value == null ? null : '${num2(value)}dp';
  }

  factory _LP.inLinear(
    NodeIR n, {
    required bool vertical,
    required bool stretch,
    required double margin,
  }) {
    var width = vertical && stretch ? 'match_parent' : 'wrap_content';
    var height = !vertical && stretch ? 'match_parent' : 'wrap_content';
    int? weight;
    final fills =
        (n.type == 'box' && n.prop<bool>('expand')) || n.type == 'list';
    final circular = n.type == 'progress' && n.props['size'] != null;
    final grows =
        n.type == 'spacer' ||
        fills ||
        (n.type == 'progress' && !vertical && !circular);
    if (grows) {
      weight = n.type == 'spacer' ? (n.props['flex'] as int? ?? 1) : 1;
      if (vertical) {
        height = '0dp';
        if (fills) width = 'match_parent';
      } else {
        width = '0dp';
        if (fills) height = 'match_parent';
      }
    }
    if (n.type == 'progress' && vertical) width = 'match_parent';
    return _LP(
      _fixed(n, 'width') ?? width,
      _fixed(n, 'height') ?? height,
      weight: weight,
      marginStart: vertical ? 0 : margin,
      marginTop: vertical ? margin : 0,
    );
  }

  factory _LP.inFrame(NodeIR n, String? gravity) {
    // An image without a size fills its frame, like `resizable()` on iOS.
    final fill =
        (n.type == 'box' && n.prop<bool>('expand')) ||
        n.type == 'image' ||
        n.type == 'list';
    final size = fill ? 'match_parent' : 'wrap_content';
    final progress = n.type == 'progress';
    // spaceBetween spreads children over the whole box, as on iOS.
    final spread = n.props['main'] == 'spaceBetween';
    return _LP(
      _fixed(n, 'width') ??
          (progress || (spread && n.type == 'row') ? 'match_parent' : size),
      _fixed(n, 'height') ??
          (spread && n.type == 'column' ? 'match_parent' : size),
      gravity: gravity,
    );
  }

  /// Parameters for the single child of a button or `if` container: it fills
  /// the container in every direction the container itself fills.
  _LP forChild(NodeIR child) {
    String fill(String dim, String containerDim) =>
        _fixed(child, dim) ??
        (containerDim == 'wrap_content' ? 'wrap_content' : 'match_parent');
    return _LP(fill('width', width), fill('height', height));
  }

  _LP withExtra(List<String> attrs) => _LP(
    width,
    height,
    weight: weight,
    gravity: gravity,
    marginStart: marginStart,
    marginTop: marginTop,
    extra: [...extra, ...attrs],
  );

  List<String> attrs() => [
    ...extra,
    'android:layout_width="$width"',
    'android:layout_height="$height"',
    if (weight != null) 'android:layout_weight="$weight"',
    if (gravity != null) 'android:layout_gravity="$gravity"',
    if (marginStart != 0) 'android:layout_marginStart="${num2(marginStart)}dp"',
    if (marginTop != 0) 'android:layout_marginTop="${num2(marginTop)}dp"',
  ];
}

String _linearGravity(bool vertical, String main, String cross) {
  final mainGravity = switch (main) {
    'center' => vertical ? 'center_vertical' : 'center_horizontal',
    'end' => vertical ? 'bottom' : 'end',
    _ => vertical ? 'top' : 'start',
  };
  final crossGravity = switch (cross) {
    'center' => vertical ? 'center_horizontal' : 'center_vertical',
    'end' => vertical ? 'end' : 'bottom',
    _ => vertical ? 'start' : 'top',
  };
  return '$mainGravity|$crossGravity';
}

double _sin(double radians) => math.sin(radians);

double _cos(double radians) => math.cos(radians);

/// Android gradient angle (0 = start→end, 90 = bottom→top, steps of 45°).
int _gradientAngle(String begin, String end) {
  (double, double) point(String a) => switch (a) {
    'topStart' => (0, 0),
    'topCenter' => (0.5, 0),
    'topEnd' => (1, 0),
    'centerStart' => (0, 0.5),
    'centerEnd' => (1, 0.5),
    'bottomStart' => (0, 1),
    'bottomCenter' => (0.5, 1),
    'bottomEnd' => (1, 1),
    _ => (0.5, 0.5),
  };
  final (bx, by) = point(begin);
  final (ex, ey) = point(end);
  final degrees = math.atan2(-(ey - by), ex - bx) * 180 / math.pi;
  final snapped = ((degrees / 45).round() * 45) % 360;
  return snapped < 0 ? snapped + 360 : snapped;
}

String _alignmentGravity(String alignment) => switch (alignment) {
  'topStart' => 'top|start',
  'topCenter' => 'top|center_horizontal',
  'topEnd' => 'top|end',
  'centerStart' => 'center_vertical|start',
  'centerEnd' => 'center_vertical|end',
  'bottomStart' => 'bottom|start',
  'bottomCenter' => 'bottom|center_horizontal',
  'bottomEnd' => 'bottom|end',
  _ => 'center',
};
