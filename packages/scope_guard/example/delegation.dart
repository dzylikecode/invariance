import 'package:scope_guard/scope_guard.dart';

import 'main.dart' show NativeValue;

// NativeValue stands in for a PyRef that owns and tracks one reference.
final class NativeObject implements ScopedResourceDelegate {
  NativeObject(this.ref);
  final NativeValue ref;

  @override
  NativeValue get scopeResource => ref;
}

void main() {
  final NativeObject result = using((scope) {
    final object = NativeObject(NativeValue(42));
    return scope.untrack(object);
  });
  print('result: ${result.ref.value}');
  result.ref.dispose();

  using((outer) {
    using((inner) {
      final object = NativeObject(NativeValue(7));
      outer.track(inner.untrack(object));
    });
    print('outer still owns 7');
  });
}
