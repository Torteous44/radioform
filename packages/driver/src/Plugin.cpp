// Radioform HAL Driver - Production Edition
// Rock-solid virtual audio device with comprehensive error recovery

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
#include <mutex>

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

// Health check intervals
constexpr int HEALTH_CHECK_INTERVAL_SECONDS = 5;
constexpr int STATS_LOG_INTERVAL_SECONDS = 30;

// Device states
enum class DeviceState {
    Uninitialized,
    Connecting,
    Connected,
    Error,
    Disconnected
};

const char* DeviceStateToString(DeviceState state) {
    switch (state) {
        case DeviceState::Uninitialized: return "Uninitialized";
        case DeviceState::Connecting: return "Connecting";
        case DeviceState::Connected: return "Connected";
        case DeviceState::Error: return "Error";
        case DeviceState::Disconnected: return "Disconnected";
    }
    return "Unknown";
}

// Statistics tracker for monitoring health
struct AudioStats {
    std::atomic<uint64_t> total_writes{0};
    std::atomic<uint64_t> failed_writes{0};
    std::atomic<uint64_t> health_check_failures{0};
    std::atomic<uint64_t> reconnection_attempts{0};
    std::atomic<uint64_t> client_starts{0};
    std::atomic<uint64_t> client_stops{0};

    void LogPeriodic() {
        static auto last_log = std::chrono::steady_clock::now();
        auto now = std::chrono::steady_clock::now();

        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - last_log).count();
        if (elapsed >= STATS_LOG_INTERVAL_SECONDS) {
            RF_LOG_INFO("=== Audio Stats (last %llds) ===", elapsed);
            RF_LOG_INFO("  Total writes: %llu", total_writes.load());
            RF_LOG_INFO("  Failed writes: %llu", failed_writes.load());
            RF_LOG_INFO("  Health failures: %llu", health_check_failures.load());
            RF_LOG_INFO("  Reconnection attempts: %llu", reconnection_attempts.load());
            RF_LOG_INFO("  Client starts: %llu", client_starts.load());
            RF_LOG_INFO("  Client stops: %llu", client_stops.load());
            last_log = now;
        }
    }
};

// Request handler for audio I/O and control
// Each device gets its own handler instance with unique shared memory
// NOW WITH ROBUST CLIENT TRACKING AND ERROR RECOVERY!
class RadioformHandler : public aspl::ControlRequestHandler, public aspl::IORequestHandler
{
public:
    RadioformHandler(const std::string& deviceUID)
        : shared_memory_(nullptr)
        , device_uid_(deviceUID)
        , io_client_count_(0)
        , state_(DeviceState::Uninitialized)
        , last_health_check_(std::chrono::steady_clock::now())
        , last_write_index_check_(0)
    {
        // Construct shared memory path based on device UID
        std::string safe_uid = deviceUID;
        for (char& c : safe_uid) {
            if (c == ':' || c == '/' || c == ' ') {
                c = '_';
            }
        }
        shm_file_path_ = "/tmp/radioform-" + safe_uid;

        RF_LOG_INFO("RadioformHandler created for device: %s (shm: %s)",
            device_uid_.c_str(), shm_file_path_.c_str());
    }

    ~RadioformHandler()
    {
        RF_LOG_INFO("RadioformHandler destructor for device: %s", device_uid_.c_str());
        Disconnect();
    }

