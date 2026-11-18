#include "embed.h"

static const uint8_t asset_file1_txt[] = {
#embed "../assets/file1.txt"
};

const uint8_t *asset_file1_txt_data(void) {
    return asset_file1_txt;
}

size_t asset_file1_txt_size(void) {
    return sizeof(asset_file1_txt);
}

static const uint8_t asset_fold1_file1_txt[] = {
#embed "../assets/fold1/file1.txt"
};

const uint8_t *asset_fold1_file1_txt_data(void) {
    return asset_fold1_file1_txt;
}

size_t asset_fold1_file1_txt_size(void) {
    return sizeof(asset_fold1_file1_txt);
}
