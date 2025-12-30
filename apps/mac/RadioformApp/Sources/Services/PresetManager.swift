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
    @Published var isEnabled: Bool = true
    @Published var currentBands: [Float] = Array(repeating: 0, count: 10) // Current gain values for 10 bands
    
    // Custom preset state
    @Published var isCustomPreset: Bool = false
    @Published var isEditingPresetName: Bool = false
    @Published var isSavingPreset: Bool = false
    @Published var saveSucceeded: Bool = false
    
    /// Reserved name that cannot be used for saved presets
    static let customPresetName = "Custom Preset"

    private let userPresetsURL: URL
    private let standardFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

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
        
        // If no preset is loaded, default to "Flat"
        if currentPreset == nil {
            if let flatPreset = bundledPresets.first(where: { $0.name == "Flat" }) {
                applyPreset(flatPreset)
            }
        }
    }

    /// Load all presets (bundled + user)
    func loadAllPresets() {
        bundledPresets = loadBundledPresets()
        userPresets = loadUserPresets()
    }

    /// Load bundled presets from app Resources
    private func loadBundledPresets() -> [EQPreset] {
        var presetsPath: String?
        
        // Debug info
        print("[PresetManager] Looking for bundled presets...")
        print("[PresetManager] Bundle.main.resourcePath: \(Bundle.main.resourcePath ?? "nil")")
        print("[PresetManager] Bundle.main.executablePath: \(Bundle.main.executablePath ?? "nil")")
        print("[PresetManager] CWD: \(FileManager.default.currentDirectoryPath)")

        // Try bundle resources first (production)
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = (resourcePath as NSString).appendingPathComponent("Resources/Presets")
            print("[PresetManager] Trying bundle path: \(bundlePath)")
            if FileManager.default.fileExists(atPath: bundlePath) {
                presetsPath = bundlePath
                print("[PresetManager] ✓ Found at bundle path")
            }
        }

        // Fall back to source directory (development - swift build)
        if presetsPath == nil {
            if let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent
                
                // For .build/debug/RadioformApp -> Sources/Resources/Presets
                let debugPath = (executableDir as NSString).appendingPathComponent("../../Sources/Resources/Presets")
                let normalizedDebugPath = (debugPath as NSString).standardizingPath
                print("[PresetManager] Trying debug path: \(normalizedDebugPath)")
                if FileManager.default.fileExists(atPath: normalizedDebugPath) {
                    presetsPath = normalizedDebugPath
                    print("[PresetManager] ✓ Found at debug path")
                }
            }
        }
        
        // Try finding based on current working directory
        if presetsPath == nil {
            let cwd = FileManager.default.currentDirectoryPath
            let possiblePaths = [
                "\(cwd)/Sources/Resources/Presets",
                "\(cwd)/apps/mac/RadioformApp/Sources/Resources/Presets",
                // Add home directory fallback for when launched from various locations
                NSString(string: "~/radioform-1/apps/mac/RadioformApp/Sources/Resources/Presets").expandingTildeInPath,
                NSString(string: "~/radioform/apps/mac/RadioformApp/Sources/Resources/Presets").expandingTildeInPath
            ]
            for path in possiblePaths {
                print("[PresetManager] Trying CWD path: \(path)")
                if FileManager.default.fileExists(atPath: path) {
                    presetsPath = path
                    print("[PresetManager] ✓ Found at CWD path")
                    break
                }
            }
        }

        guard let finalPath = presetsPath else {
            print("[PresetManager] ✗ Presets directory not found anywhere!")
            return []
        }
        
        print("[PresetManager] Loading presets from: \(finalPath)")

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: finalPath) else {
            print("[PresetManager] ✗ Failed to read presets directory")
            return []
        }
        
        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        print("[PresetManager] Found \(jsonFiles.count) JSON files: \(jsonFiles)")

        let presets = jsonFiles
            .compactMap { filename -> EQPreset? in
                let url = URL(fileURLWithPath: finalPath).appendingPathComponent(filename)
                do {
                    return try loadPreset(from: url)
                } catch {
                    print("[PresetManager] ✗ Failed to load \(filename): \(error)")
                    return nil
                }
            }
            .sorted { $0.name < $1.name }
        
        print("[PresetManager] ✓ Loaded \(presets.count) bundled presets: \(presets.map { $0.name })")
        return presets
    }

    /// Load user presets from Application Support
    private func loadUserPresets() -> [EQPreset] {
        print("[PresetManager] Loading user presets from: \(userPresetsURL.path)")
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: userPresetsURL,
            includingPropertiesForKeys: nil
        ) else {
            print("[PresetManager] No user presets directory or empty")
            return []
        }

        let presets = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? loadPreset(from: $0) }
            .sorted { $0.name < $1.name }
        
        print("[PresetManager] ✓ Loaded \(presets.count) user presets: \(presets.map { $0.name })")
        return presets
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
            
            // Reset custom preset state
            isCustomPreset = false
            isEditingPresetName = false

            // Update currentBands from preset
            for i in 0..<10 {
                let targetFreq = standardFrequencies[i]
                if let closestBand = preset.bands
                    .filter({ $0.enabled })
                    .min(by: { abs($0.frequencyHz - targetFreq) < abs($1.frequencyHz - targetFreq) }) {
                    if abs(closestBand.frequencyHz - targetFreq) < targetFreq * 0.7 {
                        currentBands[i] = closestBand.gainDb
                    } else {
                        currentBands[i] = 0
                    }
                } else {
                    currentBands[i] = 0
                }
            }
        } catch {
            print("Failed to apply preset: \(error)")
        }
    }

    /// Update a single band and apply immediately
    func updateBand(index: Int, gainDb: Float) {
        guard index >= 0 && index < 10 else { return }
        currentBands[index] = gainDb
        applyCurrentState()
    }

    /// Apply current state (either enabled with current bands, or disabled with all zeros)
    func applyCurrentState() {
        let bands: [EQBand] = standardFrequencies.enumerated().map { index, frequency in
            let gain = isEnabled ? currentBands[index] : 0.0
            return EQBand(
                frequencyHz: frequency,
                gainDb: gain,
                qFactor: 1.0,
                filterType: .peak,
                enabled: abs(gain) > 0.01
            )
        }

        let customPreset = EQPreset(
            name: "Custom",
            bands: bands,
            preampDb: 0.0,
            limiterEnabled: true,
            limiterThresholdDb: -1.0
        )

        do {
            try IPCController.shared.applyPreset(customPreset)
            if isEnabled {
                currentPreset = nil
                isCustomPreset = true
            }
        } catch {
            print("Failed to apply current state: \(error)")
        }
    }

    /// Toggle EQ enabled state
    func toggleEnabled() {
        isEnabled.toggle()
        applyCurrentState()
    }
    
    // MARK: - Custom Preset Management
    
    /// Validate preset name for saving
    func validatePresetName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        
        // Check not empty
        guard !trimmed.isEmpty else { return false }
        
        // Check not too long
        guard trimmed.count <= 64 else { return false }
        
        // Check not reserved name
        guard trimmed != Self.customPresetName else { return false }
        
        return true
    }
    
    /// Generate a unique preset name by appending numbers if needed
    func generateUniqueName(_ baseName: String) -> String {
        let allPresetNames = Set((bundledPresets + userPresets).map { $0.name })
        
        // If name doesn't exist, return as-is
        if !allPresetNames.contains(baseName) {
            return baseName
        }
        
        // Find next available number
        var counter = 2
        var candidateName = "\(baseName) \(counter)"
        
        while allPresetNames.contains(candidateName) {
            counter += 1
            candidateName = "\(baseName) \(counter)"
        }
        
        return candidateName
    }
    
    /// Save current EQ state as a custom preset
    @MainActor
    func saveCustomPreset(name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Validate
        guard validatePresetName(trimmedName) else {
            throw PresetError.invalidPreset
        }
        
        // Generate unique name if needed
        let finalName = generateUniqueName(trimmedName)
        
        // Build preset from current bands
        let bands: [EQBand] = standardFrequencies.enumerated().map { index, frequency in
            let gain = currentBands[index]
            return EQBand(
                frequencyHz: frequency,
                gainDb: gain,
                qFactor: 1.0,
                filterType: .peak,
                enabled: abs(gain) > 0.01
            )
        }
        
        let newPreset = EQPreset(
            name: finalName,
            bands: bands,
            preampDb: 0.0,
            limiterEnabled: true,
            limiterThresholdDb: -1.0
        )
        
        // Save to disk
        try savePreset(newPreset)
        
        // Set as current preset
        currentPreset = newPreset
        isCustomPreset = false
        isEditingPresetName = false
    }
    
    /// Cancel editing mode
    func cancelEditing() {
        isEditingPresetName = false
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
