// Loopback simulator (phase 1): a client and an echo-mode host run in one
// process on localhost, with a proxy between them that drops, delays and
// reorders datagrams. The client "speaks" a short tone burst once per second;
// the time until the echo comes back out of its playout is the audio round
// trip (codec, network, both jitter buffers), without the device latencies.
//
// Usage: loopback_sim [--seconds=N] [--loss=0.05] [--jitter-ms=40]
//                     [--reorder=0.02] [--delay-ms=5] [--seed=1]
// Exit status: 0 when at least half of the bursts came back.

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <map>
#include <memory>
#include <mutex>
#include <random>
#include <string>
#include <thread>
#include <vector>

#include "common/clock.h"
#include "config/core_config.h"
#include "events/core_event.h"
#include "net/audio_packet.h"
#include "net/network_binder.h"
#include "net/posix_udp_socket.h"
#include "session/peer_session.h"

namespace {

using voice_core::CoreConfig;
using voice_core::Endpoint;
using voice_core::IDatagramSocket;
using voice_core::PeerSession;
using voice_core::ReceiveResult;

constexpr uint32_t kLoopback = 0x7F000001;
constexpr int kFrameMs = 20;
constexpr int kLoopPeriodMs = 2;  // like CoreConfig::mediaLoopPeriodMs
constexpr int kStepsPerFrame = kFrameMs / kLoopPeriodMs;
constexpr int kFrameSamples = 320;
constexpr int kFramesPerBurst = 50;  // one burst per second
constexpr double kBurstHz = 1000.0;
constexpr double kBurstAmplitude = 16000.0;
constexpr int kDetectThreshold = 4000;
constexpr double kPi = 3.14159265358979323846;

struct Options {
  int seconds = 10;
  double loss = 0.0;
  int jitterMs = 0;
  double reorder = 0.0;
  int delayMs = 2;
  unsigned seed = 1;
};

bool parseFlag(const std::string& arg, const char* name, std::string* value) {
  const std::string prefix = std::string("--") + name + "=";
  if (arg.rfind(prefix, 0) != 0) {
    return false;
  }
  *value = arg.substr(prefix.size());
  return true;
}

Options parseOptions(int argc, char** argv) {
  Options options;
  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    std::string value;
    if (parseFlag(arg, "seconds", &value)) {
      options.seconds = std::stoi(value);
    } else if (parseFlag(arg, "loss", &value)) {
      options.loss = std::stod(value);
    } else if (parseFlag(arg, "jitter-ms", &value)) {
      options.jitterMs = std::stoi(value);
    } else if (parseFlag(arg, "reorder", &value)) {
      options.reorder = std::stod(value);
    } else if (parseFlag(arg, "delay-ms", &value)) {
      options.delayMs = std::stoi(value);
    } else if (parseFlag(arg, "seed", &value)) {
      options.seed = static_cast<unsigned>(std::stoul(value));
    } else {
      std::fprintf(stderr, "unknown option %s\n", arg.c_str());
      std::exit(2);
    }
  }
  return options;
}

std::unique_ptr<IDatagramSocket> openSocket(voice_core::INetworkBinder& binder) {
  auto socket = voice_core::PosixUdpSocket::open(voice_core::UdpSocketOptions{}, binder);
  if (!socket) {
    std::fprintf(stderr, "cannot open a UDP socket\n");
    std::exit(1);
  }
  return std::move(socket).value();
}

class NullSink final : public voice_core::IEventSink {
 public:
  void emit(const voice_core::CoreEvent& /*event*/) override {}
};

// Forwards datagrams between the client (side A) and the host (side B),
// applying loss, delay, jitter and reordering.
class LossyProxy {
 public:
  LossyProxy(const Options& options, voice_core::INetworkBinder& binder, Endpoint host)
      : options_(options),
        random_(options.seed),
        clientSide_(openSocket(binder)),
        hostSide_(openSocket(binder)),
        host_(host) {}

  [[nodiscard]] uint16_t clientFacingPort() const { return clientSide_->localPort(); }

  void start() {
    thread_ = std::thread([this] { run(); });
  }

  void stop() {
    running_ = false;
    thread_.join();
  }

  [[nodiscard]] uint32_t dropped() const { return dropped_; }
  [[nodiscard]] uint32_t forwarded() const { return forwarded_; }

