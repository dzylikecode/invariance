import 'package:test/test.dart';
import 'package:scope_guard/scope_guard.dart';

import 'scope_guard_test.dart' show Value;

final class Wrapper implements ScopedResourceDelegate {
  Wrapper(this.scopeResource);
  @override
  final ScopedResource scopeResource;
}

void main() {
  setUp(Scope.clearTrackedAllocations);
  tearDown(() => expect(Scope.checkNoLeaks(), isTrue));

  test('untrack returns wrapper while removing its reference', () {
    final events = <String>[];
    final Wrapper result = using((scope) {
      final ref = Value(1, events);
      final wrapper = Wrapper(ref);
      expect(scope.track(wrapper), same(wrapper));
      return scope.untrack(wrapper);
    });
    expect(events, isEmpty);
    expect(Scope.trackedAllocations, isEmpty);
    result.scopeResource.dispose();
    expect(events, ['release 1']);
  });

  test('shared wrappers do not duplicate or reorder cleanup', () {
    final events = <String>[];
    using((scope) {
      final ref = Value(1, events);
      Value(2, events);
      final a = Wrapper(ref);
      final b = Wrapper(ref);
      scope.track(a);
      scope.track(b);
      Scope.track(b);
      expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 2 : 0);
    });
    expect(events, ['release 2', 'release 1']);
  });

  test('explicit parent adoption manages the delegated resource', () {
    final events = <String>[];
    late Value ref;
    using((outer) {
      using((inner) {
        ref = Value(1, events);
        final wrapper = Wrapper(ref);
        expect(outer.track(inner.untrack(wrapper)), same(wrapper));
      });
      expect(ref.isDisposed, isFalse);
      expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
    });
    expect(events, ['release 1']);
  });

  test('wrapper cannot untrack or steal a reference owned elsewhere', () {
    using((outer) {
      final ref = Value(1, []);
      final wrapper = Wrapper(ref);
      using((inner) {
        expect(() => inner.untrack(wrapper), throwsArgumentError);
        expect(() => inner.track(wrapper), throwsStateError);
      });
    });
  });

  test('static untrack resolves wrappers outside any scope', () {
    final ref = Value(1, []);
    final wrapper = Wrapper(ref);
    Scope.untrack(wrapper);
    expect(Scope.trackedAllocations, isEmpty);
    Scope.track(wrapper);
    expect(Scope.trackedAllocations.length, Scope.trackAllocations ? 1 : 0);
    ref.dispose();
  });

  test('disposed references cannot be registered through delegates', () {
    final ref = Value(1, []);
    ref.dispose();
    using((scope) {
      expect(() => scope.track(Wrapper(ref)), throwsStateError);
      expect(() => Scope.track(Wrapper(ref)), throwsStateError);
    });
  });

  test('async delegation keeps reference alive across await', () async {
    late Value ref;
    final wrapper = await using((scope) async {
      ref = Value(1, []);
      await Future<void>.value();
      return scope.untrack(Wrapper(ref));
    });
    expect(wrapper.scopeResource, same(ref));
    expect(ref.isDisposed, isFalse);
    ref.dispose();
  });
}
