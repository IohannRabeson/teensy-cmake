include(FetchContent)

set(TEENSY_BOARD 40 CACHE STRING "Teensy board: 40 or 41")
set_property(CACHE TEENSY_BOARD PROPERTY STRINGS 40 41)
if(TEENSY_BOARD STREQUAL 40)
    set(TEENSY_LINKER_SCRIPT_NAME imxrt1062.ld)
    set(TEENSY_BOARD_VERSION 4.0)
elseif(TEENSY_BOARD STREQUAL 41)
    set(TEENSY_LINKER_SCRIPT_NAME imxrt1062_t41.ld)
    set(TEENSY_BOARD_VERSION 4.1)
else()
    message(FATAL_ERROR "TEENSY_BOARD must be 40 or 41, not '${TEENSY_BOARD}'")
endif()
# The functions of teensy-cmake run in the directory of their caller, which
# does not see the variables of this one. What they need goes in global
# properties.
set_property(GLOBAL PROPERTY TEENSY_BOARD_NAME TEENSY${TEENSY_BOARD})
set_property(GLOBAL PROPERTY TEENSY_BOARD_VERSION ${TEENSY_BOARD_VERSION})

set(TEENSY_CORES_TAG 1.62 CACHE STRING "Tag or commit of PaulStoffregen/cores")

# Default folder for the downloaded core: $XDG_CACHE_HOME or ~/.cache on Linux
# and macOS, %LOCALAPPDATA% on Windows.
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
# The first configure clones the core into the cache folder. The next ones find
# it there and use it as a local copy, without git.
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
set(TEENSY_CORE_LINKER_SCRIPT ${TEENSY_CORE_DIR}/${TEENSY_LINKER_SCRIPT_NAME})
if(NOT EXISTS ${TEENSY_CORE_LINKER_SCRIPT})
    message(FATAL_ERROR "Teensy 4 core not found in ${teensy_cores_SOURCE_DIR}")
endif()
message(STATUS "Teensy core ${TEENSY_CORES_TAG}: ${TEENSY_CORE_DIR}")

# The USB types are the "#if defined(USB_xxx)" blocks of usb_desc.h, each type
# is the name without the USB_ prefix.
file(STRINGS ${TEENSY_CORE_DIR}/usb_desc.h TEENSY_USB_TYPES REGEX "^#(el)?if defined\\(USB_[A-Z0-9_]+\\)")
list(TRANSFORM TEENSY_USB_TYPES REPLACE "^#(el)?if defined\\(USB_([A-Z0-9_]+)\\).*$" "\\2")
if(NOT TEENSY_USB_TYPES)
    message(FATAL_ERROR "No USB type found in ${TEENSY_CORE_DIR}/usb_desc.h")
endif()
set_property(GLOBAL PROPERTY TEENSY_USB_TYPES ${TEENSY_USB_TYPES})
set(TEENSY_USB_TYPE SERIAL CACHE STRING "USB type of the firmwares that do not choose one")
set_property(CACHE TEENSY_USB_TYPE PROPERTY STRINGS ${TEENSY_USB_TYPES})

# The linker script of PJRC puts .ARM.extab inside .ARM.exidx, which corrupts
# the unwind tables. This copy of the script moves .ARM.extab next to the ITCM
# code instead. The copy is only written when its content changes, otherwise
# every configure would relink all the firmwares.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${TEENSY_CORE_LINKER_SCRIPT})
file(READ ${TEENSY_CORE_LINKER_SCRIPT} TEENSY_LINKER_SCRIPT_CONTENT)
set(TEENSY_EXIDX_INPUTS "*(.ARM.exidx* .ARM.extab.text* .gnu.linkonce.armexidx.*)")
set(TEENSY_ITCM_TEXT_INPUTS "*(.text*)")
string(FIND "${TEENSY_LINKER_SCRIPT_CONTENT}" "${TEENSY_EXIDX_INPUTS}" TEENSY_EXIDX_INPUTS_FOUND)
string(FIND "${TEENSY_LINKER_SCRIPT_CONTENT}" "${TEENSY_ITCM_TEXT_INPUTS}" TEENSY_ITCM_TEXT_INPUTS_FOUND)
if(TEENSY_EXIDX_INPUTS_FOUND EQUAL -1 OR TEENSY_ITCM_TEXT_INPUTS_FOUND EQUAL -1)
    message(WARNING "${TEENSY_CORE_LINKER_SCRIPT} has changed, it is used without moving .ARM.extab out of .ARM.exidx")
    set(TEENSY_LINKER_SCRIPT ${TEENSY_CORE_LINKER_SCRIPT})
