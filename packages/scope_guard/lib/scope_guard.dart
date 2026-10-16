import 'dart:async';
import 'dart:collection';

final _key = Object();
final _owners = Expando<ScopeInstance>();

/// Executes [action] within an automatic resource management scope.
///
/// Any [ScopedResource] registered through [Scope.track] or [ScopeInstance.track]
/// is disposed when [action] finishes or throws. Resources and callbacks
/// registered through [ScopeInstance.defer] are cleaned up in reverse order.
/// Cleanup continues after failures and throws the first cleanup error, which
/// takes precedence over an error from [action].
///
/// Supports synchronous callbacks and asynchronous [Future]-returning callbacks.
/// A returned [Future] keeps the scope open until completion. Asynchronous work
/// must be awaited or returned to keep its resources alive. Resource disposal
/// and deferred callbacks remain synchronous.
///
/// Uses [ScopeInstance.untrack] to let a result survive scope exit, without
/// implicitly transferring it to an outer scope:
///
/// ```dart
/// final result = using((scope) {
///   final resource = createResource();
///   scope.defer(() => print('Leaving scope'));
///   return scope.untrack(resource);
/// });
/// ```
///
/// The inferred return type preserves synchronous values and ordinary Futures.
/// An explicit asynchronous type argument must be `Future<T>` or `FutureOr<T>`.
/// Custom [Future] subtypes must accept the result of [Future.whenComplete].
R using<R>(R Function(ScopeInstance scope) action) {
  final scope = ScopeInstance._();
  return runZoned(() {
    R result;
    try {
      result = action(scope);
    } catch (_) {
      scope._release();
      rethrow;
    }
    if (result is Future) {
      return result.whenComplete(scope._release) as R;
    }
    scope._release();
    return result;
  }, zoneValues: {_key: scope});
}

/// A resource or delegate accepted by [Scope] and [ScopeInstance].
///
/// Implements [ScopedResource] for an owned resource, or
/// [ScopedResourceDelegate] for a wrapper whose lifetime belongs to a resource.
sealed class ScopeTarget {}

/// An interface for wrappers that delegate lifetime management to a resource.
///
/// Scope operations use [scopeResource] for registration and disposal while
/// returning the original wrapper from [ScopeInstance.track] and
/// [ScopeInstance.untrack]. Delegation is resolved once, without following
/// further delegation on the returned resource.
abstract interface class ScopedResourceDelegate implements ScopeTarget {
  /// The resource that owns this wrapper's lifetime.
  ///
  /// Must return the same resource throughout registration and cleanup.
  /// Multiple wrappers may share a resource without duplicating its registration.
  ScopedResource get scopeResource;
}

ScopedResource _resolve(ScopeTarget target) => target is ScopedResourceDelegate
    ? target.scopeResource
    : target as ScopedResource;

/// An interface for resources that can be disposed and tracked by [Scope].
///
/// Each instance represents one owned resource or reference, independently of
/// its native pointer. Constructors should call [Scope.track] after successful
/// initialization, and [dispose] implementations should call [Scope.untrack].
abstract interface class ScopedResource implements ScopeTarget {
  /// Whether this resource has already been disposed.
  bool get isDisposed;

  /// Releases this resource and removes its registration through [Scope.untrack].
  ///
  /// Repeated calls must not release the resource more than once.
  void dispose();
}

/// Automatic Zone-based registration and diagnostics for [ScopedResource]s.
///
/// Uses [using] to create a [ScopeInstance] in [Zone.current]. Resource
/// constructors register through [track], and disposal removes registrations
/// through [untrack]. Scope instances provide explicit ownership transfer.
abstract final class Scope {
  /// Whether allocation tracking is enabled by `TRACK_RESOURCE_ALLOCATIONS`.
  ///
  /// Defaults to `false`. Enables diagnostics with the compilation option
  /// `-DTRACK_RESOURCE_ALLOCATIONS=true` for Dart, or
  /// `--dart-define=TRACK_RESOURCE_ALLOCATIONS=true` for Flutter.
  static const bool trackAllocations = bool.fromEnvironment(
    'TRACK_RESOURCE_ALLOCATIONS',
  );

  static final Set<ScopedResource> _trackedAllocations = HashSet.identity();

  /// A snapshot of allocations recorded when [trackAllocations] is enabled.
  ///
  /// Includes resources registered outside a scope. Delegates are represented
  /// by their [ScopedResourceDelegate.scopeResource]. Untracking removes an
  /// entry without requiring disposal, so this is not a list of all live resources.
  static List<ScopedResource> get trackedAllocations =>
      _trackedAllocations.toList();

  /// Checks that no tracked allocations remain.
  ///
  /// Throws a [StateError] if [trackedAllocations] is not empty. Returns `true`
  /// otherwise, allowing calls inside `assert`. Untracked allocations are not
  /// checked, and tracking is disabled unless [trackAllocations] is enabled.
  static bool checkNoLeaks() {
    if (_trackedAllocations.isNotEmpty) {
      throw StateError(
        'Detected ${_trackedAllocations.length} undisposed ScopedResources:\n'
        '${_trackedAllocations.map((r) => '  ${r.runtimeType}#${identityHashCode(r)}').join('\n')}',
      );
    }
    return true;
  }

