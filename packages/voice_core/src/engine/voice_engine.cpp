#include "engine/voice_engine.h"

#include <chrono>
#include <thread>
#include <utility>

#include "audio/audio_pipelines.h"
#include "audio/spsc_ring_buffer.h"
#include "engine/media_loop.h"
#include "engine/network_pump.h"

namespace voice_core {
namespace {

// Ring capacities. They bound memory, not latency: the media loop keeps the
// rings almost empty in steady state.
constexpr std::size_t kCaptureRingFrames = 8;
// Room for the largest device callback seen in practice (the emulator asks
// for tens of ms at once) plus the frame being decoded.
constexpr std::size_t kPlayoutRingFrames = 16;
constexpr std::size_t kInboundDatagrams = 64;
// Android applies a new call route asynchronously, and a route change that
// lands while the streams start disconnects them. A second, fresh device opens
// on the new route.
constexpr int kDeviceStartAttempts = 2;

}  // namespace

// Everything that exists only while the engine runs. Members are declared in
// dependency order, so they are built and destroyed in the right order.
struct VoiceEngine::Running {
  Running(const CoreConfig& sessionConfig, std::unique_ptr<IDatagramSocket> openedSocket,
          std::unique_ptr<PeerSession> createdSession, const IClock& clock)
      : config(sessionConfig),
        socket(std::move(openedSocket)),
        session(std::move(createdSession)),
        capture(static_cast<std::size_t>(config.frameSamples) * kCaptureRingFrames),
        playout(static_cast<std::size_t>(config.frameSamples) * kPlayoutRingFrames),
        inbound(kInboundDatagrams),
        capturePipeline(capture),
        playoutPipeline(playout),
        callback(capturePipeline, playoutPipeline),
        loop(*session, capture, playout, playoutPipeline, inbound, config),
        pump(*socket, inbound, clock) {}

  const CoreConfig config;
  std::unique_ptr<IDatagramSocket> socket;
  std::unique_ptr<PeerSession> session;
  SpscRingBuffer<int16_t> capture;
  SpscRingBuffer<int16_t> playout;
  SpscRingBuffer<InboundDatagram> inbound;
  CapturePipeline capturePipeline;
  PlayoutPipeline playoutPipeline;
  DuplexAudioCallback callback;
  MediaLoop loop;
  NetworkPump pump;
  std::unique_ptr<IAudioDevice> device;
  std::atomic<bool> stopRequested{false};
  std::thread media;
  std::thread network;
};

VoiceEngine::VoiceEngine(EngineDependencies dependencies) noexcept
    : dependencies_(dependencies) {}

VoiceEngine::~VoiceEngine() { stop(); }

Status VoiceEngine::init(const CoreConfig& config) {
  const std::lock_guard<std::mutex> lock(lifecycleMutex_);
  if (running_) {
    return Status::kInvalidState;
  }
  if (validate(config) != ConfigError::kNone) {
    return Status::kInvalidArgument;
  }
  config_ = config;
  return Status::kOk;
}

Status VoiceEngine::start() {
  const std::lock_guard<std::mutex> lock(lifecycleMutex_);
  if (!config_ || running_) {
    return Status::kInvalidState;
  }
  const Status status = startLocked(*config_);
  if (status == Status::kOk) {
    events_.emit(StateChangedEvent{EngineState::kRunning, Status::kOk});
  } else {
    events_.emit(StateChangedEvent{EngineState::kFailed, status});
  }
  return status;
}

Status VoiceEngine::startLocked(const CoreConfig& config) {
  UdpSocketOptions socketOptions;
  socketOptions.port = config.role == Role::kHost ? config.audioPort : uint16_t{0};
  socketOptions.dscp = config.audioDscp;
  Expected<std::unique_ptr<IDatagramSocket>> socket =
      dependencies_.sockets.openUdp(socketOptions);
  if (!socket) {
    return socket.status();
  }
  Expected<std::unique_ptr<PeerSession>> session =
      PeerSession::create(config, *socket.value(), events_);
  if (!session) {
    return session.status();
  }
  auto running = std::make_unique<Running>(config, std::move(socket).value(),
                                           std::move(session).value(), dependencies_.clock);
  AudioDeviceParams deviceParams;
  deviceParams.sampleRateHz = config.sampleRateHz;
  deviceParams.periodFrames = config.msToSamples(config.devicePeriodMs);
  Status deviceStatus = Status::kAudioDevice;
  for (int attempt = 0; attempt < kDeviceStartAttempts && deviceStatus != Status::kOk; ++attempt) {
    running->device = dependencies_.audio.create(deviceParams);
    deviceStatus = running->device->start(running->callback);
  }
  if (deviceStatus != Status::kOk) {
    return deviceStatus;
  }
  muted_.store(false, std::memory_order_relaxed);
  {
    const std::lock_guard<std::mutex> statsLock(statsMutex_);
    stats_ = EngineStats{};
  }
  Running& handle = *running;
  running->network = std::thread([this, &handle] { networkThread(handle); });
  running->media = std::thread([this, &handle] { mediaThread(handle); });
  running_ = std::move(running);
  return Status::kOk;
}

void VoiceEngine::stop() {
  const std::lock_guard<std::mutex> lock(lifecycleMutex_);
  if (!running_) {
    return;
  }
  stopLocked();
  events_.emit(StateChangedEvent{EngineState::kStopped, Status::kOk});
}

void VoiceEngine::stopLocked() {
  running_->stopRequested.store(true, std::memory_order_release);
  running_->device->stop();  // no more callbacks touch the rings
  running_->network.join();
  running_->media.join();
  running_.reset();
}

bool VoiceEngine::running() const {
  const std::lock_guard<std::mutex> lock(lifecycleMutex_);
  return running_ != nullptr;
}

bool VoiceEngine::readStats(EngineStats* out) const {
  if (!running()) {
    return false;
  }
  const std::lock_guard<std::mutex> lock(statsMutex_);
  *out = stats_;
  return true;
}

void VoiceEngine::mediaThread(Running& running) {
  const auto period = std::chrono::milliseconds(running.config.mediaLoopPeriodMs);
  while (!running.stopRequested.load(std::memory_order_acquire)) {
    running.session->setMuted(muted_.load(std::memory_order_relaxed));
    running.session->setOutputGain(outputGain_.load(std::memory_order_relaxed));
    running.loop.runOnce(dependencies_.clock.nowUs());
    publishStats(running);
    std::this_thread::sleep_for(period);
  }
}

void VoiceEngine::networkThread(Running& running) const {
  const int pollMs = running.config.networkPollMs;
  while (!running.stopRequested.load(std::memory_order_acquire)) {
    if (!running.pump.runOnce(pollMs)) {
      // A socket error (e.g. the network went away): back off, keep trying.
      std::this_thread::sleep_for(std::chrono::milliseconds(pollMs));
    }
  }
}

void VoiceEngine::publishStats(const Running& running) {
  EngineStats stats;
  stats.session = running.session->stats();
  stats.playoutUnderruns = running.playoutPipeline.underruns();
  stats.captureOverruns = running.capturePipeline.overruns();
  stats.inboundDropped = running.pump.dropped();
  const std::lock_guard<std::mutex> lock(statsMutex_);
  stats_ = stats;
}

}  // namespace voice_core
