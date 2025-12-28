/**
 * @file wav_processor.cpp
 * @brief Simple WAV file processor for testing DSP engine
 *
 * Usage: wav_processor input.wav output.wav [preset]
 * Presets: bass, treble, vocal, flat
 */

#include "radioform_dsp.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <cstdint>

// ============================================================================
// Simple WAV File I/O
// ============================================================================

struct WAVHeader {
    char riff[4];              // "RIFF"
    uint32_t file_size;        // File size - 8
    char wave[4];              // "WAVE"
    char fmt[4];               // "fmt "
    uint32_t fmt_size;         // Format chunk size (16 for PCM)
    uint16_t audio_format;     // 1 = PCM, 3 = IEEE float
    uint16_t num_channels;     // 1 = mono, 2 = stereo
    uint32_t sample_rate;      // Sample rate (e.g., 48000)
    uint32_t byte_rate;        // sample_rate * num_channels * bits_per_sample/8
    uint16_t block_align;      // num_channels * bits_per_sample/8
    uint16_t bits_per_sample;  // 16, 24, 32
    char data[4];              // "data"
    uint32_t data_size;        // Size of data section
};

bool readWAV(const char* filename, WAVHeader& header, std::vector<float>& samples) {
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "Error: Cannot open input file: " << filename << std::endl;
        return false;
    }

    // Read RIFF header
    file.read(header.riff, 4);
    file.read(reinterpret_cast<char*>(&header.file_size), 4);
    file.read(header.wave, 4);

    // Validate WAV file
    if (std::strncmp(header.riff, "RIFF", 4) != 0 ||
        std::strncmp(header.wave, "WAVE", 4) != 0) {
        std::cerr << "Error: Not a valid WAV file" << std::endl;
        return false;
    }

    // Read chunks until we find fmt and data
    bool found_fmt = false;
    bool found_data = false;

    while (!file.eof() && (!found_fmt || !found_data)) {
        char chunk_id[4];
        uint32_t chunk_size;

        file.read(chunk_id, 4);
        if (file.gcount() != 4) break;

        file.read(reinterpret_cast<char*>(&chunk_size), 4);

        if (std::strncmp(chunk_id, "fmt ", 4) == 0) {
            // Read fmt chunk
            file.read(reinterpret_cast<char*>(&header.audio_format), 16);
            found_fmt = true;
            // Skip any extra fmt data
            if (chunk_size > 16) {
                file.seekg(chunk_size - 16, std::ios::cur);
            }
        } else if (std::strncmp(chunk_id, "data", 4) == 0) {
            // Found data chunk
            header.data_size = chunk_size;
            found_data = true;
            break; // Data chunk found, stop searching
        } else {
            // Skip unknown chunk
            file.seekg(chunk_size, std::ios::cur);
        }
    }

    if (!found_fmt || !found_data) {
        std::cerr << "Error: Missing fmt or data chunk" << std::endl;
        return false;
    }

    // We only support PCM or float formats
    if (header.audio_format != 1 && header.audio_format != 3) {
        std::cerr << "Error: Only PCM and IEEE float WAV files are supported" << std::endl;
        return false;
    }

    // Print info
    std::cout << "Input file: " << filename << std::endl;
    std::cout << "  Sample rate: " << header.sample_rate << " Hz" << std::endl;
    std::cout << "  Channels: " << header.num_channels << std::endl;
    std::cout << "  Bits per sample: " << header.bits_per_sample << std::endl;
    std::cout << "  Duration: " << (header.data_size / header.byte_rate) << " seconds" << std::endl;

    // Read audio data
    uint32_t num_samples = header.data_size / (header.bits_per_sample / 8);
    samples.resize(num_samples);

    if (header.audio_format == 3 && header.bits_per_sample == 32) {
        // IEEE float - read directly
        file.read(reinterpret_cast<char*>(samples.data()), header.data_size);
    } else if (header.audio_format == 1 && header.bits_per_sample == 16) {
        // 16-bit PCM - convert to float
        std::vector<int16_t> pcm_samples(num_samples);
        file.read(reinterpret_cast<char*>(pcm_samples.data()), header.data_size);
        for (size_t i = 0; i < num_samples; i++) {
            samples[i] = pcm_samples[i] / 32768.0f;
        }
    } else if (header.audio_format == 1 && header.bits_per_sample == 24) {
        // 24-bit PCM - convert to float
        std::vector<uint8_t> bytes(header.data_size);
        file.read(reinterpret_cast<char*>(bytes.data()), header.data_size);
        for (size_t i = 0; i < num_samples; i++) {
            int32_t value = (bytes[i * 3 + 2] << 16) | (bytes[i * 3 + 1] << 8) | bytes[i * 3];
            if (value & 0x800000) value |= 0xFF000000; // Sign extend
            samples[i] = value / 8388608.0f;
        }
    } else {
        std::cerr << "Error: Unsupported bit depth: " << header.bits_per_sample << std::endl;
        return false;
    }

    return true;
}

