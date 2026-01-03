import Foundation
import CRadioformAudio

struct RadioformConfig {
    static let defaultSampleRate: UInt32 = 48000
    static let defaultChannels: UInt32 = 2
    static let defaultFormat = RF_FORMAT_FLOAT32
    static let defaultDurationMs: UInt32 = 40

    static let controlFilePath = "/tmp/radioform-devices.txt"
    static let presetFilePath = "/tmp/radioform-preset.json"

    static let heartbeatInterval: TimeInterval = 1.0
    static let presetMonitorInterval: TimeInterval = 0.5

    static let deviceWaitTimeout: TimeInterval = 2.0
    static let cleanupWaitTimeout: TimeInterval = 1.2
    static let physicalDeviceSwitchDelay: TimeInterval = 0.5
}
