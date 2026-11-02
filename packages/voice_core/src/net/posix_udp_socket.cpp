#include "net/posix_udp_socket.h"

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>

namespace voice_core {
namespace {

constexpr int kDscpShift = 2;         // DSCP occupies the upper six bits of the TOS byte
constexpr uint32_t kAnyAddress = 0;  // INADDR_ANY, without the macro's C-style cast

// RAII guard that closes a descriptor unless released.
class FdGuard {
 public:
  explicit FdGuard(int fd) noexcept : fd_(fd) {}
  ~FdGuard() {
    if (fd_ >= 0) {
      ::close(fd_);
    }
  }
  FdGuard(const FdGuard&) = delete;
  FdGuard& operator=(const FdGuard&) = delete;
  FdGuard(FdGuard&&) = delete;
  FdGuard& operator=(FdGuard&&) = delete;

  [[nodiscard]] int get() const noexcept { return fd_; }
  int release() noexcept {
    const int fd = fd_;
    fd_ = -1;
    return fd;
  }

 private:
  int fd_;
};

sockaddr_in toSockaddr(const Endpoint& endpoint) noexcept {
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(endpoint.address);
  address.sin_port = htons(endpoint.port);
  return address;
}

}  // namespace

Expected<std::unique_ptr<IDatagramSocket>> PosixUdpSocket::open(const UdpSocketOptions& options,
                                                                INetworkBinder& binder) {
  FdGuard fd(::socket(AF_INET, SOCK_DGRAM, 0));
  // GCOVR_EXCL_START: socket()/fcntl() only fail when the process runs out of
  // descriptors, which a unit test cannot provoke safely.
  if (fd.get() < 0) {
    return Status::kNetwork;
  }
  const int flags = ::fcntl(fd.get(), F_GETFL, 0);
  if (flags < 0 || ::fcntl(fd.get(), F_SETFL, flags | O_NONBLOCK) < 0 ||
      ::fcntl(fd.get(), F_SETFD, FD_CLOEXEC) < 0) {
    return Status::kNetwork;
  }
  // GCOVR_EXCL_STOP
  if (!binder.bindSocket(fd.get())) {
    return Status::kNetwork;
  }
  // Best effort: some networks ignore or strip the code point.
  const int tos = options.dscp << kDscpShift;
  ::setsockopt(fd.get(), IPPROTO_IP, IP_TOS, &tos, sizeof(tos));

  const sockaddr_in local = toSockaddr(Endpoint{kAnyAddress, options.port});
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast): POSIX sockaddr API
  if (::bind(fd.get(), reinterpret_cast<const sockaddr*>(&local), sizeof(local)) != 0) {
    return Status::kNetwork;
  }
  sockaddr_in bound{};
  socklen_t boundSize = sizeof(bound);
  // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast): POSIX sockaddr API
  ::getsockname(fd.get(), reinterpret_cast<sockaddr*>(&bound), &boundSize);
  return std::unique_ptr<IDatagramSocket>(new PosixUdpSocket(fd.release(), ntohs(bound.sin_port)));
}

PosixUdpSocket::~PosixUdpSocket() { ::close(fd_); }

bool PosixUdpSocket::sendTo(const uint8_t* data, std::size_t size, const Endpoint& to) noexcept {
  const sockaddr_in destination = toSockaddr(to);
  const ssize_t sent =
      ::sendto(fd_, data, size, MSG_DONTWAIT,
               // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast): POSIX sockaddr API
               reinterpret_cast<const sockaddr*>(&destination), sizeof(destination));
  return sent == static_cast<ssize_t>(size);
}

ReceiveResult PosixUdpSocket::receive(uint8_t* buffer, std::size_t capacity,
                                      int timeoutMs) noexcept {
  pollfd descriptor{fd_, POLLIN, 0};
  const int ready = ::poll(&descriptor, 1, timeoutMs);
  // GCOVR_EXCL_BR_START: poll() failing (EINTR, POLLERR, POLLNVAL) cannot be
  // provoked deterministically on a healthy socket.
  if (ready == 0 || (ready < 0 && errno == EINTR)) {
    return ReceiveResult{ReceiveResult::Kind::kTimeout, 0, {}};
  }
  if (ready < 0 || (descriptor.revents & POLLIN) == 0) {
    return ReceiveResult{ReceiveResult::Kind::kError, 0, {}};  // GCOVR_EXCL_LINE: see above
  }
  // GCOVR_EXCL_BR_STOP
  sockaddr_in source{};
  socklen_t sourceSize = sizeof(source);
  const ssize_t received =
      ::recvfrom(fd_, buffer, capacity, MSG_DONTWAIT,
                 // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast): POSIX sockaddr API
                 reinterpret_cast<sockaddr*>(&source), &sourceSize);
  if (received < 0) {
    // GCOVR_EXCL_START: a datagram announced by poll() vanished (EAGAIN) or the
    // socket failed between the two calls; not reproducible deterministically.
    const bool transient = errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR;
    return ReceiveResult{transient ? ReceiveResult::Kind::kTimeout : ReceiveResult::Kind::kError, 0,
                         {}};
    // GCOVR_EXCL_STOP
  }
  return ReceiveResult{ReceiveResult::Kind::kDatagram, static_cast<std::size_t>(received),
                       Endpoint{ntohl(source.sin_addr.s_addr), ntohs(source.sin_port)}};
}

}  // namespace voice_core
