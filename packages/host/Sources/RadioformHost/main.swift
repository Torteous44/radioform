import Foundation
import CoreAudio
import AudioToolbox
import CRadioformAudio
import CRadioformDSP

// MARK: - Device Discovery

struct PhysicalDevice {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let manufacturer: String
    let transportType: UInt32
    let isOutput: Bool
}

// Enumerate all physical output devices
func enumeratePhysicalDevices() -> [PhysicalDevice] {
    var devices: [PhysicalDevice] = []

    // Get all audio devices
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize
    ) == noErr else {
        return devices
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    ) == noErr else {
        return devices
    }

    // Check each device
    for deviceID in deviceIDs {
        // Get device name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr else {
            continue
        }

        let name = deviceName as String

        // Skip Radioform devices
        if name.contains("Radioform") || name.contains("Netcat") {
            continue
        }

        // Get device UID
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr else {
            continue
        }

        let uid = deviceUID as String

        // Get manufacturer
        var mfgAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturerCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mfgName: CFString = "" as CFString
        var mfgSize = UInt32(MemoryLayout<CFString>.size)

        let manufacturer = AudioObjectGetPropertyData(deviceID, &mfgAddress, 0, nil, &mfgSize, &mfgName) == noErr
            ? mfgName as String
            : "Unknown"

        // Get transport type
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transportType) == noErr else {
            continue
        }

        // Skip virtual and aggregate devices
        if transportType == kAudioDeviceTransportTypeVirtual ||
           transportType == kAudioDeviceTransportTypeAggregate {
            continue
        }

        // Check if device has output streams
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var streamSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr,
              streamSize > 0 else {
            continue
        }

        // This is a physical output device
        devices.append(PhysicalDevice(
            id: deviceID,
            name: name,
            uid: uid,
            manufacturer: manufacturer,
            transportType: transportType,
            isOutput: true
        ))
    }

    return devices
}

// Get transport type name for display
func transportTypeName(_ type: UInt32) -> String {
    switch type {
    case kAudioDeviceTransportTypeBuiltIn:
        return "Built-in"
    case kAudioDeviceTransportTypeBluetooth:
        return "Bluetooth"
    case kAudioDeviceTransportTypeUSB:
        return "USB"
    case kAudioDeviceTransportTypeDisplayPort:
        return "DisplayPort"
    case kAudioDeviceTransportTypeAirPlay:
        return "AirPlay"
    case kAudioDeviceTransportTypeHDMI:
        return "HDMI"
    default:
        return "Unknown"
    }
}

// MARK: - Device Monitoring

// Global device registry
var deviceRegistry: [PhysicalDevice] = []

// Currently active proxy device
var activeProxyUID: String?
var activePhysicalDeviceID: AudioDeviceID = 0

// Flag to prevent infinite loop when we programmatically switch devices
var isAutoSwitching = false

// Global audio unit for dynamic device switching
var outputUnit: AudioUnit?

// Global DSP engine for EQ processing
var dspEngine: OpaquePointer?

// Device list changed callback
let deviceListChangedCallback: AudioObjectPropertyListenerProc = { (
    inObjectID,
    inNumberAddresses,
    inAddresses,
    inClientData
) -> OSStatus in

    let newDevices = enumeratePhysicalDevices()

    // Find added devices
    let addedDevices = newDevices.filter { new in
        !deviceRegistry.contains { $0.uid == new.uid }
    }

    // Find removed devices
    let removedDevices = deviceRegistry.filter { old in
        !newDevices.contains { $0.uid == old.uid }
    }

    // Handle added devices
    for device in addedDevices {
        print("Device added: \(device.name) (\(transportTypeName(device.transportType)))")
        // Create shared memory for new device
        _ = createDeviceSharedMemory(uid: device.uid)
    }

    // Handle removed devices
    for device in removedDevices {
        print("Device removed: \(device.name) (\(transportTypeName(device.transportType)))")
        // Remove shared memory
        removeDeviceSharedMemory(uid: device.uid)
    }

    // Update registry and control file
    deviceRegistry = newDevices
    writeControlFile(newDevices)

    // Trigger driver reload if devices changed
    if !addedDevices.isEmpty || !removedDevices.isEmpty {
        reloadDriver()
    }

    return noErr
}