bool writeWAV(const char* filename, const WAVHeader& header, const std::vector<float>& samples) {
    std::ofstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "Error: Cannot create output file: " << filename << std::endl;
        return false;
    }

    // Build proper WAV header (always output 32-bit float)
    WAVHeader out_header;

    // RIFF header
    std::memcpy(out_header.riff, "RIFF", 4);
    std::memcpy(out_header.wave, "WAVE", 4);

    // fmt chunk
    std::memcpy(out_header.fmt, "fmt ", 4);
    out_header.fmt_size = 16;
    out_header.audio_format = 3; // IEEE float
    out_header.num_channels = header.num_channels;
    out_header.sample_rate = header.sample_rate;
    out_header.bits_per_sample = 32;
    out_header.block_align = out_header.num_channels * 4;
    out_header.byte_rate = out_header.sample_rate * out_header.block_align;

    // data chunk
    std::memcpy(out_header.data, "data", 4);
    out_header.data_size = samples.size() * sizeof(float);
    out_header.file_size = 36 + out_header.data_size;

    file.write(reinterpret_cast<const char*>(&out_header), sizeof(WAVHeader));

    // Write audio data as 32-bit float
    file.write(reinterpret_cast<const char*>(samples.data()), samples.size() * sizeof(float));

    std::cout << "Output file: " << filename << std::endl;
    std::cout << "  Format: 32-bit float" << std::endl;

    return true;
}

// ============================================================================
// Preset Configurations
// ============================================================================

void createBassBoostPreset(radioform_preset_t* preset) {
    radioform_dsp_preset_init_flat(preset);
    strncpy(preset->name, "Bass Boost", sizeof(preset->name) - 1);

    preset->num_bands = 3;

    // Sub-bass shelf (+8 dB at 60 Hz)
    preset->bands[0].enabled = true;
    preset->bands[0].frequency_hz = 60.0f;
    preset->bands[0].gain_db = 8.0f;
    preset->bands[0].q_factor = 0.707f;
    preset->bands[0].type = RADIOFORM_FILTER_LOW_SHELF;

    // Bass peak (+4 dB at 150 Hz)
    preset->bands[1].enabled = true;
    preset->bands[1].frequency_hz = 150.0f;
    preset->bands[1].gain_db = 4.0f;
    preset->bands[1].q_factor = 1.0f;
    preset->bands[1].type = RADIOFORM_FILTER_PEAK;

    // Mid cut (-2 dB at 800 Hz to balance)
    preset->bands[2].enabled = true;
    preset->bands[2].frequency_hz = 800.0f;
    preset->bands[2].gain_db = -2.0f;
    preset->bands[2].q_factor = 1.5f;
    preset->bands[2].type = RADIOFORM_FILTER_PEAK;

    preset->preamp_db = -6.0f; // Reduce preamp to prevent clipping
    preset->limiter_enabled = true;
}

void createTrebleBoostPreset(radioform_preset_t* preset) {
    radioform_dsp_preset_init_flat(preset);
    strncpy(preset->name, "EXTREME Treble", sizeof(preset->name) - 1);

    preset->num_bands = 4;

    // Upper mids boost (+6 dB at 2 kHz)
    preset->bands[0].enabled = true;
    preset->bands[0].frequency_hz = 2000.0f;
    preset->bands[0].gain_db = 6.0f;
    preset->bands[0].q_factor = 1.5f;
    preset->bands[0].type = RADIOFORM_FILTER_PEAK;

    // Presence MASSIVE boost (+10 dB at 4 kHz)
    preset->bands[1].enabled = true;
    preset->bands[1].frequency_hz = 4000.0f;
    preset->bands[1].gain_db = 10.0f;
    preset->bands[1].q_factor = 2.5f;
    preset->bands[1].type = RADIOFORM_FILTER_PEAK;

    // Brilliance boost (+8 dB at 8 kHz)
    preset->bands[2].enabled = true;
    preset->bands[2].frequency_hz = 8000.0f;
    preset->bands[2].gain_db = 8.0f;
    preset->bands[2].q_factor = 1.5f;
    preset->bands[2].type = RADIOFORM_FILTER_PEAK;

    // Air shelf (+12 dB at 12 kHz)
    preset->bands[3].enabled = true;
    preset->bands[3].frequency_hz = 12000.0f;
    preset->bands[3].gain_db = 12.0f;
    preset->bands[3].q_factor = 0.707f;
    preset->bands[3].type = RADIOFORM_FILTER_HIGH_SHELF;

    preset->preamp_db = -8.0f; // Heavy preamp reduction
    preset->limiter_enabled = true;
}

