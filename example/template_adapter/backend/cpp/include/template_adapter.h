#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
#define TEMPLATE_ADAPTER_EXTERN_C extern "C"
#else
#define TEMPLATE_ADAPTER_EXTERN_C extern
#endif

#if defined(_WIN32)
#if defined(TEMPLATE_ADAPTER_BUILDING)
#define TEMPLATE_ADAPTER_EXPORT __declspec(dllexport)
#else
#define TEMPLATE_ADAPTER_EXPORT __declspec(dllimport)
#endif
#else
#define TEMPLATE_ADAPTER_EXPORT __attribute__((visibility("default")))
#endif

#define TEMPLATE_ADAPTER_API TEMPLATE_ADAPTER_EXTERN_C TEMPLATE_ADAPTER_EXPORT

typedef uintptr_t Handle;

typedef enum ValueType {
  INT32 = 1,
  DOUBLE = 2,
} ValueType;

// Keep the C ABI fixed-width; a C enum's representation is implementation
// defined. The enum above only names the supported values.
typedef int32_t ValueType_t;

/// Creates an accumulator whose concrete C++ type is selected at runtime.
/// Returns 0 when [type] is unsupported.
TEMPLATE_ADAPTER_API Handle accumulator_create(ValueType_t type);

/// Adds the value pointed to by [value]. Its native type must match [type].
TEMPLATE_ADAPTER_API bool accumulator_add(Handle handle, const void *value);

/// Copies the current value into [output]. Its native type must match [type].
TEMPLATE_ADAPTER_API bool accumulator_get(Handle handle, void *output);

/// Releases the type-erased adapter and its concrete template instance.
TEMPLATE_ADAPTER_API void accumulator_dispose(Handle handle);
