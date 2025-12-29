import Foundation

enum PresetError: Error {
    case invalidPreset
    case fileNotFound
    case encodingFailed
    case decodingFailed
}

/// Manages loading, saving, and organizing presets
class PresetManager: ObservableObject {
    static let shared = PresetManager()

    @Published var bundledPresets: [EQPreset] = []
    @Published var userPresets: [EQPreset] = []
    @Published var currentPreset: EQPreset?

    private let userPresetsURL: URL

    private init() {
        // Get user presets directory
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        userPresetsURL = appSupport
            .appendingPathComponent("Radioform")
            .appendingPathComponent("Presets")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: userPresetsURL,
            withIntermediateDirectories: true
        )

        loadAllPresets()

        // Load current preset from IPC
        currentPreset = IPCController.shared.getCurrentPreset()
    }

    /// Load all presets (bundled + user)
    func loadAllPresets() {
        bundledPresets = loadBundledPresets()
        userPresets = loadUserPresets()
    }

    /// Load bundled presets from app Resources
    private func loadBundledPresets() -> [EQPreset] {
        var presetsPath: String?

        // Try bundle resources first (production)
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = (resourcePath as NSString).appendingPathComponent("Resources/Presets")
            if FileManager.default.fileExists(atPath: bundlePath) {
                presetsPath = bundlePath
            }
        }

        // Fall back to source directory (development)
        if presetsPath == nil {
            // Try relative to executable location
            if let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent
                let sourcePath = (executableDir as NSString).appendingPathComponent("../../../Sources/Resources/Presets")
                let normalizedPath = (sourcePath as NSString).standardizingPath
                if FileManager.default.fileExists(atPath: normalizedPath) {
                    presetsPath = normalizedPath
                }
            }
        }

        // Try absolute path as last resort (development from repo root)
        if presetsPath == nil {
            let absolutePath = "/Users/mattporteous/radioform/apps/mac/RadioformApp/Sources/Resources/Presets"
            if FileManager.default.fileExists(atPath: absolutePath) {
                presetsPath = absolutePath
            }
        }

        guard let finalPath = presetsPath else {
            print("Presets directory not found")
            return []
        }

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: finalPath) else {
            print("Failed to read presets directory")
            return []
        }

        return files
            .filter { $0.hasSuffix(".json") }
            .compactMap { filename in
                let url = URL(fileURLWithPath: finalPath).appendingPathComponent(filename)
                return try? loadPreset(from: url)
            }
            .sorted { $0.name < $1.name }
    }

    /// Load user presets from Application Support
    private func loadUserPresets() -> [EQPreset] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: userPresetsURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? loadPreset(from: $0) }
            .sorted { $0.name < $1.name }
    }

    /// Load preset from file
    private func loadPreset(from url: URL) throws -> EQPreset {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(EQPreset.self, from: data)
    }

    /// Save user preset
    func savePreset(_ preset: EQPreset) throws {
        guard preset.isValid() else {
            throw PresetError.invalidPreset
        }

        let filename = sanitizeFilename(preset.name) + ".json"
        let url = userPresetsURL.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preset)
        try data.write(to: url)

        loadAllPresets()
    }

    /// Delete user preset
    func deletePreset(_ preset: EQPreset) throws {
        let filename = sanitizeFilename(preset.name) + ".json"
        let url = userPresetsURL.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)

        loadAllPresets()
    }

    /// Apply preset via IPC
    func applyPreset(_ preset: EQPreset) {
        do {
            try IPCController.shared.applyPreset(preset)
            currentPreset = preset
        } catch {
            print("Failed to apply preset: \(error)")
        }
    }

    /// Sanitize filename (remove invalid characters)
    private func sanitizeFilename(_ name: String) -> String {
        var safe = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")

        if safe.count > 64 {
            safe = String(safe.prefix(64))
        }

        return safe.trimmingCharacters(in: .whitespaces)
    }
}
