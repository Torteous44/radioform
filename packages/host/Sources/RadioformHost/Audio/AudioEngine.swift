import Foundation
import CoreAudio
import AudioToolbox

class AudioEngine {
    private let renderer: AudioRenderer
    private let registry: DeviceRegistry
    private var outputUnit: AudioUnit?

    init(renderer: AudioRenderer, registry: DeviceRegistry) {
        self.renderer = renderer
        self.registry = registry
    }

    /// Setup with device fallback - tries preferred device first, then validated devices
    func setup(devices: [PhysicalDevice], preferredDeviceID: AudioDeviceID? = nil) throws {
        guard !devices.isEmpty else {
            throw AudioEngineError.noPhysicalDeviceFound
        }

        var lastError: AudioEngineError?

        // Try preferred device FIRST if specified
        if let preferredID = preferredDeviceID,
           let preferredDevice = devices.first(where: { $0.id == preferredID }) {
            let validationStatus = preferredDevice.validationPassed ? "✓" : "⚠"
            print("[AudioEngine] Trying preferred device: \(preferredDevice.name) \(validationStatus)")

            if !preferredDevice.validationPassed {
                print("[AudioEngine]   Warning: \(preferredDevice.validationNote ?? "Device may not work properly")")
            }

            do {
                try setupWithDevice(preferredDevice)
                print("[AudioEngine] ✓ Successfully bound to preferred device: \(preferredDevice.name)")
                return
            } catch let error as AudioEngineError {
                print("[AudioEngine] ✗ Preferred device failed: \(error)")
                print("[AudioEngine] Falling back to other devices...")
                lastError = error
                cleanupFailedSetup()
            }
        }

        // Sort remaining devices: validated first, then by original order
        let remainingDevices = devices.filter { $0.id != preferredDeviceID }
        let sortedDevices = remainingDevices.sorted { d1, d2 in
            if d1.validationPassed && !d2.validationPassed { return true }
            if !d1.validationPassed && d2.validationPassed { return false }
            return false // Maintain original order within same validation status
        }

        let validatedCount = sortedDevices.filter { $0.validationPassed }.count
        print("[AudioEngine] Attempting fallback with \(sortedDevices.count) devices (\(validatedCount) validated)")

        for (index, device) in sortedDevices.enumerated() {
            let validationStatus = device.validationPassed ? "✓" : "⚠"
            print("[AudioEngine] [\(index + 1)/\(sortedDevices.count)] Trying: \(device.name) \(validationStatus)")

            if !device.validationPassed {
                print("[AudioEngine]   Warning: \(device.validationNote ?? "Device may not work properly")")
            }

            do {
                try setupWithDevice(device)
                print("[AudioEngine] ✓ Successfully bound to: \(device.name)")
                return
            } catch let error as AudioEngineError {
                print("[AudioEngine] ✗ Failed: \(error)")
                lastError = error
                cleanupFailedSetup()
            }
        }

        // All devices failed
        throw lastError ?? AudioEngineError.allDevicesFailed
    }

    /// Legacy setup method - uses registry
    func setup() throws {
        try setup(devices: registry.devices)
    }

    /// Attempt setup with a specific device
    private func setupWithDevice(_ device: PhysicalDevice) throws {
        var componentDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &componentDesc) else {
            throw AudioEngineError.componentNotFound
        }

        var unit: AudioUnit?
        let status = AudioComponentInstanceNew(component, &unit)
        guard status == noErr, let audioUnit = unit else {
            throw AudioEngineError.instanceCreationFailed(status)
        }

        outputUnit = audioUnit

        try setOutputDevice(device.id)
        try setFormat()
        try setRenderCallback()
        try initialize()

        // VOLUME CONTROL ARCHITECTURE:
        // macOS pre-Radioform: User controls physical device volume (0-100%)
        // macOS with Radioform: Physical device locked at 100%, Radioform driver controls volume
        //
        // This gives Radioform full dynamic range to work with. The user controls volume
        // through the Radioform virtual device (via menu bar app), which applies DSP-based
        // volume control with the full bit depth of the audio signal.
        setPhysicalDeviceVolume(device.id, volume: 1.0)

