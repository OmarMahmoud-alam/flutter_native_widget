import 'dart:convert';

String upperFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// `CounterClock` → `counter_clock`.
String snakeCase(String s) => s
    .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
    .toLowerCase();

/// A single-quoted Dart string literal.
String dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// A double-quoted Kotlin string literal.
String kotlinString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return '"$escaped"';
}

/// A double-quoted Swift string literal.
String swiftString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return '"$escaped"';
}

/// Escapes text for an XML attribute value.
String xmlAttr(String value) => const HtmlEscape(
  HtmlEscapeMode.attribute,
).convert(value).replaceAll("'", '&apos;');

/// Escapes text for an Android string resource (also used in attributes,
/// where `@` and `?` at the start would be read as references).
String androidText(String value) {
  var escaped = xmlAttr(value)
      .replaceAll(r'\', r'\\')
      .replaceAll('&apos;', r"\'")
      // Stays XML-escaped (we are inside a "..." attribute); the backslash
      // keeps Android from treating it as a quoting character.
      .replaceAll('&quot;', r'\&quot;')
      .replaceAll('\n', r'\n');
  if (escaped.startsWith('@') || escaped.startsWith('?')) {
    escaped = '\\$escaped';
  }
  return escaped;
}

/// Formats a number for XML/Swift: `12` instead of `12.0`.
String num2(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// Android font resource of a font file: `assets/Cairo-Bold.ttf` →
/// `fnw_font_cairo_bold`.
String androidFontName(String path) {
  final base = path.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return 'fnw_font_${base.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_')}';
}

/// File name of a font inside the iOS extension's `Fonts` folder.
String iosFontFile(String path) => path.split('/').last;
