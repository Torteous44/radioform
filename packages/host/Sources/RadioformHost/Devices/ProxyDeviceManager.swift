import Foundation
import CoreAudio

class ProxyDeviceManager {
    private let registry: DeviceRegistry
    private var isAutoSwitching = false
    private var lastSwitchTime: Date = .distantPast
    private let switchCooldown: TimeInterval = 0.5
    private var monitoredProxyDeviceID: AudioDeviceID?
    private var monitoredVolumeElements: [UInt32] = []
    private let volumeForwardQueue = DispatchQueue(label: "com.radioform.host.proxy-volume-forward")
    private var lastForwardedProxyVolume: Float32?

    var activeProxyUID: String?
    var activePhysicalDeviceID: AudioDeviceID = 0
    var activeProxyDeviceID: AudioDeviceID = 0

    init(registry: DeviceRegistry) {
        self.registry = registry
    }

    deinit {
        stopVolumeForwarding()
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
            // If we're already on a proxy, make sure we map it to the physical device.
            if let physicalUID = uid.components(separatedBy: "-radioform").first,
               let physicalDevice = registry.find(uid: physicalUID) {
                activeProxyUID = physicalUID
                activePhysicalDeviceID = physicalDevice.id
                activeProxyDeviceID = currentDeviceID
                startVolumeForwarding(proxyDeviceID: currentDeviceID)
                forwardProxyVolumeToPhysical()
                print("[AutoSelect] Already on proxy device - mapped to \(physicalDevice.name)")
            } else {
                print("[AutoSelect] Already on proxy device - but no physical mapping found")
            }
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
            startVolumeForwarding(proxyDeviceID: proxyID)
            forwardProxyVolumeToPhysical()
        } else {
            print("[AutoSelect] ERROR: Failed to set proxy as default")
            isAutoSwitching = false
        }
    }

    /// Resolve the current output device to a physical device, if possible.
    /// If current output is a proxy, this also updates activeProxy* state.
    func resolveCurrentOutputDevice(in devices: [PhysicalDevice]) -> PhysicalDevice? {
        guard let currentDeviceID = getCurrentDefaultDevice(),
              let uid = getDeviceUID(currentDeviceID),
              let name = getDeviceName(currentDeviceID) else {
            return nil
        }

        if name.contains("Radioform") {
            if let physicalUID = uid.components(separatedBy: "-radioform").first,
               let physicalDevice = devices.first(where: { $0.uid == physicalUID }) {
                activeProxyUID = physicalUID
                activePhysicalDeviceID = physicalDevice.id
                activeProxyDeviceID = currentDeviceID
                return physicalDevice
            }
            return nil
        }

        return devices.first(where: { $0.uid == uid })
    }

    func handleProxySelection(_ proxyUID: String, deviceID: AudioDeviceID) {
        if let physicalUID = proxyUID.components(separatedBy: "-radioform").first,
           let physicalDevice = registry.find(uid: physicalUID) {
            print("Routing to: \(physicalDevice.name)")

            activeProxyUID = physicalUID
            activePhysicalDeviceID = physicalDevice.id
            activeProxyDeviceID = deviceID
            startVolumeForwarding(proxyDeviceID: deviceID)
            forwardProxyVolumeToPhysical()
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

        guard !isAutoSwitching else { return }

        guard let physicalDevice = registry.find(uid: physicalUID) else {
            stopVolumeForwarding()
            return
        }

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
            startVolumeForwarding(proxyDeviceID: proxyID)
            forwardProxyVolumeToPhysical(force: true)
        } else {
            stopVolumeForwarding()
            print("Warning: No proxy found for this device")
        }
        // Note: isAutoSwitching is reset in handleProxySelection after delay
    }

    func restorePhysicalDevice() -> Bool {
        stopVolumeForwarding()

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

    private func startVolumeForwarding(proxyDeviceID: AudioDeviceID) {
        if monitoredProxyDeviceID == proxyDeviceID {
            return
        }

        stopVolumeForwarding()
        monitoredProxyDeviceID = proxyDeviceID
        monitoredVolumeElements.removeAll(keepingCapacity: true)
        lastForwardedProxyVolume = nil

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Prefer a single master listener to avoid duplicate callback bursts.
        if AudioObjectHasProperty(proxyDeviceID, &address) {
            let status = AudioObjectAddPropertyListener(proxyDeviceID, &address, proxyVolumeChangedCallback, selfPtr)
            if status == noErr {
                monitoredVolumeElements.append(kAudioObjectPropertyElementMain)
            } else {
                print("[VolumeForward] Failed to add master listener (OSStatus: \(status))")
            }
        }

        // Fallback to channel listeners only when master is unavailable.
        if monitoredVolumeElements.isEmpty {
            for channel: UInt32 in 1...2 {
                address.mElement = channel
                guard AudioObjectHasProperty(proxyDeviceID, &address) else { continue }
                let status = AudioObjectAddPropertyListener(proxyDeviceID, &address, proxyVolumeChangedCallback, selfPtr)
                if status == noErr {
                    monitoredVolumeElements.append(channel)
                } else {
                    print("[VolumeForward] Failed to add listener for channel \(channel) (OSStatus: \(status))")
                }
            }
        }

        if monitoredVolumeElements.isEmpty {
            monitoredProxyDeviceID = nil
            print("[VolumeForward] WARNING: No volume listener registered for proxy device \(proxyDeviceID)")
        }
    }

    private func stopVolumeForwarding() {
        guard let proxyDeviceID = monitoredProxyDeviceID else { return }
        defer {
            monitoredProxyDeviceID = nil
            monitoredVolumeElements.removeAll(keepingCapacity: false)
            lastForwardedProxyVolume = nil
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for element in monitoredVolumeElements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            let status = AudioObjectRemovePropertyListener(proxyDeviceID, &address, proxyVolumeChangedCallback, selfPtr)
            if status != noErr {
                print("[VolumeForward] Failed to remove listener for element \(element) (OSStatus: \(status))")
            }
        }
    }

    fileprivate func handleProxyVolumeChanged(from objectID: AudioObjectID) {
        guard monitoredProxyDeviceID == objectID, activeProxyDeviceID == objectID else {
            return
        }

        volumeForwardQueue.async { [weak self] in
            guard let self else { return }
            guard self.monitoredProxyDeviceID == objectID, self.activeProxyDeviceID == objectID else {
                return
            }
            self.forwardProxyVolumeToPhysical()
        }
    }

    fileprivate func forwardProxyVolumeToPhysical(force: Bool = false) {
        guard activeProxyDeviceID != 0, activePhysicalDeviceID != 0 else {
            return
        }

        guard let proxyVolume = getDeviceVolume(activeProxyDeviceID) else {
            return
        }

        if !force, let lastForwardedProxyVolume, abs(proxyVolume - lastForwardedProxyVolume) < 0.001 {
            return
        }

        lastForwardedProxyVolume = proxyVolume
        _ = setDeviceVolume(activePhysicalDeviceID, volume: proxyVolume)
    }
}

private func proxyVolumeChangedCallback(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    let manager = Unmanaged<ProxyDeviceManager>.fromOpaque(clientData).takeUnretainedValue()
    manager.handleProxyVolumeChanged(from: objectID)
    return noErr
}
