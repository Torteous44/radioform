import Foundation
import CoreAudio

class DeviceMonitor {
    private let registry: DeviceRegistry
    private let proxyManager: ProxyDeviceManager
    private let memoryManager: SharedMemoryManager
    private let discovery: DeviceDiscovery
    private let audioEngine: AudioEngine
    private var lastHandledDeviceID: AudioDeviceID = 0
    private var lastHandledTime: Date = .distantPast
    private let callbackDebounce: TimeInterval = 0.3
    private var listenersRegistered = false
    private var devicesListenerRegistered = false
    private var defaultOutputListenerRegistered = false

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
        guard !listenersRegistered else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let devicesStatus = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            deviceListChangedCallbackC,
            selfPtr
        )
        devicesListenerRegistered = (devicesStatus == noErr)
        if devicesStatus != noErr {
            print("[DeviceMonitor] ERROR: Failed to register devices listener (\(devicesStatus))")
        }

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let outputStatus = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            defaultOutputChangedCallbackC,
            selfPtr
        )
        defaultOutputListenerRegistered = (outputStatus == noErr)
        if outputStatus != noErr {
            print("[DeviceMonitor] ERROR: Failed to register default output listener (\(outputStatus))")
        }

        listenersRegistered = devicesListenerRegistered && defaultOutputListenerRegistered
    }

    private func removeListeners() {
        guard devicesListenerRegistered || defaultOutputListenerRegistered else { return }
        listenersRegistered = false

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if devicesListenerRegistered {
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesAddress,
                deviceListChangedCallbackC,
                selfPtr
            )
            devicesListenerRegistered = false
        }

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if defaultOutputListenerRegistered {
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultOutputAddress,
                defaultOutputChangedCallbackC,
                selfPtr
            )
            defaultOutputListenerRegistered = false
        }
    }

    func reregisterListeners() {
        removeListeners()
        registerListeners()
        print("[DeviceMonitor] Listeners re-registered after wake")
    }

    func resetDebounce() {
        lastHandledDeviceID = 0
        lastHandledTime = .distantPast
    }

    fileprivate func handleDeviceListChanged() {
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

    fileprivate func handleDefaultOutputChanged() {
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

        // Debounce: skip if same device within cooldown period
        let now = Date()
        if deviceID == lastHandledDeviceID && now.timeIntervalSince(lastHandledTime) < callbackDebounce {
            return
        }
        lastHandledDeviceID = deviceID
        lastHandledTime = now

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

// File-level C callbacks — stable function pointers required for AudioObjectRemovePropertyListener.
// AudioObjectPropertyListenerProc requires non-optional UnsafePointer<AudioObjectPropertyAddress>.
private func deviceListChangedCallbackC(
    _ objectID: AudioObjectID,
    _ numAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<DeviceMonitor>.fromOpaque(clientData).takeUnretainedValue()
        .handleDeviceListChanged()
    return noErr
}

private func defaultOutputChangedCallbackC(
    _ objectID: AudioObjectID,
    _ numAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    Unmanaged<DeviceMonitor>.fromOpaque(clientData).takeUnretainedValue()
        .handleDefaultOutputChanged()
    return noErr
}
