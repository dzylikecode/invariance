import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'binding/api.dart';
import 'binding/shared.g.dart' as g;
import 'object.dart';
import 'runtime.dart';

/// A synchronous callback receiving borrowed positional and keyword arguments.
///
/// Arguments are valid during the callback. Retain any objects kept afterward.
/// Keyword arguments are `null` when Python supplies no keyword dictionary.
/// The returned object must own one reference, transferred to Python. Retain
/// an existing object before returning it; do not release the returned reference.
typedef PyFunctionCallback = PyObject Function(PyTuple args, PyDict? kwargs);

typedef _NativeCallback = Pointer<g.PyObject> Function(
  Pointer<g.PyObject>,
  Pointer<g.PyObject>,
  Pointer<g.PyObject>,
);

/// A Python callable backed by a synchronous Dart closure.
///
/// Supports positional and keyword arguments. Python must invoke it on the thread
/// of the creating Dart isolate; calling from another thread aborts the process.
/// Call [dispose] before shutting down Python, after removing every Python
/// reference to this function. Do not register this object's initial reference
/// in a Python scope or release it through `ref.discrement()`; [dispose] owns it.
final class PyFunction extends PyObject {
  final NativeCallable<_NativeCallback> _callback;
  final Pointer<g.PyMethodDef> _method;
  final Pointer<Char> _name;
  bool _disposed = false;
  int _activeCalls = 0;

  PyFunction._(super.ref, this._callback, this._method, this._name);

  /// Creates a callable named [name] that invokes [callback].
  factory PyFunction(
    PyFunctionCallback callback, {
    String name = 'dart_function',
  }) {
    late PyFunction function;
    final native = NativeCallable<_NativeCallback>.isolateLocal((
      Pointer<g.PyObject> self,
      Pointer<g.PyObject> args,
      Pointer<g.PyObject> kwargs,
    ) {
      function._activeCalls++;
      try {
        return callback(
          .fromHandle(args),
          kwargs == nullptr ? null : PyDict.fromHandle(kwargs),
        ).ptr;
      } catch (error) {
        var message = 'Dart callback failed';
        try {
          message = error.toString();
        } catch (_) {
          // Error formatting must not escape the native callback.
        }
        ffi.using((arena) {
          api.PyErr_SetString(
            api.PyExc_RuntimeError,
            message.toNativeUtf8(allocator: arena).cast(),
          );
        });
        return nullptr;
      } finally {
        function._activeCalls--;
      }
    });
    Pointer<Char> nativeName = nullptr;
    Pointer<g.PyMethodDef> method = nullptr;
    try {
      nativeName = name.toNativeUtf8().cast();
      method = ffi.calloc<g.PyMethodDef>();
      method.ref
        ..ml_name = nativeName
        // PyMethodDef stores PyCFunction even for the keywords signature.
        ..ml_meth = native.nativeFunction.cast()
        ..ml_flags =
            0x0001 |
            0x0002 // METH_VARARGS | METH_KEYWORDS.
        ..ml_doc = nullptr;
      final ptr = checked(
        () => api.PyCFunction_NewEx(method, nullptr, nullptr),
      );
      if (ptr == nullptr) throw StateError('Failed to create Python function');
      return function = ._(.fromHandle(ptr), native, method, nativeName);
    } catch (_) {
      native.close();
      if (method != nullptr) ffi.calloc.free(method);
      if (nativeName != nullptr) ffi.malloc.free(nativeName);
      rethrow;
    }
  }

  /// Releases the owned Python reference and native callback resources.
  ///
  /// Python must no longer hold references to this function. Repeated calls
  /// have no effect. Throws [StateError] if called during this function's callback
  /// or after the Python runtime has shut down.
  void dispose() {
    if (_disposed) return;
    if (_activeCalls != 0) throw StateError('Python function is executing');
    checked(() => api.Py_DecRef(super.ptr));
    _disposed = true;
    _callback.close();
    ffi.calloc.free(_method);
    ffi.malloc.free(_name);
  }
}
