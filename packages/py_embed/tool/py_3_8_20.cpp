#include <Python.h>
#include <tuple>

//----------------------------------------------
// ## platform
const auto platformFuncs = std::tuple{
    &PyConfig_InitPythonConfig,
    &PyConfig_SetString,
    &Py_InitializeFromConfig,
    &PyConfig_Clear,
};

using platformStructs = std::tuple<PyConfig>;

using platformAlias = std::tuple<Py_ssize_t>;


//----------------------------------------------
// ## shared

const auto funcs = std::tuple{
    &Py_Finalize,
    &PyStatus_Exception,
};

using structs = std::tuple<PyStatus>;

using alias = std::tuple<PyObject>;

