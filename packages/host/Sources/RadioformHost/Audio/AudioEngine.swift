import Foundation
import CoreAudio
import AudioToolbox

class AudioEngine {
    private let renderer: AudioRenderer
    private let registry: DeviceRegistry
    private var outputUnit: AudioUnit?
    private var currentDeviceID: AudioDeviceID?

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

        currentDeviceID = device.id

        print("    Using device ID: \(device.id)")
    }

    /// Cleanup after a failed setup attempt
    private func cleanupFailedSetup() {
        guard let unit = outputUnit else { return }
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        outputUnit = nil
        currentDeviceID = nil
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
        currentDeviceID = nil
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

        currentDeviceID = deviceID

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
            mSampleRate: Double(RadioformConfig.activeSampleRate),
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

        // Read back the actual format to confirm what the audio unit accepted.
        var actualFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let getStatus = AudioUnitGetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &actualFormat,
            &size
        )

        if getStatus == noErr {
            print("[AudioEngine] Stream format: \(actualFormat.mSampleRate) Hz, ch=\(actualFormat.mChannelsPerFrame), flags=0x\(String(actualFormat.mFormatFlags, radix: 16))")
        } else {
            print("[AudioEngine] WARNING: Failed to read back stream format (OSStatus: \(getStatus))")
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
