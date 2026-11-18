#include "embed.h"

static uint8_t file1_txt[] = {
#embed "../assets/file1.txt"
};

const uint8_t *file1_data(void) { return file1_txt; }

size_t file1_size(void) { return sizeof(file1_txt); }
