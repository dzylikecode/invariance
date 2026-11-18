#include "embed.h"

#include <stdio.h>

int main(void) {
    const size_t size = file1_size();
    if (fwrite(file1_data(), 1, size, stdout) != size) {
        return 1;
    }
    return 0;
}
