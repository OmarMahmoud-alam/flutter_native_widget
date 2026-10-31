import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const configFileName = 'flutter_native_widget.yaml';

/// Project settings: `flutter_native_widget.yaml` plus what can be detected
/// from the Android and iOS projects.
class ProjectConfig {
  final String root;

  /// iOS App Group shared by the app and the widget extension.
  final String? iosAppGroup;

  /// Minimum iOS version of the widget extension.
  final String iosDeploymentTarget;

  /// Android namespace (package of the `R` class).
  final String androidNamespace;

  /// Fully qualified class of the activity widgets open.
  final String androidMainActivity;

  const ProjectConfig({
    required this.root,
    required this.iosAppGroup,
    required this.iosDeploymentTarget,
    required this.androidNamespace,
    required this.androidMainActivity,
  });

  /// Package of the generated Kotlin code.
  String get androidPackage => '$androidNamespace.fnw';

  String androidProviderClass(String widget) =>
      '$androidPackage.${widget}WidgetProvider';

  bool get hasAndroid => Directory(p.join(root, 'android', 'app')).existsSync();

  bool get hasIos => File(
    p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
  ).existsSync();

  static ProjectConfig load(String root) {
    final file = File(p.join(root, configFileName));
    final YamlMap yaml = file.existsSync()
        ? (loadYaml(file.readAsStringSync()) as YamlMap? ?? YamlMap())
        : YamlMap();
    final ios = yaml['ios'] as YamlMap? ?? YamlMap();
    final android = yaml['android'] as YamlMap? ?? YamlMap();

    final namespace =
        android['namespace'] as String? ??
        detectAndroidNamespace(root) ??
        'com.example.app';
    return ProjectConfig(
      root: root,
      iosAppGroup: ios['app_group'] as String?,
      iosDeploymentTarget: '${ios['deployment_target'] ?? '16.0'}',
      androidNamespace: namespace,
      androidMainActivity:
          android['main_activity'] as String? ??
          detectMainActivity(root) ??
          '$namespace.MainActivity',
    );
  }
}

/// `namespace = "..."` from `android/app/build.gradle(.kts)`.
String? detectAndroidNamespace(String root) {
  for (final name in ['build.gradle.kts', 'build.gradle']) {
    final file = File(p.join(root, 'android', 'app', name));
    if (!file.existsSync()) continue;
    final match = RegExp(
      r'''namespace\s*=?\s*["']([^"']+)["']''',
    ).firstMatch(file.readAsStringSync());
    if (match != null) return match.group(1);
  }
  return null;
}

/// The package of `MainActivity` in `android/app/src/main`.
String? detectMainActivity(String root) {
  final main = Directory(p.join(root, 'android', 'app', 'src', 'main'));
  if (!main.existsSync()) return null;
  for (final entity in main.listSync(recursive: true)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name != 'MainActivity.kt' && name != 'MainActivity.java') continue;
    final match = RegExp(
      r'^\s*package\s+([\w.]+)',
      multiLine: true,
    ).firstMatch(entity.readAsStringSync());
    if (match != null) return '${match.group(1)}.MainActivity';
  }
  return null;
}