    // Called when audio I/O starts - ROBUST with reference counting
    OSStatus OnStartIO() override
    {
        std::lock_guard<std::mutex> lock(io_mutex_);

        int32_t count = ++io_client_count_;
        stats_.client_starts++;

        RF_LOG_INFO("OnStartIO() client #%d for device: %s (state: %s)",
            count, device_uid_.c_str(), DeviceStateToString(state_.load()));

        // Only connect for first client
        if (count == 1) {
            state_ = DeviceState::Connecting;

            // Try to connect with exponential backoff
            const int MAX_RETRIES = 10;
            const int BASE_DELAY_MS = 50;

            for (int attempt = 1; attempt <= MAX_RETRIES && !shared_memory_; attempt++) {
                RF_LOG_INFO("Connection attempt %d/%d...", attempt, MAX_RETRIES);

                OpenSharedMemory();

                if (shared_memory_) {
                    // Validate health before declaring success
                    if (IsSharedMemoryHealthy()) {
                        RF_LOG_INFO("✓ Successfully connected on attempt %d", attempt);
                        state_ = DeviceState::Connected;
                        break;
                    } else {
                        RF_LOG_ERROR("✗ Shared memory opened but failed health check");
                        Disconnect();
                        state_ = DeviceState::Error;
                    }
                }

                if (attempt < MAX_RETRIES) {
                    // Exponential backoff with cap
                    int delay_ms = BASE_DELAY_MS * (1 << (attempt - 1));
                    if (delay_ms > 1000) delay_ms = 1000;

                    RF_LOG_INFO("Retry in %dms...", delay_ms);
                    std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
                }
            }
        } else {
            // Additional client - verify existing connection is healthy
            if (!IsSharedMemoryHealthy()) {
                RF_LOG_ERROR("Existing connection unhealthy for additional client");
                // Try to recover
                Disconnect();
                OpenSharedMemory();
            }
        }

        if (!shared_memory_) {
            // Failed - revert the client count
            --io_client_count_;
            state_ = DeviceState::Error;

            RF_LOG_ERROR("╔════════════════════════════════════════╗");
            RF_LOG_ERROR("║   OnStartIO FAILED - NO AUDIO FLOW!   ║");
            RF_LOG_ERROR("╚════════════════════════════════════════╝");
            RF_LOG_ERROR("  Device: %s", device_uid_.c_str());
            RF_LOG_ERROR("  File: %s", shm_file_path_.c_str());
            RF_LOG_ERROR("");
            RF_LOG_ERROR("Troubleshooting:");
            RF_LOG_ERROR("  1. Is the host application running?");
            RF_LOG_ERROR("  2. Check: ls -la /tmp/radioform-*");
            RF_LOG_ERROR("  3. Check: cat /tmp/radioform-devices.txt");
            RF_LOG_ERROR("  4. Try: sudo killall coreaudiod");

            return kAudioHardwareUnspecifiedError;
        }

        RF_LOG_INFO("OnStartIO succeeded - %d client(s) active", count);
        return kAudioHardwareNoError;
    }

    // Called when audio I/O stops - ROBUST with reference counting
    void OnStopIO() override
    {
        std::lock_guard<std::mutex> lock(io_mutex_);

        if (io_client_count_ == 0) {
            RF_LOG_ERROR("OnStopIO() called but client count already 0!");
            return;
        }

        int32_t count = --io_client_count_;
        stats_.client_stops++;

        RF_LOG_INFO("OnStopIO() remaining clients: %d for device: %s",
            count, device_uid_.c_str());

        // Only disconnect when last client stops
        if (count == 0) {
            RF_LOG_INFO("Last client stopped - disconnecting shared memory");
            Disconnect();
            state_ = DeviceState::Disconnected;
        }
    }

    // Called when system sends mixed audio to our device - ROBUST with health checks
    void OnWriteMixedOutput(
        const std::shared_ptr<aspl::Stream>& stream,
        Float64 zeroTimestamp,
        Float64 timestamp,
        const void* bytes,
        UInt32 bytesCount) override
    {
        stats_.total_writes++;

        // Periodic health check (every N seconds)
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now - last_health_check_).count();

        if (elapsed >= HEALTH_CHECK_INTERVAL_SECONDS) {
            if (!IsSharedMemoryHealthy() || !IsHostAlive()) {
                stats_.health_check_failures++;
                RF_LOG_ERROR("Health check failed - attempting recovery...");

                std::lock_guard<std::mutex> lock(io_mutex_);
                Disconnect();

                if (io_client_count_ > 0) {
                    stats_.reconnection_attempts++;
                    OpenSharedMemory();
                }
            }
            last_health_check_ = now;
        }

        if (!shared_memory_) {
            stats_.failed_writes++;
            // Silent failure - already logged in health check
            return;
        }

        // Get audio format from stream
        AudioStreamBasicDescription fmt = stream->GetPhysicalFormat();

        if (fmt.mBytesPerFrame == 0 || fmt.mChannelsPerFrame != CHANNEL_COUNT) {
            static bool format_error_logged = false;
            if (!format_error_logged) {
                RF_LOG_ERROR("Invalid audio format: bytesPerFrame=%u, channels=%u",
                    fmt.mBytesPerFrame, fmt.mChannelsPerFrame);
                format_error_logged = true;
            }
            stats_.failed_writes++;
            return;
        }

        UInt32 frameCount = bytesCount / fmt.mBytesPerFrame;
        if (frameCount == 0) {
            stats_.failed_writes++;
            return;
        }

        // Convert to interleaved float32 for ring buffer
        std::vector<float> interleaved(frameCount * 2);

        // Handle different audio formats
        if (fmt.mFormatFlags & kAudioFormatFlagIsFloat) {
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
            // Signed integer format - convert to float32
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
                stats_.failed_writes++;
                return;
            }
        } else {
            static bool format_error_logged = false;
            if (!format_error_logged) {
                RF_LOG_ERROR("Unsupported audio format flags: 0x%x", fmt.mFormatFlags);
                format_error_logged = true;
            }
            stats_.failed_writes++;
            return;
        }

        // Write to shared memory ring buffer
        size_t written = rf_ring_write(shared_memory_, interleaved.data(), frameCount);

        if (written < frameCount) {
            // This shouldn't happen since rf_ring_write drops old frames on overrun
            RF_LOG_DEBUG("Partial write: %zu/%u frames", written, frameCount);
        }

        // Periodic stats logging
        stats_.LogPeriodic();
    }

