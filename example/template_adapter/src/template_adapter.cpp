#include "template_adapter.h"
#include "accumulator.hpp"
#include <cstdint>
#include <memory>

namespace {

// The non-template interface erases T from the ABI-facing object.
class AccumulatorInterface {
public:
  virtual ~AccumulatorInterface() = default;
  virtual void add(const void *value) = 0;
  virtual void get(void *output) const = 0;
};

// Each supported T gets one concrete adapter instantiation.
template <typename T>
class AccumulatorAdapter final : public AccumulatorInterface {
public:
  void add(const void *value) override {
    accumulator_.add(*static_cast<const T *>(value));
  }

  void get(void *output) const override {
    *static_cast<T *>(output) = accumulator_.value();
  }

private:
  Accumulator<T> accumulator_;
};

using Factory = std::unique_ptr<AccumulatorInterface> (*)();

template <typename T> std::unique_ptr<AccumulatorInterface> createAdapter() {
  return std::make_unique<AccumulatorAdapter<T>>();
}

struct FactoryEntry {
  ValueType type;
  Factory factory;
};

constexpr FactoryEntry kFactories[] = {
    {INT32, createAdapter<std::int32_t>},
    {DOUBLE, createAdapter<double>},
};

Factory findFactory(ValueType type) {
  for (const auto &entry : kFactories) {
    if (entry.type == type) {
      return entry.factory;
    }
  }
  return nullptr;
}

AccumulatorInterface *fromHandle(Handle handle) {
  return reinterpret_cast<AccumulatorInterface *>(handle);
}

} // namespace

Handle accumulator_create(ValueType_t type) {
  const Factory factory = findFactory(static_cast<ValueType>(type));
  if (factory == nullptr) {
    return 0;
  }
  return reinterpret_cast<Handle>(factory().release());
}

bool accumulator_add(Handle handle, const void *value) {
  if (handle == 0 || value == nullptr) {
    return false;
  }
  fromHandle(handle)->add(value);
  return true;
}

bool accumulator_get(Handle handle, void *output) {
  if (handle == 0 || output == nullptr) {
    return false;
  }
  fromHandle(handle)->get(output);
  return true;
}

void accumulator_dispose(Handle handle) { delete fromHandle(handle); }