  /// Clears [trackedAllocations] without disposing resources or changing ownership.
  static void clearTrackedAllocations() => _trackedAllocations.clear();

  /// The scope active in [Zone.current], or `null` outside [using].
  static ScopeInstance? get current => Zone.current[_key] as ScopeInstance?;

  /// Registers [target] with the active [ScopeInstance] in [Zone.current], if any.
  ///
  /// Constructors of [ScopedResource] implementations should call
  /// `Scope.track(this)` after successful initialization. Delegates register
  /// their [ScopedResourceDelegate.scopeResource] instead of the wrapper.
  /// When [trackAllocations] is enabled, records allocations even outside a scope.
  ///
  /// Throws a [StateError] if the resource is disposed, belongs to another scope,
  /// or the current scope is closed. An unowned resource registered in a closed
  /// scope is disposed immediately before the error is thrown.
  static void track(ScopeTarget target) {
    final resource = _resolve(target);
    final scope = current;
    if (resource.isDisposed) throw StateError('Resource is disposed');
    if (scope != null && scope._closed) {
      if (_owners[resource] == null) resource.dispose();
      throw StateError('Scope is closed');
    }
    scope?.track(resource);
    if (trackAllocations) _trackedAllocations.add(resource);
  }

  /// Removes [target] from its owning scope and allocation diagnostics.
  ///
  /// Disposal implementations should call `Scope.untrack(this)`. Resolves
  /// delegates to their [ScopedResourceDelegate.scopeResource] and removes the
  /// actual owner's registration, independent of [Zone.current]. Does not
  /// dispose the resource. Repeated calls have no effect.
  static void untrack(ScopeTarget target) {
    final resource = _resolve(target);
    _owners[resource]?._remove(resource);
    if (trackAllocations) _trackedAllocations.remove(resource);
  }
}

/// An individual scope that owns resources and deferred cleanup callbacks.
///
/// Created by [using] and passed to its callback. Each instance manages its own
/// registrations, disposing resources and running deferred callbacks in reverse
/// registration order. Returning a resource does not remove its registration.
///
/// Uses [untrack] to transfer responsibility to the caller, and an outer scope's
/// [track] to explicitly adopt it: `outer.track(inner.untrack(resource))`.
final class ScopeInstance._() {
  final _resources = HashMap<ScopedResource, void Function()>.identity();
  final _cleanup = <void Function()>[];
  bool _closed = false;

  /// Registers [target] in this scope and returns [target] unchanged.
  ///
  /// Delegates register their [ScopedResourceDelegate.scopeResource]. Repeated
  /// registration of the same resource preserves its original cleanup order.
  /// Records the resource in [Scope.trackedAllocations] when enabled.
  ///
  /// Throws a [StateError] if this scope is closed, the resource is disposed,
  /// or another scope owns it. Does not dispose the resource on failure.
  T track<T extends ScopeTarget>(T target) {
    _checkOpen();
    final resource = _resolve(target);
    _adopt(resource);
    if (Scope.trackAllocations) Scope._trackedAllocations.add(resource);
    return target;
  }

  /// Removes [target] from this scope and returns [target] unchanged.
  ///
  /// Delegates remove their [ScopedResourceDelegate.scopeResource]. Also removes
  /// allocation diagnostics, without disposing or transferring the resource to
  /// another scope. Unmanaged resources are returned unchanged.
  ///
  /// Throws a [StateError] if this scope is closed, or an [ArgumentError] if
  /// another scope owns the resource.
  T untrack<T extends ScopeTarget>(T target) {
    _checkOpen();
    final resource = _resolve(target);
    final owner = _owners[resource];
    if (owner != null && !identical(owner, this)) {
      throw ArgumentError('Resource belongs to another scope');
    }
    _remove(resource);
    if (Scope.trackAllocations) Scope._trackedAllocations.remove(resource);
    return target;
  }

  void _checkOpen() {
    if (_closed) throw StateError('Scope is closed');
  }

  void _adopt(ScopedResource resource) {
    _checkOpen();
    if (resource.isDisposed) throw StateError('Resource is disposed');
    final owner = _owners[resource];
    if (identical(owner, this)) return;
    if (owner != null) {
      throw StateError('Resource already belongs to a scope');
    }
    _owners[resource] = this;
    void cleanup() {
      _remove(resource);
      if (!resource.isDisposed) resource.dispose();
    }

    _resources[resource] = cleanup;
    _cleanup.add(cleanup);
  }

  void _remove(ScopedResource resource) {
    final cleanup = _resources.remove(resource);
    if (cleanup != null) _cleanup.remove(cleanup);
    _owners[resource] = null;
  }

  /// Registers [action] to run when this scope exits.
  ///
  /// Callbacks and resources share one reverse registration order. Cleanup
  /// continues after failures and throws the first cleanup error. The callback
  /// must be synchronous. Throws a [StateError] if this scope is closed.
  void defer(void Function() action) {
    _checkOpen();
    _cleanup.add(action);
  }

  void _release() {
    if (_closed) return;
    _closed = true;
    Object? firstError;
    StackTrace? firstStack;
    while (_cleanup.isNotEmpty) {
      try {
        _cleanup.removeLast()();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}
