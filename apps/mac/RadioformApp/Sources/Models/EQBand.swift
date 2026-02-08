import Foundation

/// Filter types matching radioform_filter_type_t
enum FilterType: Int, Codable, CaseIterable {
    case peak = 0
    case lowShelf = 1
    case highShelf = 2
    case lowPass = 3
    case highPass = 4
    case notch = 5
    case bandPass = 6

    var displayName: String {
        switch self {
        case .peak: return "Peak"
        case .lowShelf: return "Low Shelf"
        case .highShelf: return "High Shelf"
        case .lowPass: return "Low Pass"
        case .highPass: return "High Pass"
        case .notch: return "Notch"
        case .bandPass: return "Band Pass"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .peak: return "Peak"
        case .lowShelf: return "LoSh"
        case .highShelf: return "HiSh"
        case .lowPass: return "LoPa"
        case .highPass: return "HiPa"
        case .notch: return "Not"
        case .bandPass: return "Band"
        }
    }
}

/// Single EQ band matching radioform_band_t
struct EQBand: Codable, Identifiable, Equatable {
    let id = UUID()
    var frequencyHz: Float       // 20-20000 Hz
    var gainDb: Float           // -12.0 to +12.0 dB
    var qFactor: Float          // 0.1 to 10.0
    var filterType: FilterType
    var enabled: Bool

    static func == (lhs: EQBand, rhs: EQBand) -> Bool {
        return lhs.frequencyHz == rhs.frequencyHz &&
               lhs.gainDb == rhs.gainDb &&
               lhs.qFactor == rhs.qFactor &&
               lhs.filterType == rhs.filterType &&
               lhs.enabled == rhs.enabled
    }

    enum CodingKeys: String, CodingKey {
        case frequencyHz = "frequency_hz"
        case gainDb = "gain_db"
        case qFactor = "q_factor"
        case filterType = "filter_type"
        case enabled
    }

    init(frequencyHz: Float, gainDb: Float, qFactor: Float, filterType: FilterType, enabled: Bool) {
        self.frequencyHz = frequencyHz
        self.gainDb = gainDb
        self.qFactor = qFactor
        self.filterType = filterType
        self.enabled = enabled
    }
}
