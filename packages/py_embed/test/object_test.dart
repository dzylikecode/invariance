import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  test('tuple: take the ownership', () {
    // #region tuple-take-the-ownership
    final tuple = PyTuple(1);
    // dart format off
    final obj = PyTuple(1);  expect(obj.refCount, equals(1));
    tuple[0] = obj;          expect(obj.refCount, equals(1));
    tuple.dispose();         expect(obj.refCount, equals(0)); // tuple 释放 obj
    // dart format on
    // #endregion
  });

  test('tuple: take the ownership for primitive types', () {
    final tuple = PyTuple(1);
    // dart format off
    final obj = PyDouble(1); expect(obj.refCount, equals(1));
    tuple[0] = obj;          expect(obj.refCount, equals(1));
    tuple.dispose();         expect(obj.refCount, equals(0));
    // dart format on
  });

  test('guard out of range', () {
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

  test("list: append won't take the ownership", () {
    final owner = PyList(1);
    // dart format off
    final part = PyTuple(1); expect(part.refCount, equals(1));
    owner.append(part);      expect(part.refCount, equals(2));
    owner.dispose();         expect(part.refCount, equals(1));
    // dart format on
  });

  test("list: insert won't take the ownership", () {
    final owner = PyList(1);
    // dart format off
    final part = PyTuple(1); expect(part.refCount, equals(1));
    owner.insert(0, part);   expect(part.refCount, equals(2));
    owner.dispose();         expect(part.refCount, equals(1));
    // dart format on
  });

  test('list: take the ownership for primitive types', () {
    final owner = PyList(1);
    // dart format off
    final obj = PyDouble(1); expect(obj.refCount, equals(1));
    owner[0] = obj;          expect(obj.refCount, equals(1));
    owner.dispose();         expect(obj.refCount, equals(0));
    // dart format on
  });
}
