import 'dart:io';

import 'package:path/path.dart' as p;

import '../config.dart';
import '../emit/ios_emitter.dart';
import 'pbxproj.dart';

const _ext = iosExtensionName;

/// Everything `init` changes in the iOS project, so it can report and undo.
class IosSetupResult {
  final List<String> changed = [];
  final List<String> warnings = [];
}

String _pbxprojPath(String root) =>
    p.join(root, 'ios', 'Runner.xcodeproj', 'project.pbxproj');

bool iosExtensionExists(String root) {
  final file = File(_pbxprojPath(root));
  if (!file.existsSync()) return false;
  return PbxProject.parse(file.readAsStringSync()).targetId(_ext) != null;
}

/// Adds the `FNWWidgets` widget extension to the Xcode project and wires it
/// to the app: target, build phases, embedding, App Group entitlements and
/// the background-callback registration in `AppDelegate.swift`.
///
/// Safe to run repeatedly; a project that is already set up is left as is.
IosSetupResult ensureIosSetup(ProjectConfig config) {
  final result = IosSetupResult();
  final root = config.root;
  final appGroup = config.iosAppGroup;
  if (appGroup == null) {
    result.warnings.add(
      'No ios.app_group in $configFileName; skipped the iOS widget extension.',
    );
    return result;
  }

  _writeIfChanged(
    p.join(root, 'ios', _ext, 'Info.plist'),
    _extensionInfoPlist,
    result,
  );
  _writeEntitlements(
    p.join(root, 'ios', _ext, '$_ext.entitlements'),
    appGroup,
    result,
  );
  _writeEntitlements(
    p.join(root, 'ios', 'Runner', 'Runner.entitlements'),
    appGroup,
    result,
  );
  _writeIfChanged(
    p.join(root, 'ios', 'Flutter', '$_ext.xcconfig'),
    _xcconfig,
    result,
  );
  final swift = File(p.join(root, 'ios', _ext, '$_ext.swift'));
  if (!swift.existsSync()) {
    _writeIfChanged(swift.path, emitIos(const [], config).values.first, result);
  }
  _writeIfChanged(
    p.join(root, 'ios', 'Runner', 'FNWCallbackIntent.swift'),
    callbackIntentSwift,
    result,
  );

  final pbxFile = File(_pbxprojPath(root));
  final original = pbxFile.readAsStringSync();
  final project = PbxProject.parse(original);
  _addTarget(project, config);
  final updated = project.write();
  if (updated != original) {
    File('${pbxFile.path}.fnw-backup').writeAsStringSync(original);
    pbxFile.writeAsStringSync(updated);
    result.changed.add(p.relative(pbxFile.path, from: root));
  }

  _patchAppDelegate(root, result);
  return result;
}

