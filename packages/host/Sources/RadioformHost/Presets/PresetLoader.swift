import Foundation
import CRadioformDSP

struct PresetJSON: Codable {
    let name: String
    let bands: [BandJSON]
    let preampDb: Float
    let limiterEnabled: Bool
    let limiterThresholdDb: Float

    enum CodingKeys: String, CodingKey {
        case name, bands
        case preampDb = "preamp_db"
        case limiterEnabled = "limiter_enabled"
        case limiterThresholdDb = "limiter_threshold_db"
    }
}

struct BandJSON: Codable {
    let frequencyHz: Float
    let gainDb: Float
    let qFactor: Float
    let filterType: Int
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case frequencyHz = "frequency_hz"
        case gainDb = "gain_db"
        case qFactor = "q_factor"
        case filterType = "filter_type"
        case enabled
    }
}

class PresetLoader {
    func load(from path: String) throws -> radioform_preset_t {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let presetJSON = try JSONDecoder().decode(PresetJSON.self, from: data)

        var preset = radioform_preset_t()
        radioform_dsp_preset_init_flat(&preset)

        preset.num_bands = UInt32(min(presetJSON.bands.count, 10))

        copyName(presetJSON.name, to: &preset)
        copyBands(presetJSON.bands, to: &preset)

        preset.preamp_db = presetJSON.preampDb
        preset.limiter_enabled = presetJSON.limiterEnabled
        preset.limiter_threshold_db = presetJSON.limiterThresholdDb

        return preset
    }

    private func copyName(_ name: String, to preset: inout radioform_preset_t) {
        let nameBytes = Array(name.utf8.prefix(63))
        withUnsafeMutableBytes(of: &preset.name) { ptr in
            let buffer = ptr.baseAddress!.assumingMemoryBound(to: CChar.self)
            for (i, byte) in nameBytes.enumerated() {
                buffer[i] = CChar(bitPattern: byte)
            }
            buffer[min(nameBytes.count, 63)] = 0
        }
    }

    private func copyBands(_ bands: [BandJSON], to preset: inout radioform_preset_t) {
        for (i, band) in bands.prefix(10).enumerated() {
            withUnsafeMutablePointer(to: &preset.bands) { bandsPtr in
                let bandPtr = UnsafeMutableRawPointer(bandsPtr)
                    .advanced(by: i * MemoryLayout<radioform_band_t>.stride)
                    .assumingMemoryBound(to: radioform_band_t.self)

                bandPtr.pointee.frequency_hz = band.frequencyHz
                bandPtr.pointee.gain_db = band.gainDb
                bandPtr.pointee.q_factor = band.qFactor
                bandPtr.pointee.type = radioform_filter_type_t(UInt32(band.filterType))
                bandPtr.pointee.enabled = band.enabled
            }
        }
    }
}
