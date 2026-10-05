import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

void main() {
  runString("a = 5");
  final module = PyModule('__main__');
  test('found value', () {
    final a = module.getAttr('a').asInt();
    expect(a, equals(5));
  });

  test('not found value', () {
    expect(
      () => module.getAttr('b'),
      throwsA(
        isA<PyException>()
            .having((e) => e.type, 'type', contains('AttributeError'))
            .having(
              (e) => e.message,
              'message',
              contains("has no attribute 'b'"),
            ),
      ),
    );
  });
}
