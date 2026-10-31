/// Intermediate representation shared by every emitter.
///
/// The reader turns `@HomeScreenWidget` annotations into this tree; the Dart,
/// Android and iOS emitters only ever look at the IR. Everything here is
/// JSON-serializable so it can be cached between build steps and read back
/// by the CLI.
library;

class LibraryIR {
  /// `package:` URI of the library that declares the widgets.
  final String uri;
  final List<WidgetIR> widgets;
  final List<CallbackIR> callbacks;

  const LibraryIR({
    required this.uri,
    required this.widgets,
    required this.callbacks,
  });

  bool get isEmpty => widgets.isEmpty && callbacks.isEmpty;

  Map<String, Object?> toJson() => {
    'uri': uri,
    'widgets': [for (final w in widgets) w.toJson()],
    'callbacks': [for (final c in callbacks) c.toJson()],
  };

  factory LibraryIR.fromJson(Map<String, Object?> json) => LibraryIR(
    uri: json['uri'] as String,
    widgets: [
      for (final w in json['widgets'] as List)
        WidgetIR.fromJson((w as Map).cast()),
    ],
    callbacks: [
      for (final c in json['callbacks'] as List)
        CallbackIR.fromJson((c as Map).cast()),
    ],
  );
}

class CallbackIR {
  final String function;
  final String? widget;

  const CallbackIR({required this.function, this.widget});

  Map<String, Object?> toJson() => {'function': function, 'widget': widget};

  factory CallbackIR.fromJson(Map<String, Object?> json) => CallbackIR(
    function: json['function'] as String,
    widget: json['widget'] as String?,
  );
}

enum FieldType { string, integer, decimal, boolean, dateTime, image }

class OptionIR {
  final String key;
  final String label;
  final List<String> choices;
  final String initial;

  const OptionIR({
    required this.key,
    required this.label,
    required this.choices,
    required this.initial,
  });

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'choices': choices,
    'initial': initial,
  };

  factory OptionIR.fromJson(Map<String, Object?> json) => OptionIR(
    key: json['key'] as String,
    label: json['label'] as String,
    choices: (json['choices'] as List).cast(),
    initial: json['initial'] as String,
  );
}

class RefreshIR {
  final String url;

  /// Seconds.
  final int every;

  /// Storage key → JSON path, with repeated fields already expanded.
  final Map<String, String> values;
  final Map<String, String> headers;

  /// The option whose choice is in [url], if any.
  final String? option;

  const RefreshIR({
    required this.url,
    required this.every,
    required this.values,
    required this.headers,
    this.option,
  });

  Map<String, Object?> toJson() => {
    'url': url,
    'every': every,
    'values': values,
    'headers': headers,
    'option': option,
  };

  factory RefreshIR.fromJson(Map<String, Object?> json) => RefreshIR(
    url: json['url'] as String,
    every: json['every'] as int,
    values: (json['values'] as Map).cast(),
    headers: (json['headers'] as Map).cast(),
    option: json['option'] as String?,
  );
}

class FieldIR {
  final String key;
  final FieldType type;
  final String initial;
  final int? repeat;

  const FieldIR({
    required this.key,
    required this.type,
    required this.initial,
    this.repeat,
  });

  /// Storage keys: `key` or `key0`, `key1`, ...
  List<String> get storageKeys =>
      repeat == null ? [key] : [for (var i = 0; i < repeat!; i++) '$key$i'];

  Map<String, Object?> toJson() => {
    'key': key,
    'type': type.name,
    'initial': initial,
    'repeat': repeat,
  };

  factory FieldIR.fromJson(Map<String, Object?> json) => FieldIR(
    key: json['key'] as String,
    type: FieldType.values.byName(json['type'] as String),
    initial: json['initial'] as String,
    repeat: json['repeat'] as int?,
  );
}

class ColorIR {
  final String light;
  final String dark;

  const ColorIR(this.light, this.dark);

  /// `#AARRGGBB`, upper case, for both variants.
  String get id => '$light/$dark';

  Map<String, Object?> toJson() => {'l': light, 'd': dark};

