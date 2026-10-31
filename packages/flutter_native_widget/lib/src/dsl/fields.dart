enum NWFieldType { string, integer, decimal, boolean, dateTime, image }

/// A piece of data the app writes and the widget shows.
///
/// Every field becomes a typed parameter on the generated `save` method and
/// can be referenced from text templates as `{key}`.
///
/// With [repeat] the field is expanded into `key0`, `key1`, ... and the
/// generated API takes a `List`. Inside [NWRepeat], `{key#}` refers to the
/// current item.
class NWField {
  final String key;
  final NWFieldType type;

  /// Shown until the app saves a value. Stored as text: `'0'`, `'true'`, ...
  final String initial;

  /// Expands the field into this many indexed keys.
  final int? repeat;

  const NWField.string(this.key, {this.initial = '', this.repeat})
    : type = NWFieldType.string;

  const NWField.integer(this.key, {this.initial = '0', this.repeat})
    : type = NWFieldType.integer;

  const NWField.decimal(this.key, {this.initial = '0', this.repeat})
    : type = NWFieldType.decimal;

  const NWField.boolean(this.key, {this.initial = 'false', this.repeat})
    : type = NWFieldType.boolean;

  /// A point in time. Shown with [NWDateText] or counted with [NWTimer].
  const NWField.dateTime(this.key, {this.initial = '', this.repeat})
    : type = NWFieldType.dateTime;

  /// The path of an image file in widget storage, e.g. from
  /// `FlutterNativeWidget.saveImage` or `renderFlutterWidget`.
  const NWField.image(this.key, {this.initial = '', this.repeat})
    : type = NWFieldType.image;
}

/// A choice the user makes for each copy of the widget: on Android when the
/// widget is placed (and from "Reconfigure" on Android 12+), on iOS 17+
/// from "Edit widget".
///
/// The chosen value shows in the layout as `{key}` and works in
/// [NWCondition]s. Data the app saves with the generated
/// `save<Key>For(choice, ...)` is shown only on copies with that choice:
///
/// ```dart
/// options: [NWOption('city', label: 'City', choices: ['Cairo', 'Giza'])],
/// ...
/// await WeatherWidget.saveForCity('Giza', temp: '31°');
/// ```
class NWOption {
  final String key;
  final String label;
  final List<String> choices;

  /// Used until the user picks one. Defaults to the first choice.
  final String? initial;

  const NWOption(
    this.key, {
    required this.label,
    required this.choices,
    this.initial,
  });
}

/// Downloads JSON every [every] and saves values from it into fields,
/// natively, while the app is closed.
///
/// ```dart
/// refresh: NWRefresh(
///   url: 'https://api.example.com/weather?city={city}',
///   values: {'temp': 'current.temp', 'title#': 'items.#.title'},
/// ),
/// ```
///
/// - [url] may use `{key}` of fields and options. With an option in it,
///   each choice is downloaded and saved on its own.
/// - [values] maps a field key to a path in the JSON: object keys and list
///   indexes separated by dots. For a repeated field, `#` in both is the
///   index (`'title#': 'items.#.title'`).
/// - The system decides the exact time. iOS allows about 40–70 refreshes a
///   day, so [every] is at least 15 minutes; Android also wakes it then.
///   iOS only allows `https` URLs.
class NWRefresh {
  final String url;
  final Duration every;
  final Map<String, String> values;
  final Map<String, String> headers;

  const NWRefresh({
    required this.url,
    required this.values,
    this.every = const Duration(minutes: 30),
    this.headers = const {},
  });
}
