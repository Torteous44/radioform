cmake_minimum_required(VERSION 3.20)
project(RadioformDriver VERSION 2.0.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# macOS: build universal binary (arm64 + x86_64)
if(APPLE)
    if(NOT CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Build architectures" FORCE)
    endif()
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version" FORCE)
    message(STATUS "Building for macOS architectures: ${CMAKE_OSX_ARCHITECTURES}")
endif()

# Compiler flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g -fsanitize=address")

# libASPL
add_subdirectory(vendor/libASPL)

# Radioform Driver sources
set(DRIVER_SOURCES
    src/Plugin.cpp
)

# Create the driver bundle
add_library(RadioformDriver MODULE ${DRIVER_SOURCES})

target_include_directories(RadioformDriver
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/vendor/libASPL/include
)

target_link_libraries(RadioformDriver
    PRIVATE
        libASPL
        "-framework CoreAudio"
        "-framework CoreFoundation"
        "-framework AudioToolbox"
)

# Bundle properties
set_target_properties(RadioformDriver PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "driver"
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    OUTPUT_NAME "RadioformDriver"
)

# Install to /Library/Audio/Plug-Ins/HAL/
# This requires sudo - use install script instead
# install(TARGETS RadioformDriver
#     BUNDLE DESTINATION "/Library/Audio/Plug-Ins/HAL"
# )

message(STATUS "Radioform HAL Driver configured")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Multi-format: YES (int16/24/32, float32/64)")
message(STATUS "  Multi-rate: YES (44.1-192 kHz)")
message(STATUS "  Multi-channel: YES (1-8 channels)")
message(STATUS "  Install manually to: /Library/Audio/Plug-Ins/HAL/")
