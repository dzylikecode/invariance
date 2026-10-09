import 'package:py_embed/src/common.dart';
import 'package:test/test.dart';

void main() {
  group('version', () {
    test('parse 3.8.20', () {
      expect(Version.parse('3.8.20'), Version(3, 8, 20));
    });

    test('parse 3_8_20', () {
      expect(Version.parse('3_8_20', delimiter: '_'), Version(3, 8, 20));
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
