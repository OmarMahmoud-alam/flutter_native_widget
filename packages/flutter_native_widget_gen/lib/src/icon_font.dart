import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Outline of one icon, as SVG path data in a [width] × [height] box with
/// the y axis pointing down (what Android vector drawables expect).
class IconOutline {
  final String pathData;
  final double width;
  final double height;

  const IconOutline(this.pathData, this.width, this.height);
}

/// Reads glyph outlines from Flutter's `MaterialIcons-Regular.otf`, so a
/// widget gets small vector drawables for the icons it uses instead of the
/// whole 1.6 MB font.
class IconFont {
  final ByteData _data;
  late final int _unitsPerEm;
  late final int _ascender;
  late final int _descender;
  late final Map<int, int> _cmap;
  late final _Cff _cff;

  IconFont._(Uint8List bytes) : _data = ByteData.sublistView(bytes) {
    final tables = <String, int>{};
    final count = _u16(4);
    for (var i = 0; i < count; i++) {
      final record = 12 + 16 * i;
      final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
      tables[tag] = _u32(record + 8);
    }
    for (final tag in ['head', 'hhea', 'cmap', 'CFF ']) {
      if (!tables.containsKey(tag)) {
        throw const FormatException('Not a CFF OpenType font.');
      }
    }
    _unitsPerEm = _u16(tables['head']! + 18);
    _ascender = _s16(tables['hhea']! + 4);
    _descender = _s16(tables['hhea']! + 6);
    _cmap = _readCmap(tables['cmap']!);
    _cff = _Cff(_data, tables['CFF ']!);
  }

  static IconFont? _material;

  /// The Material Icons font of the Flutter SDK running this generator.
  static IconFont material() {
    if (_material != null) return _material!;
    final file = _findMaterialFont();
    if (file == null) {
      throw StateError(
        'MaterialIcons-Regular.otf not found. Run the generator with the '
        'Flutter SDK (`dart run build_runner build` from a Flutter project) '
        'or set FLUTTER_ROOT.',
      );
    }
    return _material = IconFont._(file.readAsBytesSync());
  }

  static File? _findMaterialFont() {
    const relative = ['bin', 'cache', 'artifacts', 'material_fonts'];
    final roots = <String>[
      ?Platform.environment['FLUTTER_ROOT'],
      // <flutter>/bin/cache/dart-sdk/bin/dart
      p.dirname(
        p.dirname(p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable)))),
      ),
    ];
    for (final root in roots) {
      final file = File(
        p.joinAll([root, ...relative, 'MaterialIcons-Regular.otf']),
      );
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// The outline of [codePoint], or `null` when the font has no such glyph.
  IconOutline? outline(int codePoint) {
    final glyph = _cmap[codePoint];
    if (glyph == null) return null;
    final path = _cff.glyphPath(glyph, flipAt: _ascender.toDouble());
    return IconOutline(
      path,
      _unitsPerEm.toDouble(),
      (_ascender - _descender).toDouble(),
    );
  }

  Map<int, int> _readCmap(int offset) {
    final count = _u16(offset + 2);
    int? best;
    var bestFormat = 0;
    for (var i = 0; i < count; i++) {
      final record = offset + 4 + 8 * i;
      final platform = _u16(record);
      final sub = offset + _u32(record + 4);
      final format = _u16(sub);
      if (platform != 0 && platform != 3) continue;
      if (format == 12 || (format == 4 && bestFormat != 12)) {
        best = sub;
        bestFormat = format;
      }
    }
    if (best == null) throw const FormatException('No Unicode cmap.');
    final map = <int, int>{};
    if (bestFormat == 12) {
      final groups = _u32(best + 12);
      for (var i = 0; i < groups; i++) {
        final g = best + 16 + 12 * i;
        final start = _u32(g), end = _u32(g + 4), glyph = _u32(g + 8);
        for (var c = start; c <= end; c++) {
          map[c] = glyph + c - start;
        }
      }
    } else {
      final segments = _u16(best + 6) ~/ 2;
      final ends = best + 14;
      final starts = ends + 2 * segments + 2;
      final deltas = starts + 2 * segments;
      final ranges = deltas + 2 * segments;
      for (var s = 0; s < segments; s++) {
        final start = _u16(starts + 2 * s), end = _u16(ends + 2 * s);
        final delta = _s16(deltas + 2 * s);
        final range = _u16(ranges + 2 * s);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (range == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final at = ranges + 2 * s + range + 2 * (c - start);
            glyph = _u16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) map[c] = glyph;
        }
      }
    }
    return map;
  }

  int _u16(int o) => _data.getUint16(o);
  int _s16(int o) => _data.getInt16(o);
  int _u32(int o) => _data.getUint32(o);
}

