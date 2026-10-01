import 'package:test/test.dart';
import 'package:py_embed/src/binding/api.dart';
import 'package:py_embed/debug.dart';
import 'package:py_embed/src/runtime.dart';

void main() {
  test(
    'getRefCount',
    () => checked(() {
    // dart format off
    // 空 tuple 是通用的，不要用它作为测试
    final a = api.PyTuple_New(1); expect(getRefCount(a), equals(1));
    api.Py_IncRef(a);             expect(getRefCount(a), equals(2));
    api.Py_DecRef(a);             expect(getRefCount(a), equals(1));
    api.Py_DecRef(a);             expect(getRefCount(a), equals(0));
    // dart format on
    }),
  );
}
