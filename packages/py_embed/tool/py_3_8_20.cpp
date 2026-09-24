#include <Python.h>
#include <tuple>

//----------------------------------------------
// ## platform
const auto funcs = std::tuple{
    &PyConfig_InitPythonConfig,
    &PyConfig_SetString,
    &Py_InitializeFromConfig,
    &PyConfig_Clear,

    &PyTuple_New,
    &PyTuple_Size,
    &PyTuple_SetItem,
    &PyTuple_GetItem,

    &PyList_New,
    &PyList_Size,
    &PyList_SetItem,
    &PyList_GetItem,
    &PyList_Append,
    &PyList_Insert,
    &PyList_Sort,
    &PyList_Reverse,

    &PyDict_New,
    &PyDict_Size,
    &PyDict_SetItem,
    &PyDict_GetItem,
    &PyDict_DelItem,
    &PyDict_Clear,
};

using structs = std::tuple<PyConfig>;

using alias = std::tuple<Py_ssize_t>;

