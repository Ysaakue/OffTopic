// Adaptive jitter buffer for one incoming stream (docs/SPEC.md: target starts
// at 40 ms, stays within 20..120 ms, late packets are dropped, losses are
// rebuilt from the next packet's FEC or concealed, clock drift is absorbed by
// dropping or inserting frames).
//
// Frames are indexed by seq. pop() is called once per frame period by the
// playout side and says what to decode; it never allocates. Silence gaps
// (DTX: consecutive seq, jumping timestamp) are not losses: an empty buffer
// waits without advancing, and a talkspurt start re-anchors the delay.

#ifndef VOICE_CORE_SRC_JITTER_JITTER_BUFFER_H_
#define VOICE_CORE_SRC_JITTER_JITTER_BUFFER_H_

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

#include "jitter/target_delay_estimator.h"
#include "net/audio_packet.h"

namespace voice_core {

struct CoreConfig;

struct JitterBufferParams {
  TargetDelayParams delay;
  int adaptHoldMs = 0;
  int concealmentMaxMs = 0;

  static JitterBufferParams fromConfig(const CoreConfig& config) noexcept;
};

enum class PlayoutKind : uint8_t {
  kSilence,      // nothing to play: output zeros
  kFrame,        // decode `payload`
  kFecFromNext,  // the frame was lost: decode `payload` (the next packet) in FEC mode
  kConceal,      // the frame is missing: run packet loss concealment
};

struct PlayoutDecision {
  PlayoutKind kind = PlayoutKind::kSilence;
  const uint8_t* payload = nullptr;  // valid until the next insert()
  std::size_t size = 0;
};

enum class InsertResult : uint8_t { kStored, kDuplicate, kLate, kRestarted, kRejected };

struct JitterBufferStats {
  uint32_t stored = 0;
  uint32_t duplicates = 0;
  uint32_t late = 0;
  uint32_t lost = 0;          // frames missing at their playout time
  uint32_t fecRecovered = 0;  // ... of which rebuilt from FEC
  uint32_t concealed = 0;     // concealment frames played
  uint32_t dropped = 0;       // frames skipped to shrink the delay (drift)
  uint32_t inserted = 0;      // frames inserted to grow the delay (drift)
  uint32_t emptyTicks = 0;    // pops with nothing buffered (silence or underflow)
  uint32_t restarts = 0;      // stream restarts (seq jumped out of range)
};

class JitterBuffer {
 public:
  explicit JitterBuffer(const JitterBufferParams& params);

  InsertResult insert(const AudioHeader& header, const uint8_t* payload, std::size_t size,
                      uint64_t arrivalUs) noexcept;

  PlayoutDecision pop() noexcept;

  /// Forgets the stream (used when the link goes down).
  void reset() noexcept;

  [[nodiscard]] int depthMs() const noexcept { return spanFrames() * frameMs_; }
  [[nodiscard]] int targetMs() const noexcept { return estimator_.targetMs(); }
  [[nodiscard]] bool playing() const noexcept { return playing_; }
  [[nodiscard]] std::size_t capacityFrames() const noexcept { return slots_.size(); }
  [[nodiscard]] const JitterBufferStats& stats() const noexcept { return stats_; }

 private:
  struct Slot {
    bool used = false;
    uint16_t seq = 0;
    uint16_t size = 0;
    std::array<uint8_t, kMaxOpusPayloadBytes> data{};
  };

  [[nodiscard]] Slot& slotFor(uint16_t seq) noexcept { return slots_[seq & mask_]; }
  [[nodiscard]] bool has(uint16_t seq) const noexcept;
  [[nodiscard]] int spanFrames() const noexcept;
  [[nodiscard]] int targetFrames() const noexcept { return targetMs() / frameMs_; }
  [[nodiscard]] int capacity() const noexcept { return static_cast<int>(slots_.size()); }

  void store(const AudioHeader& header, const uint8_t* payload, std::size_t size) noexcept;
  void consume(uint16_t seq) noexcept;
  void restart(const AudioHeader& header, const uint8_t* payload, std::size_t size,
               uint64_t arrivalUs) noexcept;
  void clearStream() noexcept;
  bool readyToPlay() noexcept;
  [[nodiscard]] PlayoutDecision concealOrSilence() noexcept;

  const int frameMs_;
  const int holdTicks_;
  const int concealmentMaxFrames_;
  TargetDelayEstimator estimator_;
  std::vector<Slot> slots_;
  std::size_t mask_;

  bool started_ = false;
  bool playing_ = false;
  uint16_t nextSeq_ = 0;
  uint16_t highestSeq_ = 0;
  int count_ = 0;
  int waitTicks_ = 0;
  int aboveTicks_ = 0;
  int belowTicks_ = 0;
  int concealRun_ = 0;
  JitterBufferStats stats_;
};

}  // namespace voice_core

#endif  // VOICE_CORE_SRC_JITTER_JITTER_BUFFER_H_
