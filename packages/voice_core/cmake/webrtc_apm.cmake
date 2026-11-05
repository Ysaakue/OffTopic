# WebRTC audio processing (webrtc-audio-processing v2.1) built with CMake.
#
# Upstream builds with Meson; this file mirrors its source lists
# (webrtc/**/meson.build at the pinned tag) for the platforms we ship:
# Linux desktop (x86_64, tests) and Android (arm64-v8a, armeabi-v7a, x86_64).
# When the submodule tag changes, diff the meson.build files and update the
# lists below. Defines the static library `vc_webrtc_apm`.

set(VC_APM_DIR ${PROJECT_SOURCE_DIR}/third_party/webrtc-audio-processing/webrtc)

# --- Abseil (only the header-heavy parts the APM uses are built).
set(ABSL_PROPAGATE_CXX_STD ON CACHE BOOL "" FORCE)
set(ABSL_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(ABSL_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/abseil-cpp EXCLUDE_FROM_ALL SYSTEM)

# --- Architecture (mirrors the cpu_family checks of the top-level meson.build).
set(VC_APM_X86 OFF)
set(VC_APM_ARM64 OFF)
set(VC_APM_ARMV7 OFF)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64|i[3-6]86)$")
  set(VC_APM_X86 ON)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(VC_APM_ARM64 ON)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^armv7")
  set(VC_APM_ARMV7 ON)
else()
  message(FATAL_ERROR "webrtc_apm.cmake: unsupported processor '${CMAKE_SYSTEM_PROCESSOR}'.")
endif()

set(VC_APM_SOURCES
  # rtc_base/meson.build
  rtc_base/checks.cc
  rtc_base/containers/flat_tree.cc
  rtc_base/event.cc
  rtc_base/event_tracer.cc
  rtc_base/experiments/field_trial_parser.cc
  rtc_base/logging.cc
  rtc_base/memory/aligned_malloc.cc
  rtc_base/platform_thread.cc
  rtc_base/platform_thread_types.cc
  rtc_base/race_checker.cc
  rtc_base/random.cc
  rtc_base/string_encode.cc
  rtc_base/string_to_number.cc
  rtc_base/string_utils.cc
  rtc_base/strings/string_builder.cc
  rtc_base/synchronization/sequence_checker_internal.cc
  rtc_base/synchronization/yield_policy.cc
  rtc_base/system/file_wrapper.cc
  rtc_base/system_time.cc
  rtc_base/time_utils.cc
  rtc_base/zero_memory.cc
  # api/meson.build
  api/audio/audio_frame.cc
  api/audio/audio_processing.cc
  api/audio/audio_processing_statistics.cc
  api/audio/channel_layout.cc
  api/audio/echo_canceller3_config.cc
  api/rtp_headers.cc
  api/rtp_packet_info.cc
  api/task_queue/task_queue_base.cc
  api/units/frequency.cc
  api/units/time_delta.cc
  api/units/timestamp.cc
  api/video/color_space.cc
  api/video/hdr_metadata.cc
  api/video/video_content_type.cc
  api/video/video_timing.cc
  # system_wrappers/meson.build
  system_wrappers/source/cpu_features.cc
  system_wrappers/source/denormal_disabler.cc
  system_wrappers/source/field_trial.cc
  system_wrappers/source/metrics.cc
  system_wrappers/source/sleep.cc
  # common_audio/meson.build (portable C; the ARM assembly variants are not used)
  common_audio/audio_converter.cc
  common_audio/audio_util.cc
  common_audio/channel_buffer.cc
  common_audio/fir_filter_c.cc
  common_audio/fir_filter_factory.cc
  common_audio/resampler/push_resampler.cc
  common_audio/resampler/push_sinc_resampler.cc
  common_audio/resampler/resampler.cc
  common_audio/resampler/sinc_resampler.cc
  common_audio/resampler/sinusoidal_linear_chirp_source.cc
  common_audio/ring_buffer.c
  common_audio/signal_processing/auto_correlation.c
  common_audio/signal_processing/auto_corr_to_refl_coef.c
  common_audio/signal_processing/complex_bit_reverse.c
  common_audio/signal_processing/complex_fft.c
  common_audio/signal_processing/copy_set_operations.c
  common_audio/signal_processing/cross_correlation.c
  common_audio/signal_processing/division_operations.c
  common_audio/signal_processing/dot_product_with_scale.cc
  common_audio/signal_processing/downsample_fast.c
  common_audio/signal_processing/filter_ar.c
  common_audio/signal_processing/filter_ar_fast_q12.c
  common_audio/signal_processing/energy.c
  common_audio/signal_processing/filter_ma_fast_q12.c
  common_audio/signal_processing/get_hanning_window.c
  common_audio/signal_processing/get_scaling_square.c
  common_audio/signal_processing/ilbc_specific_functions.c
  common_audio/signal_processing/levinson_durbin.c
  common_audio/signal_processing/lpc_to_refl_coef.c
  common_audio/signal_processing/min_max_operations.c
  common_audio/signal_processing/randomization_functions.c
  common_audio/signal_processing/real_fft.c
  common_audio/signal_processing/refl_coef_to_lpc.c
  common_audio/signal_processing/resample_48khz.c
  common_audio/signal_processing/resample_by_2.c
  common_audio/signal_processing/resample_by_2_internal.c
  common_audio/signal_processing/resample.c
  common_audio/signal_processing/resample_fractional.c
  common_audio/signal_processing/spl_init.c
  common_audio/signal_processing/spl_inl.c
  common_audio/signal_processing/splitting_filter.c
  common_audio/signal_processing/spl_sqrt.c
  common_audio/signal_processing/sqrt_of_one_minus_x_squared.c
  common_audio/signal_processing/vector_scaling_operations.c
  common_audio/smoothing_filter.cc
  common_audio/third_party/ooura/fft_size_128/ooura_fft.cc
  common_audio/third_party/ooura/fft_size_256/fft4g.cc
  common_audio/third_party/spl_sqrt_floor/spl_sqrt_floor.c
  common_audio/vad/vad.cc
  common_audio/vad/vad_core.c
  common_audio/vad/vad_filterbank.c
  common_audio/vad/vad_gmm.c
  common_audio/vad/vad_sp.c
  common_audio/vad/webrtc_vad.c
  # third_party/pffft, third_party/rnnoise, modules/third_party/fft
  third_party/pffft/src/pffft.c
  third_party/rnnoise/src/rnn_vad_weights.cc
  modules/third_party/fft/fft.c
  # modules/audio_coding/meson.build (isac_vad_sources)
  modules/audio_coding/codecs/isac/main/source/filter_functions.c
  modules/audio_coding/codecs/isac/main/source/isac_vad.c
  modules/audio_coding/codecs/isac/main/source/pitch_estimator.c
  modules/audio_coding/codecs/isac/main/source/pitch_filter.c
)

