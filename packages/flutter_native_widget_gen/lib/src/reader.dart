import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'icon_font.dart';
import 'ir.dart';
import 'sf_symbols.dart';

/// A problem in a widget declaration, reported to the developer as is.
class FnwException implements Exception {
  final String message;

  FnwException(this.message);

  @override
  String toString() => 'flutter_native_widget: $message';
}

const _runtimeLibrary = 'package:flutter_native_widget/';

/// Names used by the generated classes, plus Dart's reserved words.
const _reservedFieldKeys = {
  'startsAt',
  'toValues',
  'update',
  'name',
  'initialValues',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
};

/// Reads every `@HomeScreenWidget` class and `@WidgetCallback` function in
/// [library].
LibraryIR readLibrary(LibraryElement library) {
  final widgets = <WidgetIR>[];
  final callbacks = <CallbackIR>[];

  for (final cls in library.classes) {
    for (final annotation in cls.metadata.annotations) {
      final value = annotation.computeConstantValue();
      if (_isRuntimeType(value, 'HomeScreenWidget')) {
        widgets.add(_WidgetReader(cls.name ?? '', value!).read());
      }
    }
  }

  for (final function in library.topLevelFunctions) {
    for (final annotation in function.metadata.annotations) {
      final value = annotation.computeConstantValue();
      if (_isRuntimeType(value, 'WidgetCallback')) {
        if (function.formalParameters.length != 1) {
          throw FnwException(
            '@WidgetCallback function `${function.name}` must take exactly one '
            'parameter: `${function.name}(WidgetEvent event)`.',
          );
        }
        callbacks.add(
          CallbackIR(
            function: function.name ?? '',
            widget: value!.getField('widget')?.toStringValue(),
          ),
        );
      }
    }
  }

  final names = <String>{};
  for (final w in widgets) {
    if (!names.add(w.name)) {
      throw FnwException('Two widgets are named `${w.name}`.');
    }
  }

  return LibraryIR(
    uri: library.uri.toString(),
    widgets: widgets,
    callbacks: callbacks,
  );
}

bool _isRuntimeType(DartObject? value, String name) {
  final type = value?.type;
  if (type is! InterfaceType) return false;
  final element = type.element;
  return element.name == name &&
      element.library.uri.toString().startsWith(_runtimeLibrary);
}

String? _typeName(DartObject object) {
  final type = object.type;
  return type is InterfaceType ? type.element.name : null;
}

class _WidgetReader {
  final String className;
  final DartObject annotation;

  late final String name;
  late final Map<String, FieldIR> _fieldsByStorageKey;

  /// Index substituted for `#` while reading inside an `NWRepeat`, or
  /// [_template] while reading an `NWList` item that keeps its `#`.
  int? _repeatIndex;
  static const _template = -1;
  final List<String> _path = [];

  _WidgetReader(this.className, this.annotation);

  WidgetIR read() {
    name = _resolveName();
    final fields = [for (final f in _list(annotation, 'fields')) _readField(f)];
    _fieldsByStorageKey = {
      for (final f in fields)
        for (final k in f.storageKeys) k: f,
    };
    _checkUniqueKeys(fields);
    final options = [
      for (final (i, o) in _list(annotation, 'options').indexed)
        _inPath('options[$i]', () => _readOption(o)),
    ];
    for (final o in options) {
      if (_fieldsByStorageKey.containsKey(o.key)) {
        _fail('Option `${o.key}` has the same key as a field.');
      }
      // Options read like string fields in templates and conditions.
      _fieldsByStorageKey[o.key] = FieldIR(
        key: o.key,
        type: FieldType.string,
        initial: o.initial,
      );
    }
    final refreshObject = annotation.getField('refresh');
    final refresh = refreshObject == null || refreshObject.isNull
        ? null
        : _inPath(
            'refresh',
            () => _readRefresh(refreshObject, fields, options),
          );

    final sizes = [for (final s in _list(annotation, 'sizes')) _enumName(s)];
    if (sizes.isEmpty) _fail('`sizes` must not be empty.');

    final sizeLayouts = <String, NodeIR>{};
    for (final size in [...homeScreenSizes, ...lockScreenSizes]) {
      final layout = annotation.getField('${size}Layout');
      if (layout == null || layout.isNull) continue;
      if (!sizes.contains(size)) {
        _fail('`${size}Layout` is set but `sizes` does not include $size.');
      }
      sizeLayouts[size] = _inPath('${size}Layout', () => _readNode(layout));
    }

    return WidgetIR(
      name: name,
      displayName: _string(annotation, 'displayName') ?? name,
      description: _string(annotation, 'description') ?? '',
      sizes: sizes,
      fields: fields,
      options: options,
      refresh: refresh,
      layout: _inPath('layout', () => _readNode(_field(annotation, 'layout'))),
      sizeLayouts: sizeLayouts,
      background: _readColor(_field(annotation, 'background')),
      padding: _readInsets(_field(annotation, 'padding')),
      onTap: _inPath('onTap', () => _readAction(_field(annotation, 'onTap'))),
    );
  }

