cmake_minimum_required(VERSION 4.1)

# The version lives in src/core_version.h so that every build system (CMake,
# CocoaPods) reads the same value.
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/src/core_version.h" VC_VERSION_LINE
     REGEX "kVersion\\[\\] = \"[0-9]+\\.[0-9]+\\.[0-9]+\"")
string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VC_VERSION "${VC_VERSION_LINE}")

project(voice_core VERSION ${VC_VERSION} LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

if(PROJECT_IS_TOP_LEVEL AND NOT ANDROID AND NOT IOS)
  set(VC_DESKTOP_DEFAULT ON)
else()
  set(VC_DESKTOP_DEFAULT OFF)
endif()

option(VC_BUILD_TESTS "Build the GoogleTest suite." ${VC_DESKTOP_DEFAULT})
option(VC_BUILD_TOOLS "Build the desktop tools (tools/loopback_sim)." ${VC_DESKTOP_DEFAULT})
option(VC_BUILD_FUZZERS "Build the libFuzzer targets (clang only)." OFF)
option(VC_ENABLE_COVERAGE "Instrument voice_core_lib for gcov/gcovr." OFF)
option(VC_WARNINGS_AS_ERRORS "Treat compiler warnings as errors." OFF)
set(VC_SANITIZER "" CACHE STRING "Sanitizer to enable: '', 'address' or 'thread'.")
set_property(CACHE VC_SANITIZER PROPERTY STRINGS "" address thread)

include(cmake/VoiceCoreOptions.cmake)

# --- Third-party libraries: git submodules pinned to tags (docs/DEPENDENCIES.md).
# Nothing is downloaded during the build.
set(OPUS_BUILD_SHARED_LIBRARY OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_PKG_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_CMAKE_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
set(OPUS_DRED OFF CACHE BOOL "" FORCE)  # DRED and OSCE need model files that would
set(OPUS_OSCE OFF CACHE BOOL "" FORCE)  # have to be downloaded
add_subdirectory(third_party/opus EXCLUDE_FROM_ALL SYSTEM)

# miniaudio: only the low-level device API is compiled.
add_library(vc_miniaudio STATIC third_party/miniaudio/miniaudio.c)
target_include_directories(vc_miniaudio SYSTEM PUBLIC ${PROJECT_SOURCE_DIR}/third_party/miniaudio)
target_compile_definitions(vc_miniaudio PUBLIC
  MA_NO_DECODING MA_NO_ENCODING MA_NO_GENERATION MA_NO_RESOURCE_MANAGER MA_NO_NODE_GRAPH
  MA_NO_ENGINE)
find_package(Threads REQUIRED)
target_link_libraries(vc_miniaudio PUBLIC Threads::Threads ${CMAKE_DL_LIBS} m)

# --- Core objects: all logic, shared by the shared library, tests and fuzzers.
add_library(voice_core_lib OBJECT
  src/api/config_mapper.cpp
  src/api/engine_registry.cpp
  src/api/voice_core_api.cpp
  src/audio/audio_pipelines.cpp
  src/audio/miniaudio_device.cpp
  src/codec/opus_codec.cpp
  src/common/clock.cpp
  src/config/core_config.cpp
  src/engine/media_loop.cpp
  src/engine/network_pump.cpp
  src/engine/voice_engine.cpp
  src/events/core_event.cpp
  src/events/event_dispatcher.cpp
  src/jitter/jitter_buffer.cpp
  src/jitter/target_delay_estimator.cpp
  src/net/audio_packet.cpp
  src/net/endpoint.cpp
  src/net/posix_udp_socket.cpp
  src/session/peer_session.cpp
  src/stats/interarrival_jitter.cpp
  src/stats/loss_tracker.cpp
  src/stats/rtt_estimator.cpp
)
if(ANDROID)
  # Device-only shell (JNI); excluded from the desktop coverage gate.
  target_sources(voice_core_lib PRIVATE src/platform/android/jni_bridge.cpp)
endif()
target_include_directories(voice_core_lib
  PUBLIC ${PROJECT_SOURCE_DIR}/include
  PRIVATE ${PROJECT_SOURCE_DIR}/src
)
target_compile_features(voice_core_lib PUBLIC cxx_std_17)
target_link_libraries(voice_core_lib PUBLIC opus vc_miniaudio)
vc_apply_warnings(voice_core_lib)
vc_apply_coverage(voice_core_lib)

# --- Shared library loaded by dart:ffi and by JNI (libvoice_core.so).
add_library(voice_core SHARED $<TARGET_OBJECTS:voice_core_lib>)
target_link_libraries(voice_core PRIVATE opus vc_miniaudio)
if(VC_ENABLE_COVERAGE)
  target_link_options(voice_core PRIVATE --coverage)
endif()
set_target_properties(voice_core PROPERTIES OUTPUT_NAME "voice_core")
if(NOT APPLE)
  # Export only the vc_* API and JNI_OnLoad: not Opus, miniaudio or the C++ runtime.
  set(VC_VERSION_SCRIPT "${PROJECT_SOURCE_DIR}/cmake/voice_core.map")
  target_link_options(voice_core PRIVATE "-Wl,--version-script=${VC_VERSION_SCRIPT}")
  set_property(TARGET voice_core APPEND PROPERTY LINK_DEPENDS "${VC_VERSION_SCRIPT}")
endif()
if(ANDROID)
  # 16 KB page alignment, required by Google Play for native libraries.
  target_link_options(voice_core PRIVATE "-Wl,-z,max-page-size=16384")
endif()

if(VC_BUILD_TESTS)
  enable_testing()
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  add_subdirectory(third_party/googletest EXCLUDE_FROM_ALL SYSTEM)
  add_subdirectory(tests)
endif()

if(VC_BUILD_TOOLS)
  add_subdirectory(${PROJECT_SOURCE_DIR}/../../tools/loopback_sim ${CMAKE_BINARY_DIR}/loopback_sim)
endif()

if(VC_BUILD_FUZZERS)
  add_subdirectory(tests/fuzz)
endif()
