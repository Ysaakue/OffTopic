// Test-only heap allocation counter.
//
// The test binary replaces the global operator new/delete (see
// allocation_guard.cpp), so every heap allocation made through new,
// std::vector, std::string, std::function, etc. is counted. Real-time code
// paths (audio callbacks, pipelines) assert that they perform zero allocations.

#ifndef VOICE_CORE_TESTS_SUPPORT_ALLOCATION_GUARD_H_
#define VOICE_CORE_TESTS_SUPPORT_ALLOCATION_GUARD_H_

#include <cstddef>

// ThreadSanitizer ships its own operator new, so the replacement (and the
// counting) is compiled only when VC_COUNT_ALLOCATIONS is defined by CMake.
#if defined(VC_COUNT_ALLOCATIONS)
#define VC_ALLOCATION_COUNTING_SUPPORTED 1
#else
#define VC_ALLOCATION_COUNTING_SUPPORTED 0
#endif

/// Skips the current GoogleTest test when allocations cannot be counted.
#define VC_SKIP_WITHOUT_ALLOCATION_COUNTING()                                   \
  do {                                                                          \
    if (!VC_ALLOCATION_COUNTING_SUPPORTED) {                                    \
      GTEST_SKIP() << "Allocation counting is unavailable in this build "      \
                      "(ThreadSanitizer replaces operator new).";               \
    }                                                                           \
  } while (false)

namespace voice_core::testing {

/// Counts the heap allocations made by the current thread while it is alive.
class AllocationGuard {
 public:
  AllocationGuard();
  ~AllocationGuard() = default;

  AllocationGuard(const AllocationGuard&) = delete;
  AllocationGuard& operator=(const AllocationGuard&) = delete;
  AllocationGuard(AllocationGuard&&) = delete;
  AllocationGuard& operator=(AllocationGuard&&) = delete;

  /// Number of allocations made by this thread since the guard was created.
  [[nodiscard]] std::size_t allocations() const;

 private:
  std::size_t start_;
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_SUPPORT_ALLOCATION_GUARD_H_
