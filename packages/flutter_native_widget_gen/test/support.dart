import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:flutter_native_widget_gen/src/ir.dart';
import 'package:flutter_native_widget_gen/src/reader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The real DSL sources of the runtime package, served in memory so the
/// reader sees exactly what app code sees (without needing Flutter).
Map<String, String> dslSources() {
  final lib = p.join('..', 'flutter_native_widget', 'lib');
  return {
    'flutter_native_widget|lib/dsl.dart': File(
      p.join(lib, 'dsl.dart'),
    ).readAsStringSync(),
    for (final file in Directory(p.join(lib, 'src', 'dsl')).listSync())
      'flutter_native_widget|lib/src/dsl/${p.basename(file.path)}': File(
        file.path,
      ).readAsStringSync(),
  };
}

/// Reads the IR of [source], a library in package `app` that imports the DSL.
Future<LibraryIR> readSource(String source) => resolveSources(
  {
    ...dslSources(),
    'app|lib/widgets.dart':
        "import 'package:flutter_native_widget/dsl.dart';\n$source",
  },
  (resolver) async => readLibrary(
    await resolver.libraryFor(AssetId('app', 'lib/widgets.dart')),
  ),
  resolverFor: 'app|lib/widgets.dart',
);

/// Reads a single widget declared in [source].
Future<WidgetIR> readWidget(String source) async =>
    (await readSource(source)).widgets.single;

/// The message of the error reading [source] throws.
Future<String> errorOf(String source) async {
  try {
    await readSource(source);
  } on FnwException catch (e) {
    return e.message;
  }
  fail('Expected an FnwException');
}
