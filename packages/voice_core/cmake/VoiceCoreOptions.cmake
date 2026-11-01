# Build options shared by every voice_core target.

if(VC_SANITIZER STREQUAL "address")
  # Applied globally so that GoogleTest and the core agree on the runtime.
  add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all)
  add_link_options(-fsanitize=address,undefined)
elseif(VC_SANITIZER STREQUAL "thread")
  add_compile_options(-fsanitize=thread -fno-omit-frame-pointer)
  add_link_options(-fsanitize=thread)
elseif(NOT VC_SANITIZER STREQUAL "")
  message(FATAL_ERROR "Unknown VC_SANITIZER '${VC_SANITIZER}'. Use '', 'address' or 'thread'.")
endif()

function(vc_apply_warnings target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4)
    if(VC_WARNINGS_AS_ERRORS)
      target_compile_options(${target} PRIVATE /WX)
    endif()
  else()
    target_compile_options(${target} PRIVATE
      -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
      -Wnon-virtual-dtor -Wold-style-cast -Woverloaded-virtual -Wnull-dereference)
    if(VC_WARNINGS_AS_ERRORS)
      target_compile_options(${target} PRIVATE -Werror)
    endif()
  endif()
endfunction()

function(vc_apply_coverage target)
  if(VC_ENABLE_COVERAGE)
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      message(FATAL_ERROR "VC_ENABLE_COVERAGE requires GCC (gcov/gcovr).")
    endif()
    target_compile_options(${target} PRIVATE --coverage -O0 -g)
    target_link_options(${target} PUBLIC --coverage)
  endif()
endfunction()
