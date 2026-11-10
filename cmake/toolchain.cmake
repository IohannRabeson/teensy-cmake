set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR cortex-m7)

# The Arm GNU Toolchain from arm.com installs in
# /Applications/ArmGNUToolchain/<version> on macOS, the newest version first.
# Then Homebrew and the system packages.
file(GLOB TEENSY_ARM_TOOLCHAIN_BINS LIST_DIRECTORIES true /Applications/ArmGNUToolchain/*/arm-none-eabi/bin)
list(SORT TEENSY_ARM_TOOLCHAIN_BINS COMPARE NATURAL ORDER DESCENDING)
set(TEENSY_ARM_TOOLCHAIN_HINTS ${TEENSY_ARM_TOOLCHAIN_BINS} /opt/homebrew/bin /usr/local/bin /usr/bin)

find_program(CMAKE_C_COMPILER arm-none-eabi-gcc HINTS ${TEENSY_ARM_TOOLCHAIN_HINTS} REQUIRED)
find_program(CMAKE_CXX_COMPILER arm-none-eabi-g++ HINTS ${TEENSY_ARM_TOOLCHAIN_HINTS} REQUIRED)
# The other tools must come from the same toolchain as the compiler.
cmake_path(GET CMAKE_C_COMPILER PARENT_PATH TEENSY_ARM_TOOLCHAIN_DIR)
find_program(CMAKE_OBJCOPY arm-none-eabi-objcopy HINTS ${TEENSY_ARM_TOOLCHAIN_DIR} REQUIRED)

# Cortex-M7 with its double precision FPU. Each function and variable gets its
# own section, so --gc-sections can drop the unused ones at link time.
set(CMAKE_C_FLAGS_INIT "-mthumb -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-d16 -ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_C_FLAGS_INIT}")
set(CMAKE_ASM_FLAGS_INIT "-mthumb -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-d16")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl,--gc-sections")
# An executable cannot link without the core and its linker script, so CMake
# tests the compiler by building a library.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Programs are searched on the host, libraries and headers only for the target.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
