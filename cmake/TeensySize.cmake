cmake_minimum_required(VERSION 3.25)

foreach(variable IN ITEMS READELF ELF LINKER_SCRIPT NAME BOARD)
    if(NOT DEFINED ${variable})
        message(FATAL_ERROR "TeensySize.cmake needs -D${variable}=...")
    endif()
endforeach()

# RAM1 is the FlexRAM: 16 banks of 32 KB, shared between ITCM (code) and DTCM
# (variables and stack). The startup code gives ITCM as many whole banks as its
# code needs, and the rest to DTCM.
set(flexram_bank_size 32768)
set(flexram_bank_count 16)

function(teensy_kilobytes bytes out)
    # math() only knows integers, so this counts tenths of a kilobyte (+ 512 to
    # round to the nearest), then splits them into the whole part and the one
    # decimal, glued back with a dot.
    math(EXPR tenths "(${bytes} * 10 + 512) / 1024")
    math(EXPR whole "${tenths} / 10")
    math(EXPR fraction "${tenths} % 10")
    set(${out} "${whole}.${fraction} KB" PARENT_SCOPE)
endfunction()

# Reads the MEMORY block of the linker script, lines like:
#   FLASH (rx): ORIGIN = 0x60000000, LENGTH = 1984K
# For each region, this defines <region>_start, <region>_length, <region>_end
# and <region>_used, with the region name in lowercase (itcm, dtcm, ram, flash).
file(READ ${LINKER_SCRIPT} script)
string(REGEX MATCHALL "[A-Z]+ \\([a-z]+\\): *ORIGIN = 0x[0-9A-Fa-f]+, LENGTH = [0-9]+K" region_lines "${script}")
set(regions)
foreach(region_line IN LISTS region_lines)
    if(NOT region_line MATCHES "^([A-Z]+) \\([a-z]+\\): *ORIGIN = (0x[0-9A-Fa-f]+), LENGTH = ([0-9]+)K$")
        continue()
    endif()
    string(TOLOWER ${CMAKE_MATCH_1} region)
    math(EXPR ${region}_start "${CMAKE_MATCH_2}")
    math(EXPR ${region}_length "${CMAKE_MATCH_3} * 1024")
    math(EXPR ${region}_end "${${region}_start} + ${${region}_length}")
    set(${region}_used 0)
    list(APPEND regions ${region})
endforeach()
foreach(region IN ITEMS itcm dtcm ram flash)
    if(NOT region IN_LIST regions)
        message(FATAL_ERROR "No ${region} region in ${LINKER_SCRIPT}")
    endif()
endforeach()

execute_process(
    COMMAND ${READELF} -S -W ${ELF}
    OUTPUT_VARIABLE sections
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "${READELF} failed on ${ELF}")
endif()

# Reads the section table printed by readelf -S -W, lines like:
#   [ 7] .data  PROGBITS  20000000 006000 000ac0 00  WA  0   0 4096
#   [Nr] Name   Type      Addr     Off    Size   ES  Flg Lk Inf Al
# The regex captures the name, the type, the address, the size and the flags.
# The other lines (titles, flag legend) do not match and are skipped.
set(copied_from_flash 0)
set(matched_sections 0)
string(REPLACE "\n" ";" lines "${sections}")
foreach(line IN LISTS lines)
    if(NOT line MATCHES "^ *\\[ *[0-9]+\\] +([^ ]+) +([A-Z_]+) +([0-9a-f]+) +[0-9a-f]+ +([0-9a-f]+) +[0-9a-f]+ +([A-Za-z]*) +[0-9]+ +[0-9]+ +[0-9]+$")
        continue()
    endif()
    math(EXPR matched_sections "${matched_sections} + 1")
    set(type ${CMAKE_MATCH_2})
    set(flags "${CMAKE_MATCH_5}")
    math(EXPR address "0x${CMAKE_MATCH_3}")
    math(EXPR size "0x${CMAKE_MATCH_4}")
    # Only the sections with the A (alloc) flag take memory on the board. The
    # others (debug information, symbols) only exist in the .elf file.
    if(NOT flags MATCHES "A")
        continue()
    endif()
    # A section belongs to the region that contains its address. Sections outside
    # every region are ignored.
    foreach(region IN LISTS regions)
        if(address GREATER_EQUAL ${${region}_start} AND address LESS ${${region}_end})
            math(EXPR ${region}_used "${${region}_used} + ${size}")
            # ITCM and DTCM are RAM: their content is stored in flash and copied
            # there at startup. NOBITS sections (.bss) have no content, they are
            # only zeroed.
            if(region MATCHES "^(itcm|dtcm)$" AND NOT type STREQUAL NOBITS)
                math(EXPR copied_from_flash "${copied_from_flash} + ${size}")
            endif()
            break()
        endif()
    endforeach()
endforeach()
# No matching line means readelf printed something else, and the report would
# show 0 KB everywhere.
if(matched_sections EQUAL 0)
    message(FATAL_ERROR "Could not read the sections of ${ELF} from the output of ${READELF}:\n${sections}")
endif()

math(EXPR flash_used "${flash_used} + ${copied_from_flash}")
# Rounds the ITCM code up to whole FlexRAM banks, the rest of the last bank is
# lost padding.
math(EXPR itcm_allocated "(${itcm_used} + ${flexram_bank_size} - 1) / ${flexram_bank_size} * ${flexram_bank_size}")
math(EXPR itcm_padding "${itcm_allocated} - ${itcm_used}")
math(EXPR ram1_length "${flexram_bank_count} * ${flexram_bank_size}")
math(EXPR ram1_used "${itcm_allocated} + ${dtcm_used}")
math(EXPR ram1_free "${ram1_length} - ${ram1_used}")
math(EXPR ram_free "${ram_length} - ${ram_used}")
math(EXPR flash_percent "${flash_used} * 100 / ${flash_length}")
math(EXPR ram1_percent "${ram1_used} * 100 / ${ram1_length}")
math(EXPR ram_percent "${ram_used} * 100 / ${ram_length}")

foreach(value IN ITEMS flash_used flash_length itcm_allocated itcm_used itcm_padding dtcm_used ram1_used ram1_length ram1_free ram_used ram_length ram_free)
    teensy_kilobytes(${${value}} ${value}_text)
endforeach()

message(NOTICE "${NAME}: memory usage on Teensy ${BOARD}")
message(NOTICE "  FLASH  ${flash_used_text} of ${flash_length_text} (${flash_percent}%)")
message(NOTICE "  RAM1   ${ram1_used_text} of ${ram1_length_text} (${ram1_percent}%): ITCM ${itcm_allocated_text} (code ${itcm_used_text}, padding ${itcm_padding_text}), DTCM ${dtcm_used_text}, ${ram1_free_text} left for the stack")
message(NOTICE "  RAM2   ${ram_used_text} of ${ram_length_text} (${ram_percent}%), ${ram_free_text} left for malloc and new")
