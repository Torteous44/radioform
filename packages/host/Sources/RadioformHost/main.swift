import Foundation
import CoreAudio
import AudioToolbox
import CRadioformAudio

// Shared memory file path
let SHM_FILE_PATH = "/tmp/radioform-audio-v1"
let RING_CAPACITY_FRAMES: UInt32 = 1440

// Global shared memory pointer
var sharedMemory: UnsafeMutablePointer<RFSharedAudioV1>?

// Create shared memory file (host creates, driver opens)
func createSharedMemory() -> Bool {
    // Remove any existing file
    unlink(SHM_FILE_PATH)

    // Create new shared memory file with world read/write permissions
    let fd = open(SHM_FILE_PATH, O_CREAT | O_RDWR, 0666)
    guard fd >= 0 else {
        print("Failed to create shared memory file: \(String(cString: strerror(errno)))")
        return false
    }

    // Explicitly set permissions (umask may interfere)
    fchmod(fd, 0o666)

    let shmSize = rf_shared_audio_size(RING_CAPACITY_FRAMES)

    // Set size
    guard ftruncate(fd, Int64(shmSize)) == 0 else {
        print("Failed to set file size: \(String(cString: strerror(errno)))")
        close(fd)
        return false
    }

    // Map memory
    let mem = mmap(nil, shmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
    close(fd)

    guard mem != MAP_FAILED else {
        print("Failed to map shared memory: \(String(cString: strerror(errno)))")
        return false
    }

    sharedMemory = mem!.assumingMemoryBound(to: RFSharedAudioV1.self)

    // Initialize the shared memory structure
    rf_shared_audio_init(sharedMemory, RING_CAPACITY_FRAMES)

    print("✓ Created shared memory file: \(SHM_FILE_PATH)")
    return true
}

// Find first physical output device
func findPhysicalDevice() -> AudioDeviceID {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize
    )

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    )

    // Find first output device that's not Radioform
    for deviceID in deviceIDs {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr {
            let name = deviceName as String
            if !name.contains("Radioform") && !name.contains("eqMac") {
                // Check if it has output channels
                var streamAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyStreams,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )

                var streamSize: UInt32 = 0
                if AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr,
                   streamSize > 0 {
                    print("✓ Using output device: \(name) (ID: \(deviceID))")
                    return deviceID
                }
            }
        }
    }

    print("⚠ No physical output device found")
    return 0
}

// Audio render callback - reads from ring buffer and outputs to device
let renderCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    guard let sharedMem = sharedMemory else { return noErr }
    guard let bufferList = ioData else { return noErr }

    // Read interleaved audio from ring buffer
    var tempBuffer = [Float](repeating: 0, count: Int(inNumberFrames) * 2)
    let framesRead = rf_ring_read(sharedMem, &tempBuffer, inNumberFrames)

    // Deinterleave to output buffers (left/right channels)
    let leftBuffer = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
    let rightBuffer = UnsafeMutableAudioBufferListPointer(bufferList)[1].mData!.assumingMemoryBound(to: Float.self)

    for i in 0..<Int(framesRead) {
        leftBuffer[i] = tempBuffer[i * 2]
        rightBuffer[i] = tempBuffer[i * 2 + 1]
    }

    // Zero out remaining frames if underrun
    for i in Int(framesRead)..<Int(inNumberFrames) {
        leftBuffer[i] = 0
        rightBuffer[i] = 0
    }

    return noErr
}

// Main
print("Radioform Host v2.0")
print("===================")

// 1. Create shared memory file (driver will open it)
guard createSharedMemory() else {
    exit(1)
}

// 2. Find physical output device
let outputDeviceID = findPhysicalDevice()
guard outputDeviceID != 0 else {
    exit(1)
}

// 3. Create audio unit
var outputUnit: AudioUnit?
var componentDesc = AudioComponentDescription(
    componentType: kAudioUnitType_Output,
    componentSubType: kAudioUnitSubType_HALOutput,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0,
    componentFlagsMask: 0
)

guard let component = AudioComponentFindNext(nil, &componentDesc) else {
    print("Failed to find output component")
    exit(1)
}

var status = AudioComponentInstanceNew(component, &outputUnit)
guard status == noErr, let unit = outputUnit else {
    print("Failed to create audio unit")
    exit(1)
}

// 4. Set output device
var deviceID = outputDeviceID
status = AudioUnitSetProperty(
    unit,
    kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global,
    0,
    &deviceID,
    UInt32(MemoryLayout<AudioDeviceID>.size)
)

guard status == noErr else {
    print("Failed to set output device")
    exit(1)
}

// 5. Set format (48kHz stereo float32 non-interleaved)
var format = AudioStreamBasicDescription(
    mSampleRate: 48000.0,
    mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
    mBytesPerPacket: 4,
    mFramesPerPacket: 1,
    mBytesPerFrame: 4,
    mChannelsPerFrame: 2,
    mBitsPerChannel: 32,
    mReserved: 0
)

status = AudioUnitSetProperty(
    unit,
    kAudioUnitProperty_StreamFormat,
    kAudioUnitScope_Input,
    0,
    &format,
    UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
)

guard status == noErr else {
    print("Failed to set format")
    exit(1)
}

// 6. Set render callback
var callbackStruct = AURenderCallbackStruct(
    inputProc: renderCallback,
    inputProcRefCon: nil
)

status = AudioUnitSetProperty(
    unit,
    kAudioUnitProperty_SetRenderCallback,
    kAudioUnitScope_Input,
    0,
    &callbackStruct,
    UInt32(MemoryLayout<AURenderCallbackStruct>.size)
)

guard status == noErr else {
    print("Failed to set render callback")
    exit(1)
}

// 7. Initialize and start
status = AudioUnitInitialize(unit)
guard status == noErr else {
    print("Failed to initialize audio unit")
    exit(1)
}

status = AudioOutputUnitStart(unit)
guard status == noErr else {
    print("Failed to start audio unit")
    exit(1)
}

print("✓ Host running - reading from shared memory and outputting to device")
print("Press Ctrl+C to stop...")

// Keep running
signal(SIGINT) { _ in
    print("\nStopping...")
    if let unit = outputUnit {
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
    }
    if let mem = sharedMemory {
        munmap(mem, rf_shared_audio_size(RING_CAPACITY_FRAMES))
    }
    exit(0)
}

RunLoop.current.run()
