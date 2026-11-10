set_property(GLOBAL PROPERTY TEENSY_SIZE_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/TeensySize.cmake)

function(teensy_add_firmware name)
    cmake_parse_arguments(PARSE_ARGV 1 firmware "" "USB_TYPE" "")
    if(NOT firmware_USB_TYPE)
        set(firmware_USB_TYPE ${TEENSY_USB_TYPE})
    endif()
    teensy_core_target(${firmware_USB_TYPE} core)
    get_property(linker_script GLOBAL PROPERTY TEENSY_LINKER_SCRIPT)
    get_property(board_version GLOBAL PROPERTY TEENSY_BOARD_VERSION)
    get_property(size_script GLOBAL PROPERTY TEENSY_SIZE_SCRIPT)
    add_executable(${name} ${firmware_UNPARSED_ARGUMENTS})
    target_link_libraries(${name} PRIVATE ${core})
    set_target_properties(${name} PROPERTIES SUFFIX .elf)
    target_link_options(${name} PRIVATE -Wl,-Map=$<TARGET_FILE_DIR:${name}>/${name}.map)
    add_custom_command(TARGET ${name} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom $<TARGET_FILE:${name}> $<TARGET_FILE_DIR:${name}>/${name}.hex
        COMMAND ${CMAKE_COMMAND} -DREADELF=${CMAKE_READELF} -DELF=$<TARGET_FILE:${name}> -DLINKER_SCRIPT=${linker_script} -DNAME=${name} -DBOARD=${board_version} -P ${size_script}
        COMMENT "Writing ${name}.hex and reporting its memory usage"
    )
    teensy_add_flash_target(${name})
endfunction()