void createVocalEnhancePreset(radioform_preset_t* preset) {
    radioform_dsp_preset_init_flat(preset);
    strncpy(preset->name, "Vocal Enhance", sizeof(preset->name) - 1);

    preset->num_bands = 4;

    // High-pass filter to remove rumble
    preset->bands[0].enabled = true;
    preset->bands[0].frequency_hz = 80.0f;
    preset->bands[0].gain_db = 0.0f;
    preset->bands[0].q_factor = 0.707f;
    preset->bands[0].type = RADIOFORM_FILTER_HIGH_PASS;

    // Reduce muddiness
    preset->bands[1].enabled = true;
    preset->bands[1].frequency_hz = 250.0f;
    preset->bands[1].gain_db = -3.0f;
    preset->bands[1].q_factor = 1.0f;
    preset->bands[1].type = RADIOFORM_FILTER_PEAK;

    // Presence boost for clarity
    preset->bands[2].enabled = true;
    preset->bands[2].frequency_hz = 3000.0f;
    preset->bands[2].gain_db = 5.0f;
    preset->bands[2].q_factor = 2.0f;
    preset->bands[2].type = RADIOFORM_FILTER_PEAK;

    // Reduce sibilance
    preset->bands[3].enabled = true;
    preset->bands[3].frequency_hz = 8000.0f;
    preset->bands[3].gain_db = -2.0f;
    preset->bands[3].q_factor = 1.5f;
    preset->bands[3].type = RADIOFORM_FILTER_PEAK;

    preset->preamp_db = -2.0f;
    preset->limiter_enabled = true;
}

// ============================================================================
// Main Processing
// ============================================================================

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cout << "Radioform DSP WAV Processor" << std::endl;
        std::cout << "Usage: " << argv[0] << " input.wav output.wav [preset]" << std::endl;
        std::cout << std::endl;
        std::cout << "Presets:" << std::endl;
        std::cout << "  bass   - Heavy bass boost (default)" << std::endl;
        std::cout << "  treble - Treble boost with presence" << std::endl;
        std::cout << "  vocal  - Vocal enhancement" << std::endl;
        std::cout << "  flat   - No processing (transparent)" << std::endl;
        return 1;
    }

    const char* input_file = argv[1];
    const char* output_file = argv[2];
    const char* preset_name = (argc > 3) ? argv[3] : "bass";

    // Read input WAV file
    WAVHeader header;
    std::vector<float> samples;

    if (!readWAV(input_file, header, samples)) {
        return 1;
    }

    // Only support stereo files for now
    if (header.num_channels != 2) {
        std::cerr << "Error: Only stereo files are supported" << std::endl;
        return 1;
    }

    // Create DSP engine
    radioform_dsp_engine_t* engine = radioform_dsp_create(header.sample_rate);
    if (!engine) {
        std::cerr << "Error: Failed to create DSP engine" << std::endl;
        return 1;
    }

    // Apply preset
    radioform_preset_t preset;
    if (strcmp(preset_name, "bass") == 0) {
        createBassBoostPreset(&preset);
    } else if (strcmp(preset_name, "treble") == 0) {
        createTrebleBoostPreset(&preset);
    } else if (strcmp(preset_name, "vocal") == 0) {
        createVocalEnhancePreset(&preset);
    } else {
        radioform_dsp_preset_init_flat(&preset);
    }

    std::cout << std::endl;
    std::cout << "Applying preset: " << preset.name << std::endl;

    radioform_error_t err = radioform_dsp_apply_preset(engine, &preset);
    if (err != RADIOFORM_OK) {
        std::cerr << "Error: Failed to apply preset" << std::endl;
        radioform_dsp_destroy(engine);
        return 1;
    }

    // Process audio
    std::cout << "Processing audio..." << std::endl;

    uint32_t num_frames = samples.size() / 2;
    radioform_dsp_process_interleaved(engine, samples.data(), samples.data(), num_frames);

    std::cout << "Processed " << num_frames << " frames" << std::endl;

    // Get statistics
    radioform_stats_t stats;
    radioform_dsp_get_stats(engine, &stats);
    std::cout << "Total frames processed: " << stats.frames_processed << std::endl;

    // Write output WAV file
    std::cout << std::endl;
    if (!writeWAV(output_file, header, samples)) {
        radioform_dsp_destroy(engine);
        return 1;
    }

    // Cleanup
    radioform_dsp_destroy(engine);

    std::cout << std::endl;
    std::cout << "Success! Play the files to compare:" << std::endl;
    std::cout << "  Original: afplay " << input_file << std::endl;
    std::cout << "  Processed: afplay " << output_file << std::endl;

    return 0;
}
