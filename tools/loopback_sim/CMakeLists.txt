# Desktop-only tool (see loopback_sim.cpp). Built from packages/voice_core
# when VC_BUILD_TOOLS is on; outside the coverage gate (tools/).
add_executable(loopback_sim loopback_sim.cpp)
target_include_directories(loopback_sim PRIVATE ${PROJECT_SOURCE_DIR}/src)
target_link_libraries(loopback_sim PRIVATE voice_core_lib)
vc_apply_warnings(loopback_sim)
