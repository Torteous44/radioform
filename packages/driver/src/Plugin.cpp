// Radioform HAL Driver
// Minimal virtual audio device with shared memory transport

#include <aspl/Driver.hpp>
#include <CoreAudio/AudioServerPlugIn.h>

#include "../include/RFSharedAudio.h"

#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <memory>
#include <atomic>
#include <os/log.h>

namespace {

// Audio format
constexpr UInt32 SAMPLE_RATE = 48000;
constexpr UInt32 CHANNEL_COUNT = 2;

// Shared memory config
constexpr uint32_t RING_CAPACITY_FRAMES = RF_RING_DEFAULT_FRAMES;
const char* SHM_FILE_PATH = "/tmp/radioform-audio-v1";

// Request handler for audio I/O and control
class RadioformHandler : public aspl::ControlRequestHandler, public aspl::IORequestHandler
{
public:
    RadioformHandler()
        : shared_memory_(nullptr)
    {
        // Don't open shared memory yet - wait for OnStartIO
    }

    ~RadioformHandler()
    {
        Disconnect();
    }

    // Called when audio I/O starts - open shared memory connection
    OSStatus OnStartIO() override
    {
        if (!shared_memory_) {
            OpenSharedMemory();
        }

        if (!shared_memory_) {
            return kAudioHardwareUnspecifiedError;
        }

        return kAudioHardwareNoError;
    }

    // Called when audio I/O stops
    void OnStopIO() override
    {
        // Keep shared memory open for next start
    }

    // Called when system sends mixed audio to our device
    void OnWriteMixedOutput(
        const std::shared_ptr<aspl::Stream>& stream,
        Float64 zeroTimestamp,
        Float64 timestamp,
        const void* bytes,
        UInt32 bytesCount) override
    {
        if (!shared_memory_) {
            return;
        }

        // Get audio format from stream
        AudioStreamBasicDescription fmt = stream->GetPhysicalFormat();

        if (fmt.mBytesPerFrame == 0 || fmt.mChannelsPerFrame != CHANNEL_COUNT) {
            return;
        }

        UInt32 frameCount = bytesCount / fmt.mBytesPerFrame;
        if (frameCount == 0) {
            return;
        }

        // Convert to interleaved float32 for ring buffer
        std::vector<float> interleaved(frameCount * 2);

        // Handle different audio formats
        if (fmt.mFormatFlags & kAudioFormatFlagIsFloat) {
            // Float32 format
            const float* input = static_cast<const float*>(bytes);
            if (fmt.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                // Non-interleaved: convert to interleaved
                const float* leftChannel = input;
                const float* rightChannel = input + frameCount;
                for (UInt32 i = 0; i < frameCount; i++) {
                    interleaved[i * 2] = leftChannel[i];
                    interleaved[i * 2 + 1] = rightChannel[i];
                }
            } else {
                // Already interleaved float32
                std::memcpy(interleaved.data(), input, frameCount * 2 * sizeof(float));
            }
        } else if (fmt.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
            // Signed integer format - convert to float32 in range [-1.0, 1.0]
            if (fmt.mBitsPerChannel == 16) {
                const int16_t* input = static_cast<const int16_t*>(bytes);
                for (UInt32 i = 0; i < frameCount * 2; i++) {
                    interleaved[i] = static_cast<float>(input[i]) / 32768.0f;
                }
            } else if (fmt.mBitsPerChannel == 32) {
                const int32_t* input = static_cast<const int32_t*>(bytes);
                for (UInt32 i = 0; i < frameCount * 2; i++) {
                    interleaved[i] = static_cast<float>(input[i]) / 2147483648.0f;
                }
            } else {
                return; // Unsupported bit depth
            }
        } else {
            return; // Unsupported format
        }

        // Write to shared memory ring buffer
        rf_ring_write(shared_memory_, interleaved.data(), frameCount);
    }

private:
    void OpenSharedMemory()
    {
        // Open existing shared memory file (created by host)
        int fd = open(SHM_FILE_PATH, O_RDWR);
        if (fd == -1) {
            return;
        }

        size_t shm_size = rf_shared_audio_size(RING_CAPACITY_FRAMES);

        // Map memory
        void* mem = mmap(nullptr, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        close(fd);

        if (mem == MAP_FAILED) {
            return;
        }

        shared_memory_ = reinterpret_cast<RFSharedAudioV1*>(mem);
    }

    void Disconnect()
    {
        if (shared_memory_) {
            size_t shm_size = rf_shared_audio_size(RING_CAPACITY_FRAMES);
            munmap(shared_memory_, shm_size);
            shared_memory_ = nullptr;
        }
        // Don't unlink - host owns the file
    }

    RFSharedAudioV1* shared_memory_;
};

std::shared_ptr<aspl::Driver> CreateRadioformDriver()
{
    auto context = std::make_shared<aspl::Context>();

    // Create device
    aspl::DeviceParameters deviceParams;
    deviceParams.Name = "Radioform";
    deviceParams.Manufacturer = "Radioform";
    deviceParams.SampleRate = SAMPLE_RATE;
    deviceParams.ChannelCount = CHANNEL_COUNT;
    deviceParams.EnableMixing = true;

    auto device = std::make_shared<aspl::Device>(context, deviceParams);

    // Add output stream
    device->AddStreamWithControlsAsync(aspl::Direction::Output);

    // Set control and I/O handlers
    auto handler = std::make_shared<RadioformHandler>();
    device->SetControlHandler(handler);
    device->SetIOHandler(handler);

    // Create plugin and driver
    auto plugin = std::make_shared<aspl::Plugin>(context);
    plugin->AddDevice(device);

    auto driver = std::make_shared<aspl::Driver>(context, plugin);

    return driver;
}

} // namespace

// Plugin entry point
extern "C" void* RadioformDriverPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID)
{
    if (!CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) {
        return nullptr;
    }

    static std::shared_ptr<aspl::Driver> driver = CreateRadioformDriver();

    return driver->GetReference();
}
