function(teensy_add_firmware name)
    cmake_parse_arguments(PARSE_ARGV 1 firmware "" "USB_TYPE" "")
    if(NOT firmware_USB_TYPE)
        set(firmware_USB_TYPE ${TEENSY_USB_TYPE})
    endif()
    teensy_core_target(${firmware_USB_TYPE} core)
    add_executable(${name} ${firmware_UNPARSED_ARGUMENTS})
    target_link_libraries(${name} PRIVATE ${core})
    set_target_properties(${name} PROPERTIES SUFFIX .elf)
    target_link_options(${name} PRIVATE -Wl,-Map=$<TARGET_FILE_DIR:${name}>/${name}.map)
    add_custom_command(TARGET ${name} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom $<TARGET_FILE:${name}> $<TARGET_FILE_DIR:${name}>/${name}.hex
        COMMENT "Writing ${name}.hex"
    )
    teensy_add_flash_target(${name})
endfunction()
