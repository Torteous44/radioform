import Foundation
import CoreAudio

class ProxyDeviceManager {
    private let registry: DeviceRegistry
    private var isAutoSwitching = false
    private var lastSwitchTime: Date = .distantPast
    private let switchCooldown: TimeInterval = 0.5

    var activeProxyUID: String?
    var activePhysicalDeviceID: AudioDeviceID = 0
    var activeProxyDeviceID: AudioDeviceID = 0

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

        // Capture physical volume and sync to proxy BEFORE switching
        let originalVolume = getDeviceVolume(currentDeviceID)
        if let volume = originalVolume {
            print("[AutoSelect] Physical device volume: \(String(format: "%.0f%%", volume * 100))")
            if setDeviceVolume(proxyID, volume: volume) {
                print("[AutoSelect] ✓ Set proxy volume to \(String(format: "%.0f%%", volume * 100))")
            }
        }

        print("[AutoSelect] Switching to proxy device...")
        isAutoSwitching = true
        lastSwitchTime = Date()
        if setDefaultOutputDevice(proxyID) {
            print("[AutoSelect] ✓ Successfully switched to proxy")
            activeProxyUID = uid
            activePhysicalDeviceID = currentDeviceID
            activeProxyDeviceID = proxyID
        } else {
            print("[AutoSelect] ERROR: Failed to set proxy as default")
            isAutoSwitching = false
        }
    }

    func handleProxySelection(_ proxyUID: String, deviceID: AudioDeviceID) {
        if let physicalUID = proxyUID.components(separatedBy: "-radioform").first,
           let physicalDevice = registry.find(uid: physicalUID) {
            print("Routing to: \(physicalDevice.name)")

            activeProxyUID = physicalUID
            activePhysicalDeviceID = physicalDevice.id
            activeProxyDeviceID = deviceID
        }

        // Delay resetting the flag to prevent race conditions with rapid callbacks
        DispatchQueue.main.asyncAfter(deadline: .now() + switchCooldown) { [weak self] in
            self?.isAutoSwitching = false
        }
    }

    func handlePhysicalSelection(_ physicalUID: String) {
        // Prevent rapid re-triggering
        let now = Date()
        guard now.timeIntervalSince(lastSwitchTime) > switchCooldown else {
            return
        }

        if !isAutoSwitching, let physicalDevice = registry.find(uid: physicalUID) {
            if let proxyID = findProxyDevice(forPhysicalUID: physicalUID) {
                // Sync volume before switching
                if let volume = getDeviceVolume(physicalDevice.id) {
                    _ = setDeviceVolume(proxyID, volume: volume)
                }

                print("Auto-switching to Radioform proxy")
                isAutoSwitching = true
                lastSwitchTime = now
                _ = setDefaultOutputDevice(proxyID)
                activeProxyDeviceID = proxyID
            } else {
                print("Warning: No proxy found for this device")
            }
        }
        // Note: isAutoSwitching is reset in handleProxySelection after delay
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

    private func getDeviceVolume(_ deviceID: AudioDeviceID) -> Float32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Try getting master volume
        if AudioObjectHasProperty(deviceID, &address) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                &volume
            )
            if status == noErr {
                return volume
            }
        }

        // Try getting channel 1 volume (left channel)
        address.mElement = 1
        if AudioObjectHasProperty(deviceID, &address) {
            var volume: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                &volume
            )
            if status == noErr {
                return volume
            }
        }

        return nil
    }

    private func setDeviceVolume(_ deviceID: AudioDeviceID, volume: Float32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Try setting master volume
        if AudioObjectHasProperty(deviceID, &address) {
            var vol = volume
            let status = AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &vol
            )
            if status == noErr {
                return true
            }
        }

        // Try setting per-channel volume (channel 1 and 2) if master failed
        var channelSet = false
        for channel: UInt32 in 1...2 {
            address.mElement = channel
            if AudioObjectHasProperty(deviceID, &address) {
                var vol = volume
                let status = AudioObjectSetPropertyData(
                    deviceID,
                    &address,
                    0,
                    nil,
                    UInt32(MemoryLayout<Float32>.size),
                    &vol
                )
                if status == noErr {
                    channelSet = true
                }
            }
        }

        return channelSet
    }
}
