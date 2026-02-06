import Foundation

enum PresetError: Error {
    case invalidPreset
    case fileNotFound
    case encodingFailed
    case decodingFailed
}

/// Result of mapping a preset's bands to the standard 10-band UI frequencies
struct MappedBandResult {
    var gains: [Float]
    var qFactors: [Float]
    var filterTypes: [FilterType]
    var warnings: [String]
}

/// Manages loading, saving, and organizing presets
class PresetManager: ObservableObject {
    static let shared = PresetManager()
    static let customPresetName = "Custom"

    @Published var bundledPresets: [EQPreset] = []
    @Published var userPresets: [EQPreset] = []
    @Published var currentPreset: EQPreset?
    @Published var isEnabled: Bool = true
    @Published var currentBands: [Float] = Array(repeating: 0, count: 10)  // Current gain values for 10 bands

    // Per-band advanced settings
    @Published var currentQFactors: [Float] = Array(repeating: 1.0, count: 10)
    @Published var currentFilterTypes: [FilterType] = Array(repeating: .peak, count: 10)

    // Global settings
    @Published var currentPreampDb: Float = 0.0
    @Published var currentLimiterEnabled: Bool = true
    @Published var currentLimiterThresholdDb: Float = -1.0

    // Focus mode state
    @Published var focusedBandIndex: Int? = nil   // nil = no focus, 0-9 = band, 10 = preamp

    // Custom preset state
    @Published var isCustomPreset: Bool = false
    @Published var isEditingPresetName: Bool = false
    @Published var isSavingPreset: Bool = false

    // Cached computed values (updated when presets change)
    private(set) var allPresets: [EQPreset] = []
    private(set) var userPresetIDs: Set<EQPreset.ID> = []

    private let userPresetsURL: URL
    private let standardFrequencies: [Float] = [
        32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
    ]

    // Timers
    private var audioApplyTimer: Timer?

    private init() {
        // Get user presets directory
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        userPresetsURL =
            appSupport
            .appendingPathComponent("Radioform")
            .appendingPathComponent("Presets")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: userPresetsURL,
            withIntermediateDirectories: true
        )

        loadAllPresets()

        // Load current preset from IPC
        let loadedPreset = IPCController.shared.getCurrentPreset()

