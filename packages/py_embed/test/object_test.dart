import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  group("PyInt", () {
    test(
      "shares the cached object and reference count for the same small integer",
      () {
        final a = PyInt(1);
        final count = a.ref.count;
        // dart format off
                                // 指针指向了同一处
        final b = PyInt(1);     expect(a.ptr, equals(b.ptr));
                                expect(b.ref.count, equals(count+1));
        a.ref.discrement();     expect(b.ref.count, equals(count));
        // dart format on
      },
    );
  });

  group("PyDouble", () {
    test("keeps independent reference counts for equal values", () {
      // dart format off
      final a = PyDouble(1);     expect(a.ref.count, equals(1));
      final count = a.ref.count;
      final b = PyDouble(1);     expect(b.ptr, isNot(equals(a.ptr)));
                                 expect(a.ref.count, equals(1));
                                 expect(b.ref.count, equals(1));
                                 expect(b.ref.count, isNot(equals(count+1)));
      a.ref.discrement();        expect(b.ref.count, equals(1));

      // dart format on
    });
  });

  group("PyString", () {
    test("shares the cached object and reference count", () {
      final a = PyString('a');
      final count = a.ref.count;
      // dart format off
        final b = PyString('a');  expect(b.ref.count, equals(count+1));
        a.ref.discrement();       expect(b.ref.count, equals(count));
        // dart format on
    });
  });

  group("PyObject", () {
    /// getAttr 对于方法：每次得到的是新的对象
    test("getAttr for methods: returns a new object on each lookup", () {
      final obj = PyString("hello");        expect(obj.hasAttr("upper"), isTrue);
      final upper1 = obj.getAttr("upper");  expect(upper1.ref.count, equals(1));
                                            // ## proof 1: 得到新的对象
      final upper2 = obj.getAttr("upper");  expect(upper2.ptr, isNot(equals(upper1.ptr)));
                                            expect(upper2.ref.count, equals(1));
      obj.ref.discrement();                 expect(upper1.ref.count, equals(1));
                                            // ## proof 2: 得到新的对象
      upper1.ref.discrement();              expect(upper1.ref.count, equals(0));
                                            expect(upper2.ref.count, equals(1));
      upper2.ref.discrement();              expect(upper2.ref.count, equals(0));
    });

    /// getAttr 对于属性：新的对象 ｜ 共享对象且 ref++
    test("getAttr for attributes: new object | shared object with ref++", () {
      final obj = PyDouble(1.5);
      final real = obj.getAttr("real");   expect(real.ptr, equals(obj.ptr)); // 同一个对象
                                          expect(real.ref.count, equals(2));
      final real2 = obj.getAttr("real");  expect(real2.ref.count, equals(3));
                                          expect(real.ptr, equals(real2.ptr));
      final imag = obj.getAttr("imag");   expect(imag.ref.count, equals(1));  // 每次都在构造新的
      final imag2 = obj.getAttr("imag");  expect(imag2.ref.count, equals(1));

      real.ref.discrement();
      real2.ref.discrement();
                                          // 说明 imag 返回的是一个新的对象
      imag.ref.discrement();              expect(imag.ref.count, equals(0));
                                          expect(imag2.ref.count, equals(1));
      imag2.ref.discrement();

      obj.ref.discrement();

      // 所以无论哪一种都是需要 ref--，对于 getDouble
    });

    /// getItem: ref++
    test("getItem: ref++", () {
      final owner = PyList(0);
      final a = PyDouble(1);      expect(a.ref.count, equals(1));
      owner.add(a);               expect(a.ref.count, equals(2));
                                  // 返回一个引用且 ref++
      final i = PyInt(0);
      final b = owner.getItem(i); expect(b.ptr, equals(a.ptr));
                                  expect(b.ref.count, equals(3));
      final c = owner[0];         expect(c.ptr, equals(a.ptr));
                                  expect(c.ref.count, equals(3));

      owner.ref.discrement();     expect(a.ref.count, equals(2));
      a.ref.discrement();         expect(a.ref.count, equals(1));
      b.ref.discrement();         expect(a.ref.count, equals(0));
      i.ref.discrement();
    });
  });

  group('PyTuple', () {
    test('fromList', () {
      final a = PyDouble(1);                  expect(a.ref.count, equals(1));
      final b = PyDouble(2);                  expect(b.ref.count, equals(1));
      final tuple = PyTuple.fromList([a, b]); expect(a.ref.count, equals(1));
                                              expect(b.ref.count, equals(1));
      tuple.ref.discrement();                 expect(a.ref.count, equals(0));
                                              expect(b.ref.count, equals(0));
    });

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
      part.ref.discrement();   expect(part.ref.count, equals(0));
      // dart format on
    });

    test('insert retains the item', () {
      final owner = PyList(1);
      // dart format off
      final part = PyTuple(1); expect(part.ref.count, equals(1));
      owner.insert(0, part);   expect(part.ref.count, equals(2));
      owner.ref.discrement();  expect(part.ref.count, equals(1));
      part.ref.discrement();   expect(part.ref.count, equals(0));
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

  group("PyDict", () {
    test("starts with zero length and is empty", () {
      final owner = PyDict();
      expect(owner.length, equals(0));
      expect(owner.isEmpty, isTrue);
    });

    test("setItem retains both the key and value", () {
      final owner = PyDict();
      // dart format off
      final key = PyDouble(1);    expect(key.ref.count, equals(1));
      final value = PyDouble(11); expect(value.ref.count, equals(1));
      owner[key] = value;         expect(key.ref.count, equals(2));
                                  expect(value.ref.count, equals(2));
      owner.ref.discrement();     expect(key.ref.count, equals(1));
                                  expect(value.ref.count, equals(1));
      key.ref.discrement();       expect(key.ref.count, equals(0));
      value.ref.discrement();     expect(value.ref.count, equals(0));
      // dart format on
    });

    test(
      "lookup returns a borrowed value without increasing its reference count",
      () {
      final owner = PyDict();
      // dart format off
      final key = PyDouble(1);    expect(key.ref.count, equals(1));
      final value = PyDouble(11); expect(value.ref.count, equals(1));
      owner[key] = value;         expect(key.ref.count, equals(2));
                                  expect(value.ref.count, equals(2));
      final v = owner[key];       expect(v, isNotNull);
                                  expect(v!.asDouble(), closeTo(11, 0.1));
                                  expect(v.ptr, equals(value.ptr));
                                  expect(v.ref.count, equals(2));
                                  expect(key.ref.count, equals(2));
      owner.ref.discrement();     expect(key.ref.count, equals(1));
                                  expect(value.ref.count, equals(1));
      key.ref.discrement();       expect(key.ref.count, equals(0));
      value.ref.discrement();     expect(value.ref.count, equals(0));
      // dart format on
      },
    );

    test("remove releases both the key and value references", () {
      final owner = PyDict();
      // dart format off
      final key = PyDouble(1);    expect(key.ref.count, equals(1));
      final value = PyDouble(11); expect(value.ref.count, equals(1));
      owner[key] = value;         expect(key.ref.count, equals(2));
                                  expect(value.ref.count, equals(2));
      owner.remove(key);          expect(key.ref.count, equals(1));
                                  expect(value.ref.count, equals(1));
                                  expect(owner.isEmpty, isTrue);
                                  expect(owner[key], isNull);
      owner.ref.discrement();     expect(key.ref.count, equals(1));
                                  expect(value.ref.count, equals(1));
      key.ref.discrement();
      value.ref.discrement();
      // dart format on
    });

    test("clear releases all key and value references", () {
      final owner = PyDict();
      // dart format off
      final key1 = PyDouble(1);    expect(key1.ref.count, equals(1));
      final value1 = PyDouble(11); expect(value1.ref.count, equals(1));
      final key2 = PyDouble(2);    expect(key2.ref.count, equals(1));
      final value2 = PyDouble(22); expect(value2.ref.count, equals(1));
      owner[key1] = value1;        expect(key1.ref.count, equals(2));
                                   expect(value1.ref.count, equals(2));
      owner[key2] = value2;        expect(key2.ref.count, equals(2));
                                   expect(value2.ref.count, equals(2));
      owner.clear();               expect(key1.ref.count, equals(1));
                                   expect(value1.ref.count, equals(1));
                                   expect(key2.ref.count, equals(1));
                                   expect(value2.ref.count, equals(1));
                                   expect(owner.isEmpty, isTrue);
                                   expect(owner[key1], isNull);
                                   expect(owner[key2], isNull);
      owner.ref.discrement();      expect(key1.ref.count, equals(1));
                                   expect(value1.ref.count, equals(1));
                                   expect(key2.ref.count, equals(1));
                                   expect(value2.ref.count, equals(1));
      key1.ref.discrement();
      value1.ref.discrement();
      key2.ref.discrement();
      value2.ref.discrement();
      // dart format on
    });

    test("keys and values snapshots retain entries after dict release", () {
      final owner = PyDict();
      // dart format off
      final key = PyDouble(1);    expect(key.ref.count, equals(1));
      final value = PyDouble(11); expect(value.ref.count, equals(1));
      owner[key] = value;         expect(key.ref.count, equals(2));
                                  expect(value.ref.count, equals(2));
      final keys = owner.keys;    expect(keys.ref.count, equals(1));
      final values = owner.values;expect(values.ref.count, equals(1));
      // 释放不会影响 keys
      owner.ref.discrement();     expect(keys.ref.count, equals(1));
                                  expect(values.ref.count, equals(1));
      keys.ref.discrement();
      values.ref.discrement();
                                  expect(key.ref.count, equals(1));
                                  expect(value.ref.count, equals(1));
      key.ref.discrement();       expect(key.ref.count, equals(0));
      value.ref.discrement();     expect(value.ref.count, equals(0));
      // dart format on
    });

    test('returns null for a missing key', () {
      final tuple = PyDict();
      final key = PyDouble(1);
      expect(tuple[key], isNull);
    });

    test(
      "getStringKey looks up a PyString key without retaining the key or value",
      () {
      final owner = PyDict();
      // dart format off
      final key = PyString("a");
      final keyCount = key.ref.count;
      final value = PyDouble(11);         expect(value.ref.count, equals(1));
      owner[key] = value;                 expect(key.ref.count, equals(keyCount + 1));
                                          expect(value.ref.count, equals(2));
      final v = owner.elementAtStr('a');  expect(v, isNotNull);
                                          expect(v!.asDouble(), closeTo(11, 0.1));
                                          expect(key.ref.count, equals(keyCount + 1));
                                          expect(value.ref.count, equals(2));
                                          expect(v.ref.count, equals(2));
      owner.ref.discrement();             expect(key.ref.count, equals(keyCount));
                                          expect(value.ref.count, equals(1));
      key.ref.discrement();
      value.ref.discrement();
      // dart format on
      },
    );

    test("setStringKey retains the value and getStringKey borrows it", () {
      final owner = PyDict();
      // dart format off
      final value = PyDouble(11);         expect(value.ref.count, equals(1));
      owner.setElementAtStr("a", value);  expect(value.ref.count, equals(2));
      final v = owner.elementAtStr('a');  expect(v, isNotNull);
                                          expect(v!.asDouble(), closeTo(11, 0.1));
                                          expect(value.ref.count, equals(2));
                                          expect(v.ref.count, equals(2));
      owner.ref.discrement();             expect(value.ref.count, equals(1));
      value.ref.discrement();
      // dart format on
    });
  });
}
