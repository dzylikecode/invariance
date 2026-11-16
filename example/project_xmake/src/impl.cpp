// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
#include <project_xmake.h>
#ifdef PROJECT_XMAKE_CPP_RUNTIME_PROBE
#include <string>

// Exercise the C++ standard library so mismatched runtime ABIs cannot hide
// behind this example's C-compatible exported functions.
int add(int a, int b) { return std::stoi(std::to_string(a)) + b; }
#else
int add(int a, int b) { return a + b; }
#endif

int subtract(int a, int b) { return a - b; }
