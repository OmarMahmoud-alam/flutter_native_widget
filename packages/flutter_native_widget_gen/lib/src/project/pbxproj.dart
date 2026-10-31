/// Reads and writes Xcode `project.pbxproj` files (OpenStep property lists)
/// in the exact format Xcode itself writes, so a parse/write round trip of an
/// untouched project is byte for byte identical.
library;

typedef PbxDict = Map<String, Object>;

/// Parses a `project.pbxproj` file. Values are `String`, `List<Object>` or
/// `Map<String, Object>`; key order is preserved.
PbxDict parsePbxproj(String source) => _Parser(source).parseRoot();

class PbxprojFormatException implements Exception {
  final String message;
  final int offset;

  PbxprojFormatException(this.message, this.offset);

  @override
  String toString() => 'Invalid project.pbxproj at offset $offset: $message';
}

class _Parser {
  final String s;
  int i = 0;

  _Parser(this.s);

  PbxDict parseRoot() {
    _skip();
    final value = _value();
    if (value is! Map<String, Object>) _fail('Expected a dictionary');
    return value;
  }

  Never _fail(String message) => throw PbxprojFormatException(message, i);

  void _skip() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        i++;
      } else if (s.startsWith('/*', i)) {
        final end = s.indexOf('*/', i + 2);
        if (end < 0) _fail('Unterminated comment');
        i = end + 2;
      } else if (s.startsWith('//', i)) {
        final end = s.indexOf('\n', i);
        i = end < 0 ? s.length : end + 1;
      } else {
        break;
      }
    }
  }

  void _expect(String char) {
    _skip();
    if (i >= s.length || s[i] != char) _fail('Expected "$char"');
    i++;
  }

  Object _value() {
    _skip();
    if (i >= s.length) _fail('Unexpected end');
    final c = s[i];
    if (c == '{') return _dict();
    if (c == '(') return _array();
    return _string();
  }

  PbxDict _dict() {
    _expect('{');
    final map = <String, Object>{};
    while (true) {
      _skip();
      if (i < s.length && s[i] == '}') {
        i++;
        return map;
      }
      final key = _string();
      _expect('=');
      map[key] = _value();
      _expect(';');
    }
  }

  List<Object> _array() {
    _expect('(');
    final list = <Object>[];
    while (true) {
      _skip();
      if (i < s.length && s[i] == ')') {
        i++;
        return list;
      }
      list.add(_value());
      _skip();
      if (i < s.length && s[i] == ',') i++;
    }
  }

  String _string() {
    _skip();
    if (i >= s.length) _fail('Expected a string');
    if (s[i] == '"') {
      i++;
      final b = StringBuffer();
      while (i < s.length && s[i] != '"') {
        if (s[i] == r'\' && i + 1 < s.length) {
          final n = s[i + 1];
          b.write(switch (n) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            _ => n,
          });
          i += 2;
        } else {
          b.write(s[i]);
          i++;
        }
      }
      if (i >= s.length) _fail('Unterminated string');
      i++;
      return b.toString();
    }
    final start = i;
    while (i < s.length && _isUnquotedChar(s.codeUnitAt(i))) {
      i++;
    }
    if (start == i) _fail('Unexpected character "${s[i]}"');
    return s.substring(start, i);
  }
}

bool _isUnquotedChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F || // _
    c == 0x24 || // $
    c == 0x2F || // /
    c == 0x3A || // :
    c == 0x2E || // .
    c == 0x2D; // - (accepted when reading, quoted when writing)

final _plainString = RegExp(r'^[A-Za-z0-9_$/:.]+$');

String _quote(String value) {
  if (_plainString.hasMatch(value)) return value;
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}

/// Object types Xcode writes on a single line.
const _singleLine = {'PBXBuildFile', 'PBXFileReference'};

/// Keys whose id values Xcode writes without a comment.
const _noCommentKeys = {'remoteGlobalIDString', 'TestTargetID'};

/// Writes [root] in Xcode's own format.
String writePbxproj(PbxDict root) => _Writer(root).write();

class _Writer {
  final PbxDict root;
  late final PbxDict objects = (root['objects'] as Map).cast();
  final out = StringBuffer();
  late final Map<String, String> _buildFilePhase = _indexBuildFilePhases();

  _Writer(this.root);

