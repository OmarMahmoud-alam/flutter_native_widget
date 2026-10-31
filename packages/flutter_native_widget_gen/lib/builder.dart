/// build_runner builders for flutter_native_widget.
///
/// 1. `ir`: reads `@HomeScreenWidget` / `@WidgetCallback` and caches the IR
///    (`.fnw.json`, hidden).
/// 2. `dart`: writes the typed `part` file (`.fnw.dart`) from the IR.
/// 3. `native`: collects every IR, writes `lib/home_widgets.g.dart` and syncs
///    the Android and iOS code into the project.
library;

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'src/config.dart';
import 'src/emit/dart_emitter.dart';
import 'src/ir.dart';
import 'src/native_sync.dart';
import 'src/reader.dart';

Builder irBuilder(BuilderOptions options) => _IrBuilder();

Builder dartBuilder(BuilderOptions options) => _DartBuilder();

Builder nativeBuilder(BuilderOptions options) =>
    _NativeBuilder(sync: options.config['sync'] as bool? ?? true);

class _IrBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.fnw.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    if (input.path.endsWith('.fnw.dart') || input.path.endsWith('.g.dart')) {
      return;
    }
    if (!await buildStep.resolver.isLibrary(input)) return;
    final source = await buildStep.readAsString(input);
    // Cheap check before resolving the library.
    if (!source.contains('HomeScreenWidget') &&
        !source.contains('WidgetCallback')) {
      return;
    }
    final library = await buildStep.inputLibrary;
    final ir = readLibrary(library);
    if (ir.isEmpty) return;
    if (ir.widgets.isNotEmpty) {
      final part = p.basename(input.changeExtension('.fnw.dart').path);
      if (!source.contains("part '$part'") &&
          !source.contains('part "$part"')) {
        log.warning(
          '${input.path} declares home screen widgets but is missing '
          "`part '$part';`. Add it to use the generated API.",
        );
      }
    }
    await buildStep.writeAsString(
      input.changeExtension('.fnw.json'),
      jsonEncode(ir.toJson()),
    );
  }
}

class _DartBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.fnw.json': ['.fnw.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final ir = LibraryIR.fromJson(
      (jsonDecode(await buildStep.readAsString(buildStep.inputId)) as Map)
          .cast(),
    );
    if (ir.widgets.isEmpty) return;
    final dartFile = buildStep.inputId.path.replaceFirst(
      RegExp(r'\.fnw\.json$'),
      '.dart',
    );
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.dart'),
      emitDartPart(ir, p.basename(dartFile)),
    );
  }
}

class _NativeBuilder implements Builder {
  final bool sync;

  _NativeBuilder({required this.sync});

  @override
  final buildExtensions = const {
    r'$package$': ['lib/home_widgets.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final libraries = <LibraryIR>[];
    final ids = await buildStep.findAssets(Glob('lib/**.fnw.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final id in ids) {
      libraries.add(
        LibraryIR.fromJson(
          (jsonDecode(await buildStep.readAsString(id)) as Map).cast(),
        ),
      );
    }

    final names = <String>{};
    for (final w in [for (final l in libraries) ...l.widgets]) {
      if (!names.add(w.name)) {
        throw FnwException(
          'Two widgets are named `${w.name}`. Widget names must be unique '
          'across the app.',
        );
      }
    }

    // build_runner runs in the root package, so the working directory is the
    // Flutter project.
    final root = Directory.current.path;
    final config = ProjectConfig.load(root);
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/home_widgets.g.dart'),
      emitRegistry(libraries, config),
    );

    if (!sync || buildStep.inputId.package != _rootPackage(root)) return;
    saveIrCache(root, libraries);
    final report = syncNative(libraries, config);
    if (report.changed) {
      log.info('flutter_native_widget: native code updated\n$report');
    }
    for (final warning in report.warnings) {
      log.warning('flutter_native_widget: $warning');
    }
  }

  String? _rootPackage(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    return RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
  }
}
