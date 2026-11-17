#ifndef EMBED_TEXT_H
#define EMBED_TEXT_H

#include <stddef.h>

#if defined(EMBED_TEXT_STATIC)
#define EMBED_TEXT_API
#elif defined(_WIN32)
#if defined(EMBED_TEXT_BUILDING)
#define EMBED_TEXT_API __declspec(dllexport)
#else
#define EMBED_TEXT_API __declspec(dllimport)
#endif
#else
#define EMBED_TEXT_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// The returned bytes are read-only and remain valid for the library's lifetime.
EMBED_TEXT_API const unsigned char *embed_text_data(void);

// The byte length excludes the extra null terminator, and may be zero.
EMBED_TEXT_API size_t embed_text_size(void);

#ifdef __cplusplus
}
#endif

#endif
