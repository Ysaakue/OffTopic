// One iteration of the media thread: received datagrams -> session, captured
// frames -> session (encode + send), decoded frames -> playout ring, then the
// session's timers. Pure logic over rings: the thread that calls runOnce()
// lives in VoiceEngine.

#ifndef VOICE_CORE_SRC_ENGINE_MEDIA_LOOP_H_
#define VOICE_CORE_SRC_ENGINE_MEDIA_LOOP_H_

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

#include "audio/audio_pipelines.h"
#include "audio/spsc_ring_buffer.h"
#include "net/audio_packet.h"
#include "net/endpoint.h"
#include "session/peer_session.h"

namespace voice_core {

/// A received datagram queued by the network thread for the media thread.
struct InboundDatagram {
  std::array<uint8_t, kMaxDatagramBytes> bytes;
  uint16_t size;
  Endpoint from;
  uint64_t arrivalUs;
};

class MediaLoop {
 public:
  MediaLoop(PeerSession& session, SpscRingBuffer<int16_t>& capture,
            SpscRingBuffer<int16_t>& playout, PlayoutPipeline& device,
            SpscRingBuffer<InboundDatagram>& inbound, const CoreConfig& config);

  void runOnce(uint64_t nowUs);

 private:
  PeerSession& session_;
  SpscRingBuffer<int16_t>& capture_;
  SpscRingBuffer<int16_t>& playout_;
  PlayoutPipeline& device_;
  SpscRingBuffer<InboundDatagram>& inbound_;
  const std::size_t frameSamples_;
  const std::size_t playoutTargetSamples_;
  std::size_t largestBurst_ = 0;  // most samples the device drained between two passes
  std::vector<int16_t> frame_;
  InboundDatagram datagram_{};
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_ENGINE_MEDIA_LOOP_H_
