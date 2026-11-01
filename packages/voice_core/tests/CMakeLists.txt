add_executable(voice_core_tests
  support/allocation_guard.cpp
  support/allocation_guard_test.cpp
  api/voice_core_api_test.cpp
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
