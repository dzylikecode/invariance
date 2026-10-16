import 'package:test/test.dart';
import 'package:py_embed/py_embed.dart';
import 'package:py_embed/debug.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));

  test("PyRef and PyObject compare by Python pointer", () {
    ResourceScope.scope(() {
      // dart format off
      final aRef = PyRef.fromHandle(.fromAddress(1));
      final bRef = PyRef.fromHandle(.fromAddress(1)); expect(aRef, bRef);
                                                      expect(aRef, isNot(same(bRef)));

      final aObj = PyObject(aRef);
      final bObj = PyObject(bRef);                    expect(aObj, bObj);
                                                      expect(aObj, isNot(same(bObj)));
      // dart format on
    });
  });

  test('equal Python pointers still own independent references', () {
    ResourceScope.scope(() {
      // dart format off
      final a = PyInt(1000000);
      final b = a.retain();                               expect(a, b);
                                                          expect(a.ref.count, 2);
      a.dispose();                                        expect(b.asInt(), 1000000);
                                                          expect(b.ref.count, 1);
      // dart format on
    });
  });

  test('equal doubles are independent Python objects', () {
    ResourceScope.scope(() {
      // dart format off
      final a = PyDouble(1.5);
      final b = PyDouble(1.5);                            expect(a, isNot(b));
                                                          expect(a.ref.count, 1);
                                                          expect(b.ref.count, 1);
      // dart format on
    });
  });

  test('attribute lookups own new references, including shared attributes', () {
    ResourceScope.scope(() {
      // dart format off
      final obj = PyDouble(1.5);
      final real = obj.getAttr('real');
      final real2 = obj.getAttr('real');                  expect(real, obj);
                                                          expect(real2.ref.count, 3);
      real.dispose();
      real2.dispose();                                    expect(obj.ref.count, 1);
      final text = PyString('hello');                     expect(text.hasAttr('upper'), isTrue);
      final first = text.getAttr('upper');
      final second = text.getAttr('upper');               expect(first, isNot(second));
                                                          expect(first.ref.count, 1);
                                                          expect(second.ref.count, 1);
      // dart format on
    });
  });

  test('typed aliases share the same lifetime without duplicate ownership', () {
    ResourceScope.scope(() {
      // dart format off
      final raw = PyConverter().toPyObject([1, 2]);
      final list = PyList.fromRef(raw.ref);               expect(list.length, 2);
                                                          expect(raw.ref.count, 1);
      list.dispose();                                     expect(raw.isDisposed, isTrue);
      // dart format on
    });
  });

  group('PyTuple', () {
    test('fromList retains inputs and survives disposal of their wrappers', () {
      ResourceScope.scope(() {
        // dart format off
        final a = PyDouble(1.5);
        final b = PyDouble(2.5);
        final tuple = PyTuple.fromList([a, b]);           expect(a.ref.count, 2);
                                                          expect(b.ref.count, 2);
        a.dispose();
        b.dispose();                                      expect(tuple[0].asDouble(), 1.5);
                                                          expect(tuple[1].asDouble(), 2.5);
        // dart format on
      });
    });

    test('insertion retains the caller reference', () {
      // #region tuple-take-the-ownership
      ResourceScope.scope(() {
        // dart format off
        final tuple = PyTuple(1);
        final value = PyDouble(3.5);
        tuple[0] = value;                                 expect(value.ref.count, 2);
        tuple.dispose();                                  expect(value.ref.count, 1);
                                                          expect(value.asDouble(), 3.5);
        // dart format on
      });
      // #endregion
    });

    test('failed setter releases only its temporary retained reference', () {
      ResourceScope.scope(() {
        // dart format off
        final tuple = PyTuple(1);
        final value = PyDouble(4.5);                      expect(() => tuple[2] = value, throwsA(isA<PyException>()));
                                                          expect(value.ref.count, 1);
                                                          expect(() => tuple[2], throwsA(isA<PyException>()));
        // dart format on
      });
    });

    test('lookup stays alive after container release', () {
      ResourceScope.scope(() {
        // dart format off
        final tuple = PyTuple.fromList([PyDouble(5.5)]);
        final value = tuple[0];
        tuple.dispose();                                  expect(value.asDouble(), 5.5);
        // dart format on
      });
    });
  });

  group('PyList', () {
    test('append, insert and set retain the caller reference', () {
      ResourceScope.scope(() {
        // dart format off
        final list = PyList(0);
        final value = PyDouble(6.5);
        list.add(value);
        list.insert(0, value);
        list[1] = value;                                  expect(value.ref.count, 3);
        list.dispose();                                   expect(value.ref.count, 1);
        // dart format on
      });
    });

    test('failed setter leaves caller ownership intact', () {
      ResourceScope.scope(() {
        // dart format off
        final list = PyList(0);
        final value = PyDouble(7.5);                      expect(() => list[0] = value, throwsA(isA<PyException>()));
                                                          expect(value.ref.count, 1);
                                                          expect(() => list[0], throwsA(isA<PyException>()));
        // dart format on
      });
    });

    test('lookup and getItem own independent references', () {
      ResourceScope.scope(() {
        // dart format off
        final list = PyList(0);
        final value = PyDouble(8.5);
        list.add(value);
        final first = list[0];
        final second = list.getItem(PyInt(0));            expect(value.ref.count, 4);
        list.dispose();
        value.dispose();                                  expect(first.asDouble(), 8.5);
        second.dispose();                                 expect(first.ref.count, 1);
        // dart format on
      });
    });

    test('sort and reverse mutate the list', () {
      ResourceScope.scope(() {
        // dart format off
        final list = PyList.fromRef(PyConverter().toPyObject([3, 1, 2]).ref);
        list.sort();                                      expect(list.toString(), '[1, 2, 3]');
        list.reverse();                                   expect(list.toString(), '[3, 2, 1]');
        // dart format on
      });
    });
  });

  group('PyDict', () {
    test('insert retains key and value; lookup owns a new reference', () {
      ResourceScope.scope(() {
        // dart format off
        final dict = PyDict();                            expect(dict.isEmpty, isTrue);
        final key = PyDouble(1.5);
        final value = PyDouble(9.5);
        dict[key] = value;                                expect(key.ref.count, 2);
                                                          expect(value.ref.count, 2);
        final lookup = dict[key]!;                        expect(value.ref.count, 3);
                                                          expect(dict.contains(key), isTrue);
        dict.remove(key);                                 expect(key.ref.count, 1);
                                                          expect(value.ref.count, 2);
                                                          expect(dict[key], isNull);
        value.dispose();                                  expect(lookup.asDouble(), 9.5);
        // dart format on
      });
    });

    test('string lookup owns a reference and survives clear', () {
      ResourceScope.scope(() {
        // dart format off
        final dict = PyDict();
        final value = PyDouble(10.5);
        dict.setElementAtStr('a', value);
        final lookup = dict.elementAtStr('a')!;           expect(value.ref.count, 3);
        dict.clear();                                     expect(dict.elementAtStr('a'), isNull);
                                                          expect(value.ref.count, 2);
        value.dispose();                                  expect(lookup.asDouble(), 10.5);
        // dart format on
      });
    });

    test('snapshots and copy survive original dictionary disposal', () {
      ResourceScope.scope(() {
        // dart format off
        final dict = PyDict();
        dict.setElementAtStr('a', PyDouble(11.5));
        final keys = dict.keys;
        final values = dict.values;
        final items = dict.items;
        final copy = dict.copy();
        dict.dispose();                                   expect(keys[0].asString(), 'a');
                                                          expect(values[0].asDouble(), 11.5);
                                                          expect(PyTuple.fromRef(items[0].ref)[1].asDouble(), 11.5);
                                                          expect(copy.elementAtStr('a')!.asDouble(), 11.5);
        // dart format on
      });
    });

    test('update, merge and string removal preserve ownership', () {
      ResourceScope.scope(() {
        // dart format off
        final a = PyDict();
        final b = PyDict();
        a.setElementAtStr('x', PyDouble(1.5));
        b.setElementAtStr('x', PyDouble(2.5));
        b.setElementAtStr('y', PyDouble(3.5));
        a.merge(b, override: false);                      expect(a.elementAtStr('x')!.asDouble(), 1.5);
        a.update(b);                                      expect(a.elementAtStr('x')!.asDouble(), 2.5);
        a.removeStr('y');                                 expect(a.elementAtStr('y'), isNull);
                                                          expect(() => a.removeStr('y'), throwsA(isA<PyException>()));
        // dart format on
      });
    });
  });
}
