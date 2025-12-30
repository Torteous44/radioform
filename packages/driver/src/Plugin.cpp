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
#include <sys/stat.h>
#include <errno.h>

// Debug logging macros - use os_log for proper system logging
static os_log_t rf_log = os_log_create("com.radioform.driver", "default");

#define RF_LOG_ERROR(fmt, ...) os_log_error(rf_log, "[RadioformDriver ERROR] " fmt, ##__VA_ARGS__)
#define RF_LOG_INFO(fmt, ...) os_log_info(rf_log, "[RadioformDriver INFO] " fmt, ##__VA_ARGS__)
#define RF_LOG_DEBUG(fmt, ...) os_log_debug(rf_log, "[RadioformDriver DEBUG] " fmt, ##__VA_ARGS__)

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
        RF_LOG_INFO("OnStartIO() called for device: %s", device_uid_.c_str());

        if (!shared_memory_) {
            RF_LOG_INFO("Shared memory not open, attempting to open: %s", shm_file_path_.c_str());

            // Try to open with retries in case file is being created
            const int MAX_RETRIES = 5;
            const int RETRY_DELAY_MS = 100; // 100ms between retries

            for (int attempt = 1; attempt <= MAX_RETRIES && !shared_memory_; attempt++) {
                RF_LOG_INFO("Attempt %d/%d to open shared memory...", attempt, MAX_RETRIES);
                OpenSharedMemory();

                if (!shared_memory_ && attempt < MAX_RETRIES) {
                    RF_LOG_INFO("Attempt %d failed, retrying in %dms...", attempt, RETRY_DELAY_MS);
                    std::this_thread::sleep_for(std::chrono::milliseconds(RETRY_DELAY_MS));
                }
            }
        } else {
            RF_LOG_DEBUG("Shared memory already open for device: %s", device_uid_.c_str());
        }

        if (!shared_memory_) {
            RF_LOG_ERROR("CRITICAL: OnStartIO() failed after all retry attempts for device: %s", device_uid_.c_str());
            RF_LOG_ERROR("  File path: %s", shm_file_path_.c_str());
            RF_LOG_ERROR("  This will result in NO AUDIO OUTPUT!");
            RF_LOG_ERROR("  Possible causes:");
            RF_LOG_ERROR("    1. Host application not running");
            RF_LOG_ERROR("    2. Shared memory file not created by host");
            RF_LOG_ERROR("    3. Permission issues accessing /tmp/radioform-* files");
            RF_LOG_ERROR("  Try: sudo killall coreaudiod (to restart audio system)");
            return kAudioHardwareUnspecifiedError;
        }

        RF_LOG_INFO("OnStartIO() succeeded for device: %s - audio should now flow", device_uid_.c_str());
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
        static uint64_t call_count = 0;
        static uint64_t last_log_time = 0;
        call_count++;

        // Log every 1000 calls (about once per second at 48kHz with 512 frame buffers)
        uint64_t current_time = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();

        if (current_time != last_log_time) {
            RF_LOG_DEBUG("OnWriteMixedOutput() called %llu times in last second, bytesCount=%u",
                call_count, bytesCount);
            call_count = 0;
            last_log_time = current_time;
        }

        if (!shared_memory_) {
            RF_LOG_ERROR("OnWriteMixedOutput() called but shared_memory is NULL - NO AUDIO CAN FLOW!");
            return;
        }

        // Get audio format from stream
        AudioStreamBasicDescription fmt = stream->GetPhysicalFormat();

        if (fmt.mBytesPerFrame == 0 || fmt.mChannelsPerFrame != CHANNEL_COUNT) {
            static bool format_error_logged = false;
            if (!format_error_logged) {
                RF_LOG_ERROR("Invalid audio format: bytesPerFrame=%u, channels=%u (expected 2 channels)",
                    fmt.mBytesPerFrame, fmt.mChannelsPerFrame);
                format_error_logged = true;
            }
            return;
        }

        UInt32 frameCount = bytesCount / fmt.mBytesPerFrame;
        if (frameCount == 0) {
            RF_LOG_ERROR("frameCount is 0 - no audio data to process");
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
            static bool format_error_logged = false;
            if (!format_error_logged) {
                RF_LOG_ERROR("Unsupported audio format flags: 0x%x", fmt.mFormatFlags);
                format_error_logged = true;
            }
            return; // Unsupported format
        }

        // Write to shared memory ring buffer
        size_t written = rf_ring_write(shared_memory_, interleaved.data(), frameCount);

        // Log occasional writes to confirm audio is flowing
        static uint64_t write_count = 0;
        write_count++;
        if (write_count % 1000 == 0) {
            RF_LOG_DEBUG("Audio flowing: wrote %zu frames (total writes: %llu)", written, write_count);
        }
    }

