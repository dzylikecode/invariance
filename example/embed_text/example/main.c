#include "embed_text.h"

#include <stdio.h>

int main(void) {
    const size_t size = embed_text_size();
    if (fwrite(embed_text_data(), 1, size, stdout) != size) {
        return 1;
    }
    return 0;
}
