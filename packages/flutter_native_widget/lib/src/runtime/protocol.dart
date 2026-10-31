/// The contract between Dart and the generated native code.
///
/// Every value is stored as a string under `fnw.<Widget>.<key>` in the
/// home_widget storage (Android `SharedPreferences` "HomeWidgetPreferences",
/// iOS `UserDefaults(suiteName: appGroup)`). The generated Kotlin and Swift
/// use the same keys and the same URI format; change both sides together.
library;

import 'dart:convert';

const fnwScheme = 'fnw';

String storageKey(String widget, String key) => 'fnw.$widget.$key';

/// JSON list of `{"t": <epoch millis>, "v": {<key>: <value>}}`, sorted by t.
String timelineKey(String widget) => 'fnw.$widget.__timeline';

/// home_widget only reports a launch as coming from a widget on iOS when the
/// URL carries this query item.
const homeWidgetMarker = 'homeWidget';

enum UriKind { action, callback, open, unknown }

UriKind uriKind(Uri uri) {
  if (uri.scheme != fnwScheme) return UriKind.unknown;
  return switch (uri.host) {
    'action' => UriKind.action,
    'callback' => UriKind.callback,
    'open' => UriKind.open,
    _ => UriKind.unknown,
  };
}

/// Applies a native action URI (`fnw://action?...`) to [current] and returns
/// the new value. Mirrors `Fnw.applyAction` (Kotlin) and `FNW.apply` (Swift).
String? applyAction(Uri uri, String? current, String initial) {
  final q = uri.queryParameters;
  final value = current ?? initial;
  switch (q['op']) {
    case 'inc':
    case 'dec':
      final by = int.tryParse(q['by'] ?? '1') ?? 1;
      var n =
          (int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0) +
          (q['op'] == 'inc' ? by : -by);
      final min = int.tryParse(q['min'] ?? '');
      final max = int.tryParse(q['max'] ?? '');
      if (min != null && n < min) n = min;
      if (max != null && n > max) n = max;
      return '$n';
    case 'toggle':
      return value == 'true' ? 'false' : 'true';
    case 'set':
      return q['v'] ?? '';
    case 'cycle':
      final values = (jsonDecode(q['vs'] ?? '[]') as List).cast<String>();
      if (values.isEmpty) return value;
      final i = values.indexOf(value);
      return values[(i + 1) % values.length];
  }
  return current;
}
