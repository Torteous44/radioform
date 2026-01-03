import Foundation

class PresetMonitor {
    private let loader: PresetLoader
    private let processor: DSPProcessor
    private var isMonitoring = false
    private var monitorQueue: DispatchQueue?

    init(loader: PresetLoader, processor: DSPProcessor) {
        self.loader = loader
        self.processor = processor
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        let queue = DispatchQueue(label: "com.radioform.preset-monitor")
        monitorQueue = queue

        queue.async { [weak self] in
            guard let self = self else { return }

            var lastModification: Date?

            while self.isMonitoring {
                if let attributes = try? FileManager.default.attributesOfItem(
                    atPath: RadioformConfig.presetFilePath
                ),
                   let modDate = attributes[.modificationDate] as? Date {

                    if lastModification == nil || modDate > lastModification! {
                        lastModification = modDate
                        self.loadAndApplyPreset()
                    }
                }

                Thread.sleep(forTimeInterval: RadioformConfig.presetMonitorInterval)
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorQueue = nil
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
            } else {
                print("Failed to apply preset")
            }
        } catch {
            print("Failed to load preset: \(error)")
        }
    }
}
