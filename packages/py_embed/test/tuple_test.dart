import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  test('tuple: take the ownership', () {
    // #region tuple-take-the-ownership
    final tuple = PyTuple(1);
    final obj = PyTuple(1);
    expect(obj.refCount, equals(1));
    tuple.setItem(0, obj);
    expect(obj.refCount, equals(1));
    tuple.dispose();
    expect(obj.refCount, equals(0)); // tuple 会释放 obj
    // #endregion
  });

  test('tuple: take the ownership for primitive types', () {
    final tuple = PyTuple(1);
    final obj = PyDouble(1);
    expect(obj.refCount, equals(1));
    tuple.setItem(0, obj);
    expect(obj.refCount, equals(1));
    tuple.dispose();
    expect(obj.refCount, equals(0)); // tuple 会释放 obj
  });
}
