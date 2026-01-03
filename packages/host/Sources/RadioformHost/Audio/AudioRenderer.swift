import Foundation
import CoreAudio
import AudioToolbox
import CRadioformAudio

class AudioRenderer {
    private let memoryManager: SharedMemoryManager
    private let dspProcessor: DSPProcessor
    private let proxyManager: ProxyDeviceManager

    init(
        memoryManager: SharedMemoryManager,
        dspProcessor: DSPProcessor,
        proxyManager: ProxyDeviceManager
    ) {
        self.memoryManager = memoryManager
        self.dspProcessor = dspProcessor
        self.proxyManager = proxyManager
    }

    func createRenderCallback() -> AURenderCallback {
        return { (
            inRefCon,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            ioData
        ) -> OSStatus in
            guard let bufferList = ioData else {
                return noErr
            }

            let renderer = Unmanaged<AudioRenderer>.fromOpaque(inRefCon).takeUnretainedValue()
            renderer.render(bufferList: bufferList, frameCount: inNumberFrames)

            return noErr
        }
    }

    private func render(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) {
        let sharedMem: UnsafeMutablePointer<RFSharedAudioV2>?

        if let activeUID = proxyManager.activeProxyUID {
            sharedMem = memoryManager.getMemory(for: activeUID)
        } else {
            sharedMem = memoryManager.getFirstMemory()
        }

        guard let mem = sharedMem else {
            outputSilence(bufferList: bufferList, frameCount: frameCount)
            return
        }

        var tempBuffer = [Float](repeating: 0, count: Int(frameCount) * 2)
        let framesRead = rf_ring_read_v2(mem, &tempBuffer, frameCount)

        dspProcessor.processInterleaved(tempBuffer, output: &tempBuffer, frameCount: frameCount)

        deinterleave(
            source: tempBuffer,
            bufferList: bufferList,
            framesRead: framesRead,
            totalFrames: frameCount
        )
    }

    private func outputSilence(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) {
        let leftBuffer = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
        let rightBuffer = UnsafeMutableAudioBufferListPointer(bufferList)[1].mData!.assumingMemoryBound(to: Float.self)

        for i in 0..<Int(frameCount) {
            leftBuffer[i] = 0
            rightBuffer[i] = 0
        }
    }

    private func deinterleave(
        source: [Float],
        bufferList: UnsafeMutablePointer<AudioBufferList>,
        framesRead: UInt32,
        totalFrames: UInt32
    ) {
        let leftBuffer = bufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: Float.self)
        let rightBuffer = UnsafeMutableAudioBufferListPointer(bufferList)[1].mData!.assumingMemoryBound(to: Float.self)

        for i in 0..<Int(framesRead) {
            leftBuffer[i] = source[i * 2]
            rightBuffer[i] = source[i * 2 + 1]
        }

        for i in Int(framesRead)..<Int(totalFrames) {
            leftBuffer[i] = 0
            rightBuffer[i] = 0
        }
    }
}
