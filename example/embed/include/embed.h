#pragma once

#include <stddef.h>
#include <stdint.h>

// clang-format off
#ifdef __cplusplus
#  define EMBED_EXTERN_C extern "C"
#else
#  define EMBED_EXTERN_C extern
#endif

#if defined(_WIN32)
#  if defined(EMBED_STATIC)
#    define EMBED_EXPORT
#  elif defined(EMBED_BUILDING)
#    define EMBED_EXPORT __declspec(dllexport)
#  else
#    define EMBED_EXPORT __declspec(dllimport)
#  endif
#else
#  define EMBED_EXPORT __attribute__((visibility("default")))
#endif
// clang-format on

#define EMBED_API EMBED_EXTERN_C EMBED_EXPORT

// The library owns the read-only bytes; use the matching size function for
// length.
EMBED_API const uint8_t *asset_file1_txt_data(void);
EMBED_API size_t asset_file1_txt_size(void);

EMBED_API const uint8_t *asset_fold1_file1_txt_data(void);
EMBED_API size_t asset_fold1_file1_txt_size(void);
