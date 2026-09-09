#pragma once

#include "common.h"

#include <stdbool.h>
#include <stdint.h>

typedef void (*CallableListener)(uint64_t timestamp_ns, uint64_t sequence);

CALLABLE_API uint64_t callable_now_ns(void);
CALLABLE_API bool callable_start(CallableListener callback,
                                 uint64_t interval_ns,
                                 uint64_t sample_count);
CALLABLE_API void callable_join(void);
