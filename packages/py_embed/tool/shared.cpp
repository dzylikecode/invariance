#include <Python.h>
#include <tuple>

const auto funcs = std::tuple{
    &Py_Finalize,
    &PyRun_SimpleString,
    &Py_IsInitialized,
    
    &PyStatus_Exception,
    &PyErr_Occurred,


    &PyObject_GetAttrString,
    &PyObject_SetAttrString,
    &PyObject_HasAttrString,

    &Py_DecRef,
    &Py_IncRef,

    &PyObject_IsTrue,
    &PyLong_AsLong,
    &PyFloat_AsDouble,
    &PyObject_Str,
    &PyUnicode_AsUTF8,

    &PyLong_FromLong,
    &PyFloat_FromDouble,
    &PyBool_FromLong,
    &PyImport_ImportModule,
    // &PyImport_AddModule,
    &PyUnicode_FromString,

    // exception
    &PyErr_Fetch,
    &PyErr_NormalizeException,
    &PyErr_Print,

    &PyObject_Call,
    &PyObject_CallObject,

    &PyGILState_Ensure,
    &PyGILState_Release,
    &PyEval_SaveThread,
};

using structs = std::tuple<PyStatus>;

using alias = std::tuple<PyObject, PyGILState_STATE, PyThreadState>;

