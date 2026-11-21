#include "multi_lang.h"
#include <cstring>
#include <string>

char *greet(const char *name) {
  std::string result = "hello, " + std::string(name) + "! I'm from cpp.";

  char *str = new char[result.size() + 1];
  std::memcpy(str, result.c_str(), result.size() + 1);

  return str;
}

void freeString(char* str) {
    delete[] str;
}