  String _resolveName() {
    var resolved = _string(annotation, 'name') ?? className;
    if (_string(annotation, 'name') == null &&
        resolved.endsWith('Widget') &&
        resolved.length > 'Widget'.length) {
      resolved = resolved.substring(0, resolved.length - 'Widget'.length);
    }
    if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(resolved)) {
      throw FnwException(
        'Widget name `$resolved` (class `$className`) must be PascalCase '
        'letters and digits, e.g. `Counter`.',
      );
    }
    return resolved;
  }

  FieldIR _readField(DartObject object) {
    final key = _string(object, 'key')!;
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      _fail('Field key `$key` must be letters, digits and `_`.');
    }
    if (_reservedFieldKeys.contains(key)) {
      _fail(
        'Field key `$key` is reserved (it would clash with the generated '
        'API or a Dart keyword). Pick another name.',
      );
    }
    final repeat = _int(object, 'repeat');
    if (repeat != null && repeat < 1) {
      _fail('Field `$key`: `repeat` must be at least 1.');
    }
    return FieldIR(
      key: key,
      type: FieldType.values[_enumIndex(_field(object, 'type'))],
      initial: _string(object, 'initial') ?? '',
      repeat: repeat,
    );
  }

  OptionIR _readOption(DartObject object) {
    final key = _string(object, 'key')!;
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      _fail('Option key `$key` must be letters, digits and `_`.');
    }
    if (_reservedFieldKeys.contains(key)) {
      _fail('Option key `$key` is reserved. Pick another name.');
    }
    final choices = [
      for (final c in _list(object, 'choices')) c.toStringValue()!,
    ];
    if (choices.isEmpty) _fail('Option `$key` needs at least one choice.');
    if (choices.toSet().length != choices.length) {
      _fail('Option `$key` lists a choice twice.');
    }
    final initial = _string(object, 'initial') ?? choices.first;
    if (!choices.contains(initial)) {
      _fail('Option `$key`: initial `$initial` is not one of its choices.');
    }
    return OptionIR(
      key: key,
      label: _string(object, 'label')!,
      choices: choices,
      initial: initial,
    );
  }

  RefreshIR _readRefresh(
    DartObject object,
    List<FieldIR> fields,
    List<OptionIR> options,
  ) {
    final url = _string(object, 'url')!;
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      _fail('NWRefresh `url` must start with https:// (iOS needs https).');
    }
    final usedOptions = <String>[];
    for (final key in templateKeys(url)) {
      _requireField(key, 'NWRefresh url');
      if (options.any((o) => o.key == key)) usedOptions.add(key);
    }
    if (usedOptions.length > 1) {
      _fail(
        'NWRefresh `url` can use at most one option, not ${usedOptions.join(', ')}.',
      );
    }
    final every = object.getField('every');
    // `inMicroseconds` in current SDKs, `_duration` in older ones.
    final micros =
        every?.getField('inMicroseconds')?.toIntValue() ??
        every?.getField('_duration')?.toIntValue() ??
        0;
    final seconds = micros ~/ 1000000;
    if (seconds < 15 * 60) {
      _fail('NWRefresh `every` must be at least 15 minutes.');
    }
    final values = <String, String>{};
    final raw = object.getField('values')?.toMapValue() ?? const {};
    for (final MapEntry(:key, :value) in raw.entries) {
      final field = key!.toStringValue()!;
      final path = value!.toStringValue()!;
      if (field.contains('#')) {
        final base = field.replaceAll('#', '');
        final repeat = fields.where((f) => f.key == base).firstOrNull?.repeat;
        if (repeat == null) {
          _fail(
            'NWRefresh `$field`: `#` needs a field declared with `repeat:`.',
          );
        }
        for (var i = 0; i < repeat; i++) {
          values['$base$i'] = path.replaceAll('#', '$i');
        }
      } else {
        _requireField(field, 'NWRefresh values');
        if (options.any((o) => o.key == field)) {
          _fail('NWRefresh cannot write the option `$field`.');
        }
        values[field] = path;
      }
    }
    if (values.isEmpty) _fail('NWRefresh `values` is empty.');
    return RefreshIR(
      url: url,
      every: seconds,
      values: values,
      headers: {
        for (final MapEntry(:key, :value)
            in (object.getField('headers')?.toMapValue() ?? const {}).entries)
          key!.toStringValue()!: value!.toStringValue()!,
      },
      option: usedOptions.firstOrNull,
    );
  }

  void _checkUniqueKeys(List<FieldIR> fields) {
    final seen = <String>{};
    for (final f in fields) {
      for (final k in f.storageKeys) {
        if (!seen.add(k)) _fail('Field key `$k` is declared twice.');
      }
    }
  }

  NodeIR _readNode(DartObject object) {
    final type = _typeName(object);
    return _inPath(type ?? '?', () {
      switch (type) {
        case 'NWColumn':
        case 'NWRow':
          return NodeIR(type == 'NWColumn' ? 'column' : 'row', {
            'main': _enumName(_field(object, 'mainAxisAlignment')),
            'cross': _enumName(_field(object, 'crossAxisAlignment')),
            'spacing': _double(object, 'spacing'),
          }, _readChildren(object));
        case 'NWStack':
          return NodeIR('stack', {
            'alignment': _enumName(_field(object, 'alignment')),
          }, _readChildren(object));
        case 'NWBox':
          final child = object.getField('child');
          return NodeIR(
            'box',
            {
              'width': _double(object, 'width'),
              'height': _double(object, 'height'),
              'padding': _readInsets(_field(object, 'padding')).toJson(),
              'color': _optionalColor(object, 'color')?.toJson(),
              'gradient': _readGradient(object.getField('gradient')),
              'borderColor': _optionalColor(object, 'borderColor')?.toJson(),
              'borderWidth': _double(object, 'borderWidth'),
              'radius': _double(object, 'radius'),
              'alignment': _enumName(_field(object, 'alignment')),
              'expand': _bool(object, 'expand'),
            },
            [if (child != null && !child.isNull) _readNode(child)],
          );
        case 'NWAnalogClock':
          return NodeIR('analog', {
            'size': _double(object, 'size'),
            'face': _readColor(_field(object, 'face')).toJson(),
            'border': _optionalColor(object, 'border')?.toJson(),
            'ticks': _readColor(_field(object, 'ticks')).toJson(),
            'hands': _readColor(_field(object, 'hands')).toJson(),
            'second': _optionalColor(object, 'secondHand')?.toJson(),
            'allTicks': _bool(object, 'allTicks'),
          });
        case 'NWSpacer':
          return NodeIR('spacer', {'flex': _int(object, 'flex')});
        case 'NWText':
          final text = _sub(_string(object, 'text')!);
          for (final key in templateKeys(text)) {
            _requireField(key, 'text `$text`');
          }
          return NodeIR('text', {
            'text': text,
            'style': _readTextStyle(_field(object, 'style')).toJson(),
            'maxLines': _int(object, 'maxLines'),
            'align': _enumName(_field(object, 'align')),
          });
        case 'NWRichText':
          final spans = [
            for (final (i, span) in _list(object, 'spans').indexed)
              _inPath('spans[$i]', () {
                final text = _sub(_string(span, 'text')!);
                for (final key in templateKeys(text)) {
                  _requireField(key, 'text `$text`');
                }
                final weight = span.getField('weight');
                return {
                  'text': text,
                  'size': _double(span, 'size'),
                  'weight': weight == null || weight.isNull
                      ? null
                      : _enumName(weight),
                  'color': _optionalColor(span, 'color')?.toJson(),
                  'italic': span.getField('italic')?.toBoolValue(),
                };
              }),
          ];
          if (spans.isEmpty) _fail('NWRichText needs at least one span.');
          return NodeIR('rich', {
            'spans': spans,
            'style': _readTextStyle(_field(object, 'style')).toJson(),
            'maxLines': _int(object, 'maxLines'),
            'align': _enumName(_field(object, 'align')),
          });
        case 'NWImage':
          final field = _sub(_string(object, 'field')!);
          _requireField(field, 'NWImage', types: {FieldType.image});
          return NodeIR('image', {
            'field': field,
            'width': _double(object, 'width'),
            'height': _double(object, 'height'),
            'fit': _enumName(_field(object, 'fit')),
          });
        case 'NWIcon':
          return _readIcon(object);
        case 'NWProgress':
          final field = _sub(_string(object, 'field')!);
          _requireField(
            field,
            'NWProgress',
            types: {FieldType.integer, FieldType.decimal},
          );
          final circular = _bool(object, 'circular');
          if (circular &&
              (_double(object, 'thickness')! <= 0 ||
                  _double(object, 'thickness')! * 2 >=
                      _double(object, 'size')!)) {
            _fail(
              'NWProgress.circular `thickness` must be between 0 and size / 2.',
            );
          }
          return NodeIR('progress', {
            'field': field,
            'max': _double(object, 'max'),
            'color': _optionalColor(object, 'color')?.toJson(),
            'track': _optionalColor(object, 'trackColor')?.toJson(),
            if (circular) 'size': _double(object, 'size'),
            if (circular) 'width': _double(object, 'size'),
            if (circular) 'height': _double(object, 'size'),
            if (circular) 'thickness': _double(object, 'thickness'),
          });
        case 'NWClock':
          return NodeIR('clock', {
            'seconds': _bool(object, 'showSeconds'),
            'use24Hour': object.getField('use24Hour')?.toBoolValue(),
            'style': _readTextStyle(_field(object, 'style')).toJson(),
            'align': _enumName(_field(object, 'align')),
          });
        case 'NWDateText':
          final rawField = _string(object, 'field');
          final field = rawField == null ? null : _sub(rawField);
          if (field != null) {
            _requireField(field, 'NWDateText', types: {FieldType.dateTime});
          }
          return NodeIR('date', {
            'pattern': _string(object, 'pattern'),
            'field': field,
            'style': _readTextStyle(_field(object, 'style')).toJson(),
            'align': _enumName(_field(object, 'align')),
          });
        case 'NWTimer':
          final field = _sub(_string(object, 'field')!);
          _requireField(field, 'NWTimer', types: {FieldType.dateTime});
          return NodeIR('timer', {
            'field': field,
            'style': _readTextStyle(_field(object, 'style')).toJson(),
            'align': _enumName(_field(object, 'align')),
          });
        case 'NWButton':
          return NodeIR(
            'button',
            {'action': _readAction(_field(object, 'action')).toJson()},
            [_readNode(_field(object, 'child'))],
          );
        case 'NWIf':
          final orElse = object.getField('orElse');
          return NodeIR(
            'if',
            {'condition': _readCondition(_field(object, 'condition')).toJson()},
            [
              _readNode(_field(object, 'child')),
              if (orElse != null && !orElse.isNull) _readNode(orElse),
            ],
          );
        case 'NWList':
          if (_repeatIndex != null) {
            _fail('NWList cannot be inside NWRepeat or another NWList.');
          }
          final count = _int(object, 'count')!;
          if (count < 1) _fail('NWList `count` must be at least 1.');
          final child = _field(object, 'child');
          _repeatIndex = _template;
          final template = _inPath('child', () => _readNode(child));
          final items = <NodeIR>[];
          for (var i = 0; i < count; i++) {
            _repeatIndex = i;
            items.add(_inPath('[$i]', () => _readNode(child)));
          }
          _repeatIndex = null;
          return NodeIR('list', {
            'count': count,
            'spacing': _double(object, 'spacing'),
            'template': template.toJson(),
          }, items);
        case 'NWRepeat':
          if (_repeatIndex != null) _fail('NWRepeat cannot be nested.');
          final count = _int(object, 'count')!;
          if (count < 1) _fail('NWRepeat `count` must be at least 1.');
          final child = _field(object, 'child');
          final items = <NodeIR>[];
          for (var i = 0; i < count; i++) {
            _repeatIndex = i;
            items.add(_inPath('[$i]', () => _readNode(child)));
          }
          _repeatIndex = null;
          return NodeIR(_bool(object, 'horizontal') ? 'row' : 'column', {
            'main': 'start',
            'cross': 'stretch',
            'spacing': _double(object, 'spacing'),
          }, items);
        default:
          _fail(
            'Unsupported layout element `$type`. Use the NW* elements from '
            'package:flutter_native_widget (NWColumn, NWText, ...).',
          );
      }
    });
  }

  NodeIR _readIcon(DartObject object) {
    final icon = _field(object, 'icon');
    final codePoint = icon.getField('codePoint')?.toIntValue();
    if (codePoint == null) {
      _fail(
        'NWIcon needs an IconData from `Icons`, e.g. `NWIcon(Icons.favorite)`.',
      );
    }
    final family = icon.getField('fontFamily')?.toStringValue();
    if (family != 'MaterialIcons') {
      _fail('NWIcon supports Material icons (`Icons.*`) only, not `$family`.');
    }
    final name = icon.variable?.name ?? 'u${codePoint.toRadixString(16)}';
    final base = name.replaceFirst(
      RegExp(r'_(outlined|outline|rounded|sharp)$'),
      '',
    );
    final sf =
        _string(object, 'sfSymbol') ?? sfSymbolFor[name] ?? sfSymbolFor[base];
    if (sf == null) {
      _fail(
        'No SF Symbol is known for `Icons.$name`. Pass the iOS one with '
        '`sfSymbol:`, e.g. `NWIcon(Icons.$name, sfSymbol: \'star.fill\')`.',
      );
    }
    final outline = IconFont.material().outline(codePoint);
    if (outline == null) {
      _fail(
        '`Icons.$name` is not in the Material Icons font of this Flutter SDK.',
      );
    }
    final size = _double(object, 'size')!;
    return NodeIR('icon', {
      'name': name,
      'path': outline.pathData,
      'viewportWidth': outline.width,
      'viewportHeight': outline.height,
      'sf': sf,
      'width': size,
      'height': size,
      'color': _optionalColor(object, 'color')?.toJson(),
    });
  }

  List<NodeIR> _readChildren(DartObject object) => [
    for (final (i, child) in _list(object, 'children').indexed)
      _inPath('children[$i]', () => _readNode(child)),
  ];

  ActionIR _readAction(DartObject object) {
    final kind = ActionKind.values[_enumIndex(_field(object, 'kind'))];
    final key = _sub(_string(object, 'key') ?? '');
    final value = _string(object, 'value');
    switch (kind) {
      case ActionKind.increment:
      case ActionKind.decrement:
        _requireField(key, 'NWAction.${kind.name}', types: {FieldType.integer});
      case ActionKind.toggle:
        _requireField(key, 'NWAction.toggle', types: {FieldType.boolean});
      case ActionKind.set:
      case ActionKind.cycle:
        _requireField(key, 'NWAction.${kind.name}');
      case ActionKind.callback:
        if (key.isEmpty) _fail('NWAction.callback needs a name.');
      case ActionKind.openApp:
        if (_repeatIndex == _template) {
          _fail(
            'Items of an NWList cannot open the app. Use the widget\'s '
            '`onTap`, or a native action or callback.',
          );
        }
    }
    final values = object
        .getField('values')
        ?.toListValue()
        ?.map((v) => v.toStringValue()!)
        .toList();
    if (kind == ActionKind.cycle && (values == null || values.isEmpty)) {
      _fail('NWAction.cycle needs at least one value.');
    }
    return ActionIR(
      kind: kind,
      key: key,
      value: value == null ? null : _sub(value),
      values: values,
      by: _int(object, 'by') ?? 1,
      min: _int(object, 'min'),
      max: _int(object, 'max'),
    );
  }

  ConditionIR _readCondition(DartObject object) {
    final kind = ConditionKind.values[_enumIndex(_field(object, 'kind'))];
    final key = _sub(_string(object, 'key')!);
    _requireField(
      key,
      'NWCondition.${kind.name}',
      types: kind == ConditionKind.isTrue || kind == ConditionKind.isFalse
          ? {FieldType.boolean}
          : kind == ConditionKind.greaterThan
          ? {FieldType.integer, FieldType.decimal}
          : null,
    );
    return ConditionIR(kind, key, _string(object, 'value'));
  }

  TextStyleIR _readTextStyle(DartObject object) {
    final font = _string(object, 'font');
    if (font != null &&
        !RegExp(r'\.(ttf|otf)$', caseSensitive: false).hasMatch(font)) {
      _fail('Font `$font` must be a .ttf or .otf file.');
    }
    return TextStyleIR(
      size: _double(object, 'size') ?? 14,
      weight: _enumName(_field(object, 'weight')),
      color: _optionalColor(object, 'color'),
      italic: _bool(object, 'italic'),
      monospacedDigits: _bool(object, 'monospacedDigits'),
      font: font,
    );
  }

  Map<String, Object?>? _readGradient(DartObject? object) {
    if (object == null || object.isNull) return null;
    final colors = [
      for (final c in _list(object, 'colors')) _readColor(c).toJson(),
    ];
    if (colors.length < 2 || colors.length > 3) {
      _fail('NWGradient needs two or three colors.');
    }
    return {
      'colors': colors,
      'begin': _enumName(_field(object, 'begin')),
      'end': _enumName(_field(object, 'end')),
    };
  }

  ColorIR? _optionalColor(DartObject object, String field) {
    final value = object.getField(field);
    return value == null || value.isNull ? null : _readColor(value);
  }

  ColorIR _readColor(DartObject object) {
    final light = _normalizeColor(_string(object, 'light')!);
    final darkRaw = _string(object, 'dark');
    return ColorIR(light, darkRaw == null ? light : _normalizeColor(darkRaw));
  }

  String _normalizeColor(String value) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(hex)) {
      _fail('Color `$value` must be `#RRGGBB` or `#AARRGGBB`.');
    }
    return '#${hex.length == 6 ? 'FF$hex' : hex}'.toUpperCase();
  }

  InsetsIR _readInsets(DartObject object) => InsetsIR(
    _double(object, 'start') ?? 0,
    _double(object, 'top') ?? 0,
    _double(object, 'end') ?? 0,
    _double(object, 'bottom') ?? 0,
  );

  void _requireField(String key, String usage, {Set<FieldType>? types}) {
    // An NWList item template checks against its first item.
    final field =
        _fieldsByStorageKey[_repeatIndex == _template
            ? key.replaceAll('#', '0')
            : key];
    if (field == null) {
      final hint = key.contains('#')
          ? ' `#` is only replaced inside NWRepeat.'
          : _repeatIndex == null &&
                _fieldsByStorageKey.values.any(
                  (f) => f.key == key && f.repeat != null,
                )
          ? ' `$key` repeats; use `$key#` inside NWRepeat or `${key}0`.'
          : '';
      _fail(
        '$usage uses `$key`, which is not a declared field. Add it to '
        '`fields:`, e.g. `NWField.string(\'$key\')`.$hint',
      );
    }
    if (types != null && !types.contains(field.type)) {
      _fail(
        '$usage needs a field of type ${types.map((t) => t.name).join(' or ')}, but '
        '`$key` is ${field.type.name}.',
      );
    }
  }

  String _sub(String value) => _repeatIndex == null || _repeatIndex == _template
      ? value
      : value.replaceAll('#', '$_repeatIndex');

  T _inPath<T>(String segment, T Function() body) {
    _path.add(segment);
    try {
      return body();
    } finally {
      _path.removeLast();
    }
  }

  Never _fail(String message) {
    final where = _path.isEmpty ? '' : ' (at ${_path.join(' > ')})';
    throw FnwException('Widget `$className`$where: $message');
  }

  DartObject _field(DartObject object, String name) {
    final value = object.getField(name);
    if (value == null) _fail('Missing `$name`.');
    return value;
  }

  String? _string(DartObject object, String name) =>
      object.getField(name)?.toStringValue();

  int? _int(DartObject object, String name) =>
      object.getField(name)?.toIntValue();

  double? _double(DartObject object, String name) {
    final value = object.getField(name);
    return value?.toDoubleValue() ?? value?.toIntValue()?.toDouble();
  }

  bool _bool(DartObject object, String name) =>
      object.getField(name)?.toBoolValue() ?? false;

  List<DartObject> _list(DartObject object, String name) =>
      object.getField(name)?.toListValue() ?? const [];

  int _enumIndex(DartObject object) => object.getField('index')!.toIntValue()!;

  String _enumName(DartObject object) {
    final variableName = object.variable?.name;
    if (variableName != null) return variableName;
    final type = object.type;
    if (type is InterfaceType && type.element is EnumElement) {
      final constants = (type.element as EnumElement).constants;
      return constants[_enumIndex(object)].name ?? '';
    }
    _fail('Expected an enum value.');
  }
}
