#include "session/peer_session.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>

#include "common/clock.h"

namespace voice_core {
namespace {

// Opus emits frames of at most this size while in DTX; they are not sent.
constexpr int kDtxFrameMaxBytes = 2;
constexpr float kFullScale = 32768.0F;
constexpr float kUnityGain = 1.0F;

uint32_t toMs32(uint64_t us) noexcept { return static_cast<uint32_t>(us / kMicrosPerMilli); }

uint64_t msToUs(int ms) noexcept { return static_cast<uint64_t>(ms) * kMicrosPerMilli; }

// True when more than `periodUs` passed since `sinceUs`. Times from different
// threads may be slightly out of order, so `now < since` means "not yet".
bool elapsed(uint64_t nowUs, uint64_t sinceUs, uint64_t periodUs) noexcept {
  return nowUs > sinceUs && nowUs - sinceUs >= periodUs;
}

}  // namespace

Expected<std::unique_ptr<PeerSession>> PeerSession::create(const CoreConfig& config,
                                                           IDatagramSocket& socket,
                                                           IEventSink& events) {
  Expected<OpusFrameDecoder> decoder =
      OpusFrameDecoder::create(config.sampleRateHz, config.frameSamples);
  if (!decoder) {
    return decoder.status();
  }
  Expected<OpusFrameEncoder> encoder =
      OpusFrameEncoder::create(OpusEncoderParams::fromConfig(config));
  if (!encoder) {
    return encoder.status();
  }
  std::optional<Endpoint> peer;
  if (config.role == Role::kClient) {
    peer = Endpoint{parseIpv4(config.hostIp).value_or(0), config.audioPort};
  }
  return std::unique_ptr<PeerSession>(new PeerSession(config, socket, events,
                                                      std::move(encoder).value(),
                                                      std::move(decoder).value(), peer));
}

PeerSession::PeerSession(const CoreConfig& config, IDatagramSocket& socket, IEventSink& events,
                         OpusFrameEncoder encoder, OpusFrameDecoder decoder,
                         std::optional<Endpoint> peer) noexcept
    : config_(config),
      socket_(socket),
      events_(events),
      encoder_(std::move(encoder)),
      decoder_(std::move(decoder)),
      jitter_(JitterBufferParams::fromConfig(config)),
      interarrival_(config.sampleRateHz),
      localId_(config.role == Role::kClient ? kParticipantUnassigned : kParticipantHost),
      clientRole_(config.role == Role::kClient),
      peer_(peer) {}

// --- Sending

void PeerSession::onCaptureFrame(const int16_t* pcm, bool transmit) noexcept {
  int peak = 0;
  for (int i = 0; i < config_.frameSamples; ++i) {
    peak = std::max(peak, std::abs(static_cast<int>(pcm[i])));
  }
  inputLevel_ = std::min(1.0F, static_cast<float>(peak) / kFullScale);

  const uint32_t frameTimestamp = timestamp_;
  timestamp_ += static_cast<uint32_t>(config_.frameSamples);
  if (!peer_ || config_.echoMode || !transmit) {
    inGap_ = true;
    return;
  }
  uint8_t* payload = sendBuffer_.data() + kAudioHeaderBytes;
  const int encoded = encoder_.encode(pcm, payload, kMaxOpusPayloadBytes);
  if (encoded < 0) {
    ++codecErrors_;
    inGap_ = true;
    return;
  }
  if (config_.dtxEnabled && encoded <= kDtxFrameMaxBytes) {
    inGap_ = true;  // silence: send nothing, keepalives keep the link alive
    return;
  }
  const auto payloadSize = static_cast<std::size_t>(encoded);
  AudioHeader header;
  header.participantId = localId_;
  header.seq = seq_;
  header.timestamp = frameTimestamp;
  if (OpusFrameEncoder::hasFec(payload, payloadSize)) {
    header.flags |= packet_flags::kFec;
  }
  if (inGap_) {
    header.flags |= packet_flags::kTalkspurtStart;
  }
  // The payload is already in place after the header: write the header only.
  const std::size_t headerSize =
      writePacket(header, nullptr, 0, sendBuffer_.data(), sendBuffer_.size());
  if (send(headerSize + payloadSize, *peer_)) {
    ++packetsSent_;
  }
  ++seq_;
  inGap_ = false;
}

bool PeerSession::send(std::size_t size, const Endpoint& to) noexcept {
  if (socket_.sendTo(sendBuffer_.data(), size, to)) {
    return true;
  }
  ++sendErrors_;
  return false;
}

void PeerSession::sendKeepalive(KeepaliveKind kind, uint32_t originMs,
                                const Endpoint& to) noexcept {
  AudioHeader header;
  header.flags = packet_flags::kKeepalive;
  header.participantId = localId_;
  header.seq = static_cast<uint16_t>(seq_ - 1);  // the last audio seq, not incremented
  header.timestamp = timestamp_;
  const std::size_t headerSize =
      writePacket(header, nullptr, 0, sendBuffer_.data(), sendBuffer_.size());
  const std::size_t bodySize =
      writeKeepaliveBody(KeepaliveBody{kind, originMs}, sendBuffer_.data() + headerSize,
                         sendBuffer_.size() - headerSize);
  send(headerSize + bodySize, to);
}

// --- Receiving

bool PeerSession::acceptsSource(const Endpoint& from) const noexcept {
  return !peer_ || *peer_ == from;  // a host without a peer accepts anyone
}

void PeerSession::onDatagram(const uint8_t* data, std::size_t size, const Endpoint& from,
                             uint64_t arrivalUs) noexcept {
  if (!acceptsSource(from)) {
    ++foreign_;
    return;
  }
  ParsedPacket packet;
  if (parsePacket(data, size, &packet) != PacketError::kNone ||
      (!packet.header.has(packet_flags::kKeepalive) && packet.payloadSize == 0)) {
    ++malformed_;
    return;
  }
  noteReceived(from, arrivalUs);
  if (packet.header.has(packet_flags::kKeepalive)) {
    handleKeepalive(packet, from, arrivalUs);
  } else {
    handleAudio(packet, data, size, from, arrivalUs);
  }
}

void PeerSession::noteReceived(const Endpoint& from, uint64_t arrivalUs) {
  if (!peer_) {
    peer_ = from;
  }
  lastReceiveUs_ = std::max(lastReceiveUs_, arrivalUs);
  if (!linkUp_) {
    linkUp_ = true;
    events_.emit(LinkChangedEvent{true, from});
  }
}

void PeerSession::handleKeepalive(const ParsedPacket& packet, const Endpoint& from,
                                  uint64_t arrivalUs) {
  const std::optional<KeepaliveBody> body =
      parseKeepaliveBody(packet.payload, packet.payloadSize);
  if (!body) {
    return;  // a bare "still here" or an unknown kind
  }
  if (body->kind == KeepaliveKind::kPing) {
    sendKeepalive(KeepaliveKind::kPong, body->originMs, from);
  } else {
    rtt_.onPong(toMs32(arrivalUs), body->originMs);
  }
}

void PeerSession::handleAudio(const ParsedPacket& packet, const uint8_t* data, std::size_t size,
                              const Endpoint& from, uint64_t arrivalUs) noexcept {
  ++packetsReceived_;
  if (config_.echoMode) {
    std::memcpy(sendBuffer_.data(), data, size);
    sendBuffer_[1] = kParticipantHost;  // PROTOCOL.md 3: only participant_id changes
    if (send(size, from)) {
      ++packetsSent_;
    }
    return;
  }
  const AudioHeader& header = packet.header;
  switch (jitter_.insert(header, packet.payload, packet.payloadSize, arrivalUs)) {
    case InsertResult::kRestarted:
      loss_.reset();
      interarrival_.reset();
      [[fallthrough]];
    case InsertResult::kStored:
    case InsertResult::kLate:
      loss_.onPacket(header.seq);
      interarrival_.onPacket(arrivalUs, header.timestamp);
      break;
    case InsertResult::kDuplicate:
    case InsertResult::kRejected:
      break;
  }
}

// --- Playout

void PeerSession::producePlayoutFrame(int16_t* out) noexcept {
  const PlayoutDecision decision = jitter_.pop();
  int result = 0;
  switch (decision.kind) {
    case PlayoutKind::kSilence:
      std::fill(out, out + config_.frameSamples, int16_t{0});
      return;
    case PlayoutKind::kFrame:
      result = decoder_.decode(decision.payload, decision.size, out);
      break;
    case PlayoutKind::kFecFromNext:
      result = decoder_.decodeFec(decision.payload, decision.size, out);
      break;
    case PlayoutKind::kConceal:
      result = decoder_.conceal(out);
      break;
  }
  if (result < 0) {
    ++codecErrors_;
    std::fill(out, out + config_.frameSamples, int16_t{0});
    return;
  }
  applyGain(out);
}

void PeerSession::applyGain(int16_t* pcm) const noexcept {
  if (outputGain_ == kUnityGain) {
    return;
  }
  constexpr auto kMin = static_cast<float>(std::numeric_limits<int16_t>::min());
  constexpr auto kMax = static_cast<float>(std::numeric_limits<int16_t>::max());
  for (int i = 0; i < config_.frameSamples; ++i) {
    const float scaled = std::clamp(static_cast<float>(pcm[i]) * outputGain_, kMin, kMax);
    pcm[i] = static_cast<int16_t>(std::lround(scaled));
  }
}

// --- Time

void PeerSession::tick(uint64_t nowUs) {
  if (peer_ && (!keepaliveSent_ || elapsed(nowUs, lastKeepaliveUs_,
                                           msToUs(config_.keepaliveIntervalMs)))) {
    sendKeepalive(KeepaliveKind::kPing, toMs32(nowUs), *peer_);
    keepaliveSent_ = true;
    lastKeepaliveUs_ = nowUs;
  }
  if (linkUp_ && elapsed(nowUs, lastReceiveUs_, msToUs(config_.peerTimeoutMs))) {
    linkDown();
  }
  if (!statsWindowStarted_) {
    statsWindowStarted_ = true;
    statsWindowStartUs_ = nowUs;
  } else if (elapsed(nowUs, statsWindowStartUs_, msToUs(config_.statsIntervalMs))) {
    lossPct_ = loss_.takeIntervalLossPct();
    statsWindowStartUs_ = nowUs;
  }
}

void PeerSession::linkDown() {
  linkUp_ = false;
  const Endpoint lost = peer_.value_or(Endpoint{});
  events_.emit(LinkChangedEvent{false, lost});
  jitter_.reset();
  loss_.reset();
  interarrival_.reset();
  lossPct_ = 0.0F;
  if (!clientRole_) {
    peer_.reset();  // the next valid datagram (e.g. a restarted client) becomes the peer
    keepaliveSent_ = false;
  }
}

SessionStats PeerSession::stats() const noexcept {
  const JitterBufferStats& buffer = jitter_.stats();
  SessionStats stats;
  stats.linkUp = linkUp_;
  stats.lossPct = lossPct_;
  stats.jitterMs = static_cast<float>(interarrival_.jitterMs());
  stats.jitterBufferMs = jitter_.depthMs();
  stats.jitterTargetMs = jitter_.targetMs();
  stats.rttMs = rtt_.smoothedMs();
  stats.inputLevel = inputLevel_;
  stats.packetsSent = packetsSent_;
  stats.packetsReceived = packetsReceived_;
  stats.packetsLost = static_cast<uint32_t>(loss_.lost());
  stats.packetsLate = buffer.late;
  stats.fecRecovered = buffer.fecRecovered;
  stats.concealedFrames = buffer.concealed;
  stats.malformedPackets = malformed_;
  stats.foreignPackets = foreign_;
  stats.sendErrors = sendErrors_;
  stats.codecErrors = codecErrors_;
  return stats;
}

}  // namespace voice_core