// Default output changed callback
let defaultOutputChangedCallback: AudioObjectPropertyListenerProc = { (
    inObjectID,
    inNumberAddresses,
    inAddresses,
    inClientData
) -> OSStatus in

    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var deviceID: AudioDeviceID = 0
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceID
    ) == noErr else {
        return noErr
    }

    // Get device name
    var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var deviceName: CFString = "" as CFString
    var nameSize = UInt32(MemoryLayout<CFString>.size)

    guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr else {
        return noErr
    }

    let name = deviceName as String

    print("Default output changed: \(name)")

    // Check if this is a Radioform proxy
    if name.contains("Radioform") {
        // Get proxy device UID
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var proxyUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &proxyUID) == noErr else {
            return noErr
        }

        let proxyUIDStr = proxyUID as String

        // Extract physical device UID (remove "-radioform" suffix)
        if let physicalUID = proxyUIDStr.components(separatedBy: "-radioform").first {
            // Find matching physical device
            if let physicalDevice = deviceRegistry.first(where: { $0.uid == physicalUID }) {
                print("Routing to: \(physicalDevice.name)")

                // Update active state
                activeProxyUID = physicalUID
                activePhysicalDeviceID = physicalDevice.id

                // Switch audio unit output to physical device
                if let unit = outputUnit {
                    var newDeviceID = physicalDevice.id

                    // Stop audio unit before changing device
                    var wasRunning = false
                    var isRunning: UInt32 = 0
                    var size = UInt32(MemoryLayout<UInt32>.size)

                    if AudioUnitGetProperty(unit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &isRunning, &size) == noErr {
                        wasRunning = (isRunning != 0)
                    }

                    if wasRunning {
                        AudioOutputUnitStop(unit)
                    }

                    // Change the device
                    let status = AudioUnitSetProperty(
                        unit,
                        kAudioOutputUnitProperty_CurrentDevice,
                        kAudioUnitScope_Global,
                        0,
                        &newDeviceID,
                        UInt32(MemoryLayout<AudioDeviceID>.size)
                    )

                    if status == noErr {
                        print("✓ Switched to \(physicalDevice.name)")
                    } else {
                        print("⚠️  Failed to switch device (error \(status))")
                    }

                    // Restart if it was running
                    if wasRunning {
                        AudioOutputUnitStart(unit)
                    }
                }
            }
        }

        // Reset auto-switching flag
        isAutoSwitching = false
    } else {
        // Physical device selected - automatically switch to proxy
        if !isAutoSwitching {
            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceUID: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)

            if AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr {
                let uid = deviceUID as String

                // Check if this is a physical device in our registry
                if deviceRegistry.contains(where: { $0.uid == uid }) {
                    // Find corresponding proxy
                    if let proxyID = findProxyDevice(forPhysicalUID: uid) {
                        print("Auto-switching to Radioform proxy")
                        isAutoSwitching = true
                        _ = setDefaultOutputDevice(proxyID)
                    } else {
                        print("Warning: No proxy found for this device")
                    }
                }
            }
        } else {
            // This was triggered by our own switch, reset flag
            isAutoSwitching = false
        }
    }

    return noErr
}

// Find proxy device ID for a physical device UID
func findProxyDevice(forPhysicalUID physicalUID: String) -> AudioDeviceID? {
    let proxyUID = physicalUID + "-radioform"

    // Get all audio devices
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize
    ) == noErr else {
        return nil
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    ) == noErr else {
        return nil
    }

    // Find device with matching UID
    for deviceID in deviceIDs {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        if AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr {
            let uid = deviceUID as String

            if uid == proxyUID {
                return deviceID
            }
        }
    }

    return nil
}

// Switch system default output to a specific device
func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var newDeviceID = deviceID
    let result = AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        UInt32(MemoryLayout<AudioDeviceID>.size),
        &newDeviceID
    )

    return result == noErr
}

// Register device monitoring listeners
func registerDeviceListeners() {
    // Listen for device list changes
    var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    AudioObjectAddPropertyListener(
        AudioObjectID(kAudioObjectSystemObject),
        &devicesAddress,
        deviceListChangedCallback,
        nil
    )

    // Listen for default output changes
    var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    AudioObjectAddPropertyListener(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultOutputAddress,
        defaultOutputChangedCallback,
        nil
    )
}

// MARK: - Proxy Management

let CONTROL_FILE_PATH = "/tmp/radioform-devices.txt"
let PRESET_FILE_PATH = "/tmp/radioform-preset.json"
let RING_CAPACITY_FRAMES: UInt32 = 1440

// Map of device UID -> shared memory pointer
var deviceSharedMemory: [String: UnsafeMutablePointer<RFSharedAudioV1>] = [:]

