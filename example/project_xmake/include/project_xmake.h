#pragma once

// clang-format off
#ifdef __cplusplus
#  define PROJECT_XMAKE_EXTERN_C extern "C"
#else
#  define PROJECT_XMAKE_EXTERN_C extern
#endif

#if defined(_WIN32)
#  if defined(PROJECT_XMAKE_BUILD)
#    define PROJECT_XMAKE_EXPORT __declspec(dllexport)
#  else
#    define PROJECT_XMAKE_EXPORT __declspec(dllimport)
#  endif
#else
#  define PROJECT_XMAKE_EXPORT __attribute__((visibility("default")))
#endif
// clang-format on

#define PROJECT_XMAKE_API PROJECT_XMAKE_EXTERN_C PROJECT_XMAKE_EXPORT

PROJECT_XMAKE_API int add(int a, int b);
PROJECT_XMAKE_API int subtract(int a, int b);