        print("    Using device ID: \(device.id)")
        print("    Physical device set to 100% (Radioform driver controls volume)")
    }

    /// Cleanup after a failed setup attempt
    private func cleanupFailedSetup() {
        guard let unit = outputUnit else { return }
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        outputUnit = nil
    }

    func start() throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        let status = AudioOutputUnitStart(unit)
        guard status == noErr else {
            throw AudioEngineError.startFailed(status)
        }
    }

    func stop() {
        guard let unit = outputUnit else { return }

        print("[Cleanup] Stopping audio unit...")
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        outputUnit = nil
    }

    func switchDevice(_ deviceID: AudioDeviceID) throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let wasRunning = AudioUnitGetProperty(
            unit,
            kAudioOutputUnitProperty_IsRunning,
            kAudioUnitScope_Global,
            0,
            &isRunning,
            &size
        ) == noErr && isRunning != 0

        if wasRunning {
            AudioOutputUnitStop(unit)
        }

        var newDeviceID = deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &newDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw AudioEngineError.deviceSwitchFailed(status)
        }

        if wasRunning {
            AudioOutputUnitStart(unit)
        }
    }

    private func setOutputDevice(_ deviceID: AudioDeviceID) throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        var newDeviceID = deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &newDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw AudioEngineError.setDeviceFailed(status)
        }
    }

    private func setFormat() throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        var format = AudioStreamBasicDescription(
            mSampleRate: Double(RadioformConfig.defaultSampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: RadioformConfig.defaultChannels,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        let status = AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &format,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )

        guard status == noErr else {
            throw AudioEngineError.setFormatFailed(status)
        }
    }

    private func setRenderCallback() throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        let rendererPtr = Unmanaged.passUnretained(renderer).toOpaque()

        var callbackStruct = AURenderCallbackStruct(
            inputProc: renderer.createRenderCallback(),
            inputProcRefCon: rendererPtr
        )

        let status = AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )

        guard status == noErr else {
            throw AudioEngineError.setCallbackFailed(status)
        }
    }

    private func initialize() throws {
        guard let unit = outputUnit else {
            throw AudioEngineError.unitNotInitialized
        }

        let status = AudioUnitInitialize(unit)
        guard status == noErr else {
            throw AudioEngineError.initializationFailed(status)
        }
    }

    private func getPhysicalDeviceVolume(_ deviceID: AudioDeviceID) -> Float32? {
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

    /// Sets the physical audio device volume to maximize Radioform's dynamic range control.
    ///
    /// Volume Control Architecture:
    /// - **Before Radioform**: User adjusts physical device volume (0-100%) via System Settings
    /// - **With Radioform**: Physical device locked at 100%, user controls Radioform virtual device
    ///
    /// This approach ensures:
    /// 1. Maximum dynamic range - no signal degradation from reduced hardware volume
    /// 2. Consistent audio quality - DSP operates on full-resolution signal
    /// 3. Single control point - users adjust volume via Radioform driver in Sound settings
    ///
    /// If the device cannot reach 95%+ volume, a warning is displayed as the max volume
    /// will be limited by the physical device's maximum.
    private func setPhysicalDeviceVolume(_ deviceID: AudioDeviceID, volume: Float32) {
        // Read initial volume for comparison
        let initialVolume = getPhysicalDeviceVolume(deviceID)
        if let initial = initialVolume {
            print("    Physical device initial volume: \(String(format: "%.0f%%", initial * 100))")
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volumeSet = false

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
                print("    Set physical device master volume to \(String(format: "%.0f%%", volume * 100))")
                volumeSet = true
            }
        }

        // Try setting per-channel volume (channel 1 and 2) if master failed
        if !volumeSet {
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
                        print("    Set physical device channel \(channel) volume to \(String(format: "%.0f%%", volume * 100))")
                        volumeSet = true
                    }
                }
            }
        }

        // Verify the volume was actually set
        let finalVolume = getPhysicalDeviceVolume(deviceID)
        if let final = finalVolume {
            if final < 0.95 {
                // Volume didn't reach near 100%
                print("    ⚠ WARNING: Physical device volume is \(String(format: "%.0f%%", final * 100))")
                print("    ⚠ This device may not support software volume control.")
                print("    ⚠ Maximum effective volume will be limited to \(String(format: "%.0f%%", final * 100))")
            }
        } else if !volumeSet {
            print("    ⚠ WARNING: Could not set or verify physical device volume.")
            print("    ⚠ This device may not support software volume control.")
        }
    }
}

enum AudioEngineError: Error, CustomStringConvertible {
    case componentNotFound
    case instanceCreationFailed(OSStatus)
    case unitNotInitialized
    case setDeviceFailed(OSStatus)
    case setFormatFailed(OSStatus)
    case setCallbackFailed(OSStatus)
    case initializationFailed(OSStatus)
    case startFailed(OSStatus)
    case deviceSwitchFailed(OSStatus)
    case noPhysicalDeviceFound
    case noValidDeviceFound
    case allDevicesFailed

    var description: String {
        switch self {
        case .componentNotFound:
            return "HAL output component not found"
        case .instanceCreationFailed(let status):
            return "Failed to create audio unit instance (OSStatus: \(status))"
        case .unitNotInitialized:
            return "Audio unit not initialized"
        case .setDeviceFailed(let status):
            return "Failed to set output device (OSStatus: \(status))"
        case .setFormatFailed(let status):
            return "Failed to set stream format (OSStatus: \(status))"
        case .setCallbackFailed(let status):
            return "Failed to set render callback (OSStatus: \(status))"
        case .initializationFailed(let status):
            return "Failed to initialize audio unit (OSStatus: \(status))"
        case .startFailed(let status):
            return "Failed to start audio unit (OSStatus: \(status))"
        case .deviceSwitchFailed(let status):
            return "Failed to switch device (OSStatus: \(status))"
        case .noPhysicalDeviceFound:
            return "No physical output device found in registry"
        case .noValidDeviceFound:
            return "No validated output devices available"
        case .allDevicesFailed:
            return "All available devices failed to initialize"
        }
    }
}
