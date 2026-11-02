add_executable(voice_core_tests
  support/allocation_guard.cpp
  support/allocation_guard_test.cpp
  api/config_mapper_test.cpp
  api/voice_core_api_test.cpp
  audio/audio_pipelines_test.cpp
  audio/miniaudio_device_test.cpp
  audio/spsc_ring_buffer_test.cpp
  codec/opus_codec_test.cpp
  common/clock_test.cpp
  common/expected_test.cpp
  config/core_config_test.cpp
  engine/media_loop_test.cpp
  engine/network_pump_test.cpp
  engine/voice_engine_test.cpp
  events/core_event_test.cpp
  events/event_dispatcher_test.cpp
  jitter/jitter_buffer_test.cpp
  jitter/target_delay_estimator_test.cpp
  net/audio_packet_test.cpp
  net/datagram_socket_contract_test.cpp
  net/endpoint_test.cpp
  net/posix_udp_socket_test.cpp
  net/sequence_test.cpp
  session/peer_session_test.cpp
  stats/stats_test.cpp
)
target_include_directories(voice_core_tests PRIVATE
  ${PROJECT_SOURCE_DIR}/src
  ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(voice_core_tests PRIVATE voice_core_lib GTest::gmock_main)
vc_apply_warnings(voice_core_tests)
if(NOT VC_SANITIZER STREQUAL "thread")
  target_compile_definitions(voice_core_tests PRIVATE VC_COUNT_ALLOCATIONS)
endif()

include(GoogleTest)
gtest_discover_tests(voice_core_tests DISCOVERY_MODE PRE_TEST)
