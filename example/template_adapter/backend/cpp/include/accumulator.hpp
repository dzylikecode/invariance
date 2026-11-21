#pragma once
// This is the ordinary template we want to make available to Dart.
template <typename T> class Accumulator {
public:
  void add(T value) { value_ += value; }
  T value() const { return value_; }

private:
  T value_{};
};