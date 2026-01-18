import Foundation
import CoreAudio

struct PhysicalDevice {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let manufacturer: String
    let transportType: UInt32
    let isOutput: Bool
    let validationPassed: Bool
    let validationNote: String?
}

class DeviceDiscovery {
    func enumeratePhysicalDevices() -> [PhysicalDevice] {
        var devices: [PhysicalDevice] = []

        print("[DeviceEnum] ===== ENUMERATING AUDIO DEVICES =====")

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

        for (index, deviceID) in deviceIDs.enumerated() {
            print("[DeviceEnum] --- Checking device \(index + 1)/\(deviceCount) (ID: \(deviceID)) ---")

            guard let name = getDeviceName(deviceID) else {
                print("[DeviceEnum] ✗ SKIP: Failed to get device name")
                continue
            }

            print("[DeviceEnum]   Name: \(name)")

            if name.contains("Radioform") || name.contains("Netcat") {
                print("[DeviceEnum] ✗ SKIP: Radioform/Netcat device")
                continue
            }

            guard let uid = getDeviceUID(deviceID) else {
                print("[DeviceEnum] ✗ SKIP: Failed to get device UID")
                continue
            }

            print("[DeviceEnum]   UID: \(uid)")

            let manufacturer = getDeviceManufacturer(deviceID)
            print("[DeviceEnum]   Manufacturer: \(manufacturer)")

            guard let transportType = getDeviceTransportType(deviceID) else {
                print("[DeviceEnum] ✗ SKIP: Failed to get transport type")
                continue
            }

            let transportName = transportTypeName(transportType)
            print("[DeviceEnum]   Transport: \(transportName) (0x\(String(transportType, radix: 16)))")

            if transportType == kAudioDeviceTransportTypeVirtual ||
               transportType == kAudioDeviceTransportTypeAggregate {
                print("[DeviceEnum] ✗ SKIP: Virtual or aggregate device")
                continue
            }

            let hasStreams = deviceHasOutputStreams(deviceID)
            print("[DeviceEnum]   Output streams: \(hasStreams ? "Yes" : "No")")

            guard hasStreams else {
                print("[DeviceEnum] ✗ SKIP: No output streams")
                continue
            }

            // Enhanced validation for issue #34 - detect non-functional devices
            let validation = validateDevice(deviceID, transportType: transportType)
            print("[DeviceEnum]   Validation: \(validation.valid ? "PASSED" : "FAILED")")
            if let reason = validation.reason {
                print("[DeviceEnum]   Validation note: \(reason)")
            }

            if validation.valid {
                print("[DeviceEnum] ✓ ACCEPTED: Adding to device list")
            } else {
                print("[DeviceEnum] ⚠ ACCEPTED WITH WARNING: Device may not work properly")
            }

            devices.append(PhysicalDevice(
                id: deviceID,
                name: name,
                uid: uid,
                manufacturer: manufacturer,
                transportType: transportType,
                isOutput: true,
                validationPassed: validation.valid,
                validationNote: validation.reason
            ))
        }

        let validatedCount = devices.filter { $0.validationPassed }.count
        print("[DeviceEnum] ===== ENUMERATION COMPLETE: \(devices.count) devices accepted (\(validatedCount) validated) =====")
        return devices
    }

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

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr else {
            return nil
        }

