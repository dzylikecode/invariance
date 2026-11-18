#include "embed.h"

#include <stdio.h>

int main(void) {
    const size_t size = asset_file1_txt_size();
    if (fwrite(asset_file1_txt_data(), 1, size, stdout) != size) {
        return 1;
    }
    return 0;
}
