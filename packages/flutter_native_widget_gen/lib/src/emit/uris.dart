import 'dart:convert';

import '../ir.dart';

/// URI a tap on [action] in [widget] sends. The same string is used by the
/// Android PendingIntents, the iOS fallback links and the Dart runtime.
String actionUri(String widget, ActionIR action) {
  switch (action.kind) {
    case ActionKind.openApp:
      final value = action.value;
      if (value == null || value.startsWith('/')) {
        return _build('open', {'w': widget, 'route': ?value});
      }
      // A full URL from the developer: keep it, add the markers home_widget
      // needs to report it as a widget launch.
      final uri = Uri.parse(value);
      return uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'homeWidget': '',
              'w': widget,
            },
          )
          .toString()
          .replaceFirst('homeWidget=&', 'homeWidget&');
    case ActionKind.callback:
      return _build('callback', {
        'w': widget,
        'n': action.key,
        if (action.value != null) 'p': action.value!,
      });
    case ActionKind.increment:
    case ActionKind.decrement:
    case ActionKind.toggle:
    case ActionKind.set:
    case ActionKind.cycle:
      return _build('action', {
        'w': widget,
        'op': action.op,
        'k': action.key,
        if (action.kind == ActionKind.increment ||
            action.kind == ActionKind.decrement)
          'by': '${action.by}',
        if (action.min != null) 'min': '${action.min}',
        if (action.max != null) 'max': '${action.max}',
        if (action.kind == ActionKind.set) 'v': action.value ?? '',
        if (action.kind == ActionKind.cycle) 'vs': jsonEncode(action.values),
      });
  }
}

String _build(String host, Map<String, String> query) {
  // %20 rather than `+` for spaces: Swift's URLComponents does not decode `+`.
  final encoded = query.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
  return 'fnw://$host?homeWidget&$encoded';
}
