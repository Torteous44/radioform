import Foundation
import CoreAudio

class ProxyDeviceManager {
    private let registry: DeviceRegistry
    private var isAutoSwitching = false

    var activeProxyUID: String?
    var activePhysicalDeviceID: AudioDeviceID = 0

    init(registry: DeviceRegistry) {
        self.registry = registry
    }

    func findProxyDevice(forPhysicalUID physicalUID: String) -> AudioDeviceID? {
        let proxyUID = physicalUID + "-radioform"

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

        for deviceID in deviceIDs {
            if let uid = getDeviceUID(deviceID), uid == proxyUID {
                return deviceID
            }
        }

        return nil
    }

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

    func autoSelectProxy() {
        guard let currentDeviceID = getCurrentDefaultDevice() else {
            print("[AutoSelect] ERROR: Could not get current default device")
            return
        }

        guard let uid = getDeviceUID(currentDeviceID),
              let name = getDeviceName(currentDeviceID) else {
            print("[AutoSelect] ERROR: Could not get device info")
            return
        }

        print("[AutoSelect] Current default device: \(name) (\(uid))")

        if name.contains("Radioform") {
            print("[AutoSelect] Already on proxy device - no action needed")
            return
        }

        guard registry.find(uid: uid) != nil else {
            print("[AutoSelect] Current device not in registry - no proxy available")
            return
        }

        guard let proxyID = findProxyDevice(forPhysicalUID: uid) else {
            print("[AutoSelect] WARNING: Could not find proxy for device: \(name)")
            return
        }

        print("[AutoSelect] Switching to proxy device...")
        if setDefaultOutputDevice(proxyID) {
            print("[AutoSelect] ✓ Successfully switched to proxy")
            activeProxyUID = uid
            activePhysicalDeviceID = currentDeviceID
        } else {
            print("[AutoSelect] ERROR: Failed to set proxy as default")
        }
    }

    func handleProxySelection(_ proxyUID: String, deviceID: AudioDeviceID) {
        if let physicalUID = proxyUID.components(separatedBy: "-radioform").first,
           let physicalDevice = registry.find(uid: physicalUID) {
            print("Routing to: \(physicalDevice.name)")

            activeProxyUID = physicalUID
            activePhysicalDeviceID = physicalDevice.id
        }

        isAutoSwitching = false
    }

    func handlePhysicalSelection(_ physicalUID: String) {
        if !isAutoSwitching && registry.find(uid: physicalUID) != nil {
            if let proxyID = findProxyDevice(forPhysicalUID: physicalUID) {
                print("Auto-switching to Radioform proxy")
                isAutoSwitching = true
                _ = setDefaultOutputDevice(proxyID)
            } else {
                print("Warning: No proxy found for this device")
            }
        } else {
            isAutoSwitching = false
        }
    }

    func restorePhysicalDevice() -> Bool {
        guard let currentDeviceID = getCurrentDefaultDevice(),
              let name = getDeviceName(currentDeviceID),
              name.contains("Radioform") else {
            return false
        }

        guard let proxyUID = getDeviceUID(currentDeviceID),
              let physicalUID = proxyUID.components(separatedBy: "-radioform").first,
              let physicalDevice = registry.find(uid: physicalUID) else {
            return false
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

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
            Thread.sleep(forTimeInterval: RadioformConfig.physicalDeviceSwitchDelay)
            return true
        }

        return false
    }

    private func getCurrentDefaultDevice() -> AudioDeviceID? {
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
            return nil
        }

        return deviceID
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
}
