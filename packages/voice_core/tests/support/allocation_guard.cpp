#include "support/allocation_guard.h"

#include <cstdlib>
#include <new>

namespace {

thread_local std::size_t threadAllocations = 0;

}  // namespace

namespace voice_core::testing {

AllocationGuard::AllocationGuard() : start_(threadAllocations) {}

std::size_t AllocationGuard::allocations() const { return threadAllocations - start_; }

}  // namespace voice_core::testing

#if VC_ALLOCATION_COUNTING_SUPPORTED

namespace {

void* allocate(std::size_t size) {
  ++threadAllocations;
  if (void* memory = std::malloc(size == 0 ? 1 : size)) {
    return memory;
  }
  throw std::bad_alloc();
}

void* allocateNoThrow(std::size_t size) noexcept {
  ++threadAllocations;
  return std::malloc(size == 0 ? 1 : size);
}

void* allocateAligned(std::size_t size, std::align_val_t alignment) {
  ++threadAllocations;
  const auto align = static_cast<std::size_t>(alignment);
  // aligned_alloc requires the size to be a multiple of the alignment.
  const std::size_t rounded = size == 0 ? align : (size + align - 1) / align * align;
  if (void* memory = std::aligned_alloc(align, rounded)) {
    return memory;
  }
  throw std::bad_alloc();
}

}  // namespace

// Global replacements. Memory always comes from malloc/aligned_alloc and goes
// back through free, so every new/delete pair stays consistent.
void* operator new(std::size_t size) { return allocate(size); }
void* operator new[](std::size_t size) { return allocate(size); }
void* operator new(std::size_t size, const std::nothrow_t& /*tag*/) noexcept {
  return allocateNoThrow(size);
}
void* operator new[](std::size_t size, const std::nothrow_t& /*tag*/) noexcept {
  return allocateNoThrow(size);
}
void* operator new(std::size_t size, std::align_val_t alignment) {
  return allocateAligned(size, alignment);
}
void* operator new[](std::size_t size, std::align_val_t alignment) {
  return allocateAligned(size, alignment);
}

void operator delete(void* memory) noexcept { std::free(memory); }
void operator delete[](void* memory) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t /*size*/) noexcept { std::free(memory); }
void operator delete[](void* memory, std::size_t /*size*/) noexcept { std::free(memory); }
void operator delete(void* memory, const std::nothrow_t& /*tag*/) noexcept { std::free(memory); }
void operator delete[](void* memory, const std::nothrow_t& /*tag*/) noexcept { std::free(memory); }
void operator delete(void* memory, std::align_val_t /*alignment*/) noexcept { std::free(memory); }
void operator delete[](void* memory, std::align_val_t /*alignment*/) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t /*size*/, std::align_val_t /*alignment*/) noexcept {
  std::free(memory);
}
void operator delete[](void* memory, std::size_t /*size*/,
                       std::align_val_t /*alignment*/) noexcept {
  std::free(memory);
}

#endif  // VC_ALLOCATION_COUNTING_SUPPORTED
