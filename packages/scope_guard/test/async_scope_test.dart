import 'dart:async';

import 'package:test/test.dart';
import 'package:scope_guard/scope_guard.dart';

import 'scope_guard_test.dart' show Value;

void main() {
  test('synchronous results retain their concrete type', () {
    final int result = using((scope) => 42);
    expect(result, 42);
  });

  test('scope stays alive until the returned future completes', () async {
    final gate = Completer<void>();
    final events = <String>[];
    late Value before;
    final Future<int> result = using((scope) async {
      before = Value(1, events);
      await gate.future;
      expect(before.isDisposed, isFalse);
      expect(Scope.current, same(scope));
      Value(2, events);
      scope.defer(() => events.add('defer'));
      return 42;
    });
    expect(before.isDisposed, isFalse);
    expect(events, isEmpty);
    gate.complete();
    expect(await result, 42);
    expect(events, ['defer', 'release 2', 'release 1']);
  });

  test('future failure releases resources before reaching caller', () async {
    final events = <String>[];
    final failure = StateError('body');
    await expectLater(
      using<Future<void>>((scope) async {
        Value(1, events);
        await Future<void>.value();
        Value(2, events);
        throw failure;
      }),
      throwsA(same(failure)),
    );
    expect(events, ['release 2', 'release 1']);
  });

  test(
    'cleanup failure overrides async body failure and completes cleanup',
    () async {
      final events = <String>[];
      final cleanup = StateError('cleanup');
      await expectLater(
        using((scope) async {
          Value(1, events);
          scope.defer(() => throw cleanup);
          await Future<void>.value();
          throw StateError('body');
        }),
        throwsA(same(cleanup)),
      );
      expect(events, ['release 1']);
    },
  );

  test('nested async scopes explicitly transfer ownership', () async {
    final events = <String>[];
    late Value result;
    await using((outer) async {
      result = await using((inner) async {
        await Future<void>.value();
        return outer.track(inner.untrack(Value(1, events)));
      });
      expect(Scope.current, same(outer));
      expect(result.isDisposed, isFalse);
    });
    expect(result.isDisposed, isTrue);
    expect(events, ['release 1']);
  });

  test('parallel scopes clean independently', () async {
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    late Value first;
    late Value second;
    final firstDone = using((scope) async {
      first = Value(1, []);
      await firstGate.future;
      expect(Scope.current, same(scope));
    });
    final secondDone = using((scope) async {
      second = Value(2, []);
      await secondGate.future;
      expect(Scope.current, same(scope));
    });
    firstGate.complete();
    await firstDone;
    expect(first.isDisposed, isTrue);
    expect(second.isDisposed, isFalse);
    secondGate.complete();
    await secondDone;
    expect(second.isDisposed, isTrue);
  });

  test('async result can leave the scope with untrack', () async {
    final result = await using((scope) async {
      await Future<void>.value();
      return scope.untrack(Value(1, []));
    });
    expect(result.isDisposed, isFalse);
    result.dispose();
  });

  test('future returned through FutureOr is awaited', () async {
    final events = <String>[];
    final FutureOr<int> result = using<FutureOr<int>>((scope) {
      Value(1, events);
      return Future.value(42);
    });
    expect(events, isEmpty);
    expect(await result, 42);
    expect(events, ['release 1']);
  });
}
