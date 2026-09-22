import 'package:py_embed/src/common.dart';
import 'package:test/test.dart';

void main() {
  group('version', () {
    TypeMatcher<Version> version(int major, int minor, int patch) =>
        isA<Version>()
            .having((s) => s.major, 'major', equals(major))
            .having((s) => s.minor, 'minor', equals(minor))
            .having((s) => s.patch, 'patch', equals(patch));
    test('parse 3.8.20', () {
      expect(Version.parse('3.8.20'), version(3, 8, 20));
    });

    test('parse 3_8_20', () {
      expect(Version.parse('3_8_20', delimiter: '_'), version(3, 8, 20));
    });
  });
}