  factory ColorIR.fromJson(Map<String, Object?> json) =>
      ColorIR(json['l'] as String, json['d'] as String);

  @override
  bool operator ==(Object other) =>
      other is ColorIR && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

class InsetsIR {
  final double start, top, end, bottom;

  const InsetsIR(this.start, this.top, this.end, this.bottom);

  static const zero = InsetsIR(0, 0, 0, 0);

  bool get isZero => start == 0 && top == 0 && end == 0 && bottom == 0;

  List<double> toJson() => [start, top, end, bottom];

  factory InsetsIR.fromJson(List<Object?> json) => InsetsIR(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
    (json[3] as num).toDouble(),
  );
}

class TextStyleIR {
  final double size;

  /// light, regular, medium, semibold, bold
  final String weight;
  final ColorIR? color;
  final bool italic;
  final bool monospacedDigits;

  /// Font file relative to the project root, or `null` for the system font.
  final String? font;

  const TextStyleIR({
    required this.size,
    required this.weight,
    this.color,
    this.italic = false,
    this.monospacedDigits = false,
    this.font,
  });

  Map<String, Object?> toJson() => {
    'size': size,
    'weight': weight,
    'color': color?.toJson(),
    'italic': italic,
    'mono': monospacedDigits,
    if (font != null) 'font': font,
  };

  factory TextStyleIR.fromJson(Map<String, Object?> json) => TextStyleIR(
    size: (json['size'] as num).toDouble(),
    weight: json['weight'] as String,
    color: json['color'] == null
        ? null
        : ColorIR.fromJson((json['color'] as Map).cast()),
    italic: json['italic'] as bool,
    monospacedDigits: json['mono'] as bool,
    font: json['font'] as String?,
  );
}

enum ActionKind { openApp, increment, decrement, toggle, set, cycle, callback }

class ActionIR {
  final ActionKind kind;
  final String key;
  final String? value;
  final List<String>? values;
  final int by;
  final int? min;
  final int? max;

  const ActionIR({
    required this.kind,
    this.key = '',
    this.value,
    this.values,
    this.by = 1,
    this.min,
    this.max,
  });

  bool get isNative =>
      kind != ActionKind.openApp && kind != ActionKind.callback;

  /// Short operation name used in action URIs and native code.
  String get op => switch (kind) {
    ActionKind.increment => 'inc',
    ActionKind.decrement => 'dec',
    ActionKind.toggle => 'toggle',
    ActionKind.set => 'set',
    ActionKind.cycle => 'cycle',
    ActionKind.openApp => 'open',
    ActionKind.callback => 'callback',
  };

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'key': key,
    'value': value,
    'values': values,
    'by': by,
    'min': min,
    'max': max,
  };

  factory ActionIR.fromJson(Map<String, Object?> json) => ActionIR(
    kind: ActionKind.values.byName(json['kind'] as String),
    key: json['key'] as String,
    value: json['value'] as String?,
    values: (json['values'] as List?)?.cast<String>(),
    by: json['by'] as int,
    min: json['min'] as int?,
    max: json['max'] as int?,
  );
}

enum ConditionKind { isTrue, isFalse, isEmpty, notEmpty, equals, greaterThan }

class ConditionIR {
  final ConditionKind kind;
  final String key;
  final String? value;

  const ConditionIR(this.kind, this.key, [this.value]);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'key': key,
    'value': value,
  };

  factory ConditionIR.fromJson(Map<String, Object?> json) => ConditionIR(
    ConditionKind.values.byName(json['kind'] as String),
    json['key'] as String,
    json['value'] as String?,
  );
}

/// One element of a layout. [type] is one of: column, row, stack, box,
/// spacer, text, image, icon, progress, clock, analog, date, timer, button,
/// if.
/// `NWRepeat` is expanded by the reader into a column or row. A `list` has
/// its items expanded as children (iOS, old Android) and keeps the item
/// with `#` in `props['template']` (Android 12+).
class NodeIR {
  final String type;
  final Map<String, Object?> props;
  final List<NodeIR> children;

  const NodeIR(this.type, this.props, [this.children = const []]);

  T prop<T>(String name) => props[name] as T;