/// The parts of a CFF table needed to draw glyphs.
class _Cff {
  final ByteData _d;
  late final List<(int, int)> _charStrings;
  late final List<(int, int)> _globalSubrs;
  late final List<List<(int, int)>> _localSubrs;
  late final List<int> _fdSelect;

  _Cff(this._d, int base) {
    final headerSize = _d.getUint8(base + 2);
    var at = base + headerSize;
    final (_, afterNames) = _index(at); // Name INDEX
    final (topDicts, afterTop) = _index(afterNames);
    final (_, afterStrings) = _index(afterTop); // String INDEX
    final (globals, _) = _index(afterStrings);
    _globalSubrs = globals;
    final top = _dict(topDicts.first);
    _charStrings = _index(base + top[17]!.first.toInt()).$1;
    if (top.containsKey(1236)) {
      // CID-keyed: one Private DICT per font DICT, picked by FDSelect.
      final fdArray = _index(base + top[1236]!.first.toInt()).$1;
      _localSubrs = [for (final fd in fdArray) _privateSubrs(base, _dict(fd))];
      _fdSelect = _readFdSelect(base + top[1237]!.first.toInt());
    } else {
      _localSubrs = [_privateSubrs(base, top)];
      _fdSelect = const [];
    }
  }

  List<(int, int)> _privateSubrs(int base, Map<int, List<num>> dict) {
    final private = dict[18];
    if (private == null) return const [];
    final size = private[0].toInt(), offset = base + private[1].toInt();
    final privateDict = _dict((offset, offset + size));
    final subrs = privateDict[19];
    if (subrs == null) return const [];
    return _index(offset + subrs.first.toInt()).$1;
  }

  List<int> _readFdSelect(int at) {
    final format = _d.getUint8(at);
    final glyphs = _charStrings.length;
    if (format == 0) {
      return [for (var g = 0; g < glyphs; g++) _d.getUint8(at + 1 + g)];
    }
    final result = List<int>.filled(glyphs, 0);
    final ranges = _d.getUint16(at + 1);
    for (var r = 0; r < ranges; r++) {
      final first = _d.getUint16(at + 3 + 3 * r);
      final fd = _d.getUint8(at + 5 + 3 * r);
      final next = _d.getUint16(at + 6 + 3 * r);
      for (var g = first; g < next && g < glyphs; g++) {
        result[g] = fd;
      }
    }
    return result;
  }

  /// Items of the INDEX at [at] as `(start, end)` byte ranges, and the
  /// offset right after it.
  (List<(int, int)>, int) _index(int at) {
    final count = _d.getUint16(at);
    if (count == 0) return (const <(int, int)>[], at + 2);
    final offSize = _d.getUint8(at + 2);
    int offset(int i) {
      var value = 0;
      for (var b = 0; b < offSize; b++) {
        value = (value << 8) | _d.getUint8(at + 3 + i * offSize + b);
      }
      return value;
    }

    final dataStart = at + 3 + (count + 1) * offSize - 1;
    final items = [
      for (var i = 0; i < count; i++)
        (dataStart + offset(i), dataStart + offset(i + 1)),
    ];
    return (items, dataStart + offset(count));
  }

  Map<int, List<num>> _dict((int, int) range) {
    final result = <int, List<num>>{};
    final operands = <num>[];
    var i = range.$1;
    while (i < range.$2) {
      final b0 = _d.getUint8(i);
      if (b0 <= 21) {
        var op = b0;
        i++;
        if (b0 == 12) op = 1200 + _d.getUint8(i++);
        result[op] = List.of(operands);
        operands.clear();
      } else if (b0 == 28) {
        operands.add(_d.getInt16(i + 1));
        i += 3;
      } else if (b0 == 29) {
        operands.add(_d.getInt32(i + 1));
        i += 5;
      } else if (b0 == 30) {
        // Real number: skip its nibbles (not needed for outlines).
        i++;
        while (true) {
          final b = _d.getUint8(i++);
          if ((b & 0x0F) == 0x0F || (b >> 4) == 0x0F) break;
        }
        operands.add(0);
      } else if (b0 >= 32 && b0 <= 246) {
        operands.add(b0 - 139);
        i++;
      } else if (b0 >= 247 && b0 <= 250) {
        operands.add((b0 - 247) * 256 + _d.getUint8(i + 1) + 108);
        i += 2;
      } else if (b0 >= 251 && b0 <= 254) {
        operands.add(-(b0 - 251) * 256 - _d.getUint8(i + 1) - 108);
        i += 2;
      } else {
        i++;
      }
    }
    return result;
  }

