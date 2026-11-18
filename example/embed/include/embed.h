#ifndef EMBED_H
#define EMBED_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#if defined(EMBED_STATIC)
#define EMBED_API
#elif defined(EMBED_BUILDING)
#define EMBED_API __declspec(dllexport)
#else
#define EMBED_API __declspec(dllimport)
#endif
#else
#define EMBED_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// The library owns the read-only bytes; use the matching size function for length.
EMBED_API const uint8_t *asset_file1_txt_data(void);
EMBED_API size_t asset_file1_txt_size(void);

EMBED_API const uint8_t *asset_fold1_file1_txt_data(void);
EMBED_API size_t asset_fold1_file1_txt_size(void);

#ifdef __cplusplus
}
#endif

#endif
