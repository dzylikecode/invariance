# Adapting C++ templates for Dart FFI

This example extracts the central idea used by the Unitree wrapper: instantiate
C++ templates behind a non-template interface, expose that interface through a
stable C ABI, and restore type safety in Dart.

```text
Dart: Accumulator<T>
          |
          | type binding (int / double)
          v
C ABI: fixed-width type tag + handle + void pointers
          |
          | runtime factory table
          v
C++: AccumulatorInterface
          |
          | AccumulatorAdapter<T>
          v
C++: Accumulator<T>
```

## Why an adapter is needed

C++ templates are compile-time machinery. There is no single
`Accumulator<T>` symbol that Dart FFI can call, and C++ names and class layouts
do not form a portable C ABI. The wrapper therefore explicitly instantiates the
supported types and hides them behind `AccumulatorInterface`.

`accumulator_create(ValueType_t)` looks up a factory function. `ValueType_t`
is an `int32_t`, avoiding the implementation-defined representation of a C
enum at the ABI boundary:

```cpp
constexpr FactoryEntry kFactories[] = {
    {VALUE_TYPE_INT32, createAdapter<std::int32_t>},
    {VALUE_TYPE_DOUBLE, createAdapter<double>},
};
```

The returned handle points to the non-template interface. Calls to
`accumulator_add` and `accumulator_get` dispatch virtually to the appropriate
`AccumulatorAdapter<T>`, which casts the untyped C pointer back to `T*` before
calling the original template.

On the Dart side, `_bindingFor<T>()` performs the matching operation. It maps
`int` and `double` to the native enum and knows how to allocate and read the
corresponding FFI value. Users only see the generic API:

```dart
final integers = Accumulator<int>();
integers
  ..add(3)
  ..add(5);
print(integers.value); // 8
integers.dispose();
```

The C layer cannot verify the type behind a `void*`; safety comes from keeping
the native factory table and Dart type-binding table consistent. Adding another
type therefore requires one entry on each side.

## Ownership

`accumulator_create` transfers ownership of the adapter to Dart. Calling
`dispose()` deletes it immediately and is idempotent. A Dart `Finalizer` is also
attached as a fallback for an object that becomes unreachable without explicit
disposal. Access after disposal throws `StateError` before entering native code.

## Run

The Dart build hook invokes xmake and exposes its shared library as a native
code asset, so no `.so` path is hard-coded.

```sh
dart run tool/ffigen.dart
dart run example/main.dart
dart test
dart analyze
```

## Layout

- `include/template_adapter.h`: stable C ABI
- `src/template_adapter.cpp`: template, type erasure, adapters, and factory table
- `lib/src/accumulator.dart`: type-safe Dart facade and ownership
- `lib/src/binding/`: generated FFI declarations
- `hook/build.dart`: native-assets/xmake integration
- `tool/ffigen.dart`: binding generator

## 思想

1. 用抽象类擦除 T
2. 用工厂方法擦除构造函数

    ```dart
    final constructors = {
      .classA: (args) => .new<A>(args),
      .classB: (args) => .new<B>(args)
    }
    ```