  String glyphPath(int glyph, {required double flipAt}) {
    final subrs = _localSubrs[_fdSelect.isEmpty ? 0 : _fdSelect[glyph]];
    final run = _CharString(this, subrs, flipAt);
    run.execute(_charStrings[glyph]);
    return run.path.toString().trim();
  }

  static int _bias(int count) =>
      count < 1240 ? 107 : (count < 33900 ? 1131 : 32768);
}

/// A Type 2 charstring interpreter that writes absolute SVG commands.
class _CharString {
  final _Cff cff;
  final List<(int, int)> localSubrs;
  final double flipAt;
  final path = StringBuffer();
  final stack = <double>[];
  var x = 0.0, y = 0.0;
  var stems = 0;
  var haveWidth = false;
  var open = false;
  var done = false;

  _CharString(this.cff, this.localSubrs, this.flipAt);

  String _n(double v) {
    final rounded = (v * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  void _moveTo(double dx, double dy) {
    if (open) path.write('Z ');
    x += dx;
    y += dy;
    path.write('M${_n(x)},${_n(flipAt - y)} ');
    open = true;
  }

  void _lineTo(double dx, double dy) {
    x += dx;
    y += dy;
    path.write('L${_n(x)},${_n(flipAt - y)} ');
  }

  void _curveTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  ) {
    final x1 = x + dx1, y1 = y + dy1;
    final x2 = x1 + dx2, y2 = y1 + dy2;
    x = x2 + dx3;
    y = y2 + dy3;
    path.write(
      'C${_n(x1)},${_n(flipAt - y1)} ${_n(x2)},${_n(flipAt - y2)} '
      '${_n(x)},${_n(flipAt - y)} ',
    );
  }

  /// Drops the advance width that may precede the first stack-clearing
  /// operator's arguments.
  void _width(bool hasExtra) {
    if (!haveWidth && hasExtra && stack.isNotEmpty) stack.removeAt(0);
    haveWidth = true;
  }

  void execute((int, int) range) {
    final d = cff._d;
    var i = range.$1;
    while (i < range.$2 && !done) {
      final b0 = d.getUint8(i);
      if (b0 >= 32 || b0 == 28) {
        if (b0 == 28) {
          stack.add(d.getInt16(i + 1).toDouble());
          i += 3;
        } else if (b0 <= 246) {
          stack.add(b0 - 139.0);
          i++;
        } else if (b0 <= 250) {
          stack.add((b0 - 247) * 256 + d.getUint8(i + 1) + 108.0);
          i += 2;
        } else if (b0 <= 254) {
          stack.add(-(b0 - 251) * 256 - d.getUint8(i + 1) - 108.0);
          i += 2;
        } else {
          stack.add(d.getInt32(i + 1) / 65536);
          i += 5;
        }
        continue;
      }
      i++;
      switch (b0) {
        case 1 || 3 || 18 || 23: // hstem, vstem, hstemhm, vstemhm
          _width(stack.length.isOdd);
          stems += stack.length ~/ 2;
          stack.clear();
        case 19 || 20: // hintmask, cntrmask
          _width(stack.length.isOdd);
          stems += stack.length ~/ 2;
          stack.clear();
          i += (stems + 7) ~/ 8;
        case 21: // rmoveto
          _width(stack.length > 2);
          _moveTo(stack[0], stack[1]);
          stack.clear();
        case 22: // hmoveto
          _width(stack.length > 1);
          _moveTo(stack[0], 0);
          stack.clear();
        case 4: // vmoveto
          _width(stack.length > 1);
          _moveTo(0, stack[0]);
          stack.clear();
        case 5: // rlineto
          for (var k = 0; k + 1 < stack.length; k += 2) {
            _lineTo(stack[k], stack[k + 1]);
          }
          stack.clear();
        case 6 || 7: // hlineto, vlineto
          var horizontal = b0 == 6;
          for (final v in stack) {
            horizontal ? _lineTo(v, 0) : _lineTo(0, v);
            horizontal = !horizontal;
          }
          stack.clear();
        case 8: // rrcurveto
          for (var k = 0; k + 5 < stack.length; k += 6) {
            _curveTo(
              stack[k],
              stack[k + 1],
              stack[k + 2],
              stack[k + 3],
              stack[k + 4],
              stack[k + 5],
            );
          }
          stack.clear();
        case 24: // rcurveline
          var k = 0;
          for (; k + 7 < stack.length; k += 6) {
            _curveTo(
              stack[k],
              stack[k + 1],
              stack[k + 2],
              stack[k + 3],
              stack[k + 4],
              stack[k + 5],
            );
          }
          _lineTo(stack[k], stack[k + 1]);
          stack.clear();
        case 25: // rlinecurve
          var k = 0;
          for (; k + 7 < stack.length; k += 2) {
            _lineTo(stack[k], stack[k + 1]);
          }
          _curveTo(
            stack[k],
            stack[k + 1],
            stack[k + 2],
            stack[k + 3],
            stack[k + 4],
            stack[k + 5],
          );
          stack.clear();
        case 26: // vvcurveto
          var k = 0;
          var dx1 = 0.0;
          if (stack.length.isOdd) dx1 = stack[k++];
          for (; k + 3 < stack.length; k += 4) {
            _curveTo(
              dx1,
              stack[k],
              stack[k + 1],
              stack[k + 2],
              0,
              stack[k + 3],
            );
            dx1 = 0;
          }
          stack.clear();
        case 27: // hhcurveto
          var k = 0;
          var dy1 = 0.0;
          if (stack.length.isOdd) dy1 = stack[k++];
          for (; k + 3 < stack.length; k += 4) {
            _curveTo(
              stack[k],
              dy1,
              stack[k + 1],
              stack[k + 2],
              stack[k + 3],
              0,
            );
            dy1 = 0;
          }
          stack.clear();
        case 30 || 31: // vhcurveto, hvcurveto
          var horizontal = b0 == 31;
          var k = 0;
          while (k + 3 < stack.length) {
            final last = stack.length - k == 5;
            final extra = last ? stack[k + 4] : 0.0;
            if (horizontal) {
              _curveTo(
                stack[k],
                0,
                stack[k + 1],
                stack[k + 2],
                extra,
                stack[k + 3],
              );
            } else {
              _curveTo(
                0,
                stack[k],
                stack[k + 1],
                stack[k + 2],
                stack[k + 3],
                extra,
              );
            }
            k += last ? 5 : 4;
            horizontal = !horizontal;
          }
          stack.clear();
        case 10 || 29: // callsubr, callgsubr
          final subrs = b0 == 10 ? localSubrs : cff._globalSubrs;
          final index = stack.removeLast().toInt() + _Cff._bias(subrs.length);
          execute(subrs[index]);
        case 11: // return
          return;
        case 14: // endchar
          _width(stack.length == 1 || stack.length == 5);
          if (open) path.write('Z ');
          open = false;
          done = true;
          stack.clear();
        case 12:
          final op = d.getUint8(i++);
          _flex(op);
          stack.clear();
        default:
          stack.clear();
      }
    }
  }

  void _flex(int op) {
    final s = stack;
    switch (op) {
      case 35: // flex
        _curveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
        _curveTo(s[6], s[7], s[8], s[9], s[10], s[11]);
      case 34: // hflex
        final startY = y;
        _curveTo(s[0], 0, s[1], s[2], s[3], 0);
        _curveTo(s[4], 0, s[5], startY - y, s[6], 0);
      case 36: // hflex1
        final startY = y;
        _curveTo(s[0], s[1], s[2], s[3], s[4], 0);
        _curveTo(s[5], 0, s[6], s[7], s[8], startY - (y + s[7]));
      case 37: // flex1
        final startX = x, startY = y;
        var dx = 0.0, dy = 0.0;
        for (var k = 0; k < 10; k += 2) {
          dx += s[k];
          dy += s[k + 1];
        }
        _curveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
        if (dx.abs() > dy.abs()) {
          _curveTo(s[6], s[7], s[8], s[9], s[10], startY - (y + s[7] + s[9]));
        } else {
          _curveTo(s[6], s[7], s[8], s[9], startX - (x + s[6] + s[8]), s[10]);
        }
    }
  }
}
