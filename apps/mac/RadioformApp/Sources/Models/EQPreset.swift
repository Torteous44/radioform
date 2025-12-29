import Foundation

/// Complete EQ preset matching radioform_preset_t
struct EQPreset: Codable, Identifiable, Equatable {
    let id = UUID()
    var name: String                    // Max 64 chars
    var bands: [EQBand]                 // Up to 10 bands
    var preampDb: Float                 // -12.0 to +12.0
    var limiterEnabled: Bool
    var limiterThresholdDb: Float       // -6.0 to 0.0

    static func == (lhs: EQPreset, rhs: EQPreset) -> Bool {
        return lhs.name == rhs.name &&
               lhs.bands == rhs.bands &&
               lhs.preampDb == rhs.preampDb &&
               lhs.limiterEnabled == rhs.limiterEnabled &&
               lhs.limiterThresholdDb == rhs.limiterThresholdDb
    }

    enum CodingKeys: String, CodingKey {
        case name
        case bands
        case preampDb = "preamp_db"
        case limiterEnabled = "limiter_enabled"
        case limiterThresholdDb = "limiter_threshold_db"
    }

    init(name: String, bands: [EQBand], preampDb: Float, limiterEnabled: Bool, limiterThresholdDb: Float) {
        self.name = name
        self.bands = bands
        self.preampDb = preampDb
        self.limiterEnabled = limiterEnabled
        self.limiterThresholdDb = limiterThresholdDb
    }

    /// Validate preset parameters
    func isValid() -> Bool {
        guard !name.isEmpty && name.count <= 64 else { return false }
        guard bands.count >= 1 && bands.count <= 10 else { return false }
        guard (-12.0...12.0).contains(preampDb) else { return false }
        guard (-6.0...0.0).contains(limiterThresholdDb) else { return false }

        for band in bands {
            guard (20.0...20000.0).contains(band.frequencyHz) else { return false }
            guard (-12.0...12.0).contains(band.gainDb) else { return false }
            guard (0.1...10.0).contains(band.qFactor) else { return false }
        }

        return true
    }

    /// Create a flat preset (transparent)
    static func flat() -> EQPreset {
        EQPreset(
            name: "Flat",
            bands: [
                EQBand(frequencyHz: 100, gainDb: 0, qFactor: 1.0, filterType: .peak, enabled: false)
            ],
            preampDb: 0.0,
            limiterEnabled: false,
            limiterThresholdDb: -1.0
        )
    }

    /// Create bass boost preset
    static func bassBoost() -> EQPreset {
        EQPreset(
            name: "Bass Boost",
            bands: [
                EQBand(frequencyHz: 100.0, gainDb: 6.0, qFactor: 0.707, filterType: .lowShelf, enabled: true),
                EQBand(frequencyHz: 60.0, gainDb: 3.0, qFactor: 1.0, filterType: .peak, enabled: true)
            ],
            preampDb: 0.0,
            limiterEnabled: true,
            limiterThresholdDb: -1.0
        )
    }
}
