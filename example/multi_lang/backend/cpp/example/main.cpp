#include <iostream>
#include <multi_lang.h>

int main() {
  auto str = greet("cpp-caller");
  std::cout << str << std::endl;
  freeString(str);
}
