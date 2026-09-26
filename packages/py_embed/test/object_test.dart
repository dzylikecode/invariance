import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  group('PyTuple', () {
    test('takes ownership', () {
      // #region tuple-take-the-ownership
      final tuple = PyTuple(1);
      // dart format off
      final obj = PyTuple(1);  expect(obj.ref.count, equals(1));
      tuple[0] = obj;          expect(obj.ref.count, equals(1));
      tuple.ref.discrement();  expect(obj.ref.count, equals(0)); // tuple 释放 obj
      // dart format on
      // #endregion
    });

    test('takes ownership of primitive types', () {
      final tuple = PyTuple(1);
      // dart format off
      final obj = PyDouble(1); expect(obj.ref.count, equals(1));
      tuple[0] = obj;          expect(obj.ref.count, equals(1));
      tuple.ref.discrement();  expect(obj.ref.count, equals(0));
      // dart format on
    });

    test('throws for an out-of-range index', () {
      final tuple = PyTuple(1);

      expect(
        () => tuple[2],
        throwsA(
          isA<PyException>()
              .having((e) => e.type, 'type', contains('IndexError'))
              .having((e) => e.message, 'message', "tuple index out of range"),
        ),
      );
    });
  });

  group('PyList', () {
    test('append retains the item', () {
      final owner = PyList(1);
      // dart format off
      final part = PyTuple(1); expect(part.ref.count, equals(1));
      owner.add(part);         expect(part.ref.count, equals(2));
      owner.ref.discrement();  expect(part.ref.count, equals(1));
      // dart format on
    });

    test('insert retains the item', () {
      final owner = PyList(1);
      // dart format off
      final part = PyTuple(1); expect(part.ref.count, equals(1));
      owner.insert(0, part);   expect(part.ref.count, equals(2));
      owner.ref.discrement();  expect(part.ref.count, equals(1));
      // dart format on
    });

    test('setItem takes ownership of primitive types', () {
      final owner = PyList(1);
      // dart format off
      final obj = PyDouble(1); expect(obj.ref.count, equals(1));
      owner[0] = obj;          expect(obj.ref.count, equals(1));
      owner.ref.discrement();  expect(obj.ref.count, equals(0));
      // dart format on
    });
  });
}
