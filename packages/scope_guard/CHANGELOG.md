## 0.0.1

- Introduce `using` for Zone-based resource management with synchronous and
  Future-returning callbacks.
- Add `ScopedResource` for disposable resources and `ScopedResourceDelegate`
  for wrappers that delegate to a single resource through `scopeResource`.
- Provide `Scope.track` and `Scope.untrack` for resource initialization and
  disposal, with `ScopeInstance.track` and `ScopeInstance.untrack` for explicit
  ownership transfer.
- Support deferred synchronous cleanup with `scope.defer`, sharing reverse
  registration order with resource disposal and continuing after cleanup errors.
- Add optional allocation diagnostics through `TRACK_RESOURCE_ALLOCATIONS`,
  including allocation snapshots, leak checks, and diagnostic resets.
- Include usage examples, API documentation, and tests for nested and concurrent
  scopes, asynchronous completion, delegation, and allocation tracking.
