import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';
import 'emit/ios_emitter.dart';
import 'native_sync.dart';
import 'project/ios_project.dart';
import 'project/pbxproj.dart';

const _executable = 'dart run flutter_native_widget_gen';

CommandRunner<int> buildCli() =>
    CommandRunner<int>(
        _executable,
        'Native home screen widgets from Dart, for Android and iOS.',
      )
      ..addCommand(_InitCommand())
      ..addCommand(_SyncCommand())
      ..addCommand(_DoctorCommand())
      ..addCommand(_CleanCommand());

String get _root => Directory.current.path;

void _requireFlutterProject() {
  final pubspec = File(p.join(_root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    throw UsageException('Run this in the root of a Flutter app.', '');
  }
}

class _InitCommand extends Command<int> {
  @override
  final name = 'init';

  @override
  final description =
      'Sets up the project once: config file, iOS widget extension target, '
      'App Group entitlements and Android manifest entries.';

  _InitCommand() {
    argParser.addOption(
      'app-group',
      help:
          'iOS App Group shared by the app and the widgets. '
          'Defaults to group.<bundle id>.',
    );
  }

  @override
  Future<int> run() async {
    _requireFlutterProject();
    final configFile = File(p.join(_root, configFileName));
    if (!configFile.existsSync()) {
      final appGroup =
          argResults!['app-group'] as String? ?? _defaultAppGroup(_root);
      configFile.writeAsStringSync(_configTemplate(appGroup));
      stdout.writeln('Created $configFileName (App Group: $appGroup).');
    } else if (argResults!['app-group'] != null) {
      stdout.writeln(
        '$configFileName already exists; edit ios.app_group there to change it.',
      );
    }

    final config = ProjectConfig.load(_root);
    if (config.hasIos) {
      final ios = ensureIosSetup(config);
      for (final c in ios.changed) {
        stdout.writeln('  updated ${p.relative(c, from: _root)}');
      }
      for (final w in ios.warnings) {
        stderr.writeln('  warning $w');
      }
    }
    final report = syncNative(loadIrCache(_root) ?? const [], config);
    if (report.changed || report.warnings.isNotEmpty) stdout.writeln(report);

    _checkDependencies();
    stdout.writeln('''

Done. Next:
  1. Declare a widget with @HomeScreenWidget in lib/ (see the README).
  2. dart run build_runner build
  3. Call initializeHomeWidgets() from lib/home_widgets.g.dart in main().
iOS: the widget extension signs with your app's team. On a device, make sure
the App Group "${config.iosAppGroup}" exists for your team (Xcode's automatic
signing creates it).''');
    return 0;
  }
}

class _SyncCommand extends Command<int> {
  @override
  final name = 'sync';

  @override
  final description =
      'Rewrites the native code from the last build_runner run '
      '(build_runner already does this; use it after editing the config).';

  @override
  Future<int> run() async {
    _requireFlutterProject();
    final libraries = loadIrCache(_root);
    if (libraries == null) {
      stderr.writeln(
        'No widgets found yet. Run `dart run build_runner build` first.',
      );
      return 1;
    }
    final report = syncNative(libraries, ProjectConfig.load(_root));
    stdout.writeln(
      report.changed || report.warnings.isNotEmpty
          ? report
          : 'Already up to date.',
    );
    return 0;
  }
}

class _DoctorCommand extends Command<int> {
  @override
  final name = 'doctor';

  @override
  final description = 'Checks that the project is wired up correctly.';

  @override
  Future<int> run() async {
    _requireFlutterProject();
    final config = ProjectConfig.load(_root);
    var problems = 0;
    void check(bool ok, String good, String bad) {
      stdout.writeln(ok ? '  ✓ $good' : '  ✗ $bad');
      if (!ok) problems++;
    }

    final pubspec =
        loadYaml(File(p.join(_root, 'pubspec.yaml')).readAsStringSync())
            as YamlMap;
    final deps = (pubspec['dependencies'] as YamlMap?) ?? YamlMap();
    final devDeps = (pubspec['dev_dependencies'] as YamlMap?) ?? YamlMap();
    stdout.writeln('Dart');
    check(
      deps.containsKey('flutter_native_widget'),
      'flutter_native_widget dependency',
      'add flutter_native_widget to dependencies',
    );
    check(
      devDeps.containsKey('build_runner'),
      'build_runner dev dependency',
      'add build_runner to dev_dependencies',
    );
    final libraries = loadIrCache(_root);
    final widgets = [for (final l in libraries ?? const []) ...l.widgets];
    check(
      libraries != null,
      '${widgets.length} widget(s) generated: ${widgets.map((w) => w.name).join(', ')}',
      'no generated widgets yet: run dart run build_runner build',
    );
    check(
      File(p.join(_root, 'lib', 'home_widgets.g.dart')).existsSync(),
      'lib/home_widgets.g.dart',
      'lib/home_widgets.g.dart missing: run dart run build_runner build',
    );

    if (config.hasAndroid) {
      stdout.writeln('Android');
      final manifest = File(
        p.join(_root, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      );
      final source = manifest.existsSync() ? manifest.readAsStringSync() : '';
      check(
        source.contains('flutter_native_widget:begin'),
        'manifest receivers',
        'manifest has no widget receivers: run $_executable sync',
      );
      for (final w in widgets) {
        check(
          source.contains(config.androidProviderClass(w.name)),
          '${w.name} receiver',
          '${w.name} receiver missing: run $_executable sync',
        );
      }
      check(
        File(
          p.joinAll([
            _root,
            'android',
            'app',
            'src',
            'main',
            'kotlin',
            ...config.androidPackage.split('.'),
            'FnwWidgets.kt',
          ]),
        ).existsSync(),
        'generated Kotlin in ${config.androidPackage}',
        'FnwWidgets.kt missing: run $_executable sync',
      );
    }

    if (config.hasIos) {
      stdout.writeln('iOS');
      check(
        config.iosAppGroup != null,
        'App Group ${config.iosAppGroup}',
        'set ios.app_group in $configFileName',
      );
      final pbx = File(
        p.join(_root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      final project = PbxProject.parse(pbx.readAsStringSync());
      final targetId = project.targetId(iosExtensionName);
      check(
        targetId != null,
        '$iosExtensionName extension target',
        'no widget extension target: run $_executable init',
      );
      if (targetId != null) {
        final runner = project.object(project.targetId('Runner')!);
        final embeds = (runner['buildPhases'] as List)
            .cast<String>()
            .map(project.object)
            .any((phase) => phase['name'] == 'Embed Foundation Extensions');
        check(
          embeds,
          'extension embedded in Runner',
          'extension is not embedded in Runner',
        );
      }
      for (final path in [
        'ios/Runner/Runner.entitlements',
        'ios/$iosExtensionName/$iosExtensionName.entitlements',
      ]) {
        final file = File(p.join(_root, path));
        check(
          file.existsSync() &&
              config.iosAppGroup != null &&
              file.readAsStringSync().contains(config.iosAppGroup!),
          '$path has the App Group',
          '$path lacks the App Group: run $_executable init',
        );
      }
      final delegate = File(
        p.join(_root, 'ios', 'Runner', 'AppDelegate.swift'),
      );
      check(
        delegate.existsSync() &&
            delegate.readAsStringSync().contains(
              'HomeWidgetBackgroundWorker.setPluginRegistrantCallback',
            ),
        'background callbacks registered in AppDelegate',
        'AppDelegate does not register background callbacks (only needed for @WidgetCallback)',
      );
    }

    stdout.writeln(
      problems == 0 ? '\nNo issues found.' : '\n$problems issue(s) found.',
    );
    return problems == 0 ? 0 : 1;
  }
}

class _CleanCommand extends Command<int> {
  @override
  final name = 'clean';

  @override
  final description =
      'Removes everything flutter_native_widget added to the native projects.';

  @override
  Future<int> run() async {
    _requireFlutterProject();
    final config = ProjectConfig.load(_root);
    final removed = <String>[];
    if (config.hasIos) removed.addAll(removeIosSetup(_root));
    if (config.hasAndroid) {
      final main = p.join(_root, 'android', 'app', 'src', 'main');
      final res = Directory(p.join(main, 'res'));
      if (res.existsSync()) {
        for (final file in res.listSync(recursive: true).whereType<File>()) {
          if (p.basename(file.path).startsWith('fnw_')) {
            file.deleteSync();
            removed.add(p.relative(file.path, from: _root));
          }
        }
      }
      final kotlin = Directory(p.join(main, 'kotlin'));
      if (kotlin.existsSync()) {
        for (final file in kotlin.listSync(recursive: true).whereType<File>()) {
          if (p.basename(file.path) == 'FnwWidgets.kt') {
            file.deleteSync();
            removed.add(p.relative(file.path, from: _root));
          }
        }
      }
      final manifest = File(p.join(main, 'AndroidManifest.xml'));
      if (manifest.existsSync()) {
        final source = manifest.readAsStringSync();
        final cleaned = removeManifestBlocks(source);
        if (cleaned != source) {
          manifest.writeAsStringSync(cleaned);
          removed.add('android/app/src/main/AndroidManifest.xml (receivers)');
        }
      }
    }
    stdout.writeln(
      removed.isEmpty
          ? 'Nothing to remove.'
          : removed.map((r) => '  removed $r').join('\n'),
    );
    stdout.writeln(
      'Kept $configFileName, Runner.entitlements and your @HomeScreenWidget code.',
    );
    return 0;
  }
}

String _defaultAppGroup(String root) {
  final pbx = File(p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'));
  if (pbx.existsSync()) {
    final project = PbxProject.parse(pbx.readAsStringSync());
    final runner = project.targetId('Runner');
    if (runner != null) {
      final configs = project.configurations(runner);
      final id = configs['Release'] ?? configs.values.first;
      final bundle = project.buildSettings(id)['PRODUCT_BUNDLE_IDENTIFIER'];
      if (bundle is String && !bundle.contains(r'$')) return 'group.$bundle';
    }
  }
  return 'group.${detectAndroidNamespace(root) ?? 'com.example.app'}';
}

String _configTemplate(String appGroup) =>
    '''
# flutter_native_widget settings.
ios:
  # Shared storage between the app and the widget extension. Must be enabled
  # for your team (Xcode's automatic signing does this).
  app_group: $appGroup
  # deployment_target: '16.0'
# android:
#   namespace: com.example.app          # detected from android/app/build.gradle
#   main_activity: com.example.app.MainActivity
''';

void _checkDependencies() {
  final pubspec =
      loadYaml(File(p.join(_root, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final deps = (pubspec['dependencies'] as YamlMap?) ?? YamlMap();
  final devDeps = (pubspec['dev_dependencies'] as YamlMap?) ?? YamlMap();
  final missing = [
    if (!deps.containsKey('flutter_native_widget'))
      'flutter pub add flutter_native_widget',
    if (!devDeps.containsKey('build_runner'))
      'flutter pub add dev:build_runner',
  ];
  if (missing.isNotEmpty) {
    stdout.writeln(
      '\nMissing dependencies:\n${missing.map((m) => '  $m').join('\n')}',
    );
  }
}
