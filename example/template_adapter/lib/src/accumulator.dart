import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'binding/template_adapter.g.dart' as native;

/// A type-safe Dart facade over a type-erased C ABI.
///
/// The example supports exactly [int] (native `int32_t`) and [double].
final class Accumulator<T extends num>._fromHandle(
  var int _handle,
  final _ValueBinding<T> _binding,
) {
  this {
    if (_handle == 0) {
      throw StateError('The native accumulator could not be created.');
    }
    _finalizer.attach(this, _handle, detach: this);
  }

  factory() {
    final binding = _bindingFor<T>();
    return ._fromHandle(native.accumulator_create(binding.type), binding);
  }

  static final _finalizer = Finalizer(native.accumulator_dispose);

  bool get isDisposed => _handle == 0;

  void add(T value) {
    final handle = _checkedHandle;
    using((arena) {
      final pointer = _binding.allocate(arena, value);
      if (!native.accumulator_add(handle, pointer.cast())) {
        throw StateError('The native add operation failed.');
      }
    });
  }

  T get value {
    final handle = _checkedHandle;
    return using((arena) {
      final pointer = _binding.allocate(arena, _binding.zero);
      if (!native.accumulator_get(handle, pointer.cast())) {
        throw StateError('The native get operation failed.');
      }
      return _binding.read(pointer);
    });
  }

  void dispose() {
    if (_handle == 0) return;
    final handle = _handle;
    _handle = 0;
    _finalizer.detach(this);
    native.accumulator_dispose(handle);
  }

  int get _checkedHandle {
    if (_handle == 0) {
      throw StateError('Accumulator<$T> has been disposed.');
    }
    return _handle;
  }
}

abstract interface class _ValueBinding<T extends num> {
  int get type;
  T get zero;
  Pointer<Void> allocate(Allocator allocator, T value);
  T read(Pointer<Void> pointer);
}

final class const _IntBinding() implements _ValueBinding<int> {
  @override
  int get type => native.ValueType.INT32.value;

  @override
  int get zero => 0;

  @override
  Pointer<Void> allocate(Allocator allocator, int value) {
    return (allocator<Int32>()..value = value).cast();
  }

  @override
  int read(Pointer<Void> pointer) => pointer.cast<Int32>().value;
}

final class const _DoubleBinding() implements _ValueBinding<double> {
  @override
  int get type => native.ValueType.DOUBLE.value;

  @override
  double get zero => 0;

  @override
  Pointer<Void> allocate(Allocator allocator, double value) {
    return (allocator<Double>()..value = value).cast();
  }

  @override
  double read(Pointer<Void> pointer) => pointer.cast<Double>().value;
}

_ValueBinding<T> _bindingFor<T extends num>() => switch (T) {
  == int => const _IntBinding(),
  == double => const _DoubleBinding(),
  _ => throw UnsupportedError('Unsupported accumulator type: $T.'),
} as _ValueBinding<T>;
