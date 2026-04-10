import Foundation

/// Parse AutoEQ ParametricEQ.txt files into EQPresets
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

    // MARK: - Cached Regexes

    private static let preampRegex = try? NSRegularExpression(
        pattern: #"^Preamp:\s*([-\d.]+)\s*dB"#
    )
    private static let filterRegex = try? NSRegularExpression(
        pattern: #"^Filter\s+\d+:\s+(ON|OFF)\s+(\S+)\s+Fc\s+([\d.]+)\s+Hz\s+Gain\s+([-\d.]+)\s+dB(?:\s+Q\s+([\d.]+))?"#
    )

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

        // Keep top 10 bands by impact if file has more
        if bands.count > 10 {
            bands.sort { abs($0.gainDb) > abs($1.gainDb) }
            bands = Array(bands.prefix(10))
            bands.sort { $0.frequencyHz < $1.frequencyHz }
        }

        preampDb = max(-12.0, min(12.0, preampDb))

        return EQPreset(
            name: String(name.prefix(64)),
            bands: bands,
            preampDb: preampDb,
            limiterEnabled: true,
            limiterThresholdDb: -1.0
        )
    }

    // MARK: - Private

    private static func parsePreampLine(_ line: String) -> Float? {
        guard let regex = preampRegex else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return Float(nsLine.substring(with: range))
    }

    private static func parseFilterLine(_ line: String) -> EQBand? {
        guard let regex = filterRegex else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { return nil }

        let enabled = nsLine.substring(with: match.range(at: 1)) == "ON"
        let filterType = mapFilterType(nsLine.substring(with: match.range(at: 2)))
        guard let freq = Float(nsLine.substring(with: match.range(at: 3))) else { return nil }
        guard let gain = Float(nsLine.substring(with: match.range(at: 4))) else { return nil }

        // Q is optional — default 0.707 for shelves, 1.0 for peak
        var q: Float = filterType == .peak ? 1.0 : 0.707
        if match.range(at: 5).location != NSNotFound {
            if let parsedQ = Float(nsLine.substring(with: match.range(at: 5))) {
                q = parsedQ
            }
        }

        return EQBand(
            frequencyHz: max(20.0, min(20000.0, freq)),
            gainDb: max(-12.0, min(12.0, gain)),
            qFactor: max(0.1, min(10.0, q)),
            filterType: filterType,
            enabled: enabled
        )
    }

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
