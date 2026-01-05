import Foundation
import CoreAudio

class DeviceMonitor {
    private let registry: DeviceRegistry
    private let proxyManager: ProxyDeviceManager
    private let memoryManager: SharedMemoryManager
    private let discovery: DeviceDiscovery
    private let audioEngine: AudioEngine

    init(
        registry: DeviceRegistry,
        proxyManager: ProxyDeviceManager,
        memoryManager: SharedMemoryManager,
        discovery: DeviceDiscovery,
        audioEngine: AudioEngine
    ) {
        self.registry = registry
        self.proxyManager = proxyManager
        self.memoryManager = memoryManager
        self.discovery = discovery
        self.audioEngine = audioEngine
    }

    func registerListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let deviceListCallback: AudioObjectPropertyListenerProc = { _, _, _, clientData in
            guard let clientData = clientData else { return noErr }
            let monitor = Unmanaged<DeviceMonitor>.fromOpaque(clientData).takeUnretainedValue()
            monitor.handleDeviceListChanged()
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            deviceListCallback,
            selfPtr
        )

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultOutputCallback: AudioObjectPropertyListenerProc = { _, _, _, clientData in
            guard let clientData = clientData else { return noErr }
            let monitor = Unmanaged<DeviceMonitor>.fromOpaque(clientData).takeUnretainedValue()
            monitor.handleDefaultOutputChanged()
            return noErr
        }

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            defaultOutputCallback,
            selfPtr
        )
    }

    private func handleDeviceListChanged() {
        let oldDevices = registry.devices
        let newDevices = discovery.enumeratePhysicalDevices()

        let addedDevices = newDevices.filter { new in
            !oldDevices.contains { $0.uid == new.uid }
        }
        let removedDevices = oldDevices.filter { old in
            !newDevices.contains { $0.uid == old.uid }
        }

        for device in addedDevices {
            print("Device added: \(device.name) (\(discovery.transportTypeName(device.transportType)))")
            _ = memoryManager.createMemory(for: device.uid)
        }

        for device in removedDevices {
            print("Device removed: \(device.name) (\(discovery.transportTypeName(device.transportType)))")
            memoryManager.removeMemory(for: device.uid)
        }

        registry.update(newDevices)

        if !addedDevices.isEmpty || !removedDevices.isEmpty {
            reloadDriver()
        }
    }

    private func handleDefaultOutputChanged() {
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
            return
        }

        guard let name = getDeviceName(deviceID),
              let uid = getDeviceUID(deviceID) else {
            return
        }

        print("Default output changed: \(name)")

        if name.contains("Radioform") {
            proxyManager.handleProxySelection(uid, deviceID: deviceID)

            let targetID = proxyManager.activePhysicalDeviceID
            if targetID != 0 {
                do {
                    try audioEngine.switchDevice(targetID)
                } catch {
                    print("Failed to switch audio engine device: \(error)")
                }
            } else {
                print("Warning: No active physical device mapped for proxy \(uid)")
            }
        } else {
            proxyManager.handlePhysicalSelection(uid)

            if let physical = registry.find(uid: uid) {
                do {
                    try audioEngine.switchDevice(physical.id)
                } catch {
                    print("Failed to switch audio engine device: \(error)")
                }
            }
        }
    }

    private func reloadDriver() {
        print("Driver reload required - restart coreaudiod with: sudo killall coreaudiod")
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
}
