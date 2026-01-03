import Foundation
import CoreAudio

class DeviceMonitor {
    private let registry: DeviceRegistry
    private let proxyManager: ProxyDeviceManager
    private let memoryManager: SharedMemoryManager
    private let discovery: DeviceDiscovery

    init(
        registry: DeviceRegistry,
        proxyManager: ProxyDeviceManager,
        memoryManager: SharedMemoryManager,
        discovery: DeviceDiscovery
    ) {
        self.registry = registry
        self.proxyManager = proxyManager
        self.memoryManager = memoryManager
        self.discovery = discovery
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

        let addedDevices = registry.findAdded(comparing: oldDevices)
        let removedDevices = registry.findRemoved(comparing: oldDevices)

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
        } else {
            proxyManager.handlePhysicalSelection(uid)
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
