#pragma once

// clang-format off
#ifdef __cplusplus
#  define MULTI_LANG_EXTERN_C extern "C"
#else
#  define MULTI_LANG_EXTERN_C extern
#endif

#if defined(_WIN32)
#  if defined(MULTI_LANG_STATIC)
#    define MULTI_LANG_EXPORT
#  elif defined(MULTI_LANG_BUILD)
#    define MULTI_LANG_EXPORT __declspec(dllexport)
#  else
#    define MULTI_LANG_EXPORT __declspec(dllimport)
#  endif
#else
#  define MULTI_LANG_EXPORT __attribute__((visibility("default")))
#endif
// clang-format on

#define MULTI_LANG_API MULTI_LANG_EXTERN_C MULTI_LANG_EXPORT

MULTI_LANG_API char* greet(const char* name);
MULTI_LANG_API void freeString(char* str);
