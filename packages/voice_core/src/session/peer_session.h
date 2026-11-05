// Phase 1 session: one client and one host exchanging audio over UDP only
// (docs/PROTOCOL.md, section 3). Single-threaded and free of real time: the
// media loop feeds it captured frames, received datagrams and ticks.
//
// Client: sends to host_ip:audio_port and accepts datagrams only from there.
// Host: adopts the first valid source as its peer (forgotten when the link
// goes down), sends its microphone to it, or reflects the peer's audio in
// echo mode.

#ifndef VOICE_CORE_SRC_SESSION_PEER_SESSION_H_
#define VOICE_CORE_SRC_SESSION_PEER_SESSION_H_

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>

#include "codec/opus_codec.h"
#include "common/expected.h"
#include "config/core_config.h"
#include "events/core_event.h"
#include "jitter/jitter_buffer.h"
#include "net/audio_packet.h"
#include "net/datagram_socket.h"
#include "stats/interarrival_jitter.h"
#include "stats/loss_tracker.h"
#include "stats/rtt_estimator.h"

namespace voice_core {

struct SessionStats {
  bool linkUp = false;
  float lossPct = 0.0F;
  float jitterMs = 0.0F;
  int jitterBufferMs = 0;
  int jitterTargetMs = 0;
  int rttMs = -1;
  float inputLevel = 0.0F;  // peak of the last captured frame, 0..1
  uint32_t packetsSent = 0;
  uint32_t packetsReceived = 0;
  uint32_t packetsLost = 0;  // sequence gaps (network loss)
  uint32_t packetsLate = 0;  // arrived after their playout time
  uint32_t fecRecovered = 0;
  uint32_t concealedFrames = 0;
  uint32_t malformedPackets = 0;
  uint32_t foreignPackets = 0;  // from an address that is not the peer
  uint32_t sendErrors = 0;
  uint32_t codecErrors = 0;
};

class PeerSession {
 public:
  /// Builds the session and its Opus encoder/decoder. `config` must be valid.
  static Expected<std::unique_ptr<PeerSession>> create(const CoreConfig& config,
                                                       IDatagramSocket& socket,
                                                       IEventSink& events);

  /// One captured frame (frameSamples samples). `transmit` is the voice gate's
  /// decision (detector, push to talk, mute); the level is measured either way.
  void onCaptureFrame(const int16_t* pcm, bool transmit) noexcept;

  void onDatagram(const uint8_t* data, std::size_t size, const Endpoint& from,
                  uint64_t arrivalUs) noexcept;

  /// Fills one frame (frameSamples samples) to play.
  void producePlayoutFrame(int16_t* out) noexcept;

  /// Keepalives, link timeout and the loss window. Call at least every frame.
  void tick(uint64_t nowUs);

  void setOutputGain(float gain) noexcept { outputGain_ = gain; }

  [[nodiscard]] SessionStats stats() const noexcept;
  [[nodiscard]] std::optional<Endpoint> peer() const noexcept { return peer_; }

 private:
  PeerSession(const CoreConfig& config, IDatagramSocket& socket, IEventSink& events,
              OpusFrameEncoder encoder, OpusFrameDecoder decoder,
              std::optional<Endpoint> peer) noexcept;

  [[nodiscard]] bool acceptsSource(const Endpoint& from) const noexcept;
  void noteReceived(const Endpoint& from, uint64_t arrivalUs);
  void handleKeepalive(const ParsedPacket& packet, const Endpoint& from, uint64_t arrivalUs);
  void handleAudio(const ParsedPacket& packet, const uint8_t* data, std::size_t size,
                   const Endpoint& from, uint64_t arrivalUs) noexcept;
  void sendKeepalive(KeepaliveKind kind, uint32_t originMs, const Endpoint& to) noexcept;
  bool send(std::size_t size, const Endpoint& to) noexcept;
  void linkDown();
  void applyGain(int16_t* pcm) const noexcept;

  const CoreConfig config_;
  IDatagramSocket& socket_;
  IEventSink& events_;
  OpusFrameEncoder encoder_;
  OpusFrameDecoder decoder_;
  JitterBuffer jitter_;
  LossTracker loss_;
  InterarrivalJitter interarrival_;
  RttEstimator rtt_;

  const uint8_t localId_;
  const bool clientRole_;
  std::optional<Endpoint> peer_;  // fixed for the client, learned by the host

  uint16_t seq_ = 0;
  uint32_t timestamp_ = 0;
  bool inGap_ = true;  // the next sent frame starts a talkspurt
  float outputGain_ = 1.0F;
  float inputLevel_ = 0.0F;

  bool linkUp_ = false;
  uint64_t lastReceiveUs_ = 0;
  bool keepaliveSent_ = false;
  uint64_t lastKeepaliveUs_ = 0;
  bool statsWindowStarted_ = false;
  uint64_t statsWindowStartUs_ = 0;
  float lossPct_ = 0.0F;

  uint32_t packetsSent_ = 0;
  uint32_t packetsReceived_ = 0;
  uint32_t malformed_ = 0;
  uint32_t foreign_ = 0;
  uint32_t sendErrors_ = 0;
  uint32_t codecErrors_ = 0;

  std::array<uint8_t, kMaxDatagramBytes> sendBuffer_{};
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_SESSION_PEER_SESSION_H_
