import 'dart:io';

import 'package:flutter_native_widget_gen/src/project/pbxproj.dart';
import 'package:test/test.dart';

void main() {
  test(
    'round trip of an untouched Flutter project is byte for byte identical',
    () {
      final source = File(
        'test/fixtures/flutter_3_47.pbxproj',
      ).readAsStringSync();
      expect(writePbxproj(parsePbxproj(source)), source);
    },
  );

  test(
    'a project written by another tool is normalized without losing data',
    () {
      // home_widget_cli appends objects unsorted; Xcode (and we) sort them.
      final source = File(
        'test/fixtures/home_widget_cli.pbxproj',
      ).readAsStringSync();
      final parsed = parsePbxproj(source);
      final written = writePbxproj(parsed);
      expect(parsePbxproj(written), parsed);
      expect(writePbxproj(parsePbxproj(written)), written);
    },
  );

  test('ids are deterministic and 24 hex digits', () {
    expect(pbxId('a'), pbxId('a'));
    expect(pbxId('a'), isNot(pbxId('b')));
    expect(pbxId('a'), matches(RegExp(r'^[0-9A-F]{24}$')));
  });
}