# modules/audio_processing/meson.build
foreach(source IN ITEMS
    aec_dump/null_aec_dump_factory.cc
    aec3/adaptive_fir_filter.cc aec3/adaptive_fir_filter_erl.cc aec3/aec3_common.cc
    aec3/aec3_fft.cc aec3/aec_state.cc aec3/alignment_mixer.cc
    aec3/api_call_jitter_metrics.cc aec3/block_buffer.cc aec3/block_delay_buffer.cc
    aec3/block_framer.cc aec3/block_processor.cc aec3/block_processor_metrics.cc
    aec3/clockdrift_detector.cc aec3/coarse_filter_update_gain.cc
    aec3/comfort_noise_generator.cc aec3/config_selector.cc aec3/decimator.cc
    aec3/dominant_nearend_detector.cc aec3/downsampled_render_buffer.cc
    aec3/echo_audibility.cc aec3/echo_canceller3.cc aec3/echo_path_delay_estimator.cc
    aec3/echo_path_variability.cc aec3/echo_remover.cc aec3/echo_remover_metrics.cc
    aec3/erle_estimator.cc aec3/erl_estimator.cc aec3/fft_buffer.cc
    aec3/filter_analyzer.cc aec3/frame_blocker.cc aec3/fullband_erle_estimator.cc
    aec3/matched_filter.cc aec3/matched_filter_lag_aggregator.cc aec3/moving_average.cc
    aec3/multi_channel_content_detector.cc aec3/refined_filter_update_gain.cc
    aec3/render_buffer.cc aec3/render_delay_buffer.cc aec3/render_delay_controller.cc
    aec3/render_delay_controller_metrics.cc aec3/render_signal_analyzer.cc
    aec3/residual_echo_estimator.cc aec3/reverb_decay_estimator.cc
    aec3/reverb_frequency_response.cc aec3/reverb_model.cc aec3/reverb_model_estimator.cc
    aec3/signal_dependent_erle_estimator.cc aec3/spectrum_buffer.cc
    aec3/stationarity_estimator.cc aec3/subband_erle_estimator.cc
    aec3/subband_nearend_detector.cc aec3/subtractor.cc aec3/subtractor_output_analyzer.cc
    aec3/subtractor_output.cc aec3/suppression_filter.cc aec3/suppression_gain.cc
    aec3/transparent_mode.cc
    aecm/aecm_core.cc aecm/aecm_core_c.cc aecm/echo_control_mobile.cc
    agc/agc.cc agc/agc_manager_direct.cc agc/legacy/analog_agc.cc
    agc/legacy/digital_agc.cc agc/loudness_histogram.cc agc/utility.cc
    agc2/adaptive_digital_gain_controller.cc agc2/agc2_testing_common.cc
    agc2/biquad_filter.cc agc2/clipping_predictor.cc
    agc2/clipping_predictor_level_buffer.cc agc2/compute_interpolated_gain_curve.cc
    agc2/cpu_features.cc agc2/fixed_digital_level_estimator.cc agc2/gain_applier.cc
    agc2/input_volume_controller.cc agc2/input_volume_stats_reporter.cc
    agc2/interpolated_gain_curve.cc agc2/limiter.cc agc2/limiter_db_gain_curve.cc
    agc2/noise_level_estimator.cc agc2/rnn_vad/auto_correlation.cc
    agc2/rnn_vad/features_extraction.cc agc2/rnn_vad/lp_residual.cc
    agc2/rnn_vad/pitch_search.cc agc2/rnn_vad/pitch_search_internal.cc
    agc2/rnn_vad/rnn.cc agc2/rnn_vad/rnn_fc.cc agc2/rnn_vad/rnn_gru.cc
    agc2/rnn_vad/spectral_features.cc agc2/rnn_vad/spectral_features_internal.cc
    agc2/saturation_protector.cc agc2/saturation_protector_buffer.cc
    agc2/speech_level_estimator.cc agc2/speech_probability_buffer.cc
    agc2/vad_wrapper.cc agc2/vector_float_frame.cc
    audio_buffer.cc audio_processing_builder_impl.cc audio_processing_impl.cc
    capture_levels_adjuster/audio_samples_scaler.cc
    capture_levels_adjuster/capture_levels_adjuster.cc
    echo_control_mobile_impl.cc
    echo_detector/circular_buffer.cc echo_detector/mean_variance_estimator.cc
    echo_detector/moving_max.cc echo_detector/normalized_covariance_estimator.cc
    gain_control_impl.cc gain_controller2.cc high_pass_filter.cc
    include/aec_dump.cc include/audio_frame_proxies.cc logging/apm_data_dumper.cc
    ns/fast_math.cc ns/histograms.cc ns/noise_estimator.cc ns/noise_suppressor.cc
    ns/ns_fft.cc ns/prior_signal_model.cc ns/prior_signal_model_estimator.cc
    ns/quantile_noise_estimator.cc ns/signal_model.cc ns/signal_model_estimator.cc
    ns/speech_probability_estimator.cc ns/suppression_params.cc ns/wiener_filter.cc
    residual_echo_detector.cc rms_level.cc splitting_filter.cc three_band_filter_bank.cc
    utility/cascaded_biquad_filter.cc utility/delay_estimator.cc
    utility/delay_estimator_wrapper.cc utility/pffft_wrapper.cc
    vad/gmm.cc vad/pitch_based_vad.cc vad/pitch_internal.cc vad/pole_zero_filter.cc
    vad/standalone_vad.cc vad/vad_audio_proc.cc vad/vad_circular_buffer.cc
    vad/voice_activity_detector.cc)
  list(APPEND VC_APM_SOURCES modules/audio_processing/${source})
