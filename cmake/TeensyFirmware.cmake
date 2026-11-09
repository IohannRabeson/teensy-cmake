function(teensy_add_firmware name)
    add_executable(${name} ${ARGN})
    target_link_libraries(${name} PRIVATE teensy::core)
    set_target_properties(${name} PROPERTIES SUFFIX .elf)
    target_link_options(${name} PRIVATE -Wl,-Map=$<TARGET_FILE_DIR:${name}>/${name}.map)
    add_custom_command(TARGET ${name} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom $<TARGET_FILE:${name}> $<TARGET_FILE_DIR:${name}>/${name}.hex
        COMMENT "Writing ${name}.hex"
    )
    teensy_add_flash_target(${name})
endfunction()
