#include "callable.h"

#include <atomic>
#include <chrono>
#include <thread>

namespace {
using Clock = std::chrono::steady_clock;
std::atomic<bool> is_running{false};
std::thread producer_thread;

uint64_t now_ns() {
  return static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::nanoseconds>(
          Clock::now().time_since_epoch())
          .count());
}

void produce_samples(CallableListener listener, uint64_t interval_ns,
                     uint64_t sample_count) {
  auto next_sample_time = Clock::now();
  for (uint64_t sequence = 0; sequence < sample_count; ++sequence) {
    next_sample_time += std::chrono::nanoseconds(interval_ns);
    std::this_thread::sleep_until(next_sample_time);

    const auto sent_at_ns = now_ns();
    listener(sent_at_ns, sequence);
  }
  is_running.store(false);
}
}  // namespace

uint64_t callable_now_ns() { return now_ns(); }

bool callable_start(CallableListener listener, uint64_t interval_ns,
                    uint64_t sample_count) {
  const bool invalid_arguments =
      listener == nullptr || interval_ns == 0 || sample_count == 0;
  if (invalid_arguments || is_running.exchange(true)) {
    return false;
  }

  if (producer_thread.joinable()) producer_thread.join();
  producer_thread =
      std::thread(produce_samples, listener, interval_ns, sample_count);
  return true;
}

void callable_join() {
  if (producer_thread.joinable()) producer_thread.join();
}
