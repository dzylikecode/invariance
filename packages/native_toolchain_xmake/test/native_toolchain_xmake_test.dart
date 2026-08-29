import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main() {
  group('path', () {
    // test('linux: libName.so.1.2.3', () async {
    //   expect(getLibName('lib/libName.so.1.2.3'), equals('libName'));
    // });

    // test('mac: libName.1.2.3.dylib', () async {
    //   expect(getLibName('lib/libName.1.2.3.dylib'), equals('libName'));
    // });

    test('resolve path', () async {
      expect(
        Uri.parse('a/b/').resolveUri(.directory('c')).resolve('d'),
        equals(Uri.parse('a/b/c/d')),
      );
    });

    test('kind', () async {
      expect(Kind.static.toString(), equals('static'));
      expect(Kind.shared.toString(), equals('shared'));
    });
  });
}
