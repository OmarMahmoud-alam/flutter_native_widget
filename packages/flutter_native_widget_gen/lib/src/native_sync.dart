import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';
import 'emit/android_emitter.dart';
import 'emit/ios_emitter.dart';
import 'emit/strings.dart';
import 'ir.dart';
import 'project/ios_project.dart';
import 'reader.dart' show FnwException;

/// Where the builder caches the IR of every widget for the CLI.
String irCachePath(String root) =>
    p.join(root, '.dart_tool', 'flutter_native_widget', 'ir.json');

class SyncReport {
  final written = <String>[];
  final deleted = <String>[];
  final warnings = <String>[];

  bool get changed => written.isNotEmpty || deleted.isNotEmpty;

  @override
  String toString() => [
    for (final w in written) '  wrote   $w',
    for (final d in deleted) '  removed $d',
    for (final w in warnings) '  warning $w',
  ].join('\n');
}

void saveIrCache(String root, List<LibraryIR> libraries) {
  final file = File(irCachePath(root));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert([for (final l in libraries) l.toJson()]),
  );
}

List<LibraryIR>? loadIrCache(String root) {
  final file = File(irCachePath(root));
  if (!file.existsSync()) return null;
  return [
    for (final l in jsonDecode(file.readAsStringSync()) as List)
      LibraryIR.fromJson((l as Map).cast()),
  ];
}

/// Writes the generated Android and iOS code into the Flutter project.
SyncReport syncNative(List<LibraryIR> libraries, ProjectConfig config) {
  final report = SyncReport();
  final widgets = [for (final l in libraries) ...l.widgets];
  if (config.hasAndroid) _syncAndroid(widgets, config, report);
  if (config.hasIos) _syncIos(widgets, config, report);
  return report;
}

void _syncAndroid(
  List<WidgetIR> widgets,
  ProjectConfig config,
  SyncReport report,
) {
  final root = config.root;
  final main = p.join(root, 'android', 'app', 'src', 'main');
  final output = emitAndroid(widgets, config);

  for (final MapEntry(key: path, value: content) in output.files.entries) {
    _write(p.join(main, path), content, root, report);
  }
  final fonts = {
    for (final font in {for (final w in widgets) ...w.fonts})
      'res/font/${androidFontName(font)}${p.extension(font).toLowerCase()}':
          font,
  };
  for (final MapEntry(key: path, value: font) in fonts.entries) {
    _copy(p.join(root, font), p.join(main, path), root, report);
  }

  // Remove generated resources of widgets that no longer exist.
  for (final dir in [
    'font',
    'layout',
    'xml',
    'drawable',
    'drawable-v31',
    'values',
    'values-night',
  ]) {
    final directory = Directory(p.join(main, 'res', dir));
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync().whereType<File>()) {
      final name = p.basename(file.path);
      final relative = 'res/$dir/$name';
      if (name.startsWith('fnw_') &&
          !output.files.containsKey(relative) &&
          !fonts.containsKey(relative)) {
        file.deleteSync();
        report.deleted.add(p.relative(file.path, from: root));
      }
    }
  }
  // Generated Kotlin left behind in another package (namespace changed).
  final kotlinPath = output.files.keys.firstWhere((k) => k.endsWith('.kt'));
  final kotlinRoot = Directory(p.join(main, 'kotlin'));
  if (kotlinRoot.existsSync()) {
    for (final file in kotlinRoot.listSync(recursive: true).whereType<File>()) {
      if (p.basename(file.path) == 'FnwWidgets.kt' &&
          p.normalize(file.path) != p.normalize(p.join(main, kotlinPath))) {
        file.deleteSync();
        report.deleted.add(p.relative(file.path, from: root));
      }
    }
  }

  final manifest = File(p.join(main, 'AndroidManifest.xml'));
  if (!manifest.existsSync()) {
    report.warnings.add('android/app/src/main/AndroidManifest.xml not found.');
    return;
  }
  final source = manifest.readAsStringSync();
  final updated = updateManifest(
    source,
    output.applicationEntries,
    output.manifestEntries,
  );
  if (updated == null) {
    report.warnings.add('Could not find <application> in AndroidManifest.xml.');
  } else if (updated != source) {
    manifest.writeAsStringSync(updated);
    report.written.add(p.relative(manifest.path, from: root));
  }
}

const _begin = '<!-- flutter_native_widget:begin (generated, do not edit) -->';
const _end = '<!-- flutter_native_widget:end -->';
const _permissionsBegin =
    '<!-- flutter_native_widget:permissions:begin (generated, do not edit) -->';
const _permissionsEnd = '<!-- flutter_native_widget:permissions:end -->';

