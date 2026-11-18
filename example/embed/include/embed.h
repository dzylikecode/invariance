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

EMBED_API const uint8_t *file1_data(void);
EMBED_API size_t file1_size(void);

#ifdef __cplusplus
}
#endif

#endif
