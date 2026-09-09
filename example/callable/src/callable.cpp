#include "callable.h"

#include <atomic>
#include <chrono>
#include <thread>

namespace {
using Clock = std::chrono::steady_clock;
std::atomic<bool> running{false};
std::thread worker;

uint64_t now_ns() {
  return static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::nanoseconds>(
          Clock::now().time_since_epoch())
          .count());
}
}  // namespace

uint64_t callable_now_ns() { return now_ns(); }

bool callable_start(CallableListener callback, uint64_t interval_ns,
                    uint64_t sample_count) {
  if (!callback || !interval_ns || !sample_count || running.exchange(true)) {
    return false;
  }
  if (worker.joinable()) worker.join();
  worker = std::thread([=] {
    auto next = Clock::now();
    for (uint64_t sequence = 0; sequence < sample_count; ++sequence) {
      next += std::chrono::nanoseconds(interval_ns);
      std::this_thread::sleep_until(next);
      callback(now_ns(), sequence);
    }
    running.store(false);
  });
  return true;
}

void callable_join() {
  if (worker.joinable()) worker.join();
}
