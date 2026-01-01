import Foundation
import CoreAudio
import AudioToolbox
import CRadioformAudio
import CRadioformDSP

// MARK: - V2 Configuration

// V2 Protocol defaults
let DEFAULT_SAMPLE_RATE: UInt32 = 48000
let DEFAULT_CHANNELS: UInt32 = 2
let DEFAULT_FORMAT = RF_FORMAT_FLOAT32
let DEFAULT_DURATION_MS: UInt32 = 40  // 40ms buffer

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

    print("[DeviceEnum] ===== ENUMERATING AUDIO DEVICES =====")

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
        print("[DeviceEnum] ERROR: Failed to get device list size")
        return devices
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    print("[DeviceEnum] Found \(deviceCount) total audio devices")

    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    ) == noErr else {
        print("[DeviceEnum] ERROR: Failed to get device list")
        return devices
    }

    // Check each device
    for (index, deviceID) in deviceIDs.enumerated() {
        print("[DeviceEnum] --- Checking device \(index + 1)/\(deviceCount) (ID: \(deviceID)) ---")

        // Get device name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr else {
            print("[DeviceEnum] ✗ SKIP: Failed to get device name")
            continue
        }

        let name = deviceName as String
        print("[DeviceEnum]   Name: \(name)")

        // Skip Radioform devices
        if name.contains("Radioform") || name.contains("Netcat") {
            print("[DeviceEnum] ✗ SKIP: Radioform/Netcat device")
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
            print("[DeviceEnum] ✗ SKIP: Failed to get device UID")
            continue
        }

        let uid = deviceUID as String
        print("[DeviceEnum]   UID: \(uid)")

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
        print("[DeviceEnum]   Manufacturer: \(manufacturer)")

        // Get transport type
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transportType) == noErr else {
            print("[DeviceEnum] ✗ SKIP: Failed to get transport type")
            continue
        }

        let transportName = transportTypeName(transportType)
        print("[DeviceEnum]   Transport: \(transportName) (0x\(String(transportType, radix: 16)))")

        // Skip virtual and aggregate devices
        if transportType == kAudioDeviceTransportTypeVirtual ||
           transportType == kAudioDeviceTransportTypeAggregate {
            print("[DeviceEnum] ✗ SKIP: Virtual or aggregate device")
            continue
        }

        // Check if device has output streams
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var streamSize: UInt32 = 0
        let hasStreams = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0

        print("[DeviceEnum]   Output streams: \(hasStreams ? "Yes (\(streamSize) bytes)" : "No")")

        guard hasStreams else {
            print("[DeviceEnum] ✗ SKIP: No output streams")
            continue
        }

        // This is a physical output device
        print("[DeviceEnum] ✓ ACCEPTED: Adding to device list")
        devices.append(PhysicalDevice(
            id: deviceID,
            name: name,
            uid: uid,
            manufacturer: manufacturer,
            transportType: transportType,
            isOutput: true
        ))
    }

    print("[DeviceEnum] ===== ENUMERATION COMPLETE: \(devices.count) devices accepted =====")
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
    case kAudioDeviceTransportTypeVirtual:
        return "Virtual"
    case kAudioDeviceTransportTypeAggregate:
        return "Aggregate"
    case kAudioDeviceTransportTypePCI:
        return "PCI"
    case kAudioDeviceTransportTypeFireWire:
        return "FireWire"
    case kAudioDeviceTransportTypeThunderbolt:
        return "Thunderbolt"
    default:
        let chars = [
            UInt8((type >> 24) & 0xFF),
            UInt8((type >> 16) & 0xFF),
            UInt8((type >> 8) & 0xFF),
            UInt8(type & 0xFF)
        ]
        let ascii = String(bytes: chars, encoding: .ascii) ?? ""
        return "Unknown ('\(ascii)')"
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
        _ = createDeviceSharedMemoryV2(uid: device.uid)
    }

    // Handle removed devices
    for device in removedDevices {
        print("Device removed: \(device.name) (\(transportTypeName(device.transportType)))")
        removeDeviceSharedMemoryV2(uid: device.uid)
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

// Automatically select proxy for current default device on startup
func autoSelectProxyOnStartup() {
    // Get current default output device
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
        print("[AutoSelect] ERROR: Could not get current default device")
        return
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
        print("[AutoSelect] ERROR: Could not get device UID")
        return
    }

    let uid = deviceUID as String

    // Get device name
    var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var deviceName: CFString = "" as CFString
    var nameSize = UInt32(MemoryLayout<CFString>.size)

    guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr else {
        print("[AutoSelect] ERROR: Could not get device name")
        return
    }

    let name = deviceName as String
    print("[AutoSelect] Current default device: \(name) (\(uid))")

    // Check if already on a proxy
    if name.contains("Radioform") {
        print("[AutoSelect] Already on proxy device - no action needed")
        return
    }

    // Check if this is a physical device in our registry
    guard deviceRegistry.contains(where: { $0.uid == uid }) else {
        print("[AutoSelect] Current device not in registry - no proxy available")
        return
    }

    // Find the corresponding proxy device
    guard let proxyID = findProxyDevice(forPhysicalUID: uid) else {
        print("[AutoSelect] WARNING: Could not find proxy for device: \(name)")
        return
    }

    // Set the proxy as default
    print("[AutoSelect] Switching to proxy device...")
    if setDefaultOutputDevice(proxyID) {
        print("[AutoSelect] ✓ Successfully switched to proxy")
        activeProxyUID = uid
        activePhysicalDeviceID = deviceID
    } else {
        print("[AutoSelect] ERROR: Failed to set proxy as default")
    }
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

// MARK: - Proxy Management (V2)

let CONTROL_FILE_PATH = "/tmp/radioform-devices.txt"
let PRESET_FILE_PATH = "/tmp/radioform-preset.json"

// Map of device UID -> V2 shared memory pointer
var deviceSharedMemoryV2: [String: UnsafeMutablePointer<RFSharedAudioV2>] = [:]

// Heartbeat management
var heartbeatTimer: DispatchSourceTimer?

// Start heartbeat for all devices
func startHeartbeat() {
    heartbeatTimer = DispatchSource.makeTimerSource(queue: .global())
    heartbeatTimer?.schedule(deadline: .now(), repeating: 1.0)  // Every second

    heartbeatTimer?.setEventHandler {
        for (_, mem) in deviceSharedMemoryV2 {
            rf_update_host_heartbeat(mem)
        }
    }

    heartbeatTimer?.resume()
    print("[Heartbeat] Started - updating every second")
}

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

// Add file monitoring
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

            Thread.sleep(forTimeInterval: 0.5)
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

        // Copy name
        let nameBytes = Array(presetJSON.name.utf8.prefix(63))
        withUnsafeMutableBytes(of: &preset.name) { ptr in
            let buffer = ptr.baseAddress!.assumingMemoryBound(to: CChar.self)
            for (i, byte) in nameBytes.enumerated() {
                buffer[i] = CChar(bitPattern: byte)
            }
            buffer[min(nameBytes.count, 63)] = 0
        }

        // Copy bands
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

// Create V2 shared memory for a specific device
func createDeviceSharedMemoryV2(uid: String) -> Bool {
    print("[RadioformHost V2] Creating shared memory for: \(uid)")

    // Sanitize UID for filename
    let safeUID = uid.replacingOccurrences(of: ":", with: "_")
                     .replacingOccurrences(of: "/", with: "_")
                     .replacingOccurrences(of: " ", with: "_")

    let shmPath = "/tmp/radioform-\(safeUID)"
    print("[RadioformHost V2] File: \(shmPath)")

    // Remove any existing file
    unlink(shmPath)

    // Create new shared memory file
    let fd = open(shmPath, O_CREAT | O_RDWR, 0666)
    guard fd >= 0 else {
        print("[RadioformHost V2] ERROR: Failed to create file: \(String(cString: strerror(errno)))")
        return false
    }

    fchmod(fd, 0o666)

    // Calculate size for V2 protocol
    let frames = rf_frames_for_duration(DEFAULT_SAMPLE_RATE, DEFAULT_DURATION_MS)
    let bytesPerSample = rf_bytes_per_sample(DEFAULT_FORMAT)
    let shmSize = rf_shared_audio_v2_size(frames, DEFAULT_CHANNELS, bytesPerSample)

    print("[RadioformHost V2] Size: \(shmSize) bytes (\(frames) frames @ \(DEFAULT_SAMPLE_RATE)Hz)")

    // Set size
    guard ftruncate(fd, Int64(shmSize)) == 0 else {
        print("[RadioformHost V2] ERROR: Failed to set size: \(String(cString: strerror(errno)))")
        close(fd)
        return false
    }

    // Map memory
    let mem = mmap(nil, shmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
    close(fd)

    guard mem != MAP_FAILED else {
        print("[RadioformHost V2] ERROR: mmap failed: \(String(cString: strerror(errno)))")
        return false
    }

    let sharedMem = mem!.assumingMemoryBound(to: RFSharedAudioV2.self)

    // Initialize V2 structure
    rf_shared_audio_v2_init(
        sharedMem,
        DEFAULT_SAMPLE_RATE,
        DEFAULT_CHANNELS,
        DEFAULT_FORMAT,
        DEFAULT_DURATION_MS
    )

    // Store in map
    deviceSharedMemoryV2[uid] = sharedMem

    print("[RadioformHost V2] ✓ SUCCESS")
    print("[RadioformHost V2]   Protocol: V2")
    print("[RadioformHost V2]   Format: \(DEFAULT_SAMPLE_RATE)Hz, \(DEFAULT_CHANNELS)ch, float32")
    print("[RadioformHost V2]   Buffer: \(DEFAULT_DURATION_MS)ms (\(frames) frames)")
    print("[RadioformHost V2]   Capabilities: Multi-rate, Multi-format, Heartbeat")

    return true
}

// Create V2 shared memory for all devices
func createAllDeviceSharedMemoryV2(_ devices: [PhysicalDevice]) {
    print("[RadioformHost V2] Creating shared memory for \(devices.count) devices")

    for device in devices {
        if createDeviceSharedMemoryV2(uid: device.uid) {
            print("[RadioformHost V2] ✓ \(device.name)")
        } else {
            print("[RadioformHost V2] ✗ \(device.name)")
        }
    }

    print("[RadioformHost V2] Complete")
}

// Remove V2 shared memory for a device
func removeDeviceSharedMemoryV2(uid: String) {
    guard let sharedMem = deviceSharedMemoryV2[uid] else { return }

    let shmSize = rf_shared_audio_v2_size(
        sharedMem.pointee.ring_capacity_frames,
        sharedMem.pointee.channels,
        sharedMem.pointee.bytes_per_sample
    )

    munmap(sharedMem, shmSize)
    deviceSharedMemoryV2.removeValue(forKey: uid)

    // Remove file
    let safeUID = uid.replacingOccurrences(of: ":", with: "_")
                     .replacingOccurrences(of: "/", with: "_")
                     .replacingOccurrences(of: " ", with: "_")
    let shmPath = "/tmp/radioform-\(safeUID)"
    unlink(shmPath)
}

// Trigger driver to reload
func reloadDriver() {
    print("Driver reload required - restart coreaudiod with: sudo killall coreaudiod")
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

// Audio render callback - reads from V2 ring buffer
let renderCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    guard let bufferList = ioData else { return noErr }

    // Get V2 shared memory for active proxy device
    let sharedMem: UnsafeMutablePointer<RFSharedAudioV2>?
    if let activeUID = activeProxyUID {
        sharedMem = deviceSharedMemoryV2[activeUID]
    } else {
        // Use first device if no active proxy
        sharedMem = deviceSharedMemoryV2.values.first
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

    // Read interleaved audio from V2 ring buffer (always outputs float32)
    var tempBuffer = [Float](repeating: 0, count: Int(inNumberFrames) * 2)
    let framesRead = rf_ring_read_v2(mem, &tempBuffer, inNumberFrames)

    // Apply EQ processing if engine is available
    if let engine = dspEngine {
        radioform_dsp_process_interleaved(engine, tempBuffer, &tempBuffer, inNumberFrames)
    }

    // Deinterleave to output buffers
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
print("╔════════════════════════════════════════════════════╗")
print("║   RADIOFORM HOST V2 - UNIVERSAL AUDIO DRIVER      ║")
print("╚════════════════════════════════════════════════════╝")

// 1. Discover physical devices
print("[Step 1] Discovering physical audio devices...")
deviceRegistry = enumeratePhysicalDevices()

if deviceRegistry.isEmpty {
    print("[ERROR] No physical output devices found")
    exit(1)
} else {
    print("[✓] Found \(deviceRegistry.count) physical output device(s)")
    for device in deviceRegistry {
        print("    - \(device.name) (\(device.uid))")
    }
}

// Register listeners for device changes
print("[Step 2] Registering device change listeners...")
registerDeviceListeners()

// 2. Create V2 proxy infrastructure
print("[Step 3] Creating V2 shared memory files...")
createAllDeviceSharedMemoryV2(deviceRegistry)

print("[Step 4] Writing control file...")
writeControlFile(deviceRegistry)
print("    ✓ Control file: /tmp/radioform-devices.txt")

print("[Step 5] Starting heartbeat monitor...")
startHeartbeat()

// Wait for driver to create proxy devices
print("[Step 6] Waiting for driver to create proxy devices...")
Thread.sleep(forTimeInterval: 2.0)

// Automatically switch to proxy
print("[Step 7] Auto-selecting proxy device...")
autoSelectProxyOnStartup()

// 3. Initialize DSP engine
print("[Step 8] Initializing DSP engine...")
dspEngine = radioform_dsp_create(48000)
guard dspEngine != nil else {
    print("[ERROR] Failed to create DSP engine")
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

// Band 2: Peak at 60Hz, +3dB boost
preset.bands.1.frequency_hz = 60
preset.bands.1.gain_db = 3.0
preset.bands.1.q_factor = 1.0
preset.bands.1.type = RADIOFORM_FILTER_PEAK
preset.bands.1.enabled = true

preset.preamp_db = 0.0
preset.limiter_enabled = true
preset.limiter_threshold_db = -1.0

if radioform_dsp_apply_preset(dspEngine, &preset) != RADIOFORM_OK {
    print("[ERROR] Failed to apply EQ preset")
    exit(1)
}

print("    ✓ Bass boost EQ: +6dB @ 100Hz, +3dB @ 60Hz")

// 4. Find physical output device
print("[Step 9] Finding physical output device...")
let outputDeviceID = findPhysicalDevice()
guard outputDeviceID != 0 else {
    print("[ERROR] No physical device found")
    exit(1)
}
print("    ✓ Using device ID: \(outputDeviceID)")

// 5. Create audio unit
print("[Step 10] Creating audio unit...")
var componentDesc = AudioComponentDescription(
    componentType: kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_HALOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0,
    componentFlagsMask: 0
)

guard let component = AudioComponentFindNext(nil, &componentDesc) else {
    print("[ERROR] Failed to find output component")
    exit(1)
}

var status = AudioComponentInstanceNew(component, &outputUnit)
guard status == noErr, let unit = outputUnit else {
    print("[ERROR] Failed to create audio unit")
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
    print("[ERROR] Failed to set output device")
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
    print("[ERROR] Failed to set format")
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
    print("[ERROR] Failed to set render callback")
    exit(1)
}

// 9. Initialize and start
status = AudioUnitInitialize(unit)
guard status == noErr else {
    print("[ERROR] Failed to initialize audio unit")
    exit(1)
}

status = AudioOutputUnitStart(unit)
guard status == noErr else {
    print("[ERROR] Failed to start audio unit")
    exit(1)
}

print("")
print("╔════════════════════════════════════════════════════╗")
print("║            HOST V2 RUNNING - UNIVERSAL             ║")
print("║  Features: Multi-rate, Multi-format, Heartbeat    ║")
print("╚════════════════════════════════════════════════════╝")
print("")

// Start preset monitoring
monitorPresetFile()

// Cleanup function
func cleanup() {
    print("\n[Cleanup] Starting cleanup process...")

    // Stop heartbeat
    heartbeatTimer?.cancel()
    heartbeatTimer = nil

    // Note: We don't need to mark as disconnected manually
    // The heartbeat stopping will signal disconnection to driver

    // Restore to physical device (same logic as before)
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var currentDeviceID: AudioDeviceID = 0
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

    if AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &currentDeviceID
    ) == noErr {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        if AudioObjectGetPropertyData(currentDeviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
            let name = deviceName as String

            if name.contains("Radioform") {
                print("[Cleanup] Restoring to physical device...")

                var uidAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceUID,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                var proxyUID: CFString = "" as CFString
                var uidSize = UInt32(MemoryLayout<CFString>.size)

                if AudioObjectGetPropertyData(currentDeviceID, &uidAddress, 0, nil, &uidSize, &proxyUID) == noErr {
                    let proxyUIDStr = proxyUID as String

                    if let physicalUID = proxyUIDStr.components(separatedBy: "-radioform").first {
                        if let physicalDevice = deviceRegistry.first(where: { $0.uid == physicalUID }) {
                            var physicalDeviceID = physicalDevice.id
                            let result = AudioObjectSetPropertyData(
                                AudioObjectID(kAudioObjectSystemObject),
                                &propertyAddress,
                                0,
                                nil,
                                UInt32(MemoryLayout<AudioDeviceID>.size),
                                &physicalDeviceID
                            )

                            if result == noErr {
                                print("[Cleanup] ✓ Restored to \(physicalDevice.name)")
                                Thread.sleep(forTimeInterval: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    // Stop audio unit
    if let unit = outputUnit {
        print("[Cleanup] Stopping audio unit...")
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
    }

    // Remove control file
    print("[Cleanup] Removing control file...")
    unlink(CONTROL_FILE_PATH)

    Thread.sleep(forTimeInterval: 1.2)

    // Unmap V2 shared memory
    print("[Cleanup] Unmapping V2 shared memory...")
    for (_, mem) in deviceSharedMemoryV2 {
        let size = rf_shared_audio_v2_size(
            mem.pointee.ring_capacity_frames,
            mem.pointee.channels,
            mem.pointee.bytes_per_sample
        )
        munmap(mem, size)
    }

    print("[Cleanup] ✓ Complete")
}

// Set up signal handlers
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    print("\n[Signal] Received SIGINT (Ctrl+C)")
    cleanup()
    exit(0)
}
sigintSource.resume()

let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSource.setEventHandler {
    print("\n[Signal] Received SIGTERM")
    cleanup()
    exit(0)
}
sigtermSource.resume()

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

print("[Signal] Handlers installed")

RunLoop.current.run()