 private:
  struct Pending {
    std::vector<uint8_t> bytes;
    bool towardsHost;
  };

  void run() {
    std::array<uint8_t, voice_core::kMaxDatagramBytes> buffer{};
    while (running_) {
      bool idle = true;
      ReceiveResult fromClient = clientSide_->receive(buffer.data(), buffer.size(), 0);
      if (fromClient.kind == ReceiveResult::Kind::kDatagram) {
        client_ = fromClient.from;
        schedule(buffer.data(), fromClient.size, true);
        idle = false;
      }
      ReceiveResult fromHost = hostSide_->receive(buffer.data(), buffer.size(), 0);
      if (fromHost.kind == ReceiveResult::Kind::kDatagram) {
        schedule(buffer.data(), fromHost.size, false);
        idle = false;
      }
      flushDue();
      if (idle) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
      }
    }
  }

  void schedule(const uint8_t* data, std::size_t size, bool towardsHost) {
    std::uniform_real_distribution<double> unit(0.0, 1.0);
    if (unit(random_) < options_.loss) {
      ++dropped_;
      return;
    }
    double delayMs = options_.delayMs + unit(random_) * options_.jitterMs;
    if (unit(random_) < options_.reorder) {
      delayMs += kFrameMs * 2;  // overtaken by the next packets
    }
    const auto due = std::chrono::steady_clock::now() +
                     std::chrono::microseconds(static_cast<int64_t>(delayMs * 1000.0));
    queue_.emplace(due, Pending{std::vector<uint8_t>(data, data + size), towardsHost});
  }

  void flushDue() {
    const auto now = std::chrono::steady_clock::now();
    while (!queue_.empty() && queue_.begin()->first <= now) {
      const Pending& pending = queue_.begin()->second;
      if (pending.towardsHost) {
        hostSide_->sendTo(pending.bytes.data(), pending.bytes.size(), host_);
      } else {
        clientSide_->sendTo(pending.bytes.data(), pending.bytes.size(), client_);
      }
      ++forwarded_;
      queue_.erase(queue_.begin());
    }
  }

  const Options options_;
  std::mt19937 random_;
  std::unique_ptr<IDatagramSocket> clientSide_;
  std::unique_ptr<IDatagramSocket> hostSide_;
  const Endpoint host_;
  Endpoint client_;
  std::multimap<std::chrono::steady_clock::time_point, Pending> queue_;
  std::atomic<bool> running_{true};
  std::atomic<uint32_t> dropped_{0};
  std::atomic<uint32_t> forwarded_{0};
  std::thread thread_;
};

void drain(IDatagramSocket& socket, PeerSession& session, const voice_core::IClock& clock) {
  std::array<uint8_t, voice_core::kMaxDatagramBytes> buffer{};
  for (;;) {
    const ReceiveResult result = socket.receive(buffer.data(), buffer.size(), 0);
    if (result.kind != ReceiveResult::Kind::kDatagram) {
      return;
    }
    session.onDatagram(buffer.data(), result.size, result.from, clock.nowUs());
  }
}

std::vector<int16_t> makeBurst() {
  std::vector<int16_t> frame(kFrameSamples);
  for (int i = 0; i < kFrameSamples; ++i) {
    frame[static_cast<std::size_t>(i)] = static_cast<int16_t>(std::lround(
        kBurstAmplitude * std::sin(2.0 * kPi * kBurstHz * i / CoreConfig{}.sampleRateHz)));
  }
  return frame;
}

int peak(const std::vector<int16_t>& frame) {
  int value = 0;
  for (const int16_t sample : frame) {
    value = std::max(value, std::abs(static_cast<int>(sample)));
  }
  return value;
}

}  // namespace

