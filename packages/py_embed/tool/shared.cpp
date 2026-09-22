#include <Python.h>
#include <tuple>

const auto funcs = std::tuple{
    &Py_Finalize,
    &PyStatus_Exception,
    &PyRun_SimpleString,
};

using structs = std::tuple<PyStatus>;

using alias = std::tuple<PyObject>;