endforeach()

if(ANDROID)
  list(APPEND VC_APM_SOURCES rtc_base/system/warn_current_thread_is_deadlocked.cc)
endif()

if(VC_APM_ARM64)
  list(APPEND VC_APM_SOURCES
    common_audio/fir_filter_neon.cc
    common_audio/resampler/sinc_resampler_neon.cc
    common_audio/signal_processing/cross_correlation_neon.c
    common_audio/signal_processing/downsample_fast_neon.c
    common_audio/signal_processing/min_max_operations_neon.c
    common_audio/third_party/ooura/fft_size_128/ooura_fft_neon.cc
    modules/audio_processing/aecm/aecm_core_neon.cc)
endif()

list(TRANSFORM VC_APM_SOURCES PREPEND ${VC_APM_DIR}/)

set(VC_APM_DEFINITIONS WEBRTC_APM_DEBUG_DUMP=0 WEBRTC_LIBRARY_IMPL WEBRTC_POSIX)
if(ANDROID)
  list(APPEND VC_APM_DEFINITIONS WEBRTC_ANDROID WEBRTC_LINUX)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND VC_APM_DEFINITIONS WEBRTC_LINUX)
elseif(APPLE)
  list(APPEND VC_APM_DEFINITIONS WEBRTC_MAC)
  if(IOS)
    list(APPEND VC_APM_DEFINITIONS WEBRTC_IOS)
  endif()