void _addTarget(PbxProject project, ProjectConfig config) {
  final runnerId = project.targetId('Runner');
  if (runnerId == null) {
    throw StateError('No "Runner" target in ios/Runner.xcodeproj.');
  }
  if (project.targetId(_ext) != null) {
    // Projects set up by 0.1.0 compiled the app's intent into the extension
    // too; the extension now has its own stand-in.
    final staleBuildFile = pbxId('fnw.buildfile.ext.intent#0');
    if (project.objects.containsKey(staleBuildFile)) {
      project.removeAll({staleBuildFile});
    }
    _ensureRunnerEntitlements(project, runnerId);
    return;
  }

  final objects = project.objects;
  final projectObject = project.project;
  final mainGroup = project.object(projectObject['mainGroup'] as String);
  final productsGroupId = projectObject['productRefGroup'] as String;

  String file(String seed, PbxDict fields) =>
      project.put('fnw.file.$seed', {'isa': 'PBXFileReference', ...fields});

  // Files.
  final appexRef = file('appex', {
    'explicitFileType': 'wrapper.app-extension',
    'includeInIndex': '0',
    'path': '$_ext.appex',
    'sourceTree': 'BUILT_PRODUCTS_DIR',
  });
  final swiftRef = file('swift', {
    'lastKnownFileType': 'sourcecode.swift',
    'path': '$_ext.swift',
    'sourceTree': '<group>',
  });
  final plistRef = file('plist', {
    'lastKnownFileType': 'text.plist.xml',
    'path': 'Info.plist',
    'sourceTree': '<group>',
  });
  final entitlementsRef = file('entitlements', {
    'lastKnownFileType': 'text.plist.entitlements',
    'path': '$_ext.entitlements',
    'sourceTree': '<group>',
  });
  final intentRef = file('intent', {
    'lastKnownFileType': 'sourcecode.swift',
    'path': 'FNWCallbackIntent.swift',
    'sourceTree': '<group>',
  });
  final xcconfigRef = file('xcconfig', {
    'lastKnownFileType': 'text.xcconfig',
    'name': '$_ext.xcconfig',
    'path': 'Flutter/$_ext.xcconfig',
    'sourceTree': '<group>',
  });

  project.list(project.object(productsGroupId), 'children').add(appexRef);
  final extGroup = project.put('fnw.group', {
    'isa': 'PBXGroup',
    'children': <Object>[swiftRef, plistRef, entitlementsRef],
    'path': _ext,
    'sourceTree': '<group>',
  });
  final mainChildren = project.list(mainGroup, 'children');
  final productsIndex = mainChildren.indexOf(productsGroupId);
  mainChildren.insert(
    productsIndex < 0 ? mainChildren.length : productsIndex,
    extGroup,
  );

  // The Runner group holds AppDelegate.swift; the intent goes next to it.
  final runnerGroup = project
      .ofIsa('PBXGroup')
      .firstWhere(
        (e) => e.value['path'] == 'Runner',
        orElse: () => MapEntry(projectObject['mainGroup'] as String, mainGroup),
      );
  project.list(runnerGroup.value, 'children').add(intentRef);
  final flutterGroup = project
      .ofIsa('PBXGroup')
      .firstWhere(
        (e) => e.value['name'] == 'Flutter' || e.value['path'] == 'Flutter',
        orElse: () => MapEntry(projectObject['mainGroup'] as String, mainGroup),
      );
  if (flutterGroup.value['path'] == 'Flutter') {
    // Inside a group with `path = Flutter` the reference is relative to it.
    final xcconfig = project.object(xcconfigRef);
    xcconfig['path'] = '$_ext.xcconfig';
    xcconfig.remove('name');
  }
  project.list(flutterGroup.value, 'children').add(xcconfigRef);

  // Build phases of the extension.
  String buildFile(String seed, String ref, [PbxDict extra = const {}]) =>
      project.put('fnw.buildfile.$seed', {
        'isa': 'PBXBuildFile',
        'fileRef': ref,
        ...extra,
      });
  final sources = project.put('fnw.phase.sources', {
    'isa': 'PBXSourcesBuildPhase',
    'buildActionMask': '2147483647',
    'files': <Object>[buildFile('ext.swift', swiftRef)],
    'runOnlyForDeploymentPostprocessing': '0',
  });
  final frameworks = project.put('fnw.phase.frameworks', {
    'isa': 'PBXFrameworksBuildPhase',
    'buildActionMask': '2147483647',
    'files': <Object>[],
    'runOnlyForDeploymentPostprocessing': '0',
  });
  final resources = project.put('fnw.phase.resources', {
    'isa': 'PBXResourcesBuildPhase',
    'buildActionMask': '2147483647',
    'files': <Object>[],
    'runOnlyForDeploymentPostprocessing': '0',
  });

  // Build configurations mirror the app's (Debug, Release, Profile, flavors).
  final runnerConfigs = project.configurations(runnerId);
  final configIds = <Object>[];
  for (final MapEntry(key: name, value: runnerConfigId)
      in runnerConfigs.entries) {
    final app = project.buildSettings(runnerConfigId);
    final bundleId =
        app['PRODUCT_BUNDLE_IDENTIFIER'] as String? ?? 'com.example.app';
    configIds.add(
      project.put('fnw.config.$name', {
        'isa': 'XCBuildConfiguration',
        'baseConfigurationReference': xcconfigRef,
        'buildSettings': <String, Object>{
          'APPLICATION_EXTENSION_API_ONLY': 'YES',
          'CLANG_ENABLE_OBJC_ARC': 'YES',
          'CODE_SIGN_ENTITLEMENTS': '$_ext/$_ext.entitlements',
          'CODE_SIGN_STYLE': app['CODE_SIGN_STYLE'] ?? 'Automatic',
          'CURRENT_PROJECT_VERSION': r'$(FLUTTER_BUILD_NUMBER)',
          if (app['DEVELOPMENT_TEAM'] != null)
            'DEVELOPMENT_TEAM': app['DEVELOPMENT_TEAM']!,
          'GENERATE_INFOPLIST_FILE': 'YES',
          'INFOPLIST_FILE': '$_ext/Info.plist',
          'INFOPLIST_KEY_CFBundleDisplayName': 'Widgets',
          'IPHONEOS_DEPLOYMENT_TARGET': config.iosDeploymentTarget,
          'LD_RUNPATH_SEARCH_PATHS': <Object>[
            r'$(inherited)',
            '@executable_path/Frameworks',
            '@executable_path/../../Frameworks',
          ],
          'MARKETING_VERSION': r'$(FLUTTER_BUILD_NAME)',
          'PRODUCT_BUNDLE_IDENTIFIER': '$bundleId.$_ext',
          'PRODUCT_NAME': r'$(TARGET_NAME)',
          'SKIP_INSTALL': 'YES',
          'SWIFT_EMIT_LOC_STRINGS': 'YES',
          'SWIFT_VERSION': '5.0',
          'TARGETED_DEVICE_FAMILY': '1,2',
        },
        'name': name,
      }),
    );
  }
  final configList = project.put('fnw.configlist', {
    'isa': 'XCConfigurationList',
    'buildConfigurations': configIds,
    'defaultConfigurationIsVisible': '0',
    'defaultConfigurationName': 'Release',
  });

  final targetId = project.put('fnw.target', {
    'isa': 'PBXNativeTarget',
    'buildConfigurationList': configList,
    'buildPhases': <Object>[sources, frameworks, resources],
    'buildRules': <Object>[],
    'dependencies': <Object>[],
    'name': _ext,
    'productName': _ext,
    'productReference': appexRef,
    'productType': 'com.apple.product-type.app-extension',
  });
  project.list(projectObject, 'targets').add(targetId);
  final attributes = (projectObject['attributes'] as Map)
      .cast<String, Object>();
  final targetAttributes =
      (attributes.putIfAbsent('TargetAttributes', () => <String, Object>{})
              as Map)
          .cast<String, Object>();
  targetAttributes[targetId] = <String, Object>{
    'CreatedOnToolsVersion': '15.0',
  };

  // Runner: compile the intent, depend on and embed the extension.
  final runner = project.object(runnerId);
  final runnerSources = project
      .list(runner, 'buildPhases')
      .firstWhere((id) => project.object(id)['isa'] == 'PBXSourcesBuildPhase');
  project
      .list(project.object(runnerSources), 'files')
      .add(buildFile('runner.intent', intentRef));

  final proxy = project.put('fnw.proxy', {
    'isa': 'PBXContainerItemProxy',
    'containerPortal': project.rootId,
    'proxyType': '1',
    'remoteGlobalIDString': targetId,
    'remoteInfo': _ext,
  });
  final dependency = project.put('fnw.dependency', {
    'isa': 'PBXTargetDependency',
    'target': targetId,
    'targetProxy': proxy,
  });
  project.list(runner, 'dependencies').add(dependency);

  final embed = project.put('fnw.phase.embed', {
    'isa': 'PBXCopyFilesBuildPhase',
    'buildActionMask': '2147483647',
    'dstPath': '',
    'dstSubfolderSpec': '13',
    'files': <Object>[
      buildFile('embed', appexRef, {
        'settings': <String, Object>{
          'ATTRIBUTES': <Object>['RemoveHeadersOnCopy'],
        },
      }),
    ],
    'name': 'Embed Foundation Extensions',
    'runOnlyForDeploymentPostprocessing': '0',
  });
  // Must come before Flutter's "Thin Binary" script, or Xcode reports a
  // dependency cycle.
  final phases = project.list(runner, 'buildPhases');
  final thinBinary = phases.indexWhere(
    (id) => project.object(id)['name'] == 'Thin Binary',
  );
  final resourcesIndex = phases.indexWhere(
    (id) => project.object(id)['isa'] == 'PBXResourcesBuildPhase',
  );
  final embedFrameworks = phases.indexWhere(
    (id) => project.object(id)['name'] == 'Embed Frameworks',
  );
  final insertAt = embedFrameworks >= 0
      ? embedFrameworks + 1
      : thinBinary >= 0
      ? thinBinary
      : resourcesIndex + 1;
  phases.insert(insertAt, embed);

  _ensureRunnerEntitlements(project, runnerId);
  assert(objects.containsKey(targetId));
}

