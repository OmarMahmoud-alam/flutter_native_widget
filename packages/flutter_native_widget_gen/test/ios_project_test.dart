import 'dart:io';

import 'package:flutter_native_widget_gen/src/config.dart';
import 'package:flutter_native_widget_gen/src/project/ios_project.dart';
import 'package:flutter_native_widget_gen/src/project/pbxproj.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late File pbx;
  late String original;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fnw_ios_');
    pbx = File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'))
      ..createSync(recursive: true);
    original = File('test/fixtures/flutter_3_47.pbxproj').readAsStringSync();
    pbx.writeAsStringSync(original);
    File(p.join(root.path, 'ios', 'Runner', 'AppDelegate.swift'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
''');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProjectConfig config() => ProjectConfig(
    root: root.path,
    iosAppGroup: 'group.dev.test',
    iosDeploymentTarget: '16.0',
    androidNamespace: 'dev.test',
    androidMainActivity: 'dev.test.MainActivity',
  );

  test('adds an embedded widget extension target', () {
    ensureIosSetup(config());
    final project = PbxProject.parse(pbx.readAsStringSync());
    final targetId = project.targetId('FNWWidgets');
    expect(targetId, isNotNull);
    expect(
      project.object(targetId!)['productType'],
      'com.apple.product-type.app-extension',
    );

    final runner = project.object(project.targetId('Runner')!);
    final phases = (runner['buildPhases'] as List)
        .cast<String>()
        .map(project.object)
        .toList();
    final embed = phases.indexWhere(
      (ph) => ph['name'] == 'Embed Foundation Extensions',
    );
    final thin = phases.indexWhere((ph) => ph['name'] == 'Thin Binary');
    expect(embed, isNonNegative);
    expect(embed, lessThan(thin), reason: 'must run before Thin Binary');

    final configs = project.configurations(targetId);
    expect(configs.keys, containsAll(['Debug', 'Release', 'Profile']));
    final release = project.buildSettings(configs['Release']!);
    expect(release['PRODUCT_BUNDLE_IDENTIFIER'], endsWith('.FNWWidgets'));
    expect(release['IPHONEOS_DEPLOYMENT_TARGET'], '16.0');

    expect(
      File(
        p.join(root.path, 'ios', 'FNWWidgets', 'FNWWidgets.entitlements'),
      ).readAsStringSync(),
      contains('group.dev.test'),
    );
    final delegate = File(
      p.join(root.path, 'ios', 'Runner', 'AppDelegate.swift'),
    ).readAsStringSync();
    expect(
      delegate,
      contains('HomeWidgetBackgroundWorker.setPluginRegistrantCallback'),
    );
    expect(delegate, contains('import home_widget'));
  });

  test('is idempotent', () {
    ensureIosSetup(config());
    final once = pbx.readAsStringSync();
    final result = ensureIosSetup(config());
    expect(pbx.readAsStringSync(), once);
    expect(result.changed, isEmpty);
  });

  test('the written project is in Xcode format', () {
    ensureIosSetup(config());
    final written = pbx.readAsStringSync();
    expect(writePbxproj(parsePbxproj(written)), written);
  });

  test('clean removes the target and the AppDelegate block', () {
    ensureIosSetup(config());
    removeIosSetup(root.path);
    final project = PbxProject.parse(pbx.readAsStringSync());
    expect(project.targetId('FNWWidgets'), isNull);
    expect(pbx.readAsStringSync(), isNot(contains('FNWWidgets')));
    final delegate = File(
      p.join(root.path, 'ios', 'Runner', 'AppDelegate.swift'),
    ).readAsStringSync();
    expect(delegate, isNot(contains('HomeWidgetBackgroundWorker')));
    expect(delegate, isNot(contains('import home_widget')));
  });

  test('skips iOS without an App Group', () {
    final result = ensureIosSetup(
      ProjectConfig(
        root: root.path,
        iosAppGroup: null,
        iosDeploymentTarget: '16.0',
        androidNamespace: 'dev.test',
        androidMainActivity: 'dev.test.MainActivity',
      ),
    );
    expect(result.warnings.single, contains('app_group'));
    expect(pbx.readAsStringSync(), original);
  });
}
