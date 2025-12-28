# Bridge library CMake configuration
cmake_minimum_required(VERSION 3.20)

# Bridge library (ObjC++)
add_library(radioform_dsp_bridge
    RadioformDSPEngine.mm
)

target_include_directories(radioform_dsp_bridge
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(radioform_dsp_bridge
    PUBLIC
        radioform_dsp
)

# Enable Objective-C++ and ARC
set_target_properties(radioform_dsp_bridge PROPERTIES
    COMPILE_FLAGS "-x objective-c++ -fobjc-arc"
    LINKER_LANGUAGE CXX
)

# Link Foundation framework
target_link_libraries(radioform_dsp_bridge
    PUBLIC
        "-framework Foundation"
)

# Install headers
install(FILES
    RadioformDSPEngine.h
    DESTINATION include/radioform/bridge
)

# Install library
install(TARGETS radioform_dsp_bridge
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