  ColorIR? color(String name) => props[name] == null
      ? null
      : ColorIR.fromJson((props[name] as Map).cast());

  InsetsIR insets(String name) => props[name] == null
      ? InsetsIR.zero
      : InsetsIR.fromJson(props[name] as List);

  TextStyleIR get style => TextStyleIR.fromJson((props['style'] as Map).cast());

  /// For `rich`: each span's style, with what it leaves out taken from
  /// the node's style.
  List<(String, TextStyleIR)> get spans {
    final base = style;
    return [
      for (final span in (props['spans'] as List).cast<Map>())
        (
          span['text'] as String,
          TextStyleIR(
            size: (span['size'] as num?)?.toDouble() ?? base.size,
            weight: span['weight'] as String? ?? base.weight,
            color: span['color'] == null
                ? base.color
                : ColorIR.fromJson((span['color'] as Map).cast()),
            italic: span['italic'] as bool? ?? base.italic,
            monospacedDigits: base.monospacedDigits,
            font: base.font,
          ),
        ),
    ];
  }

  ActionIR get action => ActionIR.fromJson((props['action'] as Map).cast());

  ConditionIR get condition =>
      ConditionIR.fromJson((props['condition'] as Map).cast());

  double? number(String name) => (props[name] as num?)?.toDouble();

  /// For `if`: children are `[then]` or `[then, orElse]`.
  NodeIR get thenNode => children[0];
  NodeIR? get elseNode => children.length > 1 ? children[1] : null;

  /// Visits this node and every descendant, depth first.
  Iterable<NodeIR> get descendants sync* {
    yield this;
    for (final child in children) {
      yield* child.descendants;
    }
  }

  Map<String, Object?> toJson() => {
    'type': type,
    'props': props,
    if (children.isNotEmpty) 'children': [for (final c in children) c.toJson()],
  };

  factory NodeIR.fromJson(Map<String, Object?> json) =>
      NodeIR(json['type'] as String, (json['props'] as Map).cast(), [
        for (final c in (json['children'] as List?) ?? const [])
          NodeIR.fromJson((c as Map).cast()),
      ]);
}

/// Default color of text and icons.
const labelColor = ColorIR('#FF1C1C1E', '#FFF2F2F7');

/// Default colors of `NWProgress.circular` (system blue on a faint track).
const progressColor = ColorIR('#FF007AFF', '#FF0A84FF');
const progressTrackColor = ColorIR('#336C6C70', '#40AEAEB2');

const homeScreenSizes = ['small', 'medium', 'large'];

/// iOS Lock Screen (accessory) families.
const lockScreenSizes = ['circular', 'rectangular', 'inline'];

class WidgetIR {
  /// Native name, e.g. `Counter`. Also the iOS widget kind.
  final String name;
  final String displayName;
  final String description;

  /// Entries of [homeScreenSizes] and [lockScreenSizes], in declaration order.
  final List<String> sizes;
  final List<FieldIR> fields;
  final List<OptionIR> options;
  final RefreshIR? refresh;
  final NodeIR layout;

  /// Size name → layout replacing [layout] for that size.
  final Map<String, NodeIR> sizeLayouts;
  final ColorIR background;
  final InsetsIR padding;
  final ActionIR onTap;

  const WidgetIR({
    required this.name,
    required this.displayName,
    required this.description,
    required this.sizes,
    required this.fields,
    this.options = const [],
    this.refresh,
    required this.layout,
    required this.sizeLayouts,
    required this.background,
    required this.padding,
    required this.onTap,
  });

  /// Every storage key (and option) with its initial value.
  Map<String, String> get initialValues => {
    for (final f in fields)
      for (final k in f.storageKeys) k: f.initial,
    for (final o in options) o.key: o.initial,
  };

  bool get hasHomeScreen => sizes.any(homeScreenSizes.contains);
  bool get hasLockScreen => sizes.any(lockScreenSizes.contains);

