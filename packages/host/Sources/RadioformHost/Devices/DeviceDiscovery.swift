import Foundation
import CoreAudio

struct PhysicalDevice {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let manufacturer: String
    let transportType: UInt32
    let isOutput: Bool
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
}