// MARK: - Preset Management

// JSON decoder structs
struct PresetJSON: Codable {
    let name: String
    let bands: [BandJSON]
    let preampDb: Float
    let limiterEnabled: Bool
    let limiterThresholdDb: Float

    enum CodingKeys: String, CodingKey {
        case name, bands
        case preampDb = "preamp_db"
        case limiterEnabled = "limiter_enabled"
        case limiterThresholdDb = "limiter_threshold_db"
    }
}

struct BandJSON: Codable {
    let frequencyHz: Float
    let gainDb: Float
    let qFactor: Float
    let filterType: Int
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case frequencyHz = "frequency_hz"
        case gainDb = "gain_db"
        case qFactor = "q_factor"
        case filterType = "filter_type"
        case enabled
    }
}

// Add file monitoring (reuse device pattern)
func monitorPresetFile() {
    let queue = DispatchQueue(label: "com.radioform.preset-monitor")

    queue.async {
        var lastModification: Date?

        while true {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: PRESET_FILE_PATH),
               let modDate = attributes[.modificationDate] as? Date {

                if lastModification == nil || modDate > lastModification! {
                    lastModification = modDate
                    loadAndApplyPreset()
                }
            }

            Thread.sleep(forTimeInterval: 0.5) // Check every 500ms
        }
    }
}

func loadAndApplyPreset() {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: PRESET_FILE_PATH))
        let presetJSON = try JSONDecoder().decode(PresetJSON.self, from: data)

        // Convert JSON to C struct
        var preset = radioform_preset_t()
        radioform_dsp_preset_init_flat(&preset)

        preset.num_bands = UInt32(min(presetJSON.bands.count, 10))

        // Copy name (strncpy equivalent in Swift)
        let nameBytes = Array(presetJSON.name.utf8.prefix(63))
        withUnsafeMutableBytes(of: &preset.name) { ptr in
            let buffer = ptr.baseAddress!.assumingMemoryBound(to: CChar.self)
            for (i, byte) in nameBytes.enumerated() {
                buffer[i] = CChar(bitPattern: byte)
            }
            buffer[min(nameBytes.count, 63)] = 0  // Null terminator
        }

        // Copy bands (use withUnsafeMutablePointer for tuple access)
        for (i, band) in presetJSON.bands.prefix(10).enumerated() {
            withUnsafeMutablePointer(to: &preset.bands) { bandsPtr in
                let bandPtr = UnsafeMutableRawPointer(bandsPtr)
                    .advanced(by: i * MemoryLayout<radioform_band_t>.stride)
                    .assumingMemoryBound(to: radioform_band_t.self)

                bandPtr.pointee.frequency_hz = band.frequencyHz
                bandPtr.pointee.gain_db = band.gainDb
                bandPtr.pointee.q_factor = band.qFactor
                bandPtr.pointee.type = radioform_filter_type_t(UInt32(band.filterType))
                bandPtr.pointee.enabled = band.enabled
            }
        }

        preset.preamp_db = presetJSON.preampDb
        preset.limiter_enabled = presetJSON.limiterEnabled
        preset.limiter_threshold_db = presetJSON.limiterThresholdDb

        // Apply to DSP engine
        if let engine = dspEngine {
            if radioform_dsp_apply_preset(engine, &preset) == RADIOFORM_OK {
                print("Applied preset: \(presetJSON.name)")
            } else {
                print("Failed to apply preset")
            }
        }
    } catch {
        print("Failed to load preset: \(error)")
    }
}

// Write control file for driver to read
func writeControlFile(_ devices: [PhysicalDevice]) {
    let content = devices.map { "\($0.name)|\($0.uid)" }.joined(separator: "\n")

    do {
        try content.write(toFile: CONTROL_FILE_PATH, atomically: true, encoding: .utf8)
    } catch {
        print("Failed to write control file: \(error)")
    }
}

