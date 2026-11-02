// Public C API of the OffTopic voice core.
//
// This header is the only contract shared by the Dart (dart:ffi) and Kotlin
// (JNI) sides. Every function is thread-safe. Kotlin owns the lifecycle
// (vc_init / vc_start / vc_stop, mute); Dart reads state (vc_get_stats,
// events) and sends fine-grained controls. No audio crosses this API.

#ifndef VOICE_CORE_H_
#define VOICE_CORE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define VC_API __declspec(dllexport)
#else
#define VC_API __attribute__((visibility("default")))
#endif

/// Result codes. 0 is success; every failure is negative.
typedef enum vc_result {
  VC_OK = 0,
  VC_ERR_INVALID_ARGUMENT = -1,  // bad pointer or invalid configuration
  VC_ERR_INVALID_STATE = -2,     // e.g. vc_start without vc_init, or already running
  VC_ERR_AUDIO_DEVICE = -3,      // microphone/speaker could not be opened
  VC_ERR_NETWORK = -4,           // the UDP socket could not be opened
  VC_ERR_CODEC = -5,             // Opus could not be configured
  VC_ERR_INTERNAL = -6,
} vc_result;

typedef enum vc_role { VC_ROLE_CLIENT = 0, VC_ROLE_HOST = 1 } vc_role;

/// Session configuration. Start from vc_config_defaults() and override fields:
/// the defaults live in the core only (one configuration struct).
typedef struct vc_config {
  int32_t role;              // vc_role
  const char* host_ip;       // client: dotted IPv4 of the host; ignored on the host
  const char* display_name;  // UTF-8, 1..32 characters
  uint16_t control_port;     // TCP (phase 3)
  uint16_t audio_port;       // UDP
  int32_t sample_rate_hz;
  int32_t frame_samples;
  int32_t bitrate_bps;
  int32_t fec_enabled;        // boolean
  int32_t expected_loss_pct;  // Opus FEC tuning
  int32_t dtx_enabled;        // boolean
  int32_t jitter_min_ms;
  int32_t jitter_initial_ms;
  int32_t jitter_max_ms;
  int32_t keepalive_interval_ms;
  int32_t peer_timeout_ms;
  int32_t echo_mode;  // boolean, host only: return every audio packet to its sender
} vc_config;

/// Snapshot of the running session.
typedef struct vc_stats {
  int32_t participants;      // peers with a live link (phase 1: 0 or 1)
  float loss_pct;            // network loss over the last statistics window
  float jitter_ms;           // RFC 3550 interarrival jitter
  int32_t jitter_buffer_ms;  // audio currently buffered
  int32_t jitter_target_ms;  // what the adaptive buffer aims for
  int32_t rtt_ms;            // keepalive round trip; -1 until measured
  float input_level;         // peak of the last captured frame, 0..1
  uint32_t packets_sent;
  uint32_t packets_received;
  uint32_t packets_lost;
  uint32_t packets_late;
  uint32_t fec_recovered;
  uint32_t concealed_frames;
  uint32_t playout_underruns;
  uint32_t capture_overruns;
} vc_stats;

/// Event types and their JSON payloads:
///   VC_EVENT_STATE_CHANGED  {"state":"running"|"stopped"|"failed"[,"error":<vc_result>]}
///   VC_EVENT_LINK_CHANGED   {"up":true|false,"peer":"a.b.c.d:port"}
typedef enum vc_event_type {
  VC_EVENT_STATE_CHANGED = 1,
  VC_EVENT_LINK_CHANGED = 2,
} vc_event_type;

/// Called from a core thread. `payload` is a NUL-terminated UTF-8 JSON string
/// owned by the callee, which must release it with vc_free_event_payload.
typedef void (*vc_event_callback)(int32_t event, char* payload);

/// Returns the semantic version of the voice core ("MAJOR.MINOR.PATCH").
///
/// The string is static and NUL-terminated; the caller must not free it.
VC_API const char* vc_version(void);

/// Fills `out` with the default configuration (client role, no strings).
VC_API void vc_config_defaults(vc_config* out);

/// Validates and stores the configuration (strings are copied).
VC_API int32_t vc_init(const vc_config* config);

/// Opens the socket and the audio device and starts the session.
VC_API int32_t vc_start(void);

/// Stops the session. Safe to call at any time, repeatedly.
VC_API void vc_stop(void);

/// Stops sending the microphone (keepalives continue).
VC_API void vc_set_mute(int32_t muted);

/// Playback gain, clamped to [0, 4]. Non-finite values are ignored.
VC_API void vc_set_output_gain(float gain);

/// Copies the latest statistics. VC_ERR_INVALID_STATE (and zeros) when idle.
VC_API int32_t vc_get_stats(vc_stats* out);

/// Registers the event callback; NULL unregisters. After this returns, the
/// previous callback is never called again.
VC_API void vc_set_event_callback(vc_event_callback callback);

/// Releases a payload received by the event callback. NULL is ignored.
VC_API void vc_free_event_payload(char* payload);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // VOICE_CORE_H_
