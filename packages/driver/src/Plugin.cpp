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
#include <thread>
#include <chrono>
#include <os/log.h>
#include <map>
#include <string>
#include <fstream>
#include <sstream>
#include <vector>
#include <set>

namespace {

// Audio format
constexpr UInt32 SAMPLE_RATE = 48000;
constexpr UInt32 CHANNEL_COUNT = 2;

// Shared memory config
constexpr uint32_t RING_CAPACITY_FRAMES = RF_RING_DEFAULT_FRAMES;
const char* SHM_FILE_PATH = "/tmp/radioform-audio-v1";

// Request handler for audio I/O and control
// Each device gets its own handler instance with unique shared memory
class RadioformHandler : public aspl::ControlRequestHandler, public aspl::IORequestHandler
{
public:
    RadioformHandler(const std::string& deviceUID)
        : shared_memory_(nullptr)
        , device_uid_(deviceUID)
    {
        // Construct shared memory path based on device UID
        // Replace invalid filename chars with underscores
        std::string safe_uid = deviceUID;
        for (char& c : safe_uid) {
            if (c == ':' || c == '/' || c == ' ') {
                c = '_';
            }
        }
        shm_file_path_ = "/tmp/radioform-" + safe_uid;
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
        int fd = open(shm_file_path_.c_str(), O_RDWR);
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
    std::string device_uid_;
    std::string shm_file_path_;
};

// Global state for dynamic device management
struct RadioformGlobalState {
    std::shared_ptr<aspl::Context> context;
    std::shared_ptr<aspl::Plugin> plugin;
    std::shared_ptr<aspl::Driver> driver;
    std::map<std::string, std::shared_ptr<aspl::Device>> devices; // UID -> Device
    std::thread monitor_thread;
    std::atomic<bool> should_stop{false};
};

static RadioformGlobalState* g_state = nullptr;

// Create a proxy device for a physical device
std::shared_ptr<aspl::Device> CreateProxyDevice(
    const std::string& name,
    const std::string& uid)
{
    if (!g_state) {
        return nullptr;
    }

    // Create device with proxy name
    aspl::DeviceParameters deviceParams;
    deviceParams.Name = name + " (Radioform)";
    deviceParams.DeviceUID = uid + "-radioform";
    deviceParams.Manufacturer = "Radioform";
    deviceParams.SampleRate = SAMPLE_RATE;
    deviceParams.ChannelCount = CHANNEL_COUNT;
    deviceParams.EnableMixing = true;

    // Note: Proxies are visible in Sound Settings
    // This is intentional - auto-switching provides transparent UX
    // Users can also manually select proxies if desired

    auto device = std::make_shared<aspl::Device>(g_state->context, deviceParams);

    // Add output stream
    device->AddStreamWithControlsAsync(aspl::Direction::Output);

    // Set control and I/O handlers with device-specific shared memory
    auto handler = std::make_shared<RadioformHandler>(uid);
    device->SetControlHandler(handler);
    device->SetIOHandler(handler);

    // TODO: Hide proxy device from Sound Settings UI
    // device->SetIsHidden(true);
    // Note: SetIsHidden prevents programmatic enumeration, need different approach

    return device;
}

// Add a device to the plugin
void AddDevice(const std::string& name, const std::string& uid)
{
    if (!g_state) {
        return;
    }

    // Check if device already exists
    if (g_state->devices.find(uid) != g_state->devices.end()) {
        return;
    }

    // Create proxy device
    auto device = CreateProxyDevice(name, uid);
    if (!device) {
        return;
    }

    // Add to plugin
    g_state->plugin->AddDevice(device);
    g_state->devices[uid] = device;
}

// Remove a device from the plugin
void RemoveDevice(const std::string& uid)
{
    if (!g_state) {
        return;
    }

    auto it = g_state->devices.find(uid);
    if (it == g_state->devices.end()) {
        return;
    }

    g_state->plugin->RemoveDevice(it->second);
    g_state->devices.erase(it);
}

// Parse control file and return device map
std::map<std::string, std::string> ParseControlFile()
{
    std::map<std::string, std::string> devices; // UID -> Name

    std::ifstream file("/tmp/radioform-devices.txt");
    if (!file.is_open()) {
        return devices;
    }

    std::string line;
    while (std::getline(file, line)) {
        // Format: NAME|UID
        size_t separator = line.find('|');
        if (separator == std::string::npos) {
            continue;
        }

        std::string name = line.substr(0, separator);
        std::string uid = line.substr(separator + 1);
        devices[uid] = name;
    }

    file.close();
    return devices;
}

// Synchronize devices with control file
void SyncDevices()
{
    if (!g_state) {
        return;
    }

    // Read desired devices from control file
    auto desired_devices = ParseControlFile();

    // Find devices to add
    for (const auto& [uid, name] : desired_devices) {
        if (g_state->devices.find(uid) == g_state->devices.end()) {
            AddDevice(name, uid);
        }
    }

    // Find devices to remove
    std::vector<std::string> to_remove;
    for (const auto& [uid, device] : g_state->devices) {
        if (desired_devices.find(uid) == desired_devices.end()) {
            to_remove.push_back(uid);
        }
    }

    for (const auto& uid : to_remove) {
        RemoveDevice(uid);
    }
}

// Background thread that monitors control file
void MonitorControlFile()
{
    while (!g_state->should_stop) {
        SyncDevices();

        // Check every second
        for (int i = 0; i < 10 && !g_state->should_stop; i++) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }
}

// Read device list from control file and create proxies (initial load)
void LoadDevicesFromControlFile()
{
    SyncDevices();
}

std::shared_ptr<aspl::Driver> CreateRadioformDriver()
{
    // Initialize global state
    g_state = new RadioformGlobalState();
    g_state->context = std::make_shared<aspl::Context>();
    g_state->plugin = std::make_shared<aspl::Plugin>(g_state->context);

    // Load devices from control file (created by host)
    LoadDevicesFromControlFile();

    // Start background thread to monitor control file for changes
    g_state->monitor_thread = std::thread(MonitorControlFile);

    // Create driver
    g_state->driver = std::make_shared<aspl::Driver>(g_state->context, g_state->plugin);

    return g_state->driver;
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