/// Adds `FNWWidgets/Fonts` as a folder reference to the extension's
/// resources, so every font copied there is bundled. Returns whether the
/// project changed.
bool ensureIosFontsFolder(String root) {
  final file = File(_pbxprojPath(root));
  if (!file.existsSync()) return false;
  final original = file.readAsStringSync();
  final project = PbxProject.parse(original);
  if (project.objects.containsKey(pbxId('fnw.file.fonts#0'))) return false;
  final group = project.objects[pbxId('fnw.group#0')];
  final resources = project.objects[pbxId('fnw.phase.resources#0')];
  if (group == null || resources == null) return false;
  final ref = project.put('fnw.file.fonts', {
    'isa': 'PBXFileReference',
    'lastKnownFileType': 'folder',
    'path': 'Fonts',
    'sourceTree': '<group>',
  });
  project.list((group as Map).cast(), 'children').add(ref);
  final buildFile = project.put('fnw.buildfile.ext.fonts', {
    'isa': 'PBXBuildFile',
    'fileRef': ref,
  });
  project.list((resources as Map).cast(), 'files').add(buildFile);
  file.writeAsStringSync(project.write());
  return true;
}

void _ensureRunnerEntitlements(PbxProject project, String runnerId) {
  for (final id in project.configurations(runnerId).values) {
    final settings = project.buildSettings(id);
    settings.putIfAbsent(
      'CODE_SIGN_ENTITLEMENTS',
      () => 'Runner/Runner.entitlements',
    );
  }
  final hasRef = project
      .ofIsa('PBXFileReference')
      .any((e) => e.value['path'] == 'Runner.entitlements');
  if (!hasRef) {
    final ref = project.put('fnw.file.runner.entitlements', {
      'isa': 'PBXFileReference',
      'lastKnownFileType': 'text.plist.entitlements',
      'path': 'Runner.entitlements',
      'sourceTree': '<group>',
    });
    final runnerGroup = project
        .ofIsa('PBXGroup')
        .where((e) => e.value['path'] == 'Runner');
    if (runnerGroup.isNotEmpty) {
      project.list(runnerGroup.first.value, 'children').add(ref);
    }
  }
}

