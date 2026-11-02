// A value or a failure Status, without exceptions (C++17 has no std::expected).

#ifndef VOICE_CORE_SRC_COMMON_EXPECTED_H_
#define VOICE_CORE_SRC_COMMON_EXPECTED_H_

#include <utility>
#include <variant>

#include "common/status.h"

namespace voice_core {

template <typename T>
class Expected {
 public:
  // Implicit on purpose: `return value;` and `return Status::kCodec;` both read
  // naturally. The T&& overload lets `return local;` move a move-only value.
  Expected(const T& value) : storage_(value) {}             // NOLINT(google-explicit-constructor)
  Expected(T&& value) noexcept : storage_(std::move(value)) {}  // NOLINT(google-explicit-constructor)
  Expected(Status failure) noexcept : storage_(failure) {}      // NOLINT(google-explicit-constructor)

  [[nodiscard]] bool hasValue() const noexcept { return std::holds_alternative<T>(storage_); }
  explicit operator bool() const noexcept { return hasValue(); }

  /// The value. Only valid when hasValue() is true.
  [[nodiscard]] T& value() & noexcept { return *std::get_if<T>(&storage_); }
  [[nodiscard]] const T& value() const& noexcept { return *std::get_if<T>(&storage_); }
  [[nodiscard]] T&& value() && noexcept { return std::move(*std::get_if<T>(&storage_)); }

  /// kOk when a value is present, the failure otherwise.
  [[nodiscard]] Status status() const noexcept {
    const Status* failure = std::get_if<Status>(&storage_);
    return failure == nullptr ? Status::kOk : *failure;
  }

 private:
  std::variant<T, Status> storage_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_COMMON_EXPECTED_H_