// Create shared memory for a specific device
func createDeviceSharedMemory(uid: String) -> Bool {
    print("[RadioformHost INFO] createDeviceSharedMemory() called for uid: \(uid)")

    // Sanitize UID for filename (replace : / space with _)
    let safeUID = uid.replacingOccurrences(of: ":", with: "_")
                     .replacingOccurrences(of: "/", with: "_")
                     .replacingOccurrences(of: " ", with: "_")

    let shmPath = "/tmp/radioform-\(safeUID)"
    print("[RadioformHost INFO] Creating shared memory file: \(shmPath)")

    // Remove any existing file
    unlink(shmPath)

    // Create new shared memory file with world read/write permissions
    let fd = open(shmPath, O_CREAT | O_RDWR, 0666)
    guard fd >= 0 else {
        print("[RadioformHost ERROR] FAILED to create shared memory file: \(shmPath)")
        print("[RadioformHost ERROR] Error: \(String(cString: strerror(errno)))")
        return false
    }

    print("[RadioformHost DEBUG] File created successfully, fd=\(fd)")

    // Explicitly set permissions
    fchmod(fd, 0o666)

    let shmSize = rf_shared_audio_size(RING_CAPACITY_FRAMES)
    print("[RadioformHost DEBUG] Shared memory size: \(shmSize) bytes")

    // Set size
    guard ftruncate(fd, Int64(shmSize)) == 0 else {
        print("[RadioformHost ERROR] Failed to set file size for \(shmPath)")
        print("[RadioformHost ERROR] Error: \(String(cString: strerror(errno)))")
        close(fd)
        return false
    }

    print("[RadioformHost DEBUG] File size set successfully")

    // Map memory
    let mem = mmap(nil, shmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
    close(fd)

    guard mem != MAP_FAILED else {
        print("[RadioformHost ERROR] Failed to mmap shared memory for \(shmPath)")
        print("[RadioformHost ERROR] Error: \(String(cString: strerror(errno)))")
        return false
    }

    print("[RadioformHost DEBUG] Memory mapped at: \(mem!)")

    let sharedMem = mem!.assumingMemoryBound(to: RFSharedAudioV1.self)

    // Initialize the shared memory structure
    rf_shared_audio_init(sharedMem, RING_CAPACITY_FRAMES)

    // Store in map
    deviceSharedMemory[uid] = sharedMem

    print("[RadioformHost INFO] SUCCESS: Shared memory created for device: \(uid)")
    print("[RadioformHost INFO]   File: \(shmPath)")
    print("[RadioformHost INFO]   Size: \(shmSize) bytes")
    print("[RadioformHost INFO]   Driver can now access this file")

    return true
}

// Create shared memory for all devices
func createAllDeviceSharedMemory(_ devices: [PhysicalDevice]) {
    print("[RadioformHost INFO] createAllDeviceSharedMemory() creating shared memory for \(devices.count) devices")

    for device in devices {
        let success = createDeviceSharedMemory(uid: device.uid)
        if success {
            print("[RadioformHost INFO] ✓ Created shared memory for: \(device.name) (\(device.uid))")
        } else {
            print("[RadioformHost ERROR] ✗ Failed to create shared memory for: \(device.name) (\(device.uid))")
        }
    }

    print("[RadioformHost INFO] Shared memory creation complete for all devices")
}

// Remove shared memory for a device
func removeDeviceSharedMemory(uid: String) {
    guard let sharedMem = deviceSharedMemory[uid] else { return }

    let shmSize = rf_shared_audio_size(RING_CAPACITY_FRAMES)
    munmap(sharedMem, shmSize)
    deviceSharedMemory.removeValue(forKey: uid)

    // Remove file
    let safeUID = uid.replacingOccurrences(of: ":", with: "_")
                     .replacingOccurrences(of: "/", with: "_")
                     .replacingOccurrences(of: " ", with: "_")
    let shmPath = "/tmp/radioform-\(safeUID)"
    unlink(shmPath)
}

// Trigger driver to reload (requires coreaudiod restart)
func reloadDriver() {
    print("Driver reload required - restart coreaudiod with: sudo killall coreaudiod")
}

// MARK: - Shared Memory

// Legacy shared memory path (for backward compatibility)
let SHM_FILE_PATH = "/tmp/radioform-audio-v1"

// Global shared memory pointer (for backward compatibility)
var sharedMemory: UnsafeMutablePointer<RFSharedAudioV1>?

// Create shared memory file (host creates, driver opens)
func createSharedMemory() -> Bool {
    // Remove any existing file
    unlink(SHM_FILE_PATH)

    // Create new shared memory file with world read/write permissions
    let fd = open(SHM_FILE_PATH, O_CREAT | O_RDWR, 0666)
    guard fd >= 0 else {
        print("Failed to create shared memory file: \(String(cString: strerror(errno)))")
        return false
    }

    // Explicitly set permissions (umask may interfere)
    fchmod(fd, 0o666)

    let shmSize = rf_shared_audio_size(RING_CAPACITY_FRAMES)

    // Set size
    guard ftruncate(fd, Int64(shmSize)) == 0 else {
        print("Failed to set file size: \(String(cString: strerror(errno)))")
        close(fd)
        return false
    }

    // Map memory
    let mem = mmap(nil, shmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
    close(fd)

    guard mem != MAP_FAILED else {
        print("Failed to map shared memory: \(String(cString: strerror(errno)))")
        return false
    }

    sharedMemory = mem!.assumingMemoryBound(to: RFSharedAudioV1.self)

    // Initialize the shared memory structure
    rf_shared_audio_init(sharedMemory, RING_CAPACITY_FRAMES)

    return true
}

// Find first physical output device
func findPhysicalDevice() -> AudioDeviceID {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize
    )

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    )

    // Find first output device that's not Radioform
    for deviceID in deviceIDs {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
            let name = deviceName as String
            if !name.contains("Radioform") {
                // Check if it has output channels
                var streamAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreams,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )

                var streamSize: UInt32 = 0
                if AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr,
                   streamSize > 0 {
                    return deviceID
                }
            }
        }
    }

    print("No physical output device found")
    return 0
}

