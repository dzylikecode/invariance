#include <Python.h>
#include <tuple>

const auto funcs = std::tuple{
    &Py_Finalize,
    &PyRun_SimpleString,
    &Py_IsInitialized,
    
    &PyStatus_Exception,
    &PyErr_Occurred,


    &PyObject_GetAttrString,
    &PyObject_GetAttr,
    &PyObject_GetItem,
    &PyObject_SetAttrString,
    &PyObject_SetAttr,
    &PyObject_SetItem,
    &PyObject_HasAttrString,
    &PyObject_HasAttr,
    &PyObject_DelItem,

    &Py_DecRef,
    &Py_IncRef,

    &PyObject_IsTrue,
    &PyLong_AsLong,
    &PyFloat_AsDouble,
    &PyObject_Str,
    &PyObject_Repr,
    &PyObject_IsInstance,
    &PyUnicode_AsUTF8,
    &PyObject_ASCII,

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

    // operators
    &PyObject_RichCompare,
    &PyObject_RichCompareBool,

    // arithmetic and bitwise operators
    &PyNumber_Add,
    &PyNumber_Subtract,
    &PyNumber_Multiply,
    &PyNumber_MatrixMultiply,
    &PyNumber_FloorDivide,
    &PyNumber_TrueDivide,
    &PyNumber_Remainder,
    &PyNumber_Divmod,
    &PyNumber_Power,
    &PyNumber_Lshift,
    &PyNumber_Rshift,
    &PyNumber_And,
    &PyNumber_Xor,
    &PyNumber_Or,

    // unary operators
    &PyNumber_Negative,
    &PyNumber_Positive,
    &PyNumber_Absolute,
    &PyNumber_Invert,

    // augmented assignment operators
    &PyNumber_InPlaceAdd,
    &PyNumber_InPlaceSubtract,
    &PyNumber_InPlaceMultiply,
    &PyNumber_InPlaceMatrixMultiply,
    &PyNumber_InPlaceFloorDivide,
    &PyNumber_InPlaceTrueDivide,
    &PyNumber_InPlaceRemainder,
    &PyNumber_InPlacePower,
    &PyNumber_InPlaceLshift,
    &PyNumber_InPlaceRshift,
    &PyNumber_InPlaceAnd,
    &PyNumber_InPlaceXor,
    &PyNumber_InPlaceOr,
};

using structs = std::tuple<PyStatus>;

using alias = std::tuple<PyObject, PyGILState_STATE, PyThreadState>;

