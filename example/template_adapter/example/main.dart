import 'package:template_adapter/template_adapter.dart';

void main() {
  final integers = Accumulator<int>();
  integers
    ..add(3)
    ..add(5);
  print('int: ${integers.value}');

  final doubles = Accumulator<double>();
  doubles
    ..add(1.25)
    ..add(2.5);
  print('double: ${doubles.value}');

  integers.dispose();
  doubles.dispose();
}