// Audio render callback - reads from ring buffer, applies EQ, outputs to device
let renderCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    guard let bufferList = ioData else { return noErr }

    // Get shared memory for active proxy device
    let sharedMem: UnsafeMutablePointer<RFSharedAudioV1>?
    if let activeUID = activeProxyUID {
        sharedMem = deviceSharedMemory[activeUID]
    } else {
        // Fallback to legacy single device
        sharedMem = sharedMemory
    }

    guard let mem = sharedMem else {
        // No shared memory - output silence
        let leftBuffer = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
        let rightBuffer = UnsafeMutableAudioBufferListPointer(bufferList)[1].mData!.assumingMemoryBound(to: Float.self)
        for i in 0..<Int(inNumberFrames) {
            leftBuffer[i] = 0
            rightBuffer[i] = 0
        }
        return noErr
    }

    // Read interleaved audio from ring buffer
    var tempBuffer = [Float](repeating: 0, count: Int(inNumberFrames) * 2)
    let framesRead = rf_ring_read(mem, &tempBuffer, inNumberFrames)

    // Apply EQ processing if engine is available
    if let engine = dspEngine {
        radioform_dsp_process_interleaved(engine, tempBuffer, &tempBuffer, inNumberFrames)
    }

    // Deinterleave to output buffers (left/right channels)
    let leftBuffer = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
    let rightBuffer = UnsafeMutableAudioBufferListPointer(bufferList)[1].mData!.assumingMemoryBound(to: Float.self)

    for i in 0..<Int(framesRead) {
        leftBuffer[i] = tempBuffer[i * 2]
        rightBuffer[i] = tempBuffer[i * 2 + 1]
    }

    // Zero out remaining frames if underrun
    for i in Int(framesRead)..<Int(inNumberFrames) {
        leftBuffer[i] = 0
        rightBuffer[i] = 0
    }

    return noErr
}

// Main
print("[RadioformHost INFO] ===== RADIOFORM HOST STARTING =====")

// 1. Discover physical devices
print("[RadioformHost INFO] Step 1: Discovering physical audio devices...")
deviceRegistry = enumeratePhysicalDevices()

if deviceRegistry.isEmpty {
    print("[RadioformHost ERROR] No physical output devices found")
} else {
    print("[RadioformHost INFO] Found \(deviceRegistry.count) physical output device(s):")
    for device in deviceRegistry {
        print("[RadioformHost INFO]   - \(device.name) (\(device.uid))")
    }
}

// Register listeners for device changes
print("[RadioformHost INFO] Registering device change listeners...")
registerDeviceListeners()

// 2. Create proxy infrastructure
// CRITICAL: Must create shared memory files BEFORE writing control file
// to avoid race condition with driver loading!
print("[RadioformHost INFO] Step 2: Creating shared memory files (BEFORE control file)...")
createAllDeviceSharedMemory(deviceRegistry)

print("[RadioformHost INFO] Step 3: Writing control file to notify driver...")
writeControlFile(deviceRegistry)
print("[RadioformHost INFO] Control file written: /tmp/radioform-devices.txt")

print("[RadioformHost INFO] Proxy infrastructure ready - driver will load on next coreaudiod start")
print("To activate proxies, restart coreaudiod: sudo killall coreaudiod")

// 3. Create legacy shared memory for backward compatibility
guard createSharedMemory() else {
    exit(1)
}

