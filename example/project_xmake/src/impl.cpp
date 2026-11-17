#include <project_xmake.h>
#include <limits>
#include <sstream>
#include <string>

int add(int a, int b) { return a + b; }

int subtract(int a, int b) { return a - b; }

int count_words(const char* text) {
    if (!text) return -1;

    try {
        std::istringstream input(text);
        std::string word;
        int count = 0;
        while (input >> word) {
            if (count == std::numeric_limits<int>::max()) return -1;
            ++count;
        }
        return input.bad() ? -1 : count;
    } catch (...) {
        // Keep C++ exceptions inside the C API boundary.
        return -1;
    }
}
