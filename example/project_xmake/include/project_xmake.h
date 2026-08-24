#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int add(int a, int b);

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
