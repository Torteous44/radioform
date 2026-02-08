import Foundation
import CRadioformAudio

class SharedMemoryManager {
    private var deviceMemory: [String: UnsafeMutablePointer<RFSharedAudio>] = [:]
    private var heartbeatTimer: DispatchSourceTimer?

    func createMemory(for devices: [PhysicalDevice]) {
        print("[RadioformHost] Creating shared memory for \(devices.count) devices")

        for device in devices {
            if createMemory(for: device.uid) {
                print("[RadioformHost] ✓ \(device.name)")
            } else {
                print("[RadioformHost] ✗ \(device.name)")
            }
        }

        print("[RadioformHost] Complete")
    }

    func createMemory(for uid: String) -> Bool {
        print("[RadioformHost] Creating shared memory for: \(uid)")

        let shmPath = PathManager.sharedMemoryPath(uid: uid)
        print("[RadioformHost] File: \(shmPath)")

        unlink(shmPath)

        let fd = open(shmPath, O_CREAT | O_RDWR, 0o666)
        guard fd >= 0 else {
            print("[RadioformHost] ERROR: Failed to create file: \(String(cString: strerror(errno)))")
            return false
        }

        fchmod(fd, 0o666)

        let sampleRate = RadioformConfig.activeSampleRate
        let frames = rf_frames_for_duration(
            sampleRate,
            RadioformConfig.defaultDurationMs
        )
        let bytesPerSample = rf_bytes_per_sample(RadioformConfig.defaultFormat)
        let shmSize = rf_shared_audio_size(
            frames,
            RadioformConfig.defaultChannels,
            bytesPerSample
        )

        print("[RadioformHost] Size: \(shmSize) bytes (\(frames) frames @ \(sampleRate)Hz)")

        guard ftruncate(fd, Int64(shmSize)) == 0 else {
            print("[RadioformHost] ERROR: Failed to set size: \(String(cString: strerror(errno)))")
            close(fd)
            return false
        }

        let mem = mmap(nil, shmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        close(fd)

        guard mem != MAP_FAILED else {
            print("[RadioformHost] ERROR: mmap failed: \(String(cString: strerror(errno)))")
            return false
        }

        let sharedMem = mem!.assumingMemoryBound(to: RFSharedAudio.self)

        rf_shared_audio_init(
            sharedMem,
            sampleRate,
            RadioformConfig.defaultChannels,
            RadioformConfig.defaultFormat,
            RadioformConfig.defaultDurationMs
        )

        deviceMemory[uid] = sharedMem

        print("[RadioformHost] ✓ SUCCESS")
        print("[RadioformHost]   Protocol: current")
        print("[RadioformHost]   Format: \(sampleRate)Hz, \(RadioformConfig.defaultChannels)ch, float32")
        print("[RadioformHost]   Buffer: \(RadioformConfig.defaultDurationMs)ms (\(frames) frames)")
        print("[RadioformHost]   Capabilities: Multi-rate, Multi-format, Heartbeat")

        return true
    }

    func removeMemory(for uid: String) {
        guard let sharedMem = deviceMemory[uid] else { return }

        let shmSize = rf_shared_audio_size(
            sharedMem.pointee.ring_capacity_frames,
            sharedMem.pointee.channels,
            sharedMem.pointee.bytes_per_sample
        )

        munmap(sharedMem, shmSize)
        deviceMemory.removeValue(forKey: uid)

        let shmPath = PathManager.sharedMemoryPath(uid: uid)
        unlink(shmPath)
    }

    func getMemory(for uid: String) -> UnsafeMutablePointer<RFSharedAudio>? {
        return deviceMemory[uid]
    }

    func getFirstMemory() -> UnsafeMutablePointer<RFSharedAudio>? {
        return deviceMemory.values.first
    }

    func startHeartbeat() {
        heartbeatTimer = DispatchSource.makeTimerSource(queue: .global())
        heartbeatTimer?.schedule(
            deadline: .now(),
            repeating: RadioformConfig.heartbeatInterval
        )

        heartbeatTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            for (_, mem) in self.deviceMemory {
                rf_update_host_heartbeat(mem)
            }
        }

        heartbeatTimer?.resume()
        print("[Heartbeat] Started - updating every second")
    }

    func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    func cleanup() {
        print("[Cleanup] Unmapping shared memory...")
        for (_, mem) in deviceMemory {
            let size = rf_shared_audio_size(
                mem.pointee.ring_capacity_frames,
                mem.pointee.channels,
                mem.pointee.bytes_per_sample
            )
            munmap(mem, size)
        }
        deviceMemory.removeAll()
    }
}
