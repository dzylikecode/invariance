import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  group("PyInt", () {
    test("shares the cached object and reference count for the same small integer", () {
      final a = PyInt(1);
      final count = a.ref.count;
      // dart format off
      final b = PyInt(1);     expect(b.ref.count, equals(count+1));
      a.ref.discrement();     expect(b.ref.count, equals(count));
      // dart format on
    });
  });

  group("PyDouble", () {
    test("keeps independent reference counts for equal values", () {
      // dart format off
      final a = PyDouble(1);     expect(a.ref.count, equals(1));
      final count = a.ref.count;
      final b = PyDouble(1);     expect(a.ref.count, equals(1));
                                 expect(b.ref.count, equals(1));
                                 expect(b.ref.count, isNot(equals(count+1)));
      a.ref.discrement();        expect(b.ref.count, equals(1));

      // dart format on
    });
  });

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
  });
}
