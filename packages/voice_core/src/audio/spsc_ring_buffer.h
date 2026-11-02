// Lock-free single-producer / single-consumer ring buffer.
//
// The only memory allocation happens in the constructor; push/pop/read/write
// never allocate, lock or block, so they are safe inside the audio callback.
// Exactly one thread may produce and exactly one thread may consume.

#ifndef VOICE_CORE_SRC_AUDIO_SPSC_RING_BUFFER_H_
#define VOICE_CORE_SRC_AUDIO_SPSC_RING_BUFFER_H_

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <cstring>
#include <memory>
#include <type_traits>

namespace voice_core {

template <typename T>
class SpscRingBuffer {
  static_assert(std::is_trivially_copyable_v<T>, "elements are copied with memcpy");

 public:
  /// Capacity is rounded up to the next power of two (at least 1).
  explicit SpscRingBuffer(std::size_t minCapacity)
      : capacity_(roundUpToPowerOfTwo(minCapacity)),
        mask_(capacity_ - 1),
        storage_(std::make_unique<T[]>(capacity_)) {}

  SpscRingBuffer(const SpscRingBuffer&) = delete;
  SpscRingBuffer& operator=(const SpscRingBuffer&) = delete;
  SpscRingBuffer(SpscRingBuffer&&) = delete;
  SpscRingBuffer& operator=(SpscRingBuffer&&) = delete;
  ~SpscRingBuffer() = default;

  [[nodiscard]] std::size_t capacity() const noexcept { return capacity_; }

  /// Elements ready to read. Exact on the consumer, a lower bound elsewhere.
  [[nodiscard]] std::size_t size() const noexcept {
    return head_.load(std::memory_order_acquire) - tail_.load(std::memory_order_acquire);
  }

  /// Free slots. Exact on the producer, a lower bound elsewhere.
  [[nodiscard]] std::size_t freeSpace() const noexcept { return capacity_ - size(); }

  /// Producer: appends one element; false when full.
  bool push(const T& value) noexcept { return write(&value, 1) == 1; }

  /// Consumer: removes one element; false when empty.
  bool pop(T* out) noexcept { return read(out, 1) == 1; }

  /// Producer: copies up to `count` elements; returns how many were written.
  std::size_t write(const T* data, std::size_t count) noexcept {
    const std::size_t head = head_.load(std::memory_order_relaxed);
    const std::size_t tail = tail_.load(std::memory_order_acquire);
    const std::size_t n = std::min(count, capacity_ - (head - tail));
    copyIn(head, data, n);
    head_.store(head + n, std::memory_order_release);
    return n;
  }

  /// Consumer: copies up to `count` elements out; returns how many were read.
  std::size_t read(T* out, std::size_t count) noexcept {
    const std::size_t tail = tail_.load(std::memory_order_relaxed);
    const std::size_t head = head_.load(std::memory_order_acquire);
    const std::size_t n = std::min(count, head - tail);
    copyOut(tail, out, n);
    tail_.store(tail + n, std::memory_order_release);
    return n;
  }

 private:
  // Keeps the producer and consumer indices on separate cache lines.
  static constexpr std::size_t kCacheLineBytes = 64;

  static std::size_t roundUpToPowerOfTwo(std::size_t value) noexcept {
    std::size_t capacity = 1;
    while (capacity < value) {
      capacity <<= 1U;
    }
    return capacity;
  }

  void copyIn(std::size_t head, const T* data, std::size_t n) noexcept {
    const std::size_t start = head & mask_;
    const std::size_t first = std::min(n, capacity_ - start);
    copyElements(&storage_[start], data, first);
    copyElements(&storage_[0], data + first, n - first);
  }

  void copyOut(std::size_t tail, T* out, std::size_t n) const noexcept {
    const std::size_t start = tail & mask_;
    const std::size_t first = std::min(n, capacity_ - start);
    copyElements(out, &storage_[start], first);
    copyElements(out + first, &storage_[0], n - first);
  }

  static void copyElements(T* destination, const T* source, std::size_t n) noexcept {
    if (n > 0) {
      std::memcpy(destination, source, n * sizeof(T));
    }
  }

  const std::size_t capacity_;
  const std::size_t mask_;
  const std::unique_ptr<T[]> storage_;  // NOLINT(cppcoreguidelines-avoid-c-arrays)
  alignas(kCacheLineBytes) std::atomic<std::size_t> head_{0};  // next slot to write
  alignas(kCacheLineBytes) std::atomic<std::size_t> tail_{0};  // next slot to read
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_AUDIO_SPSC_RING_BUFFER_H_
