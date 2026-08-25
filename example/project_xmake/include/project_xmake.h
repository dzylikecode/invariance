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

struct Config {
  int value;
#if defined(_WIN32) || defined(_WIN64)
  int is_windows;
#elif defined(__APPLE__)
  int is_mac;
#elif defined(__linux__)
  int is_linux;
#endif
};

#ifdef __cplusplus
}
#endif
