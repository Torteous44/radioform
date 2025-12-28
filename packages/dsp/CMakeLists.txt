cmake_minimum_required(VERSION 3.20)
project(radioform_dsp VERSION 1.0.0 LANGUAGES C CXX)

# C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    add_compile_options(
        -Wall
        -Wextra
        -Wpedantic
        -Wno-unused-parameter
        $<$<CONFIG:Release>:-O3>
        $<$<CONFIG:Release>:-ffast-math>
        $<$<CONFIG:Release>:-fno-finite-math-only>  # Preserve NaN/Inf handling
        $<$<CONFIG:Debug>:-g>
        $<$<CONFIG:Debug>:-O0>
        $<$<CONFIG:Debug>:-fsanitize=address>
    )

    # Link sanitizer in debug mode
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_link_options(-fsanitize=address)
    endif()
endif()

# macOS specific: support both architectures
if(APPLE)
    # Detect architecture
    execute_process(
        COMMAND uname -m
        OUTPUT_VARIABLE ARCH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "Building for macOS architecture: ${ARCH}")

    # Enable appropriate SIMD based on architecture
    if(ARCH STREQUAL "arm64")
        add_compile_options(-mcpu=apple-m1)
    elseif(ARCH STREQUAL "x86_64")
        add_compile_options(-march=native -mtune=native)
    endif()
endif()

# ============================================================================
# Radioform DSP Library
# ============================================================================

# Public headers
set(PUBLIC_HEADERS
    include/radioform_types.h
    include/radioform_dsp.h
)

# Source files
set(SOURCES
    src/engine.cpp
    src/biquad.cpp
    src/smoothing.cpp
    src/preset.cpp
    src/limiter.cpp
    src/version.cpp
)

# Create static library
add_library(radioform_dsp STATIC
    ${SOURCES}
    ${PUBLIC_HEADERS}
)

# Include directories
target_include_directories(radioform_dsp
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Compiler definitions
target_compile_definitions(radioform_dsp PRIVATE
    RADIOFORM_DSP_VERSION="${PROJECT_VERSION}"
)

# Platform-specific settings
if(APPLE)
    # Link Accelerate framework for optimized math
    target_link_libraries(radioform_dsp PRIVATE "-framework Accelerate")
endif()

# ============================================================================
# Testing
# ============================================================================

option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# ============================================================================
# Objective-C++ Bridge (macOS/iOS)
# ============================================================================

option(BUILD_BRIDGE "Build Objective-C++ bridge for Swift" ON)

if(BUILD_BRIDGE AND APPLE)
    add_subdirectory(bridge)
endif()

# ============================================================================
# Tools
# ============================================================================

option(BUILD_TOOLS "Build command-line tools" ON)

if(BUILD_TOOLS)
    add_subdirectory(tools)
endif()

# ============================================================================
# Installation (optional)
# ============================================================================

install(TARGETS radioform_dsp
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(FILES ${PUBLIC_HEADERS}
    DESTINATION include/radioform
)

# ============================================================================
# Summary
# ============================================================================

message(STATUS "")
message(STATUS "Radioform DSP Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Build tests: ${BUILD_TESTS}")
if(APPLE)
    message(STATUS "  macOS architecture: ${ARCH}")
    message(STATUS "  Build ObjC++ bridge: ${BUILD_BRIDGE}")
endif()
message(STATUS "  Self-contained: RBJ biquad implementation (no external DSP libs)")
message(STATUS "")
