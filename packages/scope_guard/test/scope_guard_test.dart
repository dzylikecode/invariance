import 'dart:async';

import 'package:test/test.dart';
import 'package:scope_guard/scope_guard.dart';

class Value implements ScopedResource {
  Value(this.value, this.events) {
    Scope.track(this);
  }
  final int value;
  final List<String> events;
  Value operator +(Value other) => Value(value + other.value, events);
  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Scope.untrack(this);
    events.add('release $value');
  }
}

void main() {
  test('untracked inner result is not implicitly adopted by parent', () {
    final events = <String>[];
    late Value result;
    using((outer) {
      result = using((inner) => inner.untrack(Value(1, events)));
    });
    expect(result.isDisposed, isFalse);
    expect(events, isEmpty);
    result.dispose();
  });

  test('explicit transfer preserves identity and parent cleanup order', () {
    final events = <String>[];
    late Value result;
    using((outer) {
      Value(1, events);
      using((inner) {
        final value = Value(2, events);
        result = outer.track(inner.untrack(value));
        expect(result, same(value));
      });
      expect(result.isDisposed, isFalse);
      expect(events, isEmpty);
    });
    expect(events, ['release 2', 'release 1']);
  });

  test('a closed scope cannot adopt and does not dispose its argument', () {
    late ScopeInstance closed;
    using((scope) => closed = scope);
    final value = Value(1, []);
    expect(() => closed.track(value), throwsStateError);
    expect(value.isDisposed, isFalse);
    value.dispose();
  });

  test('untrack returns same resource and survives all enclosing scopes', () {
    final events = <String>[];
    final value = using((outer) {
      return using((inner) {
        final value = Value(1, events);
        expect(inner.untrack(value), same(value));
        expect(inner.untrack(value), same(value));
        expect(inner.untrack(value), same(value));
        return value;
      });
    });
    expect(value.isDisposed, isFalse);
    expect(events, isEmpty);
    value.dispose();
    expect(events, ['release 1']);
  });

  test('captured outer scope can explicitly untrack its own resource', () {
    late Value value;
    using((outer) {
      value = Value(1, []);
      using((inner) => outer.untrack(value));
    });
    expect(value.isDisposed, isFalse);
    value.dispose();
  });

  test('untracked results may be tracked again', () {
    final value = using((scope) => scope.untrack(Value(1, [])));
    using((scope) => scope.track(value));
    expect(value.isDisposed, isTrue);
  });

  test('untrack cancels cleanup without disposing', () {
    late Value value;
    final events = <String>[];
    using((scope) {
      value = Value(1, events);
      expect(scope.untrack(value), same(value));
      expect(scope.untrack(value), same(value));
    });
    expect(value.isDisposed, isFalse);
    expect(events, isEmpty);
    value.dispose();
    expect(events, ['release 1']);
  });

  test('retracking is idempotent and preserves cleanup order', () {
    final events = <String>[];
    using((scope) {
      final first = Value(1, events);
      Value(2, events);
      scope.track(first);
    });
    expect(events, ['release 2', 'release 1']);
  });

  test('untracked resource can be adopted by another scope', () {
    late Value value;
    using((outer) {
      value = Value(1, []);
      outer.untrack(value);
      using((inner) => inner.track(value));
      expect(value.isDisposed, isTrue);
    });
  });

  test('instance untrack cannot remove another scopes ownership', () {
    late Value value;
    using((outer) {
      value = Value(1, []);
      using((inner) {
        expect(() => inner.untrack(value), throwsArgumentError);
      });
    });
    expect(value.isDisposed, isTrue);
    value.dispose();
  });

  test('tracking cannot steal another scopes resource', () {
    using((outer) {
      final value = Value(1, []);
      using((inner) {
        expect(() => inner.track(value), throwsStateError);
      });
      expect(value.isDisposed, isFalse);
    });
  });

  test('tracking disposed resources fails', () {
    final value = Value(1, []);
    value.dispose();
    using((scope) {
      expect(() => scope.track(value), throwsStateError);
    });
  });

  test('late allocation in a captured zone releases and rejects it', () {
    late Zone zone;
    final events = <String>[];
    using((scope) => zone = Zone.current);
    expect(() => zone.run(() => Value(7, events)), throwsStateError);
    expect(events, ['release 7']);
  });

  test('cleanup cannot allocate into the closing scope', () {
    final events = <String>[];
    expect(
      () => using<void>((scope) {
        Value(1, events);
        scope.defer(() => Value(2, events));
      }),
      throwsStateError,
    );
    expect(events, ['release 2', 'release 1']);
  });

  test('cleanup runs inside the owning zone', () {
    late Zone bodyZone;
    using((scope) {
      bodyZone = Zone.current;
      scope.defer(() => expect(Zone.current, same(bodyZone)));
    });
  });

  test('cleanup failure takes precedence over body failure', () {
    final body = StateError('body');
    final cleanup = StateError('cleanup');
    expect(
      () => using<void>((scope) {
        scope.defer(() => throw cleanup);
        throw body;
      }),
      throwsA(same(cleanup)),
    );
  });

  test('automatic tracking, defer and untrack', () {
    final events = <String>[];
    final result = using((scope) {
      final a = Value(1, events);
      final b = Value(2, events);
      scope.defer(() => events.add('defer'));
      return scope.untrack(a + b);
    });
    expect(result.value, 3);
    expect(result.isDisposed, isFalse);
    expect(events, ['defer', 'release 2', 'release 1']);
    result.dispose();
    expect(events.last, 'release 3');
  });

  test('parent explicitly adopts inner result', () {
    late Value result;
    using((outer) {
      result = outer.track(using((inner) => inner.untrack(Value(10, []))));
      expect(result.isDisposed, isFalse);
    });
    expect(result.isDisposed, isTrue);
  });

  test('return alone does not escape', () {
    final value = using((scope) => Value(1, []));
    expect(value.isDisposed, isTrue);
  });

  test('early dispose releases exactly once', () {
    final events = <String>[];
    using((scope) {
      final value = Value(1, events);
      value.dispose();
      value.dispose();
    });
    expect(events, ['release 1']);
  });

  test('body failure still cleans resources', () {
    final events = <String>[];
    final failure = StateError('body');
    expect(
      () => using<void>((scope) {
        Value(1, events);
        throw failure;
      }),
      throwsA(same(failure)),
    );
    expect(events, ['release 1']);
  });

  test('failed cleanup does not skip remaining cleanup', () {
    final events = <String>[];
    final failure = StateError('cleanup');
    expect(
      () => using<void>((scope) {
        Value(1, events);
        scope.defer(() => throw failure);
        Value(2, events);
      }),
      throwsA(same(failure)),
    );
    expect(events, ['release 2', 'release 1']);
  });

  test('references to same native handle release independently', () {
    final events = <String>[];
    using((scope) {
      Value(1, events);
      Value(1, events);
    });
    expect(events, ['release 1', 'release 1']);
  });

  test('untrack rejects outer ownership', () {
    using((outer) {
      final value = Value(1, []);
      using((inner) {
        expect(() => inner.untrack(value), throwsArgumentError);
      });
      expect(value.isDisposed, isFalse);
    });
  });

  test('closed scope rejects defer and untrack', () {
    late ScopeInstance closed;
    final value = using((scope) {
      closed = scope;
      return scope.untrack(Value(1, []));
    });
    expect(() => closed.defer(() {}), throwsStateError);
    expect(() => closed.untrack(value), throwsStateError);
    value.dispose();
  });

  test('outside using resources remain manually owned', () {
    final value = Value(1, []);
    using((scope) {});
    expect(value.isDisposed, isFalse);
    value.dispose();
  });
}