        return deviceName as String
    }

    private func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr else {
            return nil
        }

        return deviceUID as String
    }

    private func getDeviceManufacturer(_ deviceID: AudioDeviceID) -> String {
        var mfgAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturerCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mfgName: CFString = "" as CFString
        var mfgSize = UInt32(MemoryLayout<CFString>.size)

        return AudioObjectGetPropertyData(deviceID, &mfgAddress, 0, nil, &mfgSize, &mfgName) == noErr
            ? mfgName as String
            : "Unknown"
    }

    private func getDeviceTransportType(_ deviceID: AudioDeviceID) -> UInt32? {
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transportType) == noErr else {
            return nil
        }

        return transportType
    }

    private func deviceHasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var streamSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0
    }

    /// Check if device has active output channels (not just streams that report existence)
    private func deviceHasActiveChannels(_ deviceID: AudioDeviceID) -> Bool {
        var configAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &configAddress, 0, nil, &dataSize) == noErr else {
            return false
        }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &configAddress, 0, nil, &dataSize, bufferListPointer) == noErr else {
            return false
        }

        let bufferList = bufferListPointer.pointee
        let bufferCount = Int(bufferList.mNumberBuffers)

        if bufferCount == 0 {
            return false
        }

        // Check if at least one buffer has channels
        let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        for buffer in buffers {
            if buffer.mNumberChannels > 0 {
                return true
            }
        }

        return false
    }

    /// Check jack connection status for HDMI/DisplayPort devices
    /// Returns true for non-applicable transport types (built-in, USB, etc.)
    private func isDeviceJackConnected(_ deviceID: AudioDeviceID, transportType: UInt32) -> Bool {
        // Only check jack status for display-based connections
        guard transportType == kAudioDeviceTransportTypeDisplayPort ||
              transportType == kAudioDeviceTransportTypeHDMI else {
            return true // Non-display devices don't need jack check
        }

        var jackAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyJackIsConnected,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // If property doesn't exist, assume connected (be permissive)
        guard AudioObjectHasProperty(deviceID, &jackAddress) else {
            return true
        }

        var isConnected: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(deviceID, &jackAddress, 0, nil, &dataSize, &isConnected) == noErr else {
            return true // If we can't read, assume connected
        }

        return isConnected != 0
    }

    /// Check if device supports the required audio format (48kHz, stereo, float32)
    private func deviceSupportsRequiredFormat(_ deviceID: AudioDeviceID) -> Bool {
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormats,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // If property doesn't exist, try nominal sample rate check instead
        guard AudioObjectHasProperty(deviceID, &formatAddress) else {
            return checkNominalSampleRate(deviceID)
        }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &formatAddress, 0, nil, &dataSize) == noErr else {
            return checkNominalSampleRate(deviceID)
        }

        let formatCount = Int(dataSize) / MemoryLayout<AudioStreamBasicDescription>.size
        guard formatCount > 0 else {
            return checkNominalSampleRate(deviceID)
        }

        var formats = [AudioStreamBasicDescription](repeating: AudioStreamBasicDescription(), count: formatCount)

        guard AudioObjectGetPropertyData(deviceID, &formatAddress, 0, nil, &dataSize, &formats) == noErr else {
            return checkNominalSampleRate(deviceID)
        }

        // Check for a compatible format
        for format in formats {
            // Accept if format supports stereo or more channels and reasonable sample rate
            if format.mChannelsPerFrame >= 2 &&
               format.mSampleRate >= 44100 && format.mSampleRate <= 192000 {
                return true
            }
        }

        // Fallback: check nominal sample rate
        return checkNominalSampleRate(deviceID)
    }

    private func checkNominalSampleRate(_ deviceID: AudioDeviceID) -> Bool {
        var rateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)

        guard AudioObjectGetPropertyData(deviceID, &rateAddress, 0, nil, &dataSize, &sampleRate) == noErr else {
            return true // If we can't read, be permissive
        }

        // Accept reasonable sample rates
        return sampleRate >= 44100 && sampleRate <= 192000
    }

    /// Combined validation that checks all criteria
    func validateDevice(_ deviceID: AudioDeviceID, transportType: UInt32) -> (valid: Bool, reason: String?) {
        // Check 1: Active channels
        if !deviceHasActiveChannels(deviceID) {
            return (false, "No active output channels")
        }

        // Check 2: Jack connection for HDMI/DisplayPort
        if !isDeviceJackConnected(deviceID, transportType: transportType) {
            return (false, "Jack not connected (display audio without speakers)")
        }

        // Check 3: Format support
        if !deviceSupportsRequiredFormat(deviceID) {
            return (false, "Unsupported audio format")
        }

        return (true, nil)
    }
}
