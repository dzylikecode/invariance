#include <Python.h>
#include <tuple>

//----------------------------------------------
// ## platform
const auto funcs = std::tuple{
    &PyConfig_InitPythonConfig,
    &PyConfig_SetString,
    &Py_InitializeFromConfig,
    &PyConfig_Clear,
};

using structs = std::tuple<PyConfig>;

using alias = std::tuple<Py_ssize_t>;
