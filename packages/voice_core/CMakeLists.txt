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
option(VC_BUILD_FUZZERS "Build the libFuzzer targets (clang only)." OFF)
option(VC_ENABLE_COVERAGE "Instrument voice_core_lib for gcov/gcovr." OFF)
option(VC_WARNINGS_AS_ERRORS "Treat compiler warnings as errors." OFF)
set(VC_SANITIZER "" CACHE STRING "Sanitizer to enable: '', 'address' or 'thread'.")
set_property(CACHE VC_SANITIZER PROPERTY STRINGS "" address thread)

include(cmake/VoiceCoreOptions.cmake)

# --- Core objects: all logic, shared by the shared library, tests and fuzzers.
add_library(voice_core_lib OBJECT
  src/api/voice_core_api.cpp
)
target_include_directories(voice_core_lib
  PUBLIC ${PROJECT_SOURCE_DIR}/include
  PRIVATE ${PROJECT_SOURCE_DIR}/src
)
target_compile_features(voice_core_lib PUBLIC cxx_std_17)
vc_apply_warnings(voice_core_lib)
vc_apply_coverage(voice_core_lib)

# --- Shared library loaded by dart:ffi and by JNI (libvoice_core.so).
add_library(voice_core SHARED $<TARGET_OBJECTS:voice_core_lib>)
if(VC_ENABLE_COVERAGE)
  target_link_options(voice_core PRIVATE --coverage)
endif()
set_target_properties(voice_core PROPERTIES OUTPUT_NAME "voice_core")
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

if(VC_BUILD_FUZZERS)
  add_subdirectory(tests/fuzz)
endif()
