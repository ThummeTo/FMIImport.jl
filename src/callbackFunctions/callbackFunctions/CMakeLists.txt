#
# Copyright (c) 2022 Andreas Heuermann
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

cmake_minimum_required(VERSION 3.16)

project(callbackFunctions VERSION 1.7)

# Change default CMake install prefix
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX ${PROJECT_BINARY_DIR}/../../binaries CACHE PATH "Default installation directory" FORCE)
  # Prevent sub-projects from changing it by checking CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT after this
  set(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT FALSE)
  message(STATUS "No installation directory specified. Defaulting to: ${CMAKE_INSTALL_PREFIX}")
else()
  message(STATUS "CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")
endif()

# Get short operating system and architecture string
if(WIN32)
  set(OS_SHORT "win")
elseif(APPLE)
  set(OS_SHORT "darwin")
elseif(UNIX)
  set(OS_SHORT "linux")
endif()
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(ARCH_SHORT "64")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
  set(ARCH_SHORT "32")
endif()
set(INSTALL_DIRECTORY ${CMAKE_INSTALL_PREFIX}/${OS_SHORT}${ARCH_SHORT})
message(STATUS "Install directory: ${INSTALL_DIRECTORY}")

# Set
if(WIN32)
  add_definitions(-DBUILD_DLL)
endif(WIN32)

# Library
add_library(callbackFunctions SHARED
            main.cpp)

install(TARGETS callbackFunctions
        DESTINATION  ${INSTALL_DIRECTORY})

# Compile test
set(TEST_PROG test)
add_executable(${TEST_PROG} test.c)
target_link_libraries(${TEST_PROG} callbackFunctions)