  String write() {
    out.writeln(r'// !$*UTF8*$!');
    out.writeln('{');
    for (final key in _sortedKeys(root)) {
      if (key == 'objects') {
        out.writeln('\tobjects = {');
        _writeObjects();
        out.writeln('\t};');
      } else {
        out.write('\t${_quote(key)} = ');
        _writeValue(root[key]!, 1, key: key);
        out.writeln(';');
      }
    }
    out.writeln('}');
    return out.toString();
  }

  void _writeObjects() {
    final byIsa = <String, List<String>>{};
    for (final MapEntry(:key, :value) in objects.entries) {
      final isa = (value as Map)['isa'] as String? ?? '';
      byIsa.putIfAbsent(isa, () => []).add(key);
    }
    for (final isa in byIsa.keys.toList()..sort()) {
      out.writeln();
      out.writeln('/* Begin $isa section */');
      for (final id in byIsa[isa]!..sort()) {
        final object = (objects[id] as Map).cast<String, Object>();
        out.write('\t\t${_withComment(id)} = ');
        if (_singleLine.contains(isa)) {
          _writeInline(object);
        } else {
          _writeDict(object, 2);
        }
        out.writeln(';');
      }
      out.writeln('/* End $isa section */');
    }
  }

  List<String> _sortedKeys(Map<String, Object> map) {
    final keys = map.keys.toList()..sort();
    if (keys.remove('isa')) keys.insert(0, 'isa');
    return keys;
  }

  void _writeValue(Object value, int depth, {String? key}) {
    if (value is Map) {
      _writeDict(value.cast(), depth);
    } else if (value is List) {
      _writeArray(value.cast(), depth);
    } else {
      out.write(_reference(value as String, key));
    }
  }

  void _writeDict(Map<String, Object> map, int depth) {
    final indent = '\t' * (depth + 1);
    out.writeln('{');
    for (final key in _sortedKeys(map)) {
      // Dictionary keys are never commented, even when they are ids.
      out.write('$indent${_quote(key)} = ');
      _writeValue(map[key]!, depth + 1, key: key);
      out.writeln(';');
    }
    out.write('${'\t' * depth}}');
  }

  void _writeArray(List<Object> list, int depth) {
    final indent = '\t' * (depth + 1);
    out.writeln('(');
    for (final item in list) {
      out.write(indent);
      _writeValue(item, depth + 1);
      out.writeln(',');
    }
    out.write('${'\t' * depth})');
  }

  void _writeInline(Object value, {String? key}) {
    if (value is Map) {
      final map = value.cast<String, Object>();
      out.write('{');
      for (final k in _sortedKeys(map)) {
        out.write('${_quote(k)} = ');
        _writeInline(map[k]!, key: k);
        out.write('; ');
      }
      out.write('}');
    } else if (value is List) {
      out.write('(');
      for (final item in value.cast<Object>()) {
        _writeInline(item);
        out.write(', ');
      }
      out.write(')');
    } else {
      out.write(_reference(value as String, key));
    }
  }

  String _reference(String value, String? key) {
    if (_noCommentKeys.contains(key) || !objects.containsKey(value)) {
      return _quote(value);
    }
    return _withComment(value);
  }

  String _withComment(String id) {
    final comment = _comment(id);
    return comment == null ? _quote(id) : '${_quote(id)} /* $comment */';
  }

  Map<String, String> _indexBuildFilePhases() {
    final index = <String, String>{};
    for (final MapEntry(:key, :value) in objects.entries) {
      final object = (value as Map).cast<String, Object>();
      final files = object['files'];
      if (files is List && (object['isa'] as String).endsWith('BuildPhase')) {
        for (final file in files.cast<String>()) {
          index[file] = _phaseName(object) ?? key;
        }
      }
    }
    return index;
  }

  String? _phaseName(Map<String, Object> phase) {
    final name = phase['name'] as String?;
    if (name != null) return name;
    return switch (phase['isa']) {
      'PBXSourcesBuildPhase' => 'Sources',
      'PBXFrameworksBuildPhase' => 'Frameworks',
      'PBXResourcesBuildPhase' => 'Resources',
      'PBXHeadersBuildPhase' => 'Headers',
      'PBXCopyFilesBuildPhase' => 'CopyFiles',
      'PBXShellScriptBuildPhase' => 'ShellScript',
      _ => null,
    };
  }

