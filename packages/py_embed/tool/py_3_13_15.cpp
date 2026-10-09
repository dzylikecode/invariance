#include <Python.h>
#include <tuple>

//----------------------------------------------
// ## platform
const auto funcs = std::tuple{
    &PyConfig_InitPythonConfig,
    &PyConfig_SetString,
    &Py_InitializeFromConfig,
    &PyConfig_Clear,

    &PyObject_Size,

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
    &PyDict_Next,
    &PyDict_Keys,
    &PyDict_Values,
    &PyDict_Items,
    &PyDict_Copy,
    &PyDict_Contains,
    &PyDict_Update,
    &PyDict_Merge,
    &PyDict_GetItemString,
    &PyDict_SetItemString,
    &PyDict_DelItemString,

    &PySequence_DelItem,
    &PySequence_Size,
    &PySequence_Concat,
    &PySequence_Repeat,
    &PySequence_GetItem,
    &PySequence_SetItem,

    &Py_GetConstant,
    &Py_GetConstantBorrowed,
};

using structs = std::tuple<PyConfig>;

using alias = std::tuple<Py_ssize_t>;
