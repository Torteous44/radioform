import Foundation

/// Handles IPC with audio host via JSON control file
class IPCController {
    static let shared = IPCController()

    private let presetFilePath = "/tmp/radioform-preset.json"

    private init() {}

    /// Apply preset by writing to control file
    func applyPreset(_ preset: EQPreset) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(preset)

        // Atomic write: write to temp file, then rename
        let tempPath = presetFilePath + ".tmp"
        let tempURL = URL(fileURLWithPath: tempPath)
        try data.write(to: tempURL, options: .atomic)

        // Remove destination if it exists, then move
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: presetFilePath) {
            try fileManager.removeItem(atPath: presetFilePath)
        }

        try fileManager.moveItem(atPath: tempPath, toPath: presetFilePath)
    }

    /// Read current preset from control file
    func getCurrentPreset() -> EQPreset? {
        guard FileManager.default.fileExists(atPath: presetFilePath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: presetFilePath))
            let decoder = JSONDecoder()
            return try decoder.decode(EQPreset.self, from: data)
        } catch {
            print("Failed to read current preset: \(error)")
            return nil
        }
    }
}
