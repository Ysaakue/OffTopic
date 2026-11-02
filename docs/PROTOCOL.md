# OffTopic wire protocol

Version **1**. This document is the contract between phones; the C++ core is
its only implementation, and its tests use the vectors below byte for byte.

- Audio travels over **UDP unicast**, control over **TCP** (phase 3).
- The host is the centre of a star. It is addressed like any other endpoint
  (IPv4 address + ports), never assumed to be on the local network, so that a
  relay server can take its place later (phase 6).
- All multi-byte integers are **unsigned, big-endian** (network order).
- Multicast and broadcast are never used.

| Port | Transport | Default | Configured by |
| --- | --- | --- | --- |
| Control | TCP | 47800 | `CoreConfig::control_port` |
| Audio | UDP | 47801 | `CoreConfig::audio_port` |

## 1. Audio datagram (UDP)

One datagram carries one header and at most one Opus frame.

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|version|R|S|F|K|participant_id |              seq              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           timestamp                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     payload (0..1275 bytes)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| Field | Bits / bytes | Meaning |
| --- | --- | --- |
| `version` | high 4 bits of byte 0 | Always `1`. Receivers drop any other value. |
| `R` (0x08) | bit 3 | Reserved. Senders write 0; receivers ignore it. |
| `S` (0x04) | bit 2 | **Talkspurt start** ("DTX" in the spec): first audio frame after a silence gap (DTX, mute or stream start). The receiver may re-anchor its jitter buffer here. |
| `F` (0x02) | bit 1 | **FEC**: the Opus payload carries in-band FEC (LBRR) data for the previous frame. |
| `K` (0x01) | bit 0 | **Keepalive**: the payload is a keepalive body (section 1.2), not audio. |
| `participant_id` | byte 1 | `0` = host (and the host's mixed stream). `1..254` = assigned in `WELCOME`. `255` = not assigned yet. |
| `seq` | bytes 2–3 | Audio frame counter. Increments by 1 for every **sent** audio frame and wraps from 65535 to 0. Keepalives repeat the last audio `seq` and do not increment it. |
| `timestamp` | bytes 4–7 | Sampling instant of the first sample of the frame, in samples at 16 kHz. Advances by 320 per 20 ms frame **including frames not sent** (DTX, mute), and wraps from 2³²−1 to 0. |
| payload | bytes 8.. | One Opus frame (16 kHz mono, 20 ms). Empty or a keepalive body when `K` is set. |

- Minimum datagram: 8 bytes. Maximum: 8 + 1275 = **1283 bytes**, below every Wi-Fi MTU.
- A receiver drops (and counts) datagrams that are shorter than 8 bytes,
  have another version, carry more than 1275 payload bytes, or have `K` set
  with a body that is neither empty nor exactly 8 bytes.
- Gaps in `seq` are losses. A jump in `timestamp` with consecutive `seq`
  (and `S` set) is silence, not loss.
- Sequence and timestamp comparisons use serial-number arithmetic: `a` is
  newer than `b` when `(int16)(a − b) > 0` (`int32` for timestamps).

### 1.1 Opus parameters

Fixed for protocol version 1 and repeated in `WELCOME` (phase 3):
application VOIP, 16 000 Hz, mono, 20 ms (320 samples), 24 kbps, in-band FEC
on, expected loss 10 %, DTX on. Senders do not transmit the 1–2 byte frames
Opus produces while in DTX; they send a keepalive at least once per second
instead.

### 1.2 Keepalive body

Sent every `CoreConfig::keepalive_interval_ms` (1 s) by both sides, whether
or not audio is flowing. It proves the path is alive and measures the RTT.

| Offset | Size | Field | Meaning |
| --- | --- | --- | --- |
| 0 | 1 | `kind` | `0` = PING, `1` = PONG. Other values: drop. |
| 1 | 3 | reserved | Senders write 0; receivers ignore. |
| 4 | 4 | `origin_ms` | PING: sender's monotonic clock in ms, truncated to 32 bits. PONG: copied unchanged from the PING it answers. |

On a PING the receiver immediately answers a PONG to the datagram's source
address. On a PONG, `RTT = now_ms − origin_ms` (32-bit wrapping subtraction).
An empty keepalive body is a valid "still here" with no RTT probe.

### 1.3 Test vectors

| Case | Bytes (hex) |
| --- | --- |
| Audio, FEC, participant 3, seq 0x1234, ts 0x00ABCDEF, payload `DE AD` | `12 03 12 34 00 AB CD EF DE AD` |
| Talkspurt start + FEC, participant 1, seq 0, ts 0, payload `01` | `16 01 00 00 00 00 00 00 01` |
| Keepalive PING from host, seq 0xFFFF, ts 0xFFFFFFC0, origin 123456 ms | `11 00 FF FF FF FF FF C0 00 00 00 00 00 01 E2 40` |
| Keepalive PONG to the vector above, sent by participant 255 | `11 FF FF FF FF FF FF C0 01 00 00 00 00 01 E2 40` |
| Empty keepalive, participant 7, seq 9, ts 2880 | `11 07 00 09 00 00 0B 40` |
| Rejected: version 2 | `22 03 12 34 00 AB CD EF DE AD` |
| Rejected: 7 bytes | `12 03 12 34 00 AB CD` |
| Rejected: keepalive with a 3-byte body | `11 00 00 01 00 00 00 00 00 00 00` |

## 2. Control channel (TCP)

Implemented in phase 3. The client opens one TCP connection to the host's
control port and keeps it for the whole session.

### 2.1 Framing

Each message is a 4-byte unsigned big-endian **length** followed by that many
bytes of UTF-8 JSON (one object). The length counts the JSON bytes only.

- Length `0` or above **16 384** is a protocol error: the receiver closes the
  connection.
- A reader must accept a frame split across any number of TCP reads, and
  several frames in one read.

Vector: `{"type":"BYE"}` (14 bytes) → `00 00 00 0E 7B 22 74 79 70 65 22 3A 22 42 59 45 22 7D`.

### 2.2 Messages

Every message is a JSON object with a string field `type`. Unknown fields are
ignored (forward compatibility). A message with an unknown `type` is ignored.
A known message with a missing or mistyped required field is a protocol error.

| `type` | Direction | Fields |
| --- | --- | --- |
| `HELLO` | client → host | `protocol_version` (int, `1`), `name` (string, 1–32 chars), `device_id` (string, 32 lowercase hex chars, stable per install) |
| `WELCOME` | host → client | `protocol_version`, `participant_id` (1–254), `codec` (object: `sample_rate`, `frame_samples`, `bitrate_bps`, `fec`, `dtx`, `expected_loss_pct`), `participants` (roster array) |
| `ROSTER` | host → all | `participants`: array of `{ "participant_id": int, "name": string, "muted": bool }`, the host included as id 0 |
| `MUTE` | client → host | `muted` (bool) |
| `PING` | both | `t` (int, sender's monotonic ms, 32-bit) |
| `PONG` | both | `t` copied from the PING |
| `BYE` | both | `reason`: `"leaving"`, `"room_full"`, `"incompatible_version"`, `"protocol_error"` or `"host_closed"` |

Example `WELCOME`:

```json
{"type":"WELCOME","protocol_version":1,"participant_id":2,
 "codec":{"sample_rate":16000,"frame_samples":320,"bitrate_bps":24000,
          "fec":true,"dtx":true,"expected_loss_pct":10},
 "participants":[{"participant_id":0,"name":"Ana","muted":false},
                 {"participant_id":2,"name":"Bia","muted":false}]}
```

### 2.3 Session rules

1. The client sends `HELLO` right after connecting. The host answers `WELCOME`
   or `BYE` (`room_full` above `CoreConfig::max_participants` = 8,
   `incompatible_version` when `protocol_version` differs) and closes.
2. After `WELCOME` the client sends its audio with the assigned
   `participant_id`. The host accepts UDP from that id only when the source
   IP equals the TCP peer IP, and learns the source port from the first
   datagram.
3. Both sides send `PING` every second (`control_ping_interval_ms`). A peer
   that sends nothing for 5 s (`control_timeout_ms`) is gone: the host drops
   it from the roster, the client starts reconnecting.
4. Reconnection (phase 4): the client sends `HELLO` with the same
   `device_id`; the host returns the same `participant_id` while the slot is
   reserved (`reconnect_grace_ms`).
5. `BYE` is sent before a voluntary close. The receiver closes without
   waiting for anything else.

## 3. Phase 1 proof of concept

Until the control channel exists (phase 3), two phones talk with UDP only:

- The client is started with the host's IP typed by hand. It sends audio and
  keepalives to `host_ip:audio_port` with `participant_id` 255 and accepts
  datagrams only from that address.
- The host listens on `audio_port`, adopts the source address of the first
  valid datagram as its peer and ignores every other source while that link
  is up. When the link goes down it forgets the peer, so a restarted client
  (new source port) is adopted again. It sends its own microphone stream to
  the peer with `participant_id` 0.
- **Echo mode** (host only, for measuring the audio round trip): the host does
  not send its microphone; it returns every audio datagram it receives to the
  sender unchanged except `participant_id`, which becomes 0. Keepalives are
  answered as usual.
- The link is **up** after the first valid datagram from the peer and
  **down** after `peer_timeout_ms` (5 s) without one.

## 4. Versioning

The audio header carries its own version (4 bits). The control channel
negotiates `protocol_version` in `HELLO`. A change that an old receiver would
misread increments both; additions that old receivers safely ignore
(new JSON fields, new keepalive kinds they drop) do not.
