import 'dart:io';

import 'package:flutter_native_widget_gen/src/config.dart';
import 'package:flutter_native_widget_gen/src/emit/android_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/dart_emitter.dart';
import 'package:flutter_native_widget_gen/src/emit/ios_emitter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Everything the generator writes for `fixtures/showcase.dart.txt` must
/// match `goldens/showcase/`. After an intended change, refresh with:
///
///     UPDATE_GOLDENS=1 dart test test/golden_test.dart
void main() {
  const config = ProjectConfig(
    root: '/tmp/app',
    iosAppGroup: 'group.com.example.app',
    iosDeploymentTarget: '16.0',
    androidNamespace: 'com.example.app',
    androidMainActivity: 'com.example.app.MainActivity',
  );
  final goldens = Directory(p.join('test', 'goldens', 'showcase'));
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';

  late Map<String, String> outputs;

  setUpAll(() async {
    final source = File(
      p.join('test', 'fixtures', 'showcase.dart.txt'),
    ).readAsStringSync();
    final library = await readSource(source);
    final android = emitAndroid(library.widgets, config);
    outputs = {
      for (final MapEntry(:key, :value) in android.files.entries)
        'android/$key': value,
      'android/manifest_application.xml': android.applicationEntries,
      'android/manifest.xml': android.manifestEntries,
      for (final MapEntry(:key, :value) in emitIos(
        library.widgets,
        config,
      ).entries)
        'ios/$key': value,
      'dart/widgets.fnw.dart.txt': emitDartPart(library, 'widgets.dart'),
      'dart/home_widgets.g.dart.txt': emitRegistry([library], config),
    };
    if (update) {
      if (goldens.existsSync()) goldens.deleteSync(recursive: true);
      for (final MapEntry(:key, :value) in outputs.entries) {
        File(p.join(goldens.path, key))
          ..createSync(recursive: true)
          ..writeAsStringSync(value);
      }
    }
  });

  test('output matches the goldens', () {
    final stored = {
      for (final file in goldens.listSync(recursive: true).whereType<File>())
        p.posix.joinAll(p.split(p.relative(file.path, from: goldens.path))):
            file.readAsStringSync(),
    };
    expect(
      outputs.keys.toSet(),
      stored.keys.toSet(),
      reason: 'files added or removed; run with UPDATE_GOLDENS=1',
    );
    for (final MapEntry(:key, :value) in outputs.entries) {
      expect(value, stored[key], reason: '$key changed');
    }
  });

  test('output is the same on every run', () async {
    final source = File(
      p.join('test', 'fixtures', 'showcase.dart.txt'),
    ).readAsStringSync();
    final again = await readSource(source);
    expect(
      emitIos(again.widgets, config)['FNWWidgets/FNWWidgets.swift'],
      outputs['ios/FNWWidgets/FNWWidgets.swift'],
    );
    expect(emitAndroid(again.widgets, config).files, {
      for (final MapEntry(:key, :value) in outputs.entries)
        if (key.startsWith('android/res/') || key.startsWith('android/kotlin/'))
          key.substring('android/'.length): value,
    });
  });
}