  /// This widget without its Lock Screen sizes, for platforms that have none.
  WidgetIR get homeScreenOnly => WidgetIR(
    name: name,
    displayName: displayName,
    description: description,
    sizes: [...sizes.where(homeScreenSizes.contains)],
    fields: fields,
    options: options,
    refresh: refresh,
    layout: layout,
    sizeLayouts: {
      for (final MapEntry(:key, :value) in sizeLayouts.entries)
        if (homeScreenSizes.contains(key)) key: value,
    },
    background: background,
    padding: padding,
    onTap: onTap,
  );

  /// The layout used for [size].
  NodeIR layoutFor(String size) => sizeLayouts[size] ?? layout;

  /// All distinct layouts: `main` plus one per size override.
  Map<String, NodeIR> get layouts => {'main': layout, ...sizeLayouts};

  Iterable<NodeIR> get allNodes => [
    for (final l in layouts.values) ...l.descendants,
  ];

  /// Font files used by this widget's text.
  Set<String> get fonts => {
    for (final n in allNodes)
      if ((n.props['style'] as Map?)?['font'] case final String font) font,
  };

  /// Needs a refresh every minute on iOS (digital or analog clock).
  bool get hasClock =>
      allNodes.any((n) => n.type == 'clock' || n.type == 'analog');

  bool get hasLiveDate =>
      allNodes.any((n) => n.type == 'date' && n.props['field'] == null);

  /// dateTime fields used by timers; their moments trigger a refresh.
  Set<String> get timerFields => {
    for (final n in allNodes)
      if (n.type == 'timer') n.prop<String>('field'),
  };

  Map<String, Object?> toJson() => {
    'name': name,
    'displayName': displayName,
    'description': description,
    'sizes': sizes,
    'options': [for (final o in options) o.toJson()],
    'refresh': refresh?.toJson(),
    'fields': [for (final f in fields) f.toJson()],
    'layout': layout.toJson(),
    'sizeLayouts': {
      for (final MapEntry(:key, :value) in sizeLayouts.entries)
        key: value.toJson(),
    },
    'background': background.toJson(),
    'padding': padding.toJson(),
    'onTap': onTap.toJson(),
  };

  factory WidgetIR.fromJson(Map<String, Object?> json) => WidgetIR(
    name: json['name'] as String,
    displayName: json['displayName'] as String,
    description: json['description'] as String,
    sizes: (json['sizes'] as List).cast<String>(),
    options: [
      for (final o in (json['options'] as List?) ?? const [])
        OptionIR.fromJson((o as Map).cast()),
    ],
    refresh: json['refresh'] == null
        ? null
        : RefreshIR.fromJson((json['refresh'] as Map).cast()),
    fields: [
      for (final f in json['fields'] as List)
        FieldIR.fromJson((f as Map).cast()),
    ],
    layout: NodeIR.fromJson((json['layout'] as Map).cast()),
    sizeLayouts: {
      for (final MapEntry(:key, :value)
          in (json['sizeLayouts'] as Map).cast<String, Object?>().entries)
        key: NodeIR.fromJson((value as Map).cast()),
    },
    background: ColorIR.fromJson((json['background'] as Map).cast()),
    padding: InsetsIR.fromJson(json['padding'] as List),
    onTap: ActionIR.fromJson((json['onTap'] as Map).cast()),
  );
}

/// Evaluates [c] against [values] the way the native code does.
bool evaluateCondition(ConditionIR c, Map<String, String> values) {
  final value = values[c.key] ?? '';
  return switch (c.kind) {
    ConditionKind.isTrue => value == 'true',
    ConditionKind.isFalse => value != 'true',
    ConditionKind.isEmpty => value.isEmpty,
    ConditionKind.notEmpty => value.isNotEmpty,
    ConditionKind.equals => value == c.value,
    ConditionKind.greaterThan =>
      (double.tryParse(value) ?? 0) > (double.tryParse(c.value ?? '') ?? 0),
  };
}

/// Parses `{key}` placeholders in text templates.
/// `{key}`; inside an `NWList` item template the key may hold `#`.
final templatePattern = RegExp(r'\{([A-Za-z_][A-Za-z0-9_#]*)\}');

Set<String> templateKeys(String template) => {
  for (final m in templatePattern.allMatches(template)) m.group(1)!,
};