endif()
if(VC_APM_X86)
  list(APPEND VC_APM_DEFINITIONS WEBRTC_ENABLE_AVX2)
elseif(VC_APM_ARM64)
  list(APPEND VC_APM_DEFINITIONS WEBRTC_ARCH_ARM64 WEBRTC_HAS_NEON)
elseif(VC_APM_ARMV7)
  # NEON code paths are left out on 32-bit ARM (portable C instead).
  list(APPEND VC_APM_DEFINITIONS WEBRTC_ARCH_ARM WEBRTC_ARCH_ARM_V7)
endif()

set(VC_APM_ABSL absl::strings absl::base absl::core_headers absl::nullability
    absl::algorithm_container absl::any_invocable absl::type_traits)

# Upstream always compiles the APM with NDEBUG (no RTC_DCHECKs) and optimized:
# even the desktop debug builds run real audio through it in the tests.
function(vc_configure_apm_target target)
  target_include_directories(${target} SYSTEM PUBLIC ${VC_APM_DIR})
  target_compile_definitions(${target} PUBLIC ${VC_APM_DEFINITIONS} PRIVATE NDEBUG)
  target_compile_options(${target} PRIVATE -w $<$<CONFIG:Debug>:-O2>
    # Some v2.1 headers (rtc_base/trace_event.h) use uint8_t without
    # <cstdint>, which recent libstdc++ no longer pulls in transitively.
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include cstdint>")
  if(VC_APM_ARMV7)  # pffft: no NEON on 32-bit ARM
    target_compile_definitions(${target} PRIVATE PFFFT_SIMD_DISABLE)
  endif()
  target_link_libraries(${target} PUBLIC ${VC_APM_ABSL})
endfunction()

add_library(vc_webrtc_apm STATIC ${VC_APM_SOURCES})
vc_configure_apm_target(vc_webrtc_apm)
target_compile_definitions(vc_webrtc_apm PRIVATE _GNU_SOURCE)  # pffft
find_package(Threads REQUIRED)
target_link_libraries(vc_webrtc_apm PUBLIC Threads::Threads m)
if(ANDROID)
  target_link_libraries(vc_webrtc_apm PUBLIC log)
endif()

if(VC_APM_X86)
  # SIMD code lives in separate files, compiled with its own flags and chosen
  # at run time by CPU detection (as in common_audio and audio_processing meson).
  add_library(vc_webrtc_apm_sse2 OBJECT
    ${VC_APM_DIR}/common_audio/fir_filter_sse.cc
    ${VC_APM_DIR}/common_audio/resampler/sinc_resampler_sse.cc
    ${VC_APM_DIR}/common_audio/third_party/ooura/fft_size_128/ooura_fft_sse2.cc)
  vc_configure_apm_target(vc_webrtc_apm_sse2)
  target_compile_options(vc_webrtc_apm_sse2 PRIVATE -msse2)

  add_library(vc_webrtc_apm_avx2 OBJECT
    ${VC_APM_DIR}/common_audio/fir_filter_avx2.cc
    ${VC_APM_DIR}/common_audio/resampler/sinc_resampler_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/aec3/adaptive_fir_filter_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/aec3/adaptive_fir_filter_erl_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/aec3/fft_data_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/aec3/matched_filter_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/aec3/vector_math_avx2.cc
    ${VC_APM_DIR}/modules/audio_processing/agc2/rnn_vad/vector_math_avx2.cc)
  vc_configure_apm_target(vc_webrtc_apm_avx2)
  target_compile_options(vc_webrtc_apm_avx2 PRIVATE -mavx2 -mfma)

  target_sources(vc_webrtc_apm PRIVATE
    $<TARGET_OBJECTS:vc_webrtc_apm_sse2> $<TARGET_OBJECTS:vc_webrtc_apm_avx2>)
endif()
