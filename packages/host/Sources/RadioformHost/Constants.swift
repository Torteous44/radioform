import Foundation
import CRadioformAudio

struct RadioformConfig {
    /// Active sample rate - set at runtime to match physical device for HiFi/lossless playback
    static var activeSampleRate: UInt32 = 48000
    /// Fallback sample rate if device query fails
    static let defaultSampleRate: UInt32 = 48000
    static let defaultChannels: UInt32 = 2
    static let defaultFormat = RF_FORMAT_FLOAT32
    static let defaultDurationMs: UInt32 = 20

    static var controlFilePath: String {
        return PathManager.controlFilePath
    }

    static var presetFilePath: String {
        return PathManager.presetFilePath.path
    }

    static let heartbeatInterval: TimeInterval = 1.0
    static let presetMonitorInterval: TimeInterval = 0.5

    static let deviceWaitTimeout: TimeInterval = 2.0
    static let cleanupWaitTimeout: TimeInterval = 1.2
    static let physicalDeviceSwitchDelay: TimeInterval = 0.5
}
