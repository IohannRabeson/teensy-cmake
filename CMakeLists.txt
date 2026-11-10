cmake_minimum_required(VERSION 3.25)

# Built alone, teensy-cmake uses its own toolchain. A project that adds it with
# add_subdirectory() must set the toolchain before its own project().
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR AND NOT CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain.cmake)
endif()

project(teensy-cmake LANGUAGES C CXX ASM)

if(NOT CMAKE_SYSTEM_PROCESSOR STREQUAL cortex-m7)
    message(FATAL_ERROR "teensy-cmake needs its toolchain: set CMAKE_TOOLCHAIN_FILE to ${CMAKE_CURRENT_SOURCE_DIR}/cmake/toolchain.cmake before project()")
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/TeensyCore.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/TeensyFlash.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/TeensyFirmware.cmake)

if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory(tests)
endif()
