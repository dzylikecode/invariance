#pragma once

#if defined(_WIN32)
  #if defined(PROJECT_XMAKE_BUILD)
    #define PROJECT_XMAKE_API __declspec(dllexport)
  #else
    #define PROJECT_XMAKE_API __declspec(dllimport)
  #endif
#else
  #define PROJECT_XMAKE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

PROJECT_XMAKE_API int add(int a, int b);

#ifdef __cplusplus
}
#endif
