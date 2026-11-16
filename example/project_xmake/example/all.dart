// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:ffi';

import 'package:project_xmake/project_xmake.dart';

void main() {
  final sum = add(3, 5);
  final difference = subtract(9, 4);
  if (sum != 8 || difference != 5) {
    throw StateError('Unexpected native results: $sum, $difference');
  }
  print('Both native functions passed: $sum, $difference');
}
