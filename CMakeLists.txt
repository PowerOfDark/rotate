cmake_minimum_required(VERSION 2.8)

project(rotate C CXX)

enable_language(ASM_NASM)
set(CMAKE_C_STANDARD 99 CACHE STRING "" FORCE)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -no-pie -std=c99" CACHE STRING "" FORCE)
set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64 CACHE STRING "" FORCE)
set(CMAKE_ASM_NASM_FLAGS "-I ${CMAKE_CURRENT_SOURCE_DIR}/asm/" CACHE STRING "" FORCE)
set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <FLAGS> -f ${CMAKE_ASM_NASM_OBJECT_FORMAT} <SOURCE> -o <OBJECT>")

include_directories(inc src)

file(GLOB source_files
        "src/*.c"
        "inc/*.h"
        "asm/*.asm")

add_executable(rotate main.c ${source_files})

add_executable(gen_lookup gen/gen_lookup.c)
