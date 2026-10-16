# scope_guard (experiment)

An independent API experiment inspired by Scientific Dart's
resource_scope. No runtime package dependencies; py_embed is not modified.

```dart
final result = using((scope) {
  final a = NativeValue(1);
  final b = NativeValue(2);
  scope.defer(() => print('done'));
  return scope.untrack(a + b);
});
result.dispose();
```

Each scope manages only its own registrations. Both instance methods return the
original concrete resource type:

```dart
T track<T extends ScopeTarget>(T resource);
T untrack<T extends ScopeTarget>(T resource);
```

Untracking never implicitly promotes a resource. Parent adoption is explicit:

```dart
using((outer) {
  final result = using((inner) {
    return outer.track(inner.untrack(NativeValue(42)));
  });
  // result remains alive until outer exits.
});
```

## Asynchronous callbacks

```dart
final result = await using((scope) async {
  final a = NativeValue(1);
  await Future<void>.delayed(Duration.zero);
  final b = NativeValue(2); // Still automatically tracked in the same Zone.
  return scope.untrack(a + b);
});
result.dispose();
```

Both pre-await and post-await allocations are cleaned before the returned Future
completes. Concurrent calls have separate scopes. Return types are inferred;
if supplying a type argument explicitly, use `using<Future<T>>` for async work,
not `using<T>` or `using<void>`. Future subtypes whose `whenComplete` result is
not assignable to the declared return type are unsupported.

## Scope and ScopeInstance

`Scope` is a static facade. `Scope.track(this)` registers a resource in the
current Zone's instance; `Scope.untrack(this)` is the disposal hook that removes
actual ownership. Allocation diagnostics also live on `Scope`.

Each `using` creates a private-constructed `ScopeInstance`, stores it in the
Zone, and passes it to the callback. The instance holds the cleanup queue and
provides `track`, `untrack`, and `defer`. Instance operations affect only their
receiver; explicit transfer is `outer.track(inner.untrack(value))`.

## Resource integration

Resources implement ScopedResource: isDisposed and dispose().
Each wrapper represents one owned reference, even when two wrappers share a
native pointer. Resources need not inherit a base class.

- Call Scope.track(this) after successful initialization. This
  constructor hook registers with the active Zone's scope and records allocation
  diagnostics even when no scope exists.
- Implement idempotent dispose() and call Scope.untrack(this) when
  releasing ownership. This lifecycle hook removes the actual owner's entry,
  including when disposal occurs inside a different scope.

The lifecycle hooks are separate from the instance API: scope.untrack(value)
never removes another scope's entry. Scope.current exposes the active scope.

## Delegation and composition

`ScopeTarget` is the common type accepted by track/untrack. A target is either
an actual `ScopedResource` or a `ScopedResourceDelegate`. Existing resources
continue implementing only `ScopedResource`.

For a PyRef that already implements ScopedResource and registers itself:

```dart
class PyObject implements ScopedResourceDelegate {
  PyObject(this.ref);
  final PyRef ref;

  @override
  PyRef get scopeResource => ref;
}

final PyObject result = using((scope) {
  final object = PyObject(PyRef(/* owned Python reference */));
  return scope.untrack(object); // Untracks ref; returns the same PyObject.
});
result.ref.dispose();
```

All static and instance registration methods read a delegate's resource once. Wrappers need not register separately. Shared wrappers are aliases to
one owned reference, not independent Python reference counts. Diagnostics and
cleanup are keyed by the final resource's identity; only that resource is
scheduled for disposal. Extra wrapper-specific cleanup must be registered
separately with defer or owned by a different resource.

Delegation is one level only: `ScopedResourceDelegate.scopeResource` has the type
`ScopedResource`, so an ordinary delegate cannot target another delegate.
The target must remain identical for its lifetime; prefer a final field.
If a class implements both interfaces, its delegate target is used directly,
without recursively following further delegation.
Parent adoption remains explicit: outer.track(inner.untrack(object)).

See example/delegation.dart for a runnable native-reference simulation.

## Semantics

- Callbacks may return a synchronous value or a Future. Future results keep the
  scope alive until success or failure; synchronous calls still return immediately.
- Resource disposal and deferred callbacks remain synchronous. Async defer is
  unsupported. Await or return all asynchronous work that uses scoped resources;
  unawaited work does not extend the scope lifetime.
- Resources created outside using remain manually owned.
- Tracking uses wrapper identity; tracking twice in the same scope is a no-op
  and preserves cleanup order. Tracking in another scope requires untracking first.
- Untrack is idempotent for unmanaged resources but rejects resources owned by
  another scope. Both instance methods reject closed scopes.
- Resources and deferred callbacks share a LIFO cleanup queue.
- Returning a resource without untracking does not preserve its lifetime.
- No escape method, implicit parent adoption, or parent-scope chain is needed.
- Untracking and adoption take effect immediately, even if later code throws.
- Cleanup continues after failures and throws its first error. A cleanup error
  takes precedence over a body error.
- Late constructor registration into a closed Zone disposes an unowned resource
  immediately and throws. Explicit tracking into a closed scope rejects it
  without disposing the caller's resource.

## Allocation diagnostics

Enable with a compilation define (not a shell environment variable):

```sh
dart run -DTRACK_RESOURCE_ALLOCATIONS=true example/main.dart
```

```dart
Scope.trackAllocations;          // false by default
Scope.trackedAllocations;        // snapshot of registered references
assert(Scope.checkNoLeaks());    // throws StateError if entries remain
Scope.clearTrackedAllocations(); // resets diagnostics without disposal
```

Untracking also removes diagnostic entries; explicit tracking
records them again. This follows the original package's untracking semantics,
so diagnostics are not a complete census of live native references. Resource
implementations must call Scope.untrack when disposing. The registry uses
wrapper identity and retains strong references while enabled, per isolate.

Run tests in both configurations (source compilation inherits VM defines):

```sh
dart test
dart -DTRACK_RESOURCE_ALLOCATIONS=true test --compiler=source
```

## Before integrating py_embed

Separate owned/borrowed handle construction, retain public borrowed results,
and pass separately retained references to stealing CPython setters. Migrate
internal using return paths to untrack, with explicit caller adoption where
needed. Validate against CPython refcounts and destructors. These Python-specific
behaviors are not implemented here. Cleanup queue removal is currently linear;
performance has not been validated.