private:
    // Health check: verify shared memory is valid
    bool IsSharedMemoryHealthy() const
    {
        if (!shared_memory_) {
            return false;
        }

        // Check if file still exists
        struct stat st;
        if (stat(shm_file_path_.c_str(), &st) != 0) {
            RF_LOG_ERROR("Health check FAILED: file vanished: %s", shm_file_path_.c_str());
            return false;
        }

        // Check protocol version
        if (shared_memory_->protocol_version != RF_AUDIO_PROTOCOL_VERSION) {
            RF_LOG_ERROR("Health check FAILED: protocol mismatch (expected 0x%x, got 0x%x)",
                RF_AUDIO_PROTOCOL_VERSION, shared_memory_->protocol_version);
            return false;
        }

        // Check for ring buffer corruption
        uint64_t write_idx = atomic_load(&shared_memory_->write_index);
        uint64_t read_idx = atomic_load(&shared_memory_->read_index);

        if (write_idx < read_idx) {
            RF_LOG_ERROR("Health check FAILED: corruption (write_idx=%llu < read_idx=%llu)",
                write_idx, read_idx);
            return false;
        }

        uint64_t used = write_idx - read_idx;
        if (used > shared_memory_->ring_capacity_frames) {
            RF_LOG_ERROR("Health check FAILED: overflow (used=%llu > capacity=%u)",
                used, shared_memory_->ring_capacity_frames);
            return false;
        }

        return true;
    }

    // Health check: verify host process is alive
    bool IsHostAlive() const
    {
        if (!shared_memory_) {
            return false;
        }

        // Check timestamp age - if too old, shared memory is stale
        uint64_t now = (uint64_t)time(NULL);
        uint64_t creation_time = shared_memory_->creation_timestamp;
        uint64_t age_seconds = now - creation_time;

        const uint64_t MAX_AGE_SECONDS = 24 * 60 * 60; // 24 hours
        if (age_seconds > MAX_AGE_SECONDS) {
            RF_LOG_ERROR("Host check FAILED: shared memory stale (age: %llu seconds)", age_seconds);
            return false;
        }

        // Check if write_index is advancing (host is writing)
        auto now_time = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            now_time - last_write_check_time_).count();

        if (elapsed >= HEALTH_CHECK_INTERVAL_SECONDS) {
            uint64_t current_write_idx = atomic_load(&shared_memory_->write_index);

            // Note: We're the WRITER (driver), host is the READER
            // So we check if our own writes are succeeding, not if host is writing
            // A better check is to see if the device is still in the control file

            // Check control file
            std::ifstream file("/tmp/radioform-devices.txt");
            if (!file.is_open()) {
                RF_LOG_ERROR("Host check FAILED: control file missing");
                return false;
            }

            std::string line;
            bool found = false;
            while (std::getline(file, line)) {
                size_t separator = line.find('|');
                if (separator != std::string::npos) {
                    std::string uid = line.substr(separator + 1);
                    if (uid == device_uid_) {
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                RF_LOG_ERROR("Host check FAILED: device not in control file");
                return false;
            }

            last_write_check_time_ = now_time;
        }

        return true;
    }

    void OpenSharedMemory()
    {
        RF_LOG_INFO("OpenSharedMemory() attempting: %s", shm_file_path_.c_str());

        // Check if file exists
        struct stat st;
        if (stat(shm_file_path_.c_str(), &st) != 0) {
            RF_LOG_ERROR("File does not exist: %s (errno=%d: %s)",
                shm_file_path_.c_str(), errno, strerror(errno));
            return;
        }

        RF_LOG_DEBUG("File exists, size=%lld bytes", (long long)st.st_size);

        // Open file
        int fd = open(shm_file_path_.c_str(), O_RDWR);
        if (fd == -1) {
            RF_LOG_ERROR("Failed to open: %s (errno=%d: %s)",
                shm_file_path_.c_str(), errno, strerror(errno));
            return;
        }

        size_t shm_size = rf_shared_audio_size(RING_CAPACITY_FRAMES);
        RF_LOG_DEBUG("Mapping %zu bytes...", shm_size);

        // Map memory
        void* mem = mmap(nullptr, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        int mmap_errno = errno;
        close(fd);

        if (mem == MAP_FAILED) {
            RF_LOG_ERROR("mmap() failed: %s (errno=%d: %s)",
                shm_file_path_.c_str(), mmap_errno, strerror(mmap_errno));
            return;
        }

        shared_memory_ = reinterpret_cast<RFSharedAudioV1*>(mem);
        RF_LOG_INFO("✓ Shared memory mapped at %p", mem);

        // Log initial state
        uint64_t write_idx = atomic_load(&shared_memory_->write_index);
        uint64_t read_idx = atomic_load(&shared_memory_->read_index);
        RF_LOG_INFO("Initial indices: write=%llu, read=%llu", write_idx, read_idx);
    }

    void Disconnect()
    {
        if (shared_memory_) {
            RF_LOG_INFO("Disconnecting shared memory for device: %s", device_uid_.c_str());
            size_t shm_size = rf_shared_audio_size(RING_CAPACITY_FRAMES);
            munmap(shared_memory_, shm_size);
            shared_memory_ = nullptr;
        }
    }

    // Member variables
    RFSharedAudioV1* shared_memory_;
    std::string device_uid_;
    std::string shm_file_path_;

    // I/O client tracking (like eqMac)
    std::atomic<int32_t> io_client_count_;
    std::mutex io_mutex_;

    // Device state
    std::atomic<DeviceState> state_;

    // Health monitoring
    std::chrono::steady_clock::time_point last_health_check_;
    mutable std::chrono::steady_clock::time_point last_write_check_time_;
    mutable uint64_t last_write_index_check_;

    // Statistics
    AudioStats stats_;
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
    RF_LOG_INFO("CreateProxyDevice: name='%s', uid='%s'", name.c_str(), uid.c_str());

    if (!g_state) {
        RF_LOG_ERROR("CreateProxyDevice failed: g_state is NULL");
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

    auto device = std::make_shared<aspl::Device>(g_state->context, deviceParams);

    // Add output stream
    device->AddStreamWithControlsAsync(aspl::Direction::Output);

    // Set handlers with device-specific shared memory
    auto handler = std::make_shared<RadioformHandler>(uid);
    device->SetControlHandler(handler);
    device->SetIOHandler(handler);

    RF_LOG_INFO("✓ Proxy device created: '%s'", deviceParams.Name.c_str());

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

    RF_LOG_INFO("Device added to plugin: %s", uid.c_str());
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

    RF_LOG_INFO("Device removed from plugin: %s", uid.c_str());
}

// Parse control file and return device map
std::map<std::string, std::string> ParseControlFile()
{
    std::map<std::string, std::string> devices; // UID -> Name

    std::ifstream file("/tmp/radioform-devices.txt");
    if (!file.is_open()) {
        // Don't log error - file might not exist yet
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
            RF_LOG_INFO("Adding device: '%s' (%s)", name.c_str(), uid.c_str());
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
        RF_LOG_INFO("Removing device: %s", uid.c_str());
        RemoveDevice(uid);
    }
}

// Background thread that monitors control file
void MonitorControlFile()
{
    RF_LOG_INFO("Monitor thread started");

    while (!g_state->should_stop) {
        SyncDevices();

        // Check every second
        for (int i = 0; i < 10 && !g_state->should_stop; i++) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

    RF_LOG_INFO("Monitor thread stopped");
}

std::shared_ptr<aspl::Driver> CreateRadioformDriver()
{
    RF_LOG_INFO("╔═══════════════════════════════════════╗");
    RF_LOG_INFO("║   RADIOFORM DRIVER - PRODUCTION v2    ║");
    RF_LOG_INFO("╚═══════════════════════════════════════╝");

    // Initialize global state
    g_state = new RadioformGlobalState();
    g_state->context = std::make_shared<aspl::Context>();
    g_state->plugin = std::make_shared<aspl::Plugin>(g_state->context);

    RF_LOG_INFO("Context and plugin initialized");

    // Initial device load
    SyncDevices();

    // Start monitor thread
    RF_LOG_INFO("Starting monitor thread...");
    g_state->monitor_thread = std::thread(MonitorControlFile);

    // Create driver
    g_state->driver = std::make_shared<aspl::Driver>(g_state->context, g_state->plugin);

    RF_LOG_INFO("✓ Driver ready - %zu devices loaded", g_state->devices.size());
    RF_LOG_INFO("Features: Client tracking, Health checks, Auto-recovery");

    return g_state->driver;
}

} // namespace

// Plugin entry point
extern "C" void* RadioformDriverPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID)
{
    RF_LOG_INFO("RadioformDriverPluginFactory() called");

    if (!CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) {
        RF_LOG_ERROR("Wrong UUID - rejecting");
        return nullptr;
    }

    static std::shared_ptr<aspl::Driver> driver = CreateRadioformDriver();

    return driver->GetReference();
}
