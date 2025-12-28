/**
 * @file version.cpp
 * @brief Version information for Radioform DSP library
 */

#include "radioform_dsp.h"

#ifndef RADIOFORM_DSP_VERSION
#define RADIOFORM_DSP_VERSION "1.0.0-dev"
#endif

const char* radioform_dsp_get_version(void) {
    return RADIOFORM_DSP_VERSION;
}
