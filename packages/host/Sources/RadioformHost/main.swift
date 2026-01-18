import AudioToolbox
import CRadioformAudio
import CRadioformDSP
import CoreAudio
import Foundation

let deviceDiscovery = DeviceDiscovery()
let deviceRegistry = DeviceRegistry()
let memoryManager = SharedMemoryManager()
let dspProcessor = DSPProcessor(sampleRate: RadioformConfig.defaultSampleRate)
let proxyManager = ProxyDeviceManager(registry: deviceRegistry)
let renderer = AudioRenderer(
    memoryManager: memoryManager,
    dspProcessor: dspProcessor,
    proxyManager: proxyManager
)
let audioEngine = AudioEngine(renderer: renderer, registry: deviceRegistry)
let deviceMonitor = DeviceMonitor(
    registry: deviceRegistry,
    proxyManager: proxyManager,
    memoryManager: memoryManager,
    discovery: deviceDiscovery,
    audioEngine: audioEngine
)
let presetLoader = PresetLoader()
let presetMonitor = PresetMonitor(loader: presetLoader, processor: dspProcessor)

func main() {

    print("[Step 0] Setting up directories...")
    do {
        try PathManager.ensureDirectories()
        PathManager.migrateOldPreset()
        print("    ✓ Application Support: \(PathManager.appSupportDir.path)")
        print("    ✓ Logs: \(PathManager.logsDir.path)")
    } catch {
        print("[ERROR] Failed to create directories: \(error)")
        exit(1)
    }

    print("[Step 1] Discovering physical audio devices...")
    let devices = deviceDiscovery.enumeratePhysicalDevices()

    guard !devices.isEmpty else {
        print("[ERROR] No physical output devices found")
        exit(1)
    }

    let validatedDevices = devices.filter { $0.validationPassed }
    print("[✓] Found \(devices.count) physical output device(s) (\(validatedDevices.count) validated)")
    for device in devices {
        let status = device.validationPassed ? "✓" : "⚠"
        var line = "    \(status) \(device.name) (\(device.uid))"
        if let note = device.validationNote {
            line += " - \(note)"
        }
        print(line)
    }

    if validatedDevices.isEmpty {
        print("[WARNING] No validated devices found. Will attempt setup with available devices anyway.")
    }

    deviceRegistry.update(devices)

    print("[Step 2] Registering device change listeners...")
    deviceMonitor.registerListeners()

    print("[Step 3] Creating V2 shared memory files...")
    memoryManager.createMemory(for: devices)

    print("[Step 4] Writing control file...")
    deviceRegistry.writeControlFile()
    print("    ✓ Control file: \(RadioformConfig.controlFilePath)")
    print("    ✓ Preset file: \(RadioformConfig.presetFilePath)")

    print("[Step 5] Starting heartbeat monitor...")
    memoryManager.startHeartbeat()

    print("[Step 6] Waiting for driver to create proxy devices...")
    Thread.sleep(forTimeInterval: RadioformConfig.deviceWaitTimeout)

    print("[Step 7] Auto-selecting proxy device...")
    proxyManager.autoSelectProxy()

    print("[Step 8] Initializing DSP engine...")
    let bassBoost = dspProcessor.createBassBoostPreset()
    guard dspProcessor.applyPreset(bassBoost) else {
        print("[ERROR] Failed to apply EQ preset")
        exit(1)
    }

    print("[Step 9] Setting up audio engine with device fallback...")

    // Get the user's preferred device from proxy manager (set during autoSelectProxy)
    let preferredDeviceID = proxyManager.activePhysicalDeviceID
    if preferredDeviceID != 0 {
        if let preferredDevice = devices.first(where: { $0.id == preferredDeviceID }) {
            print("    Preferred device: \(preferredDevice.name)")
        } else {
            print("    Preferred device ID \(preferredDeviceID) not in device list")
        }
    }

    do {
        try audioEngine.setup(devices: devices, preferredDeviceID: preferredDeviceID != 0 ? preferredDeviceID : nil)
        try audioEngine.start()
        print("[✓] Audio engine started successfully")
    } catch let error as AudioEngineError {
        print("[ERROR] Audio engine setup failed: \(error.description)")
        if case .allDevicesFailed = error {
            print("[ERROR] All \(devices.count) device(s) failed to initialize.")
            print("[ERROR] This may indicate no functional audio output devices are available.")
        }
        exit(1)
    } catch {
        print("[ERROR] Audio engine setup failed: \(error)")
        exit(1)
    }

    presetMonitor.startMonitoring()

    setupSignalHandlers()

    print("[Signal] Handlers installed")

    RunLoop.current.run()
}

func setupSignalHandlers() {
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler {
        print("\n[Signal] Received SIGINT (Ctrl+C)")
        cleanup()
        exit(0)
    }
    sigintSource.resume()

    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler {
        print("\n[Signal] Received SIGTERM")
        cleanup()
        exit(0)
    }
    sigtermSource.resume()

    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
}

func cleanup() {
    print("\n[Cleanup] Starting cleanup process...")

    memoryManager.stopHeartbeat()

    _ = proxyManager.restorePhysicalDevice()

    audioEngine.stop()

    print("[Cleanup] Removing control file...")
    unlink(RadioformConfig.controlFilePath)

    Thread.sleep(forTimeInterval: RadioformConfig.cleanupWaitTimeout)

    memoryManager.cleanup()

    restartCoreAudio()

    print("[Cleanup] ✓ Complete")
}

private func restartCoreAudio() {
    // Force HAL to drop any lingering virtual devices by restarting coreaudiod
    let task = Process()
    task.launchPath = "/usr/bin/killall"
    task.arguments = ["-9", "coreaudiod"]

    do {
        try task.run()
        task.waitUntilExit()
        print("[Cleanup] Restarted coreaudiod (status \(task.terminationStatus))")
    } catch {
        print("[Cleanup] Failed to restart coreaudiod: \(error)")
    }
}

main()
