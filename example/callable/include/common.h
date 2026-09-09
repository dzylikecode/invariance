#pragma once

#ifdef __cplusplus
#define CALLABLE_EXTERN_C extern "C"
#else
#define CALLABLE_EXTERN_C extern
#endif

#if defined(_WIN32)
#if defined(CALLABLE_BUILDING)
#define CALLABLE_EXPORT __declspec(dllexport)
#else
#define CALLABLE_EXPORT __declspec(dllimport)
#endif
#else
#define CALLABLE_EXPORT __attribute__((visibility("default")))
#endif

#define CALLABLE_API CALLABLE_EXTERN_C CALLABLE_EXPORT