  String? _comment(String id) {
    final object = (objects[id] as Map?)?.cast<String, Object>();
    if (object == null) return null;
    final isa = object['isa'] as String?;
    switch (isa) {
      case 'PBXBuildFile':
        final ref = (object['fileRef'] ?? object['productRef']) as String?;
        final name = ref == null ? null : _comment(ref);
        final phase = _buildFilePhase[id];
        if (name == null) return phase;
        return phase == null ? name : '$name in $phase';
      case 'PBXProject':
        return 'Project object';
      case 'XCConfigurationList':
        for (final MapEntry(:value) in objects.entries) {
          final owner = (value as Map).cast<String, Object>();
          if (owner['buildConfigurationList'] == id) {
            final ownerName = owner['isa'] == 'PBXProject'
                ? _projectName()
                : owner['name'] as String? ?? '';
            return 'Build configuration list for ${owner['isa']} "$ownerName"';
          }
        }
        return null;
      case 'PBXContainerItemProxy':
      case 'PBXTargetDependency':
        return isa;
      case 'XCSwiftPackageProductDependency':
        return object['productName'] as String?;
      case 'XCLocalSwiftPackageReference':
        return 'XCLocalSwiftPackageReference "${object['relativePath']}"';
      case 'XCRemoteSwiftPackageReference':
        final url = object['repositoryURL'] as String? ?? '';
        final name = url.split('/').last.replaceAll('.git', '');
        return 'XCRemoteSwiftPackageReference "$name"';
      default:
        if (isa != null && isa.endsWith('BuildPhase')) {
          return _phaseName(object);
        }
        return (object['name'] ?? object['path']) as String?;
    }
  }

  String _projectName() {
    // Xcode uses the .xcodeproj name; Flutter projects always use Runner.
    return 'Runner';
  }
}

/// Convenience view over a parsed project with the edits we need.
class PbxProject {
  final PbxDict root;

  PbxProject(this.root);

  factory PbxProject.parse(String source) => PbxProject(parsePbxproj(source));

  String write() => writePbxproj(root);

  PbxDict get objects => (root['objects'] as Map).cast();

  String get rootId => root['rootObject'] as String;

  PbxDict object(String id) => (objects[id] as Map).cast();

  PbxDict get project => object(rootId);

  Iterable<MapEntry<String, PbxDict>> ofIsa(String isa) sync* {
    for (final MapEntry(:key, :value) in objects.entries) {
      final object = (value as Map).cast<String, Object>();
      if (object['isa'] == isa) yield MapEntry(key, object);
    }
  }

  String? targetId(String name) {
    for (final id in (project['targets'] as List).cast<String>()) {
      if (object(id)['name'] == name) return id;
    }
    return null;
  }

  List<String> list(PbxDict object, String key) =>
      (object.putIfAbsent(key, () => <Object>[]) as List).cast<String>();

  /// Build configurations of [targetId]: name → id.
  Map<String, String> configurations(String targetId) {
    final listId = object(targetId)['buildConfigurationList'] as String;
    return {
      for (final id
          in (object(listId)['buildConfigurations'] as List).cast<String>())
        object(id)['name'] as String: id,
    };
  }

  PbxDict buildSettings(String configurationId) =>
      (object(configurationId)['buildSettings'] as Map).cast();

  /// A deterministic, unused 24-digit id derived from [seed].
  String newId(String seed) {
    var attempt = 0;
    while (true) {
      final id = pbxId('$seed#$attempt');
      if (!objects.containsKey(id)) return id;
      attempt++;
    }
  }

  /// Adds [object] under the deterministic id for [seed], replacing an
  /// existing object with the same seed.
  String put(String seed, PbxDict object) {
    final id = pbxId('$seed#0');
    objects[id] = object;
    return id;
  }

  /// Removes [ids] and every reference to them.
  void removeAll(Set<String> ids) {
    for (final id in ids) {
      objects.remove(id);
    }
    void clean(Object value) {
      if (value is Map) {
        final map = value.cast<String, Object>();
        map.removeWhere(
          (key, v) =>
              ids.contains(key) ||
              (v is String && ids.contains(v) && key != 'isa'),
        );
        for (final v in map.values) {
          clean(v);
        }
      } else if (value is List) {
        value.removeWhere((v) => v is String && ids.contains(v));
        for (final v in value) {
          clean(v as Object);
        }
      }
    }

    clean(objects);
  }
}

/// 24 upper-case hex digits from two FNV-1a hashes of [seed].
String pbxId(String seed) {
  int fnv(String s, int basis) {
    var hash = basis;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  final a = fnv(seed, 0x811C9DC5);
  final b = fnv('fnw:$seed', 0x811C9DC5);
  final c = fnv('$seed:xcode', 0x811C9DC5);
  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return '${hex(a)}${hex(b)}${hex(c)}'.toUpperCase();
}
