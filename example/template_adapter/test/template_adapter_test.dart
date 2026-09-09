import 'package:template_adapter/template_adapter.dart';
import 'package:test/test.dart';

void main() {
  test('instantiates and uses Accumulator<int>', () {
    final accumulator = Accumulator<int>();
    addTearDown(accumulator.dispose);

    accumulator
      ..add(3)
      ..add(5)
      ..add(-2);

    expect(accumulator.value, 6);
  });

  test('instantiates and uses Accumulator<double>', () {
    final accumulator = Accumulator<double>();
    addTearDown(accumulator.dispose);

    accumulator
      ..add(1.25)
      ..add(2.5);

    expect(accumulator.value, closeTo(3.75, 1e-12));
  });

  test('dispose is idempotent and prevents further access', () {
    final accumulator = Accumulator<int>();
    accumulator.dispose();
    accumulator.dispose();

    expect(accumulator.isDisposed, isTrue);
    expect(() => accumulator.add(1), throwsStateError);
    expect(() => accumulator.value, throwsStateError);
  });

  test('rejects Dart numeric types without a native template instance', () {
    expect(() => Accumulator<num>(), throwsUnsupportedError);
  });
}
