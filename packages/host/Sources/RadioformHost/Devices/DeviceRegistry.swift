import Foundation

class DeviceRegistry {
    private(set) var devices: [PhysicalDevice] = []

    func update(_ newDevices: [PhysicalDevice]) {
        devices = newDevices
        writeControlFile()
    }

    func find(uid: String) -> PhysicalDevice? {
        return devices.first { $0.uid == uid }
    }

    func findAdded(comparing old: [PhysicalDevice]) -> [PhysicalDevice] {
        return devices.filter { new in
            !old.contains { $0.uid == new.uid }
        }
    }

    func findRemoved(comparing old: [PhysicalDevice]) -> [PhysicalDevice] {
        return old.filter { old in
            !devices.contains { $0.uid == old.uid }
        }
    }

    func writeControlFile() {
        let content = devices.map { "\($0.name)|\($0.uid)" }.joined(separator: "\n")

        do {
            try content.write(
                toFile: RadioformConfig.controlFilePath,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            print("Failed to write control file: \(error)")
        }
    }
}
