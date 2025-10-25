cmake_minimum_required(VERSION 3.14)
project(gopher_flutter_client LANGUAGES CXX)

set(BINARY_NAME "gopher_flutter_client")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Zi")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /DEBUG /OPT:REF /OPT:ICF")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /DEBUG /OPT:REF /OPT:ICF")

add_subdirectory("runner")

add_subdirectory("flutter")

add_custom_target(AADDVARK ALL
  COMMAND ${CMAKE_COMMAND} -E echo "Building Flutter Application"
)
