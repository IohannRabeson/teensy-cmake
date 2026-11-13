# Flashing uses teensy_loader_cli when it is installed, otherwise the
# teensy_post_compile tool of Teensyduino.
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
    # The newest Teensyduino version first.
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
    get_property(board_name GLOBAL PROPERTY TEENSY_BOARD_NAME)
    if(TEENSY_LOADER_CLI)
        # -w waits for the board to enter its bootloader (press its button),
        # -v prints the progress.
        add_custom_target(${name}_flash
            COMMAND ${TEENSY_LOADER_CLI} --mcu=${board_name} -w -v $<TARGET_FILE_DIR:${name}>/${name}.hex
            DEPENDS ${name}
            COMMENT "Flashing ${name}.hex"
            USES_TERMINAL
        )
    elseif(TEENSY_POST_COMPILE)
        # teensy_post_compile hands the .hex to the Teensy Loader application,
        # -reboot asks the running firmware to reboot into the bootloader.
        # On Unix, sh ignores SIGHUP before running it (trap), so it stays alive
        # when CLion closes the terminal of the target. nohup does the same but
        # hides the output in a nohup.out file. The command and its arguments
        # are passed to sh as $0 and $@, so they need no quoting.
        cmake_path(GET TEENSY_POST_COMPILE PARENT_PATH tools)
        set(ignore_hangup)
        if(CMAKE_HOST_UNIX)
            set(ignore_hangup sh -c "trap '' HUP && exec \"$0\" \"$@\"")
        endif()
        add_custom_target(${name}_flash
            COMMAND ${ignore_hangup} ${TEENSY_POST_COMPILE} -file=${name} -path=$<TARGET_FILE_DIR:${name}> -tools=${tools} -board=${board_name} -reboot
            DEPENDS ${name}
            COMMENT "Flashing ${name}.hex"
            VERBATIM
        )
    endif()
endfunction()