else()
    string(REPLACE "${TEENSY_EXIDX_INPUTS}" "*(.ARM.exidx* .gnu.linkonce.armexidx.*)" TEENSY_LINKER_SCRIPT_PATCHED "${TEENSY_LINKER_SCRIPT_CONTENT}")
    string(REPLACE "${TEENSY_ITCM_TEXT_INPUTS}" "*(.text*)\n\t\t*(.ARM.extab* .gnu.linkonce.armextab.*)" TEENSY_LINKER_SCRIPT_PATCHED "${TEENSY_LINKER_SCRIPT_PATCHED}")
    set(TEENSY_LINKER_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/${TEENSY_LINKER_SCRIPT_NAME})
    set(TEENSY_LINKER_SCRIPT_PREVIOUS "")
    if(EXISTS ${TEENSY_LINKER_SCRIPT})
        file(READ ${TEENSY_LINKER_SCRIPT} TEENSY_LINKER_SCRIPT_PREVIOUS)
    endif()
    if(NOT TEENSY_LINKER_SCRIPT_PREVIOUS STREQUAL TEENSY_LINKER_SCRIPT_PATCHED)
        file(WRITE ${TEENSY_LINKER_SCRIPT} "${TEENSY_LINKER_SCRIPT_PATCHED}")
    endif()
endif()

# CONFIGURE_DEPENDS: the build checks the glob again, a file added to the core
# reconfigures the project.
file(GLOB TEENSY_CORE_SOURCES CONFIGURE_DEPENDS
    ${TEENSY_CORE_DIR}/*.c
    ${TEENSY_CORE_DIR}/*.cpp
    ${TEENSY_CORE_DIR}/*.S
)
set_property(GLOBAL PROPERTY TEENSY_CORE_SOURCES ${TEENSY_CORE_SOURCES})
set_property(GLOBAL PROPERTY TEENSY_CORE_DIR ${TEENSY_CORE_DIR})
set_property(GLOBAL PROPERTY TEENSY_LINKER_SCRIPT ${TEENSY_LINKER_SCRIPT})

# Returns in out the core target of a USB type, created the first time it is
# needed. The USB type changes what the core compiles, so each type needs its
# own build of the core.
function(teensy_core_target usb_type out)
    get_property(usb_types GLOBAL PROPERTY TEENSY_USB_TYPES)
    if(NOT usb_type IN_LIST usb_types)
        message(FATAL_ERROR "Unknown Teensy USB type '${usb_type}', expected one of: ${usb_types}")
    endif()
    string(TOLOWER ${usb_type} suffix)
    set(target teensy_core_${suffix})
    if(NOT TARGET ${target})
        get_property(sources GLOBAL PROPERTY TEENSY_CORE_SOURCES)
        get_property(core_dir GLOBAL PROPERTY TEENSY_CORE_DIR)
        get_property(linker_script GLOBAL PROPERTY TEENSY_LINKER_SCRIPT)
        get_property(board_name GLOBAL PROPERTY TEENSY_BOARD_NAME)
        add_library(${target} STATIC ${sources})
        target_include_directories(${target} SYSTEM PUBLIC ${core_dir})
        # The defines and flags Teensyduino uses for a Teensy 4 (boards.txt and
        # platform.txt). The defines are public, the headers of the core depend
        # on them. The flags are private, they do not apply to the firmwares.
        target_compile_definitions(${target} PUBLIC
            __IMXRT1062__
            ARDUINO_${board_name}
            TEENSYDUINO=160
            ARDUINO=10819
            F_CPU=600000000
            USB_${usb_type}
            LAYOUT_US_ENGLISH
        )
        set_target_properties(${target} PROPERTIES
            CXX_STANDARD 17
            CXX_STANDARD_REQUIRED ON
            CXX_EXTENSIONS ON
        )
        target_compile_options(${target} PRIVATE
            -O2
            $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions -fpermissive -fno-rtti -fno-threadsafe-statics -felide-constructors -Wno-error=narrowing -Wno-psabi -Wno-maybe-uninitialized>
            $<$<COMPILE_LANGUAGE:ASM>:-x assembler-with-cpp>
        )
        # The firmwares that link the core are linked with its linker script,
        # and relinked when the script changes (INTERFACE_LINK_DEPENDS).
        target_link_options(${target} INTERFACE
            -T${linker_script}
            -Wl,--relax
            -Wl,--no-warn-rwx-segments
        )
        target_link_libraries(${target} INTERFACE m stdc++)
        set_target_properties(${target} PROPERTIES INTERFACE_LINK_DEPENDS ${linker_script})
    endif()
    set(${out} ${target} PARENT_SCOPE)
endfunction()

# teensy::core is the core of the default USB type.
teensy_core_target(${TEENSY_USB_TYPE} TEENSY_DEFAULT_CORE)
add_library(teensy::core ALIAS ${TEENSY_DEFAULT_CORE})