int main(int argc, char** argv) {
  const Options options = parseOptions(argc, argv);
  voice_core::NoopNetworkBinder binder;
  voice_core::SteadyClock clock;
  NullSink events;

  std::unique_ptr<IDatagramSocket> hostSocket = openSocket(binder);
  LossyProxy proxy(options, binder, Endpoint{kLoopback, hostSocket->localPort()});
  std::unique_ptr<IDatagramSocket> clientSocket = openSocket(binder);

  CoreConfig hostConfig;
  hostConfig.role = voice_core::Role::kHost;
  hostConfig.displayName = "host";
  hostConfig.echoMode = true;
  CoreConfig clientConfig;
  clientConfig.displayName = "client";
  clientConfig.hostIp = "127.0.0.1";
  clientConfig.audioPort = proxy.clientFacingPort();  // the client talks to the proxy
  if (voice_core::validate(hostConfig) != voice_core::ConfigError::kNone ||
      voice_core::validate(clientConfig) != voice_core::ConfigError::kNone) {
    std::fprintf(stderr, "invalid configuration\n");
    return 1;
  }
  auto host = PeerSession::create(hostConfig, *hostSocket, events);
  auto client = PeerSession::create(clientConfig, *clientSocket, events);
  if (!host || !client) {
    std::fprintf(stderr, "cannot create the sessions\n");
    return 1;
  }
  PeerSession& hostSession = *host.value();
  PeerSession& clientSession = *client.value();

  const std::vector<int16_t> burst = makeBurst();
  const std::vector<int16_t> silence(kFrameSamples, 0);
  std::vector<int16_t> played(kFrameSamples);
  std::vector<int> latenciesMs;
  int bursts = 0;
  int burstFrame = -1;
  bool detected = true;

  proxy.start();
  // The media loop of each phone, run every 2 ms; capture and playout happen
  // once per 20 ms frame, as the audio device would drive them.
  const int frames = options.seconds * 1000 / kFrameMs;
  auto next = std::chrono::steady_clock::now();
  for (int step = 0; step < frames * kStepsPerFrame; ++step) {
    next += std::chrono::milliseconds(kLoopPeriodMs);
    drain(*hostSocket, hostSession, clock);
    drain(*clientSocket, clientSession, clock);
    if (step % kStepsPerFrame == 0) {
      const int frame = step / kStepsPerFrame;
      const bool speak = frame % kFramesPerBurst == kFramesPerBurst / 2;
      clientSession.onCaptureFrame(speak ? burst.data() : silence.data(), true);
      hostSession.onCaptureFrame(silence.data(), true);  // echo mode: not sent
      if (speak) {
        ++bursts;
        burstFrame = frame;
        detected = false;
      }
      // The echo-mode host buffers nothing, so only the client plays audio.
      clientSession.producePlayoutFrame(played.data());
      if (!detected && peak(played) > kDetectThreshold) {
        latenciesMs.push_back((frame - burstFrame) * kFrameMs);
        detected = true;
      }
    }
    hostSession.tick(clock.nowUs());
    clientSession.tick(clock.nowUs());
    std::this_thread::sleep_until(next);
  }
  proxy.stop();

  const voice_core::SessionStats stats = clientSession.stats();
  std::printf("loopback_sim: %d s, loss %.1f %%, jitter 0..%d ms, reorder %.1f %%, seed %u\n",
              options.seconds, options.loss * 100.0, options.jitterMs, options.reorder * 100.0,
              options.seed);
  std::printf("  proxy: %u forwarded, %u dropped\n", proxy.forwarded(), proxy.dropped());
  std::printf("  bursts: %d sent, %zu came back\n", bursts, latenciesMs.size());
  if (!latenciesMs.empty()) {
    const auto [minIt, maxIt] = std::minmax_element(latenciesMs.begin(), latenciesMs.end());
    double sum = 0.0;
    for (const int latency : latenciesMs) {
      sum += latency;
    }
    std::printf("  audio round trip: min %d ms, avg %.0f ms, max %d ms (frame resolution)\n",
                *minIt, sum / static_cast<double>(latenciesMs.size()), *maxIt);
  }
  std::printf("  client: loss %.1f %%, jitter %.1f ms, buffer %d/%d ms, rtt %d ms\n",
              static_cast<double>(stats.lossPct), static_cast<double>(stats.jitterMs),
              stats.jitterBufferMs, stats.jitterTargetMs, stats.rttMs);
  std::printf("  client: %u received, %u lost, %u late, %u fec, %u concealed\n",
              stats.packetsReceived, stats.packetsLost, stats.packetsLate, stats.fecRecovered,
              stats.concealedFrames);
  return latenciesMs.size() * 2 >= static_cast<std::size_t>(bursts) ? 0 : 1;
}
