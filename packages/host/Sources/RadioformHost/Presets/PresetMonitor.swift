import Foundation

class PresetMonitor {
    private let loader: PresetLoader
    private let processor: DSPProcessor
    private let queue = DispatchQueue(label: "com.radioform.preset-monitor")
    private var timer: DispatchSourceTimer?
    private var lastModification: Date?

    init(loader: PresetLoader, processor: DSPProcessor) {
        self.loader = loader
        self.processor = processor
    }

    func startMonitoring() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now(),
            repeating: RadioformConfig.presetMonitorInterval
        )
        timer.setEventHandler { [weak self] in
            self?.checkForChanges()
        }
        timer.resume()
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    private func checkForChanges() {
        if let attributes = try? FileManager.default.attributesOfItem(
            atPath: RadioformConfig.presetFilePath
        ),
           let modDate = attributes[.modificationDate] as? Date {

            if lastModification == nil || modDate > lastModification! {
                lastModification = modDate
                loadAndApplyPreset()
            }
        }
    }

    private func loadAndApplyPreset() {
        do {
            let preset = try loader.load(from: RadioformConfig.presetFilePath)

            if processor.applyPreset(preset) {
                let name = String(
                    cString: withUnsafeBytes(of: preset.name) {
                        $0.baseAddress!.assumingMemoryBound(to: CChar.self)
                    }
                )
                print("Applied preset: \(name)")
                print("    preamp_db=\(preset.preamp_db) limiter_enabled=\(preset.limiter_enabled) limiter_threshold_db=\(preset.limiter_threshold_db)")
                print("    bands=\(preset.num_bands)")
            } else {
                print("Failed to apply preset")
            }
        } catch {
            print("Failed to load preset: \(error)")
        }
    }
}
