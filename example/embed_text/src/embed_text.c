#include "embed_text.h"

// #embed expands the file into integer byte values at compile time.
// Keep an extra null byte even when the input is empty; it is not part of size.
static const unsigned char text[] = {
#embed "../resources/message.txt" suffix(, 0) if_empty(0)
};

const unsigned char *embed_text_data(void) {
    return text;
}

size_t embed_text_size(void) {
    return sizeof(text) - 1;
}

