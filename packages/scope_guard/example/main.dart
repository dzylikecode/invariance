import 'package:scope_guard/scope_guard.dart';

// Simulates one owned native reference without requiring a Python runtime.
final class NativeValue implements ScopedResource {
  NativeValue(this.value) {
    Scope.track(this);
  }
  final int value;
  NativeValue operator +(NativeValue other) => NativeValue(value + other.value);
  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Scope.untrack(this);
    print('release $value');
  }
}

void main() {
  final result = using((scope) {
    final a = NativeValue(1);
    final b = NativeValue(2);
    scope.defer(() => print('hello world'));
    return scope.untrack(a + b);
  });
  print('result: ${result.value}');
  result.dispose();
}