/// Replaces (or adds) the generated blocks in an `AndroidManifest.xml`.
/// Nothing outside the markers is touched. Returns null when the manifest
/// has no `<application>` element.
String? updateManifest(String source, String application, String manifest) {
  String replaceBlock(
    String text,
    String begin,
    String end,
    String body,
    String indent, {
    required String Function(String) insert,
  }) {
    final block = '$indent$begin\n$body$indent$end\n';
    final start = text.indexOf(begin);
    if (start >= 0) {
      final lineStart = text.lastIndexOf('\n', start) + 1;
      final stop = text.indexOf(end, start);
      final lineEnd = text.indexOf('\n', stop);
      return text.replaceRange(
        lineStart,
        lineEnd < 0 ? text.length : lineEnd + 1,
        block,
      );
    }
    return insert(block);
  }

  if (!source.contains('<application')) return null;
  var text = replaceBlock(
    source,
    _permissionsBegin,
    _permissionsEnd,
    manifest,
    '    ',
    insert: (block) {
      final index = source.indexOf('<application');
      final lineStart = source.lastIndexOf('\n', index) + 1;
      return source.replaceRange(lineStart, lineStart, block);
    },
  );
  text = replaceBlock(
    text,
    _begin,
    _end,
    application,
    '        ',
    insert: (block) {
      final index = text.lastIndexOf('</application>');
      final lineStart = text.lastIndexOf('\n', index) + 1;
      return text.replaceRange(lineStart, lineStart, block);
    },
  );
  return text;
}

/// Removes the generated blocks from an `AndroidManifest.xml`.
String removeManifestBlocks(String source) {
  var text = source;
  for (final (begin, end) in [
    (_begin, _end),
    (_permissionsBegin, _permissionsEnd),
  ]) {
    final start = text.indexOf(begin);
    if (start < 0) continue;
    final lineStart = text.lastIndexOf('\n', start) + 1;
    final stop = text.indexOf(end, start);
    final lineEnd = text.indexOf('\n', stop);
    text = text.replaceRange(
      lineStart,
      lineEnd < 0 ? text.length : lineEnd + 1,
      '',
    );
  }
  return text;
}

void _syncIos(List<WidgetIR> widgets, ProjectConfig config, SyncReport report) {
  final root = config.root;
  if (config.iosAppGroup == null) {
    report.warnings.add(
      'iOS skipped: set ios.app_group in $configFileName '
      '(or run `dart run flutter_native_widget_gen init`).',
    );
    return;
  }
  if (!iosExtensionExists(root)) {
    final setup = ensureIosSetup(config);
    report.written.addAll(setup.changed.map((c) => p.relative(c, from: root)));
    report.warnings.addAll(setup.warnings);
  }
  for (final MapEntry(key: path, value: content) in emitIos(
    widgets,
    config,
  ).entries) {
    _write(p.join(root, 'ios', path), content, root, report);
  }

  // Fonts go to a folder the extension bundles as a whole.
  final fontsDir = Directory(p.join(root, 'ios', iosExtensionName, 'Fonts'));
  final fonts = {
    for (final font in {for (final w in widgets) ...w.fonts})
      iosFontFile(font): font,
  };
  for (final MapEntry(key: name, value: font) in fonts.entries) {
    _copy(p.join(root, font), p.join(fontsDir.path, name), root, report);
  }
  if (fontsDir.existsSync()) {
    for (final file in fontsDir.listSync().whereType<File>()) {
      if (!fonts.containsKey(p.basename(file.path))) {
        file.deleteSync();
        report.deleted.add(p.relative(file.path, from: root));
      }
    }
  }
  if (fonts.isNotEmpty && ensureIosFontsFolder(root)) {
    report.written.add('ios/Runner.xcodeproj/project.pbxproj (Fonts folder)');
  }
}

/// Copies a file the app owns (a font) when it is missing or changed.
void _copy(String from, String to, String root, SyncReport report) {
  final source = File(from);
  if (!source.existsSync()) {
    throw FnwException(
      'Font `${p.relative(from, from: root)}` not found. Font paths in '
      'NWTextStyle(font: ...) are relative to the project root.',
    );
  }
  final bytes = source.readAsBytesSync();
  final target = File(to);
  if (target.existsSync()) {
    final current = target.readAsBytesSync();
    if (current.length == bytes.length &&
        Iterable.generate(bytes.length).every((i) => current[i] == bytes[i])) {
      return;
    }
  }
  target.parent.createSync(recursive: true);
  target.writeAsBytesSync(bytes);
  report.written.add(p.relative(to, from: root));
}

void _write(String path, String content, String root, SyncReport report) {
  final file = File(path);
  if (file.existsSync() && file.readAsStringSync() == content) return;
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  report.written.add(p.relative(path, from: root));
}
