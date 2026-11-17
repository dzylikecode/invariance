import 'dart:convert';
import 'dart:io';

import 'package:native_toolchain_xmake/src/lua.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('String lists round-trip through xmake Lua', () async {
    final directory = await Directory.systemTemp.createTemp('xmake_lua_test_');
    try {
      final script = File(p.join(directory.path, 'roundtrip.lua'));
      await script.writeAsString('''
function main(value)
    import("core.base.json")
    local values = assert(value:deserialize())
    assert(type(values) == "table")
    print(json.encode({count = #values, values = values}))
end
''');

      final cases = <List<String>>[
        ['add', 'count_words', '_symbol@12'],
        [],
        [''],
        [
          '''quotes: " and ' ''',
          r'backslash: \ and \123',
          'controls: \u00007\n2\r3\t4\u001f5\u007f6',
          'Unicode: 中文 😀 café',
          r'"}; error("must remain data"); --',
          r'[[ delimiters ]=] {foo,bar}; --',
        ],
      ];
      for (final values in cases) {
        final encoded = encodeLuaStringList(values);
        final result = await Process.run(
          'xmake',
          ['lua', script.path, encoded],
          workingDirectory: directory.path,
          environment: {'XMAKE_COLORTERM': 'nocolor'},
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        expect(
          result.exitCode,
          0,
          reason:
              'xmake Lua failed for $encoded:\n'
              '${result.stdout}\n${result.stderr}',
        );
        final decoded =
            jsonDecode(result.stdout as String) as Map<String, Object?>;
        expect(decoded['count'], values.length, reason: encoded);
        // Lua 空表在 JSON 中可能是对象，空列表只比较 Lua 端的元素数。
        if (values.isNotEmpty) {
          expect(decoded['values'], equals(values), reason: encoded);
        }
      }
    } finally {
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