/// Removes everything [ensureIosSetup] added to the Xcode project.
List<String> removeIosSetup(String root) {
  final removed = <String>[];
  final pbxFile = File(_pbxprojPath(root));
  if (pbxFile.existsSync()) {
    final original = pbxFile.readAsStringSync();
    final project = PbxProject.parse(original);
    final ours = <String>{
      for (final id in project.objects.keys)
        if (_ourSeeds.any((seed) => pbxId('$seed#0') == id)) id,
    };
    for (final MapEntry(:key, :value) in project.ofIsa(
      'XCBuildConfiguration',
    )) {
      if (value['baseConfigurationReference'] == pbxId('fnw.file.xcconfig#0')) {
        ours.add(key);
      }
    }
    if (ours.isNotEmpty) {
      project.removeAll(ours);
      pbxFile.writeAsStringSync(project.write());
      removed.add('ios/Runner.xcodeproj/project.pbxproj (FNWWidgets target)');
    }
  }
  for (final path in [
    p.join(root, 'ios', _ext),
    p.join(root, 'ios', 'Flutter', '$_ext.xcconfig'),
    p.join(root, 'ios', 'Runner', 'FNWCallbackIntent.swift'),
  ]) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else {
      File(path).deleteSync();
    }
    removed.add(p.relative(path, from: root));
  }
  final delegate = File(p.join(root, 'ios', 'Runner', 'AppDelegate.swift'));
  if (delegate.existsSync()) {
    final source = delegate.readAsStringSync();
    final cleaned = source
        .replaceAll(
          RegExp(
            r'\n?[ \t]*// flutter_native_widget:begin[\s\S]*?// flutter_native_widget:end\n',
          ),
          '\n',
        )
        .replaceAll('import home_widget // flutter_native_widget\n', '');
    if (cleaned != source) {
      delegate.writeAsStringSync(cleaned);
      removed.add('ios/Runner/AppDelegate.swift (callback registration)');
    }
  }
  return removed;
}

