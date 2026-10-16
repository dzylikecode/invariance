import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

void main() {
  test(
    'found value',
    () => ResourceScope.scope(() {
      final module = PyModule.fromSource('a = 5');
      final a = module.getAttr('a').asInt();
      expect(a, equals(5));
    }),
  );

  test(
    'not found value',
    () => ResourceScope.scope(() {
      final module = PyModule.fromSource('a = 5');
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
    }),
  );
}
