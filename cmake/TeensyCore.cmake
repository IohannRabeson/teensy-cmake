include(FetchContent)

set(TEENSY_BOARD 40 CACHE STRING "Teensy board: 40 or 41")
set_property(CACHE TEENSY_BOARD PROPERTY STRINGS 40 41)
if(TEENSY_BOARD STREQUAL 40)
    set(TEENSY_LINKER_SCRIPT_NAME imxrt1062.ld)
elseif(TEENSY_BOARD STREQUAL 41)
    set(TEENSY_LINKER_SCRIPT_NAME imxrt1062_t41.ld)
else()
    message(FATAL_ERROR "TEENSY_BOARD must be 40 or 41, not '${TEENSY_BOARD}'")
endif()
set(TEENSY_BOARD_NAME TEENSY${TEENSY_BOARD})

set(TEENSY_CORES_TAG 1.62 CACHE STRING "Tag or commit of PaulStoffregen/cores")

if(DEFINED ENV{XDG_CACHE_HOME})
    set(TEENSY_CORES_CACHE_DEFAULT $ENV{XDG_CACHE_HOME}/teensy-cmake)
elseif(DEFINED ENV{HOME})
    set(TEENSY_CORES_CACHE_DEFAULT $ENV{HOME}/.cache/teensy-cmake)
elseif(DEFINED ENV{LOCALAPPDATA})
    file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}/teensy-cmake" TEENSY_CORES_CACHE_DEFAULT)
else()
    set(TEENSY_CORES_CACHE_DEFAULT "")
endif()
set(TEENSY_CORES_CACHE_DIR ${TEENSY_CORES_CACHE_DEFAULT} CACHE PATH "Folder shared by all build directories for the downloaded core, empty to download it in each build directory")

set(TEENSY_CORES_FETCH_ARGS
    GIT_REPOSITORY https://github.com/PaulStoffregen/cores.git
    GIT_TAG ${TEENSY_CORES_TAG}
    GIT_SHALLOW TRUE
)
if(TEENSY_CORES_CACHE_DIR AND NOT FETCHCONTENT_SOURCE_DIR_TEENSY_CORES)
    set(TEENSY_CORES_CACHED ${TEENSY_CORES_CACHE_DIR}/cores-${TEENSY_CORES_TAG})
    if(EXISTS ${TEENSY_CORES_CACHED}/teensy4/${TEENSY_LINKER_SCRIPT_NAME})
        set(FETCHCONTENT_SOURCE_DIR_TEENSY_CORES ${TEENSY_CORES_CACHED})
    else()
        list(APPEND TEENSY_CORES_FETCH_ARGS SOURCE_DIR ${TEENSY_CORES_CACHED})
    endif()
endif()

FetchContent_Declare(teensy_cores ${TEENSY_CORES_FETCH_ARGS})
FetchContent_MakeAvailable(teensy_cores)

set(TEENSY_CORE_DIR ${teensy_cores_SOURCE_DIR}/teensy4)
set(TEENSY_LINKER_SCRIPT ${TEENSY_CORE_DIR}/${TEENSY_LINKER_SCRIPT_NAME})
if(NOT EXISTS ${TEENSY_LINKER_SCRIPT})
    message(FATAL_ERROR "Teensy 4 core not found in ${teensy_cores_SOURCE_DIR}")
endif()
message(STATUS "Teensy core ${TEENSY_CORES_TAG}: ${TEENSY_CORE_DIR}")

file(GLOB TEENSY_CORE_SOURCES CONFIGURE_DEPENDS
    ${TEENSY_CORE_DIR}/*.c
    ${TEENSY_CORE_DIR}/*.cpp
    ${TEENSY_CORE_DIR}/*.S
)

add_library(teensy_core STATIC ${TEENSY_CORE_SOURCES})
add_library(teensy::core ALIAS teensy_core)
target_include_directories(teensy_core SYSTEM PUBLIC ${TEENSY_CORE_DIR})
target_compile_definitions(teensy_core PUBLIC
    __IMXRT1062__
    ARDUINO_${TEENSY_BOARD_NAME}
    TEENSYDUINO=160
    ARDUINO=10819
    F_CPU=600000000
    USB_SERIAL
    LAYOUT_US_ENGLISH
)
set_target_properties(teensy_core PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS ON
)
target_compile_options(teensy_core PRIVATE
    -O2
    $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fpermissive -fno-rtti -fno-threadsafe-statics -felide-constructors -Wno-error=narrowing -Wno-psabi -Wno-maybe-uninitialized>
    $<$<COMPILE_LANGUAGE:ASM>:-x assembler-with-cpp>
)
target_link_options(teensy_core INTERFACE
    -T${TEENSY_LINKER_SCRIPT}
    -Wl,--relax
    -Wl,--no-warn-rwx-segments
)
target_link_libraries(teensy_core INTERFACE m stdc++)
set_target_properties(teensy_core PROPERTIES
    INTERFACE_LINK_DEPENDS ${TEENSY_LINKER_SCRIPT}
    TEENSY_BOARD_NAME ${TEENSY_BOARD_NAME}
)
