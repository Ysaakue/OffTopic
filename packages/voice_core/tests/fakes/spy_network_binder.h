// INetworkBinder that records the descriptors it was asked to bind.

#ifndef VOICE_CORE_TESTS_FAKES_SPY_NETWORK_BINDER_H_
#define VOICE_CORE_TESTS_FAKES_SPY_NETWORK_BINDER_H_

#include <vector>

#include "net/network_binder.h"

namespace voice_core::testing {

class SpyNetworkBinder final : public INetworkBinder {
 public:
  bool bindSocket(int fd) noexcept override {
    descriptors.push_back(fd);
    return result;
  }

  bool result = true;
  std::vector<int> descriptors;
};

}  // namespace voice_core::testing

#endif  // VOICE_CORE_TESTS_FAKES_SPY_NETWORK_BINDER_H_
