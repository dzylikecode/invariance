#include <Python.h>
#include <tuple>

const auto funcs = std::tuple{
    &Py_Finalize,
    &PyRun_SimpleString,
    
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
};

using structs = std::tuple<PyStatus>;

using alias = std::tuple<PyObject>;

