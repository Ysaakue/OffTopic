#include "jitter/jitter_buffer.h"

#include <algorithm>
#include <cstring>

#include "config/core_config.h"
#include "net/sequence.h"

namespace voice_core {
namespace {

// A packet older than this many buffer capacities means the sender restarted
// its stream (a genuinely late packet is never that late).
constexpr int kRestartDistanceFactor = 4;
// The depth may differ from the target by this many frames before the
// buffer drops or inserts one.
constexpr int kHysteresisFrames = 1;
// Slots cover twice the maximum delay, so a burst after a stall still fits.
constexpr int kSlotsPerMaxFrame = 2;
constexpr int kExtraSlots = 2;

std::size_t slotCount(const JitterBufferParams& params) noexcept {
  const int maxFrames = params.delay.maxMs / params.delay.frameMs;
  const auto needed = static_cast<std::size_t>(kSlotsPerMaxFrame * maxFrames + kExtraSlots);
  std::size_t count = 1;
  while (count < needed) {
    count <<= 1U;  // a power of two keeps seq -> slot continuous across the 16-bit wrap
  }
  return count;
}

}  // namespace

JitterBufferParams JitterBufferParams::fromConfig(const CoreConfig& config) noexcept {
  JitterBufferParams params;
  params.delay.sampleRateHz = config.sampleRateHz;
  params.delay.frameMs = config.frameMs();
  params.delay.minMs = config.jitterMinMs;
  params.delay.initialMs = config.jitterInitialMs;
  params.delay.maxMs = config.jitterMaxMs;
  params.delay.windowMs = config.jitterWindowMs;
  params.adaptHoldMs = config.jitterAdaptHoldMs;
  params.concealmentMaxMs = config.concealmentMaxMs;
  return params;
}

JitterBuffer::JitterBuffer(const JitterBufferParams& params)
    : frameMs_(params.delay.frameMs),
      holdTicks_(std::max(1, params.adaptHoldMs / params.delay.frameMs)),
      concealmentMaxFrames_(params.concealmentMaxMs / params.delay.frameMs),
      estimator_(params.delay),
      slots_(slotCount(params)),
      mask_(slots_.size() - 1) {}

bool JitterBuffer::has(uint16_t seq) const noexcept {
  const Slot& slot = slots_[seq & mask_];
  return slot.used && slot.seq == seq;
}

int JitterBuffer::spanFrames() const noexcept {
  return count_ == 0 ? 0 : seqDelta(highestSeq_, nextSeq_) + 1;
}

void JitterBuffer::store(const AudioHeader& header, const uint8_t* payload,
                         std::size_t size) noexcept {
  Slot& slot = slotFor(header.seq);
  slot.used = true;
  slot.seq = header.seq;
  slot.size = static_cast<uint16_t>(size);
  if (size > 0) {
    std::memcpy(slot.data.data(), payload, size);
  }
  if (++count_ == 1 || seqNewer(header.seq, highestSeq_)) {
    highestSeq_ = header.seq;
  }
  ++stats_.stored;
}

void JitterBuffer::consume(uint16_t seq) noexcept {
  if (has(seq)) {
    slotFor(seq).used = false;
    --count_;
  }
}

void JitterBuffer::clearStream() noexcept {
  for (Slot& slot : slots_) {
    slot.used = false;
  }
  count_ = 0;
  playing_ = false;
  waitTicks_ = 0;
  aboveTicks_ = 0;
  belowTicks_ = 0;
  concealRun_ = 0;
}

void JitterBuffer::restart(const AudioHeader& header, const uint8_t* payload, std::size_t size,
                           uint64_t arrivalUs) noexcept {
  clearStream();
  estimator_.reset();
  estimator_.onPacket(arrivalUs, header.timestamp);
  started_ = true;
  nextSeq_ = header.seq;
  store(header, payload, size);
}

void JitterBuffer::reset() noexcept {
  clearStream();
  estimator_.reset();
  started_ = false;
}

InsertResult JitterBuffer::insert(const AudioHeader& header, const uint8_t* payload,
                                  std::size_t size, uint64_t arrivalUs) noexcept {
  if (size > kMaxOpusPayloadBytes) {
    return InsertResult::kRejected;
  }
  if (!started_) {
    restart(header, payload, size, arrivalUs);
    return InsertResult::kStored;
  }
  const int delta = seqDelta(header.seq, nextSeq_);
  const int slots = capacity();
  if (delta >= 0 && delta < slots && has(header.seq)) {
    ++stats_.duplicates;
    return InsertResult::kDuplicate;
  }
  if (delta < 0 && !playing_ && seqDelta(highestSeq_, header.seq) < slots) {
    // Reordered before playout started: begin the stream earlier.
    estimator_.onPacket(arrivalUs, header.timestamp);
    nextSeq_ = header.seq;
    store(header, payload, size);
    return InsertResult::kStored;
  }
  if (delta >= slots || delta < -kRestartDistanceFactor * slots ||
      (delta < 0 && header.has(packet_flags::kTalkspurtStart))) {
    restart(header, payload, size, arrivalUs);
    ++stats_.restarts;
    return InsertResult::kRestarted;
  }
  estimator_.onPacket(arrivalUs, header.timestamp);
  if (delta < 0) {
    ++stats_.late;
    return InsertResult::kLate;
  }
  if (playing_ && count_ == 0 && header.has(packet_flags::kTalkspurtStart)) {
    // A silence gap ended: rebuild the target delay before playing again.
    playing_ = false;
    waitTicks_ = 0;
    nextSeq_ = header.seq;
  }
  store(header, payload, size);
  return InsertResult::kStored;
}

bool JitterBuffer::readyToPlay() noexcept {
  ++waitTicks_;
  const int target = targetFrames();
  if (spanFrames() >= target || waitTicks_ >= target) {
    playing_ = true;
    aboveTicks_ = 0;
    belowTicks_ = 0;
    return true;
  }
  return false;
}

PlayoutDecision JitterBuffer::concealOrSilence() noexcept {
  if (concealRun_ < concealmentMaxFrames_) {
    ++concealRun_;
    ++stats_.concealed;
    return PlayoutDecision{PlayoutKind::kConceal, nullptr, 0};
  }
  return PlayoutDecision{};
}

PlayoutDecision JitterBuffer::pop() noexcept {
  if (!started_) {
    ++stats_.emptyTicks;
    return PlayoutDecision{};
  }
  if (!playing_ && !readyToPlay()) {
    return PlayoutDecision{};
  }

  // Drift control: keep the depth within one frame of the target.
  const int span = spanFrames();
  const int target = targetFrames();
  aboveTicks_ = span > target + kHysteresisFrames ? aboveTicks_ + 1 : 0;
  belowTicks_ = (span > 0 && span < target - kHysteresisFrames) ? belowTicks_ + 1 : 0;
  if (aboveTicks_ >= holdTicks_) {
    aboveTicks_ = 0;
    consume(nextSeq_);
    ++nextSeq_;
    ++stats_.dropped;
  } else if (belowTicks_ >= holdTicks_) {
    belowTicks_ = 0;
    ++stats_.inserted;
    ++stats_.concealed;
    return PlayoutDecision{PlayoutKind::kConceal, nullptr, 0};
  }

  if (has(nextSeq_)) {
    Slot& slot = slotFor(nextSeq_);
    slot.used = false;
    --count_;
    ++nextSeq_;
    concealRun_ = 0;
    return PlayoutDecision{PlayoutKind::kFrame, slot.data.data(), slot.size};
  }
  if (count_ == 0) {
    // Underflow or a silence gap: wait for the frame without skipping it.
    ++stats_.emptyTicks;
    return concealOrSilence();
  }
  // The frame is missing but newer ones arrived: it is lost.
  ++stats_.lost;
  ++nextSeq_;
  if (has(nextSeq_)) {
    ++stats_.fecRecovered;
    concealRun_ = 0;
    const Slot& next = slotFor(nextSeq_);
    return PlayoutDecision{PlayoutKind::kFecFromNext, next.data.data(), next.size};
  }
  return concealOrSilence();
}

}  // namespace voice_core