// 4. Initialize DSP engine with bass boost preset
dspEngine = radioform_dsp_create(48000)
guard dspEngine != nil else {
    print("Failed to create DSP engine")
    exit(1)
}

// Create a bass boost preset
var preset = radioform_preset_t()
radioform_dsp_preset_init_flat(&preset)
preset.num_bands = 2

// Band 1: Low shelf at 100Hz, +6dB boost
preset.bands.0.frequency_hz = 100
preset.bands.0.gain_db = 6.0
preset.bands.0.q_factor = 0.707
preset.bands.0.type = RADIOFORM_FILTER_LOW_SHELF
preset.bands.0.enabled = true

// Band 2: Peak at 60Hz, +3dB boost (sub-bass)
preset.bands.1.frequency_hz = 60
preset.bands.1.gain_db = 3.0
preset.bands.1.q_factor = 1.0
preset.bands.1.type = RADIOFORM_FILTER_PEAK
preset.bands.1.enabled = true

preset.preamp_db = 0.0
preset.limiter_enabled = true
preset.limiter_threshold_db = -1.0

// Apply the preset
if radioform_dsp_apply_preset(dspEngine, &preset) != RADIOFORM_OK {
    print("Failed to apply EQ preset")
    exit(1)
}

print("Bass boost EQ enabled: +6dB @ 100Hz, +3dB @ 60Hz")

// 5. Find physical output device for current routing
let outputDeviceID = findPhysicalDevice()
guard outputDeviceID != 0 else {
    exit(1)
}

// 5. Create audio unit
var componentDesc = AudioComponentDescription(
    componentType: kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_HALOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0,
    componentFlagsMask: 0
)

guard let component = AudioComponentFindNext(nil, &componentDesc) else {
    print("Failed to find output component")
    exit(1)
}

var status = AudioComponentInstanceNew(component, &outputUnit)
guard status == noErr, let unit = outputUnit else {
    print("Failed to create audio unit")
    exit(1)
}

// 6. Set output device
var deviceID = outputDeviceID
status = AudioUnitSetProperty(
    unit,
    kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global,
    0,
    &deviceID,
    UInt32(MemoryLayout<AudioDeviceID>.size)
)

guard status == noErr else {
    print("Failed to set output device")
    exit(1)
}

// 7. Set format (48kHz stereo float32 non-interleaved)
var format = AudioStreamBasicDescription(
    mSampleRate: 48000.0,
    mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
    mBytesPerPacket: 4,
    mFramesPerPacket: 1,
    mBytesPerFrame: 4,
    mChannelsPerFrame: 2,
    mBitsPerChannel: 32,
    mReserved: 0
)

status = AudioUnitSetProperty(
    unit,
    kAudioUnitProperty_StreamFormat,
    kAudioUnitScope_Input,
    0,
    &format,
    UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
)

guard status == noErr else {
    print("Failed to set format")
    exit(1)
}

// 8. Set render callback
var callbackStruct = AURenderCallbackStruct(
    inputProc: renderCallback,
    inputProcRefCon: nil
)

status = AudioUnitSetProperty(
    unit,
    kAudioUnitProperty_SetRenderCallback,
    kAudioUnitScope_Input,
    0,
    &callbackStruct,
    UInt32(MemoryLayout<AURenderCallbackStruct>.size)
)

guard status == noErr else {
    print("Failed to set render callback")
    exit(1)
}

// 9. Initialize and start
status = AudioUnitInitialize(unit)
guard status == noErr else {
    print("Failed to initialize audio unit")
    exit(1)
}

status = AudioOutputUnitStart(unit)
guard status == noErr else {
    print("Failed to start audio unit")
    exit(1)
}

print("Host running")

// Start preset monitoring
monitorPresetFile()

// Cleanup function
func cleanup() {
    // Stop audio unit
    if let unit = outputUnit {
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
    }

    // Unmap all shared memory
    if let mem = sharedMemory {
        munmap(mem, rf_shared_audio_size(RING_CAPACITY_FRAMES))
    }
    for (_, mem) in deviceSharedMemory {
        munmap(mem, rf_shared_audio_size(RING_CAPACITY_FRAMES))
    }

    // Remove control file - driver will detect and remove proxies automatically
    unlink(CONTROL_FILE_PATH)

    print("Host stopped - proxies will be removed within 1 second")
}

// Keep running
signal(SIGINT) { _ in
    print("Stopping...")
    cleanup()
    exit(0)
}

RunLoop.current.run()
