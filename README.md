# teensy-cmake

Build Teensy 4.x firmware with CMake, without the Arduino IDE.

## Requirements

- CMake 3.25 or newer.
- `arm-none-eabi-gcc` with C++20 support: Homebrew (`brew install --cask gcc-arm-embedded`), the [Arm GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) in `/Applications` or on the `PATH`, or `apt install gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib`.
- For flashing: `teensy_loader_cli` (`brew install teensy_loader_cli`) or Teensyduino. Without either, no `_flash` target is created.

## Usage

Add the repository as a git submodule, in `externals/teensy-cmake` for example:

```cmake
cmake_minimum_required(VERSION 3.25)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/externals/teensy-cmake/cmake/toolchain.cmake)
project(my_firmware LANGUAGES C CXX ASM)

add_subdirectory(externals/teensy-cmake)

teensy_add_firmware(blink main.cpp)
target_compile_features(blink PRIVATE cxx_std_20)
```

`teensy_add_firmware` produces `blink.elf`, `blink.hex` and `blink.map`, and a `blink_flash` target. With `teensy_loader_cli`, press the button of the board when flashing.

After each link, the memory usage is printed, like Teensyduino does:

```
blink: memory usage on Teensy 4.0
  FLASH  25.0 KB of 1984.0 KB (1%)
  RAM1   35.4 KB of 512.0 KB (6%): ITCM 32.0 KB (code 11.4 KB, padding 20.6 KB), DTCM 3.4 KB, 476.6 KB left for the stack
  RAM2   12.1 KB of 512.0 KB (2%), 499.9 KB left for malloc and new
```

The C++ standard of your targets is your choice. The Teensy core is built with its own flags (`-std=gnu++17` and the Teensyduino flags), kept private to the core target.

The USB type (the Tools > USB Type menu of Teensyduino) is chosen per firmware, `TEENSY_USB_TYPE` when omitted:

```cmake
teensy_add_firmware(synth USB_TYPE MIDI_SERIAL main.cpp)
```

The core is compiled once per USB type in use. `teensy::core` is the core of the `TEENSY_USB_TYPE` type.

## Presets

With CMake presets, set the toolchain in the preset instead of the `CMakeLists.txt`:

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "teensy",
      "binaryDir": "${sourceDir}/build/teensy",
      "toolchainFile": "${sourceDir}/externals/teensy-cmake/cmake/toolchain.cmake",
      "cacheVariables": {
        "TEENSY_BOARD": "40"
      }
    }
  ]
}
```

## Options

| Cache variable | Default | |
|---|---|---|
| `TEENSY_BOARD` | `40` | `40` or `41` |
| `TEENSY_USB_TYPE` | `SERIAL` | USB type of the firmwares that do not choose one, among those of the core's `teensy4/usb_desc.h`: `SERIAL`, `MIDI_SERIAL`, `MIDI_AUDIO_SERIAL`... |
| `TEENSY_CORES_TAG` | `1.62` | Tag or commit of [PaulStoffregen/cores](https://github.com/PaulStoffregen/cores) |
| `TEENSY_TEENSYDUINO` | `160` | Value of the `TEENSYDUINO` define, `160` like Teensyduino 1.62 |
| `TEENSY_CORES_CACHE_DIR` | `~/.cache/teensy-cmake` | Where the core is downloaded once for every build directory. Empty: downloaded in each build directory |
| `FETCHCONTENT_SOURCE_DIR_TEENSY_CORES` | | A local copy of the core to use instead |

## License

Boost Software License 1.0, see [LICENSE](LICENSE).

The Teensy core is not part of this repository: it is downloaded at configure time and has its own license (PJRC, MIT style, with a clause about Teensy boards in build systems that list target devices). It applies to whoever builds and distributes a firmware.
