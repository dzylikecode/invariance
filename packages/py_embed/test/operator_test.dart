import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));
  group("PyObjectOperator", () {
    test(
      "arithmetic follows Python floor division and remainder semantics",
      () => ResourceScope.scope(() {
        // dart format off
      final a = PyInt(-7);
      final b = PyInt(3);
      final result0 = a + b;                     expect(result0.asInt(), equals(-4));
      result0.dispose();
      final result1 = a - b;                     expect(result1.asInt(), equals(-10));
      result1.dispose();
      final result2 = a * b;                     expect(result2.asInt(), equals(-21));
      result2.dispose();
      final result3 = a / b;                     expect(result3.asDouble(), closeTo(-7 / 3, 1e-12));
      result3.dispose();
      final result4 = a ~/ b;                    expect(result4.asInt(), equals(-3));
      result4.dispose();
      final result5 = a % b;                     expect(result5.asInt(), equals(2));
      result5.dispose();
      final result6 = -a;                        expect(result6.asInt(), equals(7));
      result6.dispose();
      final result7 = a.positive();              expect(result7.asInt(), equals(-7));
      result7.dispose();
      final result8 = abs(a);                    expect(result8.asInt(), equals(7));
      result8.dispose();
      final result = divmod(a, b);
      final tuple = PyTuple.fromRef(result.ref); expect(tuple[0].asInt(), equals(-3));
                                                   expect(tuple[1].asInt(), equals(2));
      result.dispose();
      a.dispose();
      b.dispose();
      // dart format on
      }),
    );

    test(
      "bitwise operators",
      () => ResourceScope.scope(() {
        // dart format off
      final a = PyInt(5);
      final b = PyInt(3);
      final result0 = a & b;                     expect(result0.asInt(), equals(1));
      result0.dispose();
      final result1 = a | b;                     expect(result1.asInt(), equals(7));
      result1.dispose();
      final result2 = a ^ b;                     expect(result2.asInt(), equals(6));
      result2.dispose();
      final result3 = a << b;                    expect(result3.asInt(), equals(40));
      result3.dispose();
      final result4 = a >> b;                    expect(result4.asInt(), equals(0));
      result4.dispose();
      final result5 = ~a;                        expect(result5.asInt(), equals(-6));
      result5.dispose();
      a.dispose();
      b.dispose();
      // dart format on
      }),
    );

    test(
      "power with and without a modulus",
      () => ResourceScope.scope(() {
        // dart format off
      final a = PyInt(5);
      final b = PyInt(3);
      final result0 = pow(a, b);                  expect(result0.asInt(), equals(125));
      result0.dispose();
      final result1 = a.inPlacePower(b);          expect(result1.asInt(), equals(125));
      result1.dispose();
      final modulus = PyInt(7);
      final result = pow(a, b, modulus);          expect(result.asInt(), equals(6));
      final inPlace = a.inPlacePower(b, modulus); expect(inPlace.asInt(), equals(6));
      result.dispose();
      inPlace.dispose();
      modulus.dispose();
      a.dispose();
      b.dispose();
      // dart format on
      }),
    );

    test(
      "comparison operators",
      () => ResourceScope.scope(() {
        // dart format off
      final a = PyInt(5);
      final b = PyInt(3);       expect(a > b, isTrue);
                                expect(a >= b, isTrue);
                                expect(a < b, isFalse);
                                expect(a <= b, isFalse);
                                expect(a.equals(b), isFalse);
                                expect(a.notEquals(b), isTrue);
      final result = a.richCompare(b, .greaterThan);
                                expect(result.asBool(), isTrue);
      result.dispose();
      a.dispose();
      b.dispose();
      // dart format on
      }),
    );

    /// 原地修改列表；返回相同对象，但新增一次需要释放的引用。
    test(
      "in-place addition mutates lists and returns an owned reference",
      () => ResourceScope.scope(() {
        // dart format off
      final a = PyList(0);            expect(a.ref.count, equals(1));
      final b = PyList(0);
      final value = PyInt(9);
      b.add(value);
      final result = a.inPlaceAdd(b); expect(result.ptr, equals(a.ptr));
                                      expect(a.ref.count, equals(2));
                                      expect(a.length, equals(1));
                                      expect(a[0].asInt(), equals(9));
      result.dispose();        expect(a.ref.count, equals(1));
                                      expect(a.length, equals(1));
      a.dispose();
      b.dispose();
      value.dispose();
      // dart format on
      }),
    );

    test(
      "custom matrix and comparison results preserve Python dispatch",
      () => ResourceScope.scope(() {
        runString('''
class OperatorProbe:
    def __matmul__(self, other): return 42
    def __imatmul__(self, other): return 43
    def __lt__(self, other): return [1, 2]
operator_probe = OperatorProbe()
''');
        // dart format off
      final module = PyModule('__main__');
      final a = module.getAttr('operator_probe');
      final result = a.matrixMultiply(a);        expect(result.asInt(), equals(42));
      final inPlace = a.inPlaceMatrixMultiply(a);expect(inPlace.asInt(), equals(43));
      final comparison = a.richCompare(a, .lessThan);
      final list = PyList.fromRef(comparison.ref);
                                                expect(list.length, equals(2));
                                                expect(a < a, isTrue);
      result.dispose();
      inPlace.dispose();
      comparison.dispose();
      a.dispose();
      module.dispose();
      // dart format on
      }),
    );

    test(
      "operator failures throw Python exceptions and clear the error",
      () => ResourceScope.scope(() {
        final a = PyInt(1);
        final zero = PyInt(0);
        final text = PyString('x');

        expect(
          () => a / zero,
          throwsA(
            isA<PyException>().having(
              (e) => e.type,
              'type',
              contains('ZeroDivisionError'),
            ),
          ),
        );
        expect(
          () => a + text,
          throwsA(
            isA<PyException>().having(
              (e) => e.type,
              'type',
              contains('TypeError'),
            ),
          ),
        );

        // dart format off
      final result = a + a;     expect(result.asInt(), equals(2)); // 异常已清除
      result.dispose();
      a.dispose();
      zero.dispose();
      text.dispose();
      // dart format on
      }),
    );
  });
}
