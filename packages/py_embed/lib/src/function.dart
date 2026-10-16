import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'package:resource_scope/resource_scope.dart';

import 'binding/api.dart';
import 'binding/shared.g.dart' as g;
import 'object.dart';
import 'runtime.dart';

/// A synchronous callback receiving scoped positional and keyword arguments.
///
/// Arguments are valid during the callback. Retain and detach objects kept afterward.
/// Keyword arguments are `null` when Python supplies no keyword dictionary.
/// The result is borrowed from the callback: the bridge acquires a new reference
/// for Python before cleaning up the callback scope. Return new objects, arguments,
/// or existing caller-owned objects directly, without incrementing their counts.
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
/// Dispose before shutting down Python, after removing every Python reference to
/// this function. The active scope releases both its Python reference and native
/// callback memory. A retained Python reference does not extend callback memory's
/// lifetime; keep the original function alive while Python can call it.
final class PyFunction._(_FunctionRef super.ref) extends PyObject {
  /// Creates a callable named [name] that invokes [callback].
  factory(PyFunctionCallback callback, {String name = 'dart_function'}) {
    late _FunctionRef reference;
    final native = NativeCallable<_NativeCallback>.isolateLocal((
      Pointer<g.PyObject> self,
      Pointer<g.PyObject> args,
      Pointer<g.PyObject> kwargs,
    ) {
      reference.activeCalls++;
      try {
        // Keep Python's result reference separate from every scoped wrapper.
        Pointer<g.PyObject> result = nullptr;
        try {
          ResourceScope.scope(() {
            result = callback(
              .fromBorrowedHandle(args),
              kwargs == nullptr ? null : PyDict.fromBorrowedHandle(kwargs),
            ).ptr;
            api.Py_IncRef(result);
          });
          return result;
        } catch (_) {
          if (result != nullptr) api.Py_DecRef(result);
          rethrow;
        }
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
        reference.activeCalls--;
      }
    });
    Pointer<Char> nativeName = nullptr;
    Pointer<g.PyMethodDef> method = nullptr;
    var transferred = false;
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
      transferred = true;
      reference = _FunctionRef(ptr, native, method, nativeName);
      return PyFunction._(reference);
    } catch (_) {
      if (!transferred) {
        native.close();
        if (method != nullptr) ffi.calloc.free(method);
        if (nativeName != nullptr) ffi.malloc.free(nativeName);
      }
      rethrow;
    }
  }
}

// Native resources share the lifetime of the initial owned Python reference.
final class _FunctionRef(
  super.ptr,
  final NativeCallable<_NativeCallback> callback,
  final Pointer<g.PyMethodDef> method,
  final Pointer<Char> name,
) extends PyRef {
  this : super.fromHandle();

  int activeCalls = 0;

  @override
  void dispose() {
    if (isDisposed) return;
    if (activeCalls != 0) throw StateError('Python function is executing');
    try {
      super.dispose();
    } finally {
      if (isDisposed) {
        callback.close();
        ffi.calloc.free(method);
        ffi.malloc.free(name);
      }
    }
  }
}