private:
    void OpenSharedMemory()
    {
        RF_LOG_INFO("OpenSharedMemory() attempting to open: %s", shm_file_path_.c_str());

        // Check if file exists first
        struct stat st;
        if (stat(shm_file_path_.c_str(), &st) != 0) {
            RF_LOG_ERROR("Shared memory file does NOT exist: %s (errno=%d: %s)",
                shm_file_path_.c_str(), errno, strerror(errno));
            RF_LOG_ERROR("  HOST MUST CREATE THIS FILE FIRST!");
            return;
        }

        RF_LOG_DEBUG("Shared memory file exists, size=%lld bytes", (long long)st.st_size);

        // Open existing shared memory file (created by host)
        int fd = open(shm_file_path_.c_str(), O_RDWR);
        if (fd == -1) {
            RF_LOG_ERROR("Failed to open shared memory file: %s (errno=%d: %s)",
                shm_file_path_.c_str(), errno, strerror(errno));
            return;
        }

        RF_LOG_DEBUG("Successfully opened file descriptor: fd=%d", fd);

        size_t shm_size = rf_shared_audio_size(RING_CAPACITY_FRAMES);
        RF_LOG_DEBUG("Expected shared memory size: %zu bytes", shm_size);

        // Map memory
        void* mem = mmap(nullptr, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        int mmap_errno = errno;  // Save errno before close()
        close(fd);

        if (mem == MAP_FAILED) {
            RF_LOG_ERROR("mmap() failed for file: %s (errno=%d: %s)",
                shm_file_path_.c_str(), mmap_errno, strerror(mmap_errno));
            return;
        }

        shared_memory_ = reinterpret_cast<RFSharedAudioV1*>(mem);
        RF_LOG_INFO("SUCCESS: Shared memory opened and mapped at %p for device: %s",
            mem, device_uid_.c_str());
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
    RF_LOG_INFO("CreateProxyDevice() called: name='%s', uid='%s'", name.c_str(), uid.c_str());

    if (!g_state) {
        RF_LOG_ERROR("CreateProxyDevice() failed: g_state is NULL");
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

    RF_LOG_INFO("Creating device: name='%s', uid='%s', sampleRate=%u, channels=%u",
        deviceParams.Name.c_str(), deviceParams.DeviceUID.c_str(),
        SAMPLE_RATE, CHANNEL_COUNT);

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

    RF_LOG_INFO("Proxy device created successfully: '%s' -> '%s'",
        name.c_str(), deviceParams.Name.c_str());

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

    RF_LOG_DEBUG("ParseControlFile() reading /tmp/radioform-devices.txt");

    std::ifstream file("/tmp/radioform-devices.txt");
    if (!file.is_open()) {
        RF_LOG_ERROR("ParseControlFile() failed: could not open /tmp/radioform-devices.txt");
        return devices;
    }

    std::string line;
    while (std::getline(file, line)) {
        // Format: NAME|UID
        size_t separator = line.find('|');
        if (separator == std::string::npos) {
            RF_LOG_DEBUG("ParseControlFile() skipping malformed line: %s", line.c_str());
            continue;
        }

        std::string name = line.substr(0, separator);
        std::string uid = line.substr(separator + 1);
        devices[uid] = name;
        RF_LOG_DEBUG("ParseControlFile() found device: name='%s', uid='%s'",
            name.c_str(), uid.c_str());
    }

    file.close();
    RF_LOG_INFO("ParseControlFile() found %zu devices", devices.size());
    return devices;
}

// Synchronize devices with control file
void SyncDevices()
{
    if (!g_state) {
        RF_LOG_ERROR("SyncDevices() failed: g_state is NULL");
        return;
    }

    RF_LOG_DEBUG("SyncDevices() synchronizing devices with control file");

    // Read desired devices from control file
    auto desired_devices = ParseControlFile();

    // Find devices to add
    for (const auto& [uid, name] : desired_devices) {
        if (g_state->devices.find(uid) == g_state->devices.end()) {
            RF_LOG_INFO("SyncDevices() adding new device: name='%s', uid='%s'",
                name.c_str(), uid.c_str());
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
        RF_LOG_INFO("SyncDevices() removing device: uid='%s'", uid.c_str());
        RemoveDevice(uid);
    }

    RF_LOG_INFO("SyncDevices() complete: %zu devices active", g_state->devices.size());
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
    RF_LOG_INFO("LoadDevicesFromControlFile() performing initial device load");
    SyncDevices();
    RF_LOG_INFO("LoadDevicesFromControlFile() complete");
}

std::shared_ptr<aspl::Driver> CreateRadioformDriver()
{
    RF_LOG_INFO("===== RADIOFORM DRIVER STARTING =====");
    RF_LOG_INFO("CreateRadioformDriver() initializing...");

    // Initialize global state
    g_state = new RadioformGlobalState();
    g_state->context = std::make_shared<aspl::Context>();
    g_state->plugin = std::make_shared<aspl::Plugin>(g_state->context);

    RF_LOG_INFO("Driver context and plugin initialized");

    // Load devices from control file (created by host)
    RF_LOG_INFO("Loading devices from control file...");
    LoadDevicesFromControlFile();

    // Start background thread to monitor control file for changes
    RF_LOG_INFO("Starting monitor thread for device hot-plugging...");
    g_state->monitor_thread = std::thread(MonitorControlFile);

    // Create driver
    g_state->driver = std::make_shared<aspl::Driver>(g_state->context, g_state->plugin);

    RF_LOG_INFO("Radioform driver initialization complete - driver ready");
    RF_LOG_INFO("=====================================");

    return g_state->driver;
}

} // namespace

// Plugin entry point
extern "C" void* RadioformDriverPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID)
{
    RF_LOG_INFO("RadioformDriverPluginFactory() called");

    if (!CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) {
        RF_LOG_ERROR("RadioformDriverPluginFactory() wrong UUID - rejecting");
        return nullptr;
    }

    static std::shared_ptr<aspl::Driver> driver = CreateRadioformDriver();

    RF_LOG_INFO("RadioformDriverPluginFactory() returning driver reference");
    return driver->GetReference();
}
