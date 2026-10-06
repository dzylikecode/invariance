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

    test('compares major, minor, and patch in order', () {
      final versions = [
        const Version(3, 12, 99),
        const Version(3, 13, 0),
        const Version(3, 13, 1),
        const Version(4, 0, 0),
      ];
      for (var i = 0; i < versions.length; i++) {
        for (var j = 0; j < versions.length; j++) {
          final left = versions[i];
          final right = versions[j];
          expect(left.compareTo(right).sign, i.compareTo(j).sign);
          expect(left < right, i < j);
          expect(left <= right, i <= j);
          expect(left > right, i > j);
          expect(left >= right, i >= j);
        }
      }
      expect(const Version(3, 13, 0).compareTo(Version(3, 13, 0)), 0);
    });
  });
}
