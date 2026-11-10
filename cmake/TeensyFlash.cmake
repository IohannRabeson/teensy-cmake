find_program(TEENSY_LOADER_CLI teensy_loader_cli HINTS /opt/homebrew/bin /usr/local/bin)

if(NOT TEENSY_LOADER_CLI)
    set(TEENSY_PACKAGE_ROOTS
        $ENV{HOME}/Library/Arduino15/packages/teensy
        $ENV{HOME}/.arduino15/packages/teensy
    )
    if(DEFINED ENV{LOCALAPPDATA})
        file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}/Arduino15/packages/teensy" TEENSY_WINDOWS_ROOT)
        list(APPEND TEENSY_PACKAGE_ROOTS ${TEENSY_WINDOWS_ROOT})
    endif()
    set(TEENSY_TOOLS_CANDIDATES)
    foreach(root IN LISTS TEENSY_PACKAGE_ROOTS)
        file(GLOB candidates LIST_DIRECTORIES true ${root}/tools/teensy-tools/*)
        list(APPEND TEENSY_TOOLS_CANDIDATES ${candidates})
    endforeach()
    list(SORT TEENSY_TOOLS_CANDIDATES COMPARE NATURAL ORDER DESCENDING)
    find_program(TEENSY_POST_COMPILE teensy_post_compile HINTS ${TEENSY_TOOLS_CANDIDATES} NO_DEFAULT_PATH)
endif()

if(TEENSY_LOADER_CLI)
    message(STATUS "Teensy flashing: ${TEENSY_LOADER_CLI}")
elseif(TEENSY_POST_COMPILE)
    message(STATUS "Teensy flashing: ${TEENSY_POST_COMPILE}")
else()
    message(WARNING "Neither teensy_loader_cli nor the Teensyduino tools were found: the _flash targets are not created. Install teensy_loader_cli (brew install teensy_loader_cli) or Teensyduino.")
endif()

function(teensy_add_flash_target name)
    if(TEENSY_LOADER_CLI)
        add_custom_target(${name}_flash
            COMMAND ${TEENSY_LOADER_CLI} --mcu=${TEENSY_BOARD_NAME} -w -v $<TARGET_FILE_DIR:${name}>/${name}.hex
            DEPENDS ${name}
            USES_TERMINAL
        )
    elseif(TEENSY_POST_COMPILE)
        cmake_path(GET TEENSY_POST_COMPILE PARENT_PATH tools)
        add_custom_target(${name}_flash
            COMMAND $<$<BOOL:${CMAKE_HOST_UNIX}>:nohup> ${TEENSY_POST_COMPILE} -file=${name} -path=$<TARGET_FILE_DIR:${name}> -tools=${tools} -board=${TEENSY_BOARD_NAME} -reboot
            DEPENDS ${name}
        )
    endif()
endfunction()
