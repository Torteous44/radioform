import Foundation

/// Parses AutoEQ ParametricEQ.txt files into Radioform EQPresets.
/// Supports files from AutoEQ (GitHub), squig.link, and Equalizer APO format.
enum AutoEQParser {

    enum ParseError: LocalizedError {
        case emptyFile
        case noFiltersFound
        case tooManyFilters

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "File is empty"
            case .noFiltersFound: return "No EQ filters found in file"
            case .tooManyFilters: return "File contains more than 20 filters"
            }
        }
    }

    /// Parse an AutoEQ .txt file and return an EQPreset.
    /// - Parameters:
    ///   - content: Raw text content of the file
    ///   - name: Preset name (typically derived from filename)
    /// - Returns: A valid EQPreset ready to save/apply
    static func parse(content: String, name: String) throws -> EQPreset {
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw ParseError.emptyFile }

        var preampDb: Float = 0.0
        var bands: [EQBand] = []

        for line in lines {
            if let preamp = parsePreampLine(line) {
                preampDb = preamp
            } else if let band = parseFilterLine(line) {
                bands.append(band)
            }
        }

        guard !bands.isEmpty else { throw ParseError.noFiltersFound }
        guard bands.count <= 20 else { throw ParseError.tooManyFilters }

        // If more than 10 bands, keep the 10 with the highest impact (absolute gain)
        if bands.count > 10 {
            bands.sort { abs($0.gainDb) > abs($1.gainDb) }
            bands = Array(bands.prefix(10))
            // Re-sort by frequency for consistent display
            bands.sort { $0.frequencyHz < $1.frequencyHz }
        }

        // Clamp preamp to Radioform's range
        preampDb = max(-12.0, min(12.0, preampDb))

        // Truncate name to 64 chars
        let presetName = String(name.prefix(64))

        return EQPreset(
            name: presetName,
            bands: bands,
            preampDb: preampDb,
            limiterEnabled: true,
            limiterThresholdDb: -0.1
        )
    }

    // MARK: - Line Parsers

    /// Parse "Preamp: -6.4 dB" → Float
    private static func parsePreampLine(_ line: String) -> Float? {
        let pattern = #"^Preamp:\s*([-\d.]+)\s*dB"#
        guard let match = line.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(line[match])
        // Extract the number
        let numPattern = #"[-\d.]+"#
        guard let numRange = matched.range(of: numPattern, options: .regularExpression) else { return nil }
        return Float(String(matched[numRange]))
    }

    /// Parse "Filter 1: ON PK Fc 105 Hz Gain 6.5 dB Q 0.70" → EQBand
    private static func parseFilterLine(_ line: String) -> EQBand? {
        let pattern = #"^Filter\s+\d+:\s+(ON|OFF)\s+(\S+)\s+Fc\s+([\d.]+)\s+Hz\s+Gain\s+([-\d.]+)\s+dB(?:\s+Q\s+([\d.]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { return nil }

        // Group 1: ON/OFF
        let enabledStr = nsLine.substring(with: match.range(at: 1))
        let enabled = enabledStr == "ON"

        // Group 2: Filter type
        let typeStr = nsLine.substring(with: match.range(at: 2))
        let filterType = mapFilterType(typeStr)

        // Group 3: Frequency
        guard let freq = Float(nsLine.substring(with: match.range(at: 3))) else { return nil }

        // Group 4: Gain
        guard let gain = Float(nsLine.substring(with: match.range(at: 4))) else { return nil }

        // Group 5: Q (optional, default 0.707 for shelf filters, 1.0 for peak)
        var q: Float = filterType == .peak ? 1.0 : 0.707
        if match.range(at: 5).location != NSNotFound {
            if let parsedQ = Float(nsLine.substring(with: match.range(at: 5))) {
                q = parsedQ
            }
        }

        // Clamp to Radioform's valid ranges
        let clampedFreq = max(20.0, min(20000.0, freq))
        let clampedGain = max(-12.0, min(12.0, gain))
        let clampedQ = max(0.1, min(10.0, q))

        return EQBand(
            frequencyHz: clampedFreq,
            gainDb: clampedGain,
            qFactor: clampedQ,
            filterType: filterType,
            enabled: enabled
        )
    }

    /// Map AutoEQ filter type strings to Radioform FilterType
    private static func mapFilterType(_ type: String) -> FilterType {
        switch type.uppercased() {
        case "PK", "PEQ", "MODAL":
            return .peak
        case "LS", "LSC", "LSQ", "LS 6DB", "LS 12DB":
            return .lowShelf
        case "HS", "HSC", "HSQ", "HS 6DB", "HS 12DB":
            return .highShelf
        case "LP", "LPQ":
            return .lowPass
        case "HP", "HPQ":
            return .highPass
        case "NO":
            return .notch
        case "BP":
            return .bandPass
        default:
            return .peak
        }
    }
}
