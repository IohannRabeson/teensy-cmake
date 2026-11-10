cmake_minimum_required(VERSION 3.25)

if(NOT CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/../cmake/toolchain.cmake)
endif()

project(teensy_tests LANGUAGES C CXX ASM)

if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/.. teensy-cmake)
endif()

teensy_add_firmware(teensy_test_basic basic.cpp)

teensy_add_firmware(teensy_test_cpp20 cpp20.cpp)
target_compile_features(teensy_test_cpp20 PRIVATE cxx_std_20)

teensy_add_firmware(teensy_test_stdlib stdlib.cpp)

teensy_add_firmware(teensy_test_midi USB_TYPE MIDI_SERIAL midi.cpp)
