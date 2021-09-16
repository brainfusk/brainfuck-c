cmake_minimum_required(VERSION 3.19)
project(brainfuck-c C)

set(CMAKE_C_STANDARD 11)

add_executable(brainfuck-c brainfuck.c)

add_executable(brainfuck-jit brainfuck-jit.c)