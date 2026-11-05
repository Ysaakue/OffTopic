#include "engine/media_loop.h"

#include <algorithm>

namespace voice_core {

MediaLoop::MediaLoop(PeerSession& session, SpscRingBuffer<int16_t>& capture,
                     SpscRingBuffer<int16_t>& playout, PlayoutPipeline& device,
                     SpscRingBuffer<InboundDatagram>& inbound, CaptureChain& chain,
                     const CoreConfig& config)
    : session_(session),
      capture_(capture),
      playout_(playout),
      device_(device),
      inbound_(inbound),
      chain_(chain),
      frameSamples_(static_cast<std::size_t>(config.frameSamples)),
      playoutTargetSamples_(static_cast<std::size_t>(config.msToSamples(config.playoutBufferMs))),
      frame_(frameSamples_) {}

void MediaLoop::runOnce(uint64_t nowUs) {
  while (inbound_.pop(&datagram_)) {
    session_.onDatagram(datagram_.bytes.data(), datagram_.size, datagram_.from,
                        datagram_.arrivalUs);
  }
  while (capture_.size() >= frameSamples_) {
    capture_.read(frame_.data(), frameSamples_);
    const bool transmit = chain_.processCapture(frame_.data());
    session_.onCaptureFrame(frame_.data(), transmit);
  }
  // Decode only what the device is about to need: playoutBufferMs, or the
  // largest burst it drained between two passes if that is more. The jitter
  // buffer absorbs the network. The target never exceeds what the ring holds.
  largestBurst_ = std::max(largestBurst_, device_.takeConsumed());
  const std::size_t target = std::min(std::max(playoutTargetSamples_, largestBurst_),
                                      playout_.capacity() - frameSamples_);
  while (playout_.size() < target) {
    session_.producePlayoutFrame(frame_.data());
    chain_.analyzeRender(frame_.data());
    playout_.write(frame_.data(), frameSamples_);
  }
  session_.tick(nowUs);
}

}  // namespace voice_core
