# libFuzzer targets for the parsers (AudioPacket, LengthPrefixedFramer,
# ControlMessageCodec). The first targets arrive in phase 1.

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  message(FATAL_ERROR "VC_BUILD_FUZZERS requires clang (libFuzzer).")
endif()

# Registers a fuzz target. The binary runs a short campaign from tools/verify_core.sh.
function(vc_add_fuzzer name source)
  add_executable(${name} ${source})
  target_include_directories(${name} PRIVATE ${PROJECT_SOURCE_DIR}/src)
  target_link_libraries(${name} PRIVATE voice_core_lib)
  target_compile_options(${name} PRIVATE -fsanitize=fuzzer)
  target_link_options(${name} PRIVATE -fsanitize=fuzzer)
  set_property(GLOBAL APPEND PROPERTY VC_FUZZ_TARGETS ${name})
endfunction()

vc_add_fuzzer(audio_packet_fuzzer audio_packet_fuzzer.cpp)

# Fuzz targets are registered above this line with vc_add_fuzzer().

# tools/verify_core.sh reads this list to know which binaries to run.
get_property(VC_FUZZ_TARGET_LIST GLOBAL PROPERTY VC_FUZZ_TARGETS)
file(WRITE "${CMAKE_BINARY_DIR}/fuzz_targets.txt" "${VC_FUZZ_TARGET_LIST}")