const _ourSeeds = [
  'fnw.file.appex',
  'fnw.file.swift',
  'fnw.file.plist',
  'fnw.file.entitlements',
  'fnw.file.intent',
  'fnw.file.xcconfig',
  'fnw.file.fonts',
  'fnw.group',
  'fnw.buildfile.ext.swift',
  'fnw.buildfile.ext.intent',
  'fnw.buildfile.ext.fonts',
  'fnw.buildfile.runner.intent',
  'fnw.buildfile.embed',
  'fnw.phase.sources',
  'fnw.phase.frameworks',
  'fnw.phase.resources',
  'fnw.phase.embed',
  'fnw.configlist',
  'fnw.target',
  'fnw.proxy',
  'fnw.dependency',
];

void _patchAppDelegate(String root, IosSetupResult result) {
  final file = File(p.join(root, 'ios', 'Runner', 'AppDelegate.swift'));
  if (!file.existsSync()) {
    result.warnings.add(
      'ios/Runner/AppDelegate.swift not found. For @WidgetCallback on iOS, '
      'call HomeWidgetBackgroundWorker.setPluginRegistrantCallback yourself.',
    );
    return;
  }
  final source = file.readAsStringSync();
  if (source.contains(
    'HomeWidgetBackgroundWorker.setPluginRegistrantCallback',
  )) {
    return;
  }
  final returnSuper = RegExp(
    r'^([ \t]*)return super\.application\(application, didFinishLaunchingWithOptions',
    multiLine: true,
  ).firstMatch(source);
  if (returnSuper == null || !source.contains('import Flutter')) {
    result.warnings.add(
      'Could not find where to register widget callbacks in AppDelegate.swift. '
      'Add HomeWidgetBackgroundWorker.setPluginRegistrantCallback (see README).',
    );
    return;
  }
  final indent = returnSuper.group(1)!;
  final block =
      '$indent// flutter_native_widget:begin\n'
      '$indent// Lets @WidgetCallback functions use plugins in the background.\n'
      '${indent}if #available(iOS 17, *) {\n'
      '$indent  HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in\n'
      '$indent    GeneratedPluginRegistrant.register(with: registry)\n'
      '$indent  }\n'
      '$indent}\n'
      '$indent// flutter_native_widget:end\n';
  // Insert the block first: the import sits above it, so the match offset
  // is still valid.
  final patched = source
      .replaceRange(returnSuper.start, returnSuper.start, block)
      .replaceFirst(
        'import Flutter\n',
        'import Flutter\nimport home_widget // flutter_native_widget\n',
      );
  file.writeAsStringSync(patched);
  result.changed.add('ios/Runner/AppDelegate.swift');
}

void _writeEntitlements(String path, String appGroup, IosSetupResult result) {
  final file = File(path);
  if (!file.existsSync()) {
    _writeIfChanged(path, _entitlements([appGroup]), result);
    return;
  }
  final source = file.readAsStringSync();
  if (source.contains('<string>$appGroup</string>')) return;
  final key = '<key>com.apple.security.application-groups</key>';
  String updated;
  if (source.contains(key)) {
    updated = source.replaceFirstMapped(
      RegExp('${RegExp.escape(key)}\\s*<array>'),
      (m) => '${m[0]}\n\t\t<string>$appGroup</string>',
    );
  } else {
    updated = source.replaceFirst(
      '<dict>',
      '<dict>\n\t$key\n\t<array>\n\t\t<string>$appGroup</string>\n\t</array>',
    );
  }
  _writeIfChanged(path, updated, result);
}

String _entitlements(List<String> groups) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
${[for (final g in groups) '\t\t<string>$g</string>'].join('\n')}
	</array>
</dict>
</plist>
''';

const _extensionInfoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
''';

const _xcconfig = '''
// GENERATED by flutter_native_widget_gen. Gives the widget extension the
// app's version (FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER).
FLUTTER_BUILD_NAME = 1.0.0
FLUTTER_BUILD_NUMBER = 1
#include? "Generated.xcconfig"
''';

void _writeIfChanged(String path, String content, IosSetupResult result) {
  final file = File(path);
  if (file.existsSync() && file.readAsStringSync() == content) return;
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  result.changed.add(path);
}