        // Apply the loaded preset (ensures UI sync), or default to "Flat"
        if let preset = loadedPreset {
            applyPreset(preset)
        } else if let flatPreset = bundledPresets.first(where: { $0.name == "Flat" }) {
            applyPreset(flatPreset)
        }
    }

    /// Load all presets (bundled + user)
    func loadAllPresets() {
        bundledPresets = loadBundledPresets()
        userPresets = loadUserPresets()
        // Update cached values
        allPresets = bundledPresets + userPresets
        userPresetIDs = Set(userPresets.map { $0.id })
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
            let bundlePath = (resourcePath as NSString).appendingPathComponent("Presets")
            print("[PresetManager] Trying bundle path: \(bundlePath)")
            if FileManager.default.fileExists(atPath: bundlePath) {
                presetsPath = bundlePath
                print("[PresetManager] Found at bundle path")
            }
        }

        // Fall back to source directory (development - swift build)
        if presetsPath == nil {
            if let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent

                // For .build/debug/RadioformApp -> Sources/Resources/Presets
                let debugPath = (executableDir as NSString).appendingPathComponent(
                    "../../Sources/Resources/Presets")
                let normalizedDebugPath = (debugPath as NSString).standardizingPath
                print("[PresetManager] Trying debug path: \(normalizedDebugPath)")
                if FileManager.default.fileExists(atPath: normalizedDebugPath) {
                    presetsPath = normalizedDebugPath
                    print("[PresetManager] Found at debug path")
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
                NSString(string: "~/radioform/apps/mac/RadioformApp/Sources/Resources/Presets")
                    .expandingTildeInPath,
                NSString(string: "~/radioform/apps/mac/RadioformApp/Sources/Resources/Presets")
                    .expandingTildeInPath,
            ]
            for path in possiblePaths {
                print("[PresetManager] Trying CWD path: \(path)")
                if FileManager.default.fileExists(atPath: path) {
                    presetsPath = path
                    print("[PresetManager] Found at CWD path")
                    break
                }
            }
        }

        guard let finalPath = presetsPath else {
            print("[PresetManager] ERROR: Presets directory not found anywhere!")
            return []
        }

        print("[PresetManager] Loading presets from: \(finalPath)")

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: finalPath) else {
            print("[PresetManager] ERROR: Failed to read presets directory")
            return []
        }

        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        print("[PresetManager] Found \(jsonFiles.count) JSON files: \(jsonFiles)")

        let presets =
            jsonFiles
            .compactMap { filename -> EQPreset? in
                let url = URL(fileURLWithPath: finalPath).appendingPathComponent(filename)
                do {
                    return try loadPreset(from: url)
                } catch {
                    print("[PresetManager] ERROR: Failed to load \(filename): \(error)")
                    return nil
                }
            }
            .sorted { $0.name < $1.name }

        print(
            "[PresetManager] Loaded \(presets.count) bundled presets: \(presets.map { $0.name })")
        return presets
    }

    /// Load user presets from Application Support
    private func loadUserPresets() -> [EQPreset] {
        print("[PresetManager] Loading user presets from: \(userPresetsURL.path)")

        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: userPresetsURL,
                includingPropertiesForKeys: nil
            )
        else {
            print("[PresetManager] No user presets directory or empty")
            return []
        }

        let presets =
            files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? loadPreset(from: $0) }
            .sorted { $0.name < $1.name }

        print("[PresetManager] Loaded \(presets.count) user presets: \(presets.map { $0.name })")
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
        try data.write(to: url, options: .atomic)

        loadAllPresets()
    }

    /// Delete user preset
    func deletePreset(_ preset: EQPreset) throws {
        let filename = sanitizeFilename(preset.name) + ".json"
        let url = userPresetsURL.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)

        loadAllPresets()
    }

    /// Map preset bands to standard 10-band UI frequencies
    private func mapPresetToStandardBands(_ preset: EQPreset) -> MappedBandResult {
        var gains: [Float] = Array(repeating: 0, count: 10)
        var qFactors: [Float] = Array(repeating: 1.0, count: 10)
        var filterTypes: [FilterType] = Array(repeating: .peak, count: 10)
        var warnings: [String] = []
        var usedBandIndices = Set<Int>()

        // Use logarithmic distance for frequency matching (more accurate for audio)
        func logDistance(_ f1: Float, _ f2: Float) -> Float {
            return abs(log10(f1) - log10(f2))
        }

        // Consider all bands (not just enabled) so we preserve Q/filterType for disabled bands too
        let allBands = preset.bands.enumerated().map { ($0.offset, $0.element) }

        // For each standard frequency, find best matching preset band
        for i in 0..<10 {
            let targetFreq = standardFrequencies[i]

            // Find closest unused band
            var bestMatch: (index: Int, band: EQBand, distance: Float)?

            for (presetIdx, band) in allBands {
                // Skip if this band was already used
                if usedBandIndices.contains(presetIdx) {
                    continue
                }

                let distance = logDistance(band.frequencyHz, targetFreq)

                if bestMatch == nil || distance < bestMatch!.distance {
                    bestMatch = (presetIdx, band, distance)
                }
            }

            // Apply match if found and within reasonable tolerance
            if let match = bestMatch {
                // Tolerance: 1 octave = log distance of 0.301 (log10(2))
                // Use 0.5 octaves as max tolerance (more permissive than before)
                let maxToleranceOctaves: Float = 0.5
                let maxLogDistance = maxToleranceOctaves * log10(2)

                if match.distance <= maxLogDistance {
                    gains[i] = match.band.enabled ? match.band.gainDb : 0
                    qFactors[i] = match.band.qFactor
                    filterTypes[i] = match.band.filterType
                    usedBandIndices.insert(match.index)
                } else {
                    // Band exists but too far away
                    let octaveDiff = match.distance / log10(2)
                    warnings.append(
                        "Band at \(Int(match.band.frequencyHz))Hz is \(String(format: "%.1f", octaveDiff)) octaves from \(Int(targetFreq))Hz slider - setting to 0dB"
                    )
                }
            }
        }

        // Check for unmapped preset bands that were enabled
        let enabledBands = allBands.filter { $0.1.enabled }
        for (presetIdx, band) in enabledBands {
            if !usedBandIndices.contains(presetIdx) {
                warnings.append(
                    "Band at \(Int(band.frequencyHz))Hz (\(String(format: "%.1f", band.gainDb))dB) has no matching slider - ignored"
                )
            }
        }

        return MappedBandResult(gains: gains, qFactors: qFactors, filterTypes: filterTypes, warnings: warnings)
    }

    /// Apply preset via IPC
    func applyPreset(_ preset: EQPreset) {
        do {
            try IPCController.shared.applyPreset(preset)
            currentPreset = preset

            // Reset custom preset state
            isCustomPreset = false
            isEditingPresetName = false

            // Update all tracked state from preset
            let result = mapPresetToStandardBands(preset)
            currentBands = result.gains
            currentQFactors = result.qFactors
            currentFilterTypes = result.filterTypes
            currentPreampDb = preset.preampDb
            currentLimiterEnabled = preset.limiterEnabled
            currentLimiterThresholdDb = preset.limiterThresholdDb

            // Log any mapping issues
            if !result.warnings.isEmpty {
                print("[PresetManager] Preset '\(preset.name)' mapping warnings:")
                for warning in result.warnings {
                    print("  - \(warning)")
                }
            }
        } catch {
            print("Failed to apply preset: \(error)")
        }
    }

    /// Update a single band and apply immediately (batched to avoid multiple redraws)
    func updateBand(index: Int, gainDb: Float) {
        guard index >= 0 && index < 10 else { return }

        // Update band value without triggering @Published (direct array mutation)
        // We'll manually notify once at the end
        let needsCustomUpdate = !isCustomPreset && isEnabled
        let needsPresetClear = currentPreset != nil && isEnabled

        // Batch all state changes together
        currentBands[index] = gainDb

        // Only update these if needed (avoids redundant publishes during drag)
        if needsPresetClear {
            currentPreset = nil
        }
        if needsCustomUpdate {
            isCustomPreset = true
        }

        // Reset inactivity timer if this band is focused
        if focusedBandIndex != nil {
            resetInactivityTimer()
        }

        // Apply to audio (doesn't trigger UI updates)
        applyCurrentStateToAudio()
    }

    /// Apply current state to audio, throttled to prevent IPC flooding during rapid updates
    private func applyCurrentStateToAudio() {
        // Throttle: coalesce rapid calls (drag, scroll) into one IPC write per ~30ms
        audioApplyTimer?.invalidate()
        audioApplyTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.doApplyCurrentStateToAudio()
        }
    }

    private func doApplyCurrentStateToAudio() {
        let bands = standardFrequencies.enumerated().map { index, frequency in
            let gain = isEnabled ? currentBands[index] : 0.0
            return EQBand(
                frequencyHz: frequency,
                gainDb: gain,
                qFactor: currentQFactors[index],
                filterType: currentFilterTypes[index],
                enabled: abs(gain) > 0.01
            )
        }

        let customPreset = EQPreset(
            name: "Custom",
            bands: bands,
            preampDb: currentPreampDb,
            limiterEnabled: currentLimiterEnabled,
            limiterThresholdDb: currentLimiterThresholdDb
        )

        do {
            try IPCController.shared.applyPreset(customPreset)
        } catch {
            print("Failed to apply current state: \(error)")
        }
    }

    /// Apply current state (either enabled with current bands, or disabled with all zeros)
    func applyCurrentState() {
        if isEnabled {
            currentPreset = nil
            isCustomPreset = true
        }
        applyCurrentStateToAudio()
    }

    /// Toggle EQ enabled state
    func toggleEnabled() {
        isEnabled.toggle()
        applyCurrentState()
    }

    // MARK: - Band Advanced Settings

    /// Update Q factor for a specific band
    func updateBandQ(index: Int, qFactor: Float) {
        guard index >= 0 && index < 10 else { return }
        currentQFactors[index] = max(0.1, min(10.0, qFactor))
        markCustomIfNeeded()
        resetInactivityTimer()
        applyCurrentStateToAudio()
    }

    /// Update filter type for a specific band
    func updateBandFilterType(index: Int, filterType: FilterType) {
        guard index >= 0 && index < 10 else { return }
        currentFilterTypes[index] = filterType
        markCustomIfNeeded()
        resetInactivityTimer()
        applyCurrentStateToAudio()
    }

    // MARK: - Global Settings

    /// Update preamp gain
    func updatePreamp(gainDb: Float) {
        currentPreampDb = max(-12.0, min(12.0, gainDb))
        markCustomIfNeeded()
        if focusedBandIndex != nil {
            resetInactivityTimer()
        }
        applyCurrentStateToAudio()
    }

    /// Update limiter enabled state
    func updateLimiterEnabled(_ enabled: Bool) {
        currentLimiterEnabled = enabled
        markCustomIfNeeded()
        resetInactivityTimer()
        applyCurrentStateToAudio()
    }

    /// Update limiter threshold
    func updateLimiterThreshold(db: Float) {
        currentLimiterThresholdDb = max(-6.0, min(0.0, db))
        markCustomIfNeeded()
        resetInactivityTimer()
        applyCurrentStateToAudio()
    }

    // MARK: - Focus Mode

    /// Toggle focus on a band (double-click behavior)
    func toggleFocusedBand(_ index: Int) {
        if focusedBandIndex == index {
            focusedBandIndex = nil
            cancelInactivityTimer()
        } else {
            focusedBandIndex = index
            resetInactivityTimer()
        }
    }

    /// Set focused band directly (used for unfocusing on empty space click)
    func setFocusedBand(_ index: Int?) {
        focusedBandIndex = index
        if index != nil {
            resetInactivityTimer()
        } else {
            cancelInactivityTimer()
        }
    }

    /// Reset the inactivity timer (no-op, timeout removed)
    func resetInactivityTimer() {
        // No timeout - band stays focused until user clicks elsewhere
    }

    /// Cancel the inactivity timer (no-op, timeout removed)
    func cancelInactivityTimer() {
        // No timeout to cancel
    }


    // MARK: - Custom Preset Management

    /// Mark as custom preset if a saved preset was active
    private func markCustomIfNeeded() {
        if currentPreset != nil && isEnabled {
            currentPreset = nil
        }
        if !isCustomPreset && isEnabled {
            isCustomPreset = true
        }
    }

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

        // Build preset from current bands (preserving advanced settings)
        let bands: [EQBand] = standardFrequencies.enumerated().map { index, frequency in
            let gain = currentBands[index]
            return EQBand(
                frequencyHz: frequency,
                gainDb: gain,
                qFactor: currentQFactors[index],
                filterType: currentFilterTypes[index],
                enabled: abs(gain) > 0.01
            )
        }

        let newPreset = EQPreset(
            name: finalName,
            bands: bands,
            preampDb: currentPreampDb,
            limiterEnabled: currentLimiterEnabled,
            limiterThresholdDb: currentLimiterThresholdDb
        )

        // Save to disk (this reloads all presets, creating new instances)
        try savePreset(newPreset)

        // Find the newly loaded version of the preset from userPresets
        // (savePreset reloads all presets with new UUIDs, so we need to find by name)
        if let reloadedPreset = userPresets.first(where: { $0.name == finalName }) {
            currentPreset = reloadedPreset
        } else {
            currentPreset = newPreset  // Fallback (shouldn't happen)
        }

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
