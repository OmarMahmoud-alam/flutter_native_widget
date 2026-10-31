import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_native_widget_gen/src/cli.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await buildCli().run(arguments) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}
