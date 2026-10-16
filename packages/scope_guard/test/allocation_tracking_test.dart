import 'dart:async';

import 'package:test/test.dart';
import 'package:scope_guard/scope_guard.dart';

// Equal wrappers simulate independent references to the same native object.
final class Reference implements ScopedResource {
  Reference() {
    Scope.track(this);
  }

  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Scope.untrack(this);
  }

  @override
  bool operator ==(Object other) => other is Reference;
  @override
  int get hashCode => 1;
}

void main() {
  setUp(Scope.clearTrackedAllocations);
  tearDown(() {
    expect(Scope.checkNoLeaks(), isTrue);
  });

  test('trackAllocations=${Scope.trackAllocations} matches environment', () {
    expect(
      Scope.trackAllocations,
      const bool.fromEnvironment('TRACK_RESOURCE_ALLOCATIONS'),
    );
  });

  test('outside-scope allocations are tracked only when enabled', () {
    final resource = Reference();
    try {
      expect(
        Scope.trackedAllocations,
        Scope.trackAllocations ? [resource] : isEmpty,
      );
      if (Scope.trackAllocations) {
        expect(Scope.checkNoLeaks, throwsStateError);
      } else {
        expect(Scope.checkNoLeaks(), isTrue);
      }
    } finally {
      resource.dispose();
    }
  });

  test(
    'identity tracking keeps equal wrappers distinct and avoids duplicates',
    () {
      final first = Reference();
      final second = Reference();
      try {
        Scope.track(first);
        expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 2 : 0);
        first.dispose();
        expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
      } finally {
        first.dispose();
        second.dispose();
      }
    },
  );

  test('scope cleanup clears diagnostics', () {
    using((scope) {
      Reference();
      expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
    });
    expect(Scope.trackedAllocations, isEmpty);
  });

  test(
    'untrack removes diagnostics and explicit parent adoption restores them',
    () {
      final result = using((outer) {
        final resource = using((inner) => inner.untrack(Reference()));
        expect(Scope.trackedAllocations, isEmpty);
        expect(outer.track(resource), same(resource));
        expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
        return outer.untrack(resource);
      });
      expect(Scope.trackedAllocations, isEmpty);
      result.dispose();
    },
  );

  test('clear resets diagnostics without changing scope ownership', () {
    late Reference resource;
    using((scope) {
      resource = Reference();
      final snapshot = Scope.trackedAllocations;
      snapshot.clear();
      expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
      Scope.clearTrackedAllocations();
      expect(resource.isDisposed, isFalse);
    });
    expect(resource.isDisposed, isTrue);
  });

  test('rejected late allocation does not leave diagnostic entries', () {
    late Zone zone;
    using((scope) => zone = Zone.current);
    expect(() => zone.run(Reference.new), throwsStateError);
    expect(Scope.trackedAllocations, isEmpty);
  });
}
