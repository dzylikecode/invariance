// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
#include <project_xmake.h>
#include <stdio.h>

int main(void) {
    const char* text = "C++ libraries behind a C API";
    const int words = count_words(text);
    printf("Text: %s\nWords: %d\n", text, words);
    if (words != 6) return 1;
    if (count_words("") != 0) return 1;
    if (count_words(" \t\n") != 0) return 1;
    if (count_words(NULL) != -1) return 1;
    return 0;
}
