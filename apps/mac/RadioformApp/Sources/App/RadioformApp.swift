import SwiftUI
import Foundation
import Darwin
import AppKit
import CoreText
import CoreGraphics
import CoreAudio
import Sparkle

// Main entry point - AppKit-based app with SwiftUI views
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var hostProcess: Process?
    var eventMonitor: EventMonitor?
    var onboardingCoordinator: OnboardingCoordinator?
    var updaterController: SPUStandardUpdaterController?
    var driverUpdateWindow: DriverUpdateWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register custom font
        registerCustomFont()

        // Initialize Sparkle updater
        initializeUpdater()

        // Check if onboarding is needed
        if !OnboardingState.hasCompleted() {
            // Will switch to .regular in showOnboarding()
            showOnboarding()
            return
        }

        // Onboarding complete - run as menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Check for driver version mismatch (lazy update)
        checkDriverVersionMismatch()

        // Launch audio host if not already running
        launchHostIfNeeded()

        // Set up menu bar UI
        setupMenuBar()
    }

    func initializeUpdater() {
        // Initialize Sparkle with standard user driver
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        print("✓ Sparkle updater initialized")

        // Trigger a background check on launch so updates are offered immediately
        updaterController?.updater.checkForUpdatesInBackground()
    }

    func checkDriverVersionMismatch() {
        // Only check if driver is already installed
        guard VersionManager.isDriverInstalled() else {
            print("Driver not installed - skipping version check")
            return
        }

        // Check for version mismatch
        if VersionManager.driverNeedsUpdate() {
            let installedVersion = VersionManager.installedDriverVersion() ?? "unknown"
            let bundledVersion = VersionManager.bundledDriverVersion() ?? "unknown"

            print("Driver version mismatch detected:")
            print("  Installed: \(installedVersion)")
            print("  Bundled: \(bundledVersion)")

            // Only prompt if we haven't already prompted for this version
            if OnboardingState.lastDriverVersionCheck() != bundledVersion {
                // Show update prompt
                showDriverUpdatePrompt(
                    currentVersion: installedVersion,
                    newVersion: bundledVersion
                )

                // Mark this version as checked
                OnboardingState.updateLastDriverVersionCheck(bundledVersion)
            } else {
                print("Already prompted for version \(bundledVersion), skipping")
            }
        } else {
            print("✓ Driver version is up to date")
        }
    }

    func showDriverUpdatePrompt(currentVersion: String, newVersion: String) {
        // Close existing window if any
        driverUpdateWindow?.close()

        // Create and show driver update window
        driverUpdateWindow = DriverUpdateWindow(
            currentVersion: currentVersion,
            newVersion: newVersion,
            onUpdate: { [weak self] in
                self?.performDriverUpdate()
            },
            onDismiss: { [weak self] in
                self?.driverUpdateWindow?.close()
                self?.driverUpdateWindow = nil
            }
        )

        driverUpdateWindow?.center()
        driverUpdateWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func performDriverUpdate() {
        // Close the update window
        driverUpdateWindow?.close()
        driverUpdateWindow = nil

        // Use existing DriverInstaller logic
        let installer = DriverInstaller()

        Task {
            do {
                try await installer.installDriver()
                print("✓ Driver updated successfully")

                // Show success alert
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Driver Updated"
                    alert.informativeText = "The Radioform audio driver has been updated to version \(VersionManager.bundledDriverVersion() ?? "unknown")."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            } catch {
                print("Driver update failed: \(error)")
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Update Failed"
                    alert.informativeText = "Failed to update driver: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    func showOnboarding() {
        // Switch to regular activation policy to show window properly
        NSApp.setActivationPolicy(.regular)

        // Create and show onboarding
        onboardingCoordinator = OnboardingCoordinator()
        onboardingCoordinator?.show(onComplete: { [weak self] in
            print("Onboarding completion callback called")
            self?.launchHostIfNeeded()
            self?.setupMenuBar()
            print("Host and menu bar setup complete")
        })

        print("Showing onboarding")
    }

    func setupMenuBar() {
        print("setupMenuBar() called")

        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        print("Activation policy set to .accessory")

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("Status bar item created: \(statusItem != nil)")

        if let button = statusItem?.button {
            // Load logo SVG and set as template for light/dark mode adaptation
            if let logoImage = loadLogoImage() {
                logoImage.isTemplate = true // Makes it adapt to light/dark mode
                button.image = logoImage
            } else {
                // Fallback to system icon if logo fails to load
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Radioform")
            }
            button.action = #selector(togglePopover)
            button.target = self
            print("Status bar button configured with waveform icon")
        } else {
            print("ERROR: Could not get status bar button!")
        }

        // Create popover with menu content
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.animates = false
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
        
        // Set up event monitor to dismiss popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.popover?.performClose(event)
            }
        }
        print("Menu bar setup complete - icon should be visible")
    }

    func applicationWillTerminate(_ notification: Notification) {
        let logsDir = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("Logs/Radioform")

        try? FileManager.default.createDirectory(
            at: logsDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let logFile = logsDir.appendingPathComponent("app.log").path

        func log(_ message: String) {
            let timestamp = Date()
            let logMessage = "[\(timestamp)] \(message)\n"
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile) {
                    if let handle = FileHandle(forWritingAtPath: logFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: URL(fileURLWithPath: logFile))
                }
            }
            print(message)
        }

        log("=== applicationWillTerminate CALLED ===")

        // Perform cleanup directly from the app
        performCleanup(logger: log)

        terminateHostAndProxies(logger: log)

        log("=== applicationWillTerminate COMPLETE ===")
    }

    /// Best-effort fallback to stop any running RadioformHost even if we did not launch it.
    private func terminateHostAndProxies(logger: (String) -> Void) {
        if let process = hostProcess, process.isRunning {
            logger("Terminating tracked host process (pid \(process.processIdentifier))...")
            process.terminate()
            waitForProcessExit(process, timeout: 0.3, logger: logger)
            if process.isRunning {
                logger("Host still running, sending SIGKILL")
                kill(process.processIdentifier, SIGKILL)
            }
        }

        logger("Attempting best-effort shutdown via pgrep/kill for any remaining hosts")

        let pgrep = Process()
        pgrep.launchPath = "/usr/bin/pgrep"
        pgrep.arguments = ["-f", "RadioformHost"]

        let pipe = Pipe()
        pgrep.standardOutput = pipe
        pgrep.standardError = Pipe()

        do {
            try pgrep.run()
            pgrep.waitUntilExit()
        } catch {
            logger("Failed to run pgrep: \(error)")
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .compactMap({ Int32($0) }),
              !output.isEmpty else {
            logger("No additional RadioformHost processes found")
            return
        }

        for pid in output {
            guard pid != getpid() else { continue }
            logger("Sending SIGTERM to RadioformHost pid \(pid)")
            kill(pid, SIGTERM)
            if !waitForPIDExit(pid, timeout: 0.3) {
                logger("PID \(pid) still alive, sending SIGKILL")
                kill(pid, SIGKILL)
            }
        }

        // Remove any lingering shared memory/control files so the driver tears down proxies
        cleanupTempIPC(logger: logger)
    }

    /// Poll a Process for exit up to timeout seconds.
    private func waitForProcessExit(_ process: Process, timeout: TimeInterval, logger: (String) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            logger("Process \(process.processIdentifier) did not exit within \(timeout)s")
        }
    }

    /// Poll a PID for exit up to timeout seconds.
    private func waitForPIDExit(_ pid: Int32, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if kill(pid, 0) != 0 {
                return true // no longer running
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return kill(pid, 0) != 0
    }

    /// Clean up temporary files that keep proxies alive.
    private func cleanupTempIPC(logger: (String) -> Void) {
        let fm = FileManager.default
        let controlFile = "/tmp/radioform-devices.txt"
        if fm.fileExists(atPath: controlFile) {
            logger("Removing control file \(controlFile)")
            unlink(controlFile)
        }

        // Remove shared memory files the driver might watch
        if let tmpItems = try? fm.contentsOfDirectory(atPath: "/tmp") {
            for item in tmpItems where item.hasPrefix("radioform-") {
                let path = "/tmp/\(item)"
                logger("Removing shared memory file \(path)")
                unlink(path)
            }
        }
    }

    func performCleanup(logger: (String) -> Void = { print($0) }) {
        logger("[Cleanup] Starting cleanup process...")

        // 1. Restore default device to physical device (if currently on proxy)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var currentDeviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        if AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &currentDeviceID
        ) == noErr {
            // Get current device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<CFString>.size)

            if AudioObjectGetPropertyData(currentDeviceID, &nameAddress, 0, nil, &nameSize, &deviceName) == noErr,
               let name = deviceName?.takeUnretainedValue() as String? {

                // If currently on a Radioform proxy, switch back to physical device
                if name.contains("Radioform") {
                    logger("[Cleanup] Currently on proxy device: \(name)")

                    // Get proxy UID
                    var uidAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceUID,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )

                    var deviceUID: Unmanaged<CFString>?
                    var uidSize = UInt32(MemoryLayout<CFString>.size)

                    if AudioObjectGetPropertyData(currentDeviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr,
                       let proxyUIDStr = deviceUID?.takeUnretainedValue() as String? {

                        // Extract physical device UID (remove "-radioform" suffix)
                        if let physicalUID = proxyUIDStr.components(separatedBy: "-radioform").first {
                            logger("[Cleanup] Looking for physical device with UID: \(physicalUID)")

                            // Find the physical device
                            if let physicalDeviceID = findDeviceByUID(physicalUID) {
                                logger("[Cleanup] Restoring default device to physical device (ID: \(physicalDeviceID))")

                                var newDeviceID = physicalDeviceID
                                let result = AudioObjectSetPropertyData(
                                    AudioObjectID(kAudioObjectSystemObject),
                                    &propertyAddress,
                                    0,
                                    nil,
                                    UInt32(MemoryLayout<AudioDeviceID>.size),
                                    &newDeviceID
                                )

                                if result == noErr {
                                    logger("[Cleanup] Restored to physical device")
                                    // Give system time to switch
                                    Thread.sleep(forTimeInterval: 0.3)
                                } else {
                                    logger("[Cleanup] WARNING: Failed to restore device (error \(result))")
                                }
                            } else {
                                logger("[Cleanup] WARNING: Could not find physical device with UID: \(physicalUID)")
                            }
                        }
                    }
                } else {
                    logger("[Cleanup] Already on physical device: \(name)")
                }
            }
        }

        // 2. Remove control file - driver will detect and remove proxies
        let controlFilePath = "/tmp/radioform-devices.txt"
        logger("[Cleanup] Removing control file: \(controlFilePath)")
        unlink(controlFilePath)

        // 3. Wait for driver to remove devices (driver checks every 1 second)
        logger("[Cleanup] Waiting for driver to remove proxy devices...")
        Thread.sleep(forTimeInterval: 1.5)

        logger("[Cleanup] Cleanup complete")
    }

    func findDeviceByUID(_ targetUID: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return nil
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return nil
        }

        // Find device with matching UID
        for deviceID in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceUID: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<CFString>.size)

            if AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr,
               let uid = deviceUID?.takeUnretainedValue() as String? {
                if uid == targetUID {
                    return deviceID
                }
            }
        }

        return nil
    }

    func checkAndLoadDriverIfNeeded() {
        // Check if Radioform driver is already loaded
        if isDriverLoaded() {
            print("Radioform driver already loaded, no need to restart coreaudiod")
            return
        }

        print("WARNING: Radioform driver not detected, attempting to load...")

        // Check if driver is installed
        let driverPath = "/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver"
        guard FileManager.default.fileExists(atPath: driverPath) else {
            showAlert("Driver Not Installed", "Radioform driver is not installed at \(driverPath)\n\nPlease run setup.sh first.")
            return
        }

        // Attempt to restart coreaudiod
        // This uses AppleScript to request admin privileges
        let script = """
        do shell script "killall coreaudiod" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            print("Failed to restart coreaudiod: \(error)")
            showAlert("Driver Load Failed", "Could not restart coreaudiod. You may need to manually run:\nsudo killall coreaudiod")
        } else {
            print("coreaudiod restarted successfully")
            // Wait a bit for coreaudiod to restart
            Thread.sleep(forTimeInterval: 2.0)
        }
    }

    func isDriverLoaded() -> Bool {
        // Use system_profiler to check if Radioform devices are visible
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPAudioDataType"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("Radioform")
            }
        } catch {
            print("Failed to check driver status: \(error)")
        }

        return false
    }

    func launchHostIfNeeded() {
        // Check if RadioformHost is already running
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "RadioformHost"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output.isEmpty {
            // Host not running, launch it
            print("Launching RadioformHost...")
            startHost()
        } else {
            print("RadioformHost already running (PID: \(output))")
        }
    }

    func startHost() {
        // Find the host executable - try multiple possible locations
        let fileManager = FileManager.default
        var possiblePaths: [String] = []

        // PRIORITY 1: Check for embedded binary in .app bundle (for distribution)
        if let executablePath = Bundle.main.executableURL?.deletingLastPathComponent().path {
            let embeddedHost = "\(executablePath)/RadioformHost"
            possiblePaths.append(embeddedHost)
        }

        // PRIORITY 2: Development builds - relative to app bundle
        var possibleBasePaths: [String] = []

        if let appPath = Bundle.main.bundlePath as String? {
            // If running from Xcode/build, go up to project root
            let appURL = URL(fileURLWithPath: appPath)
            if appPath.contains("/RadioformApp/") {
                let projectRoot = appURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                possibleBasePaths.append(projectRoot.path)
            }
        }

        // Try current working directory
        if let cwd = fileManager.currentDirectoryPath as String? {
            possibleBasePaths.append(cwd)
        }

        // Try home directory
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            possibleBasePaths.append("\(homeDir)/radioform")
        }

        // Build development paths
        for basePath in possibleBasePaths {
            // Try release build (with architecture subdirectory)
            if let arch = getArchitecture() {
                possiblePaths.append("\(basePath)/packages/host/.build/\(arch)/release/RadioformHost")
            }
            possiblePaths.append("\(basePath)/packages/host/.build/release/RadioformHost")
            // Try debug build
            if let arch = getArchitecture() {
                possiblePaths.append("\(basePath)/packages/host/.build/\(arch)/debug/RadioformHost")
            }
            possiblePaths.append("\(basePath)/packages/host/.build/debug/RadioformHost")
        }

        // Also try absolute path based on current user
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            if let arch = getArchitecture() {
                possiblePaths.append("\(homeDir)/radioform/packages/host/.build/\(arch)/release/RadioformHost")
            }
            possiblePaths.append("\(homeDir)/radioform/packages/host/.build/release/RadioformHost")
        }

        // Try environment variable if set
        if let radioformRoot = ProcessInfo.processInfo.environment["RADIOFORM_ROOT"] {
            if let arch = getArchitecture() {
                possiblePaths.append("\(radioformRoot)/packages/host/.build/\(arch)/release/RadioformHost")
            }
            possiblePaths.append("\(radioformRoot)/packages/host/.build/release/RadioformHost")
        }

        guard let hostPath = possiblePaths.first(where: { fileManager.fileExists(atPath: $0) }) else {
            print("ERROR: Could not find RadioformHost executable")
            print("Searched in:")
            for path in possiblePaths {
                print("  - \(path)")
            }
            showAlert("Radioform Host Not Found", "Please build the host first:\ncd packages/host && swift build -c release")
            return
        }

        hostProcess = Process()
        hostProcess?.launchPath = hostPath
        hostProcess?.arguments = []

        // Capture output for debugging
        let outputPipe = Pipe()
        hostProcess?.standardOutput = outputPipe
        hostProcess?.standardError = outputPipe

        hostProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard self != nil else { return }
                print("RadioformHost terminated (status: \(process.terminationStatus), reason: \(process.terminationReason.rawValue))")
                NSApp.terminate(nil)
            }
        }

        do {
            try hostProcess?.run()
            print("Started RadioformHost at: \(hostPath)")
        } catch {
            print("Failed to launch host: \(error)")
            showAlert("Failed to Launch Host", error.localizedDescription)
        }
    }

    func getArchitecture() -> String? {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let arch = String(cString: machine)
        
        // Map to SwiftPM architecture names
        if arch.contains("arm64") {
            return "arm64-apple-macosx"
        } else if arch.contains("x86_64") {
            return "x86_64-apple-macosx"
        }
        return nil
    }
    
    func loadLogoImage() -> NSImage? {
        let fileManager = FileManager.default
        var logoURL: URL?

        // PRIORITY 1: Try using Bundle's resource API (works across bundle structures)
        // First try to find the resource bundle
        if let resourceBundleURL = Bundle.main.url(forResource: "RadioformApp_RadioformApp", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let logoPath = resourceBundle.url(forResource: "icons/radioform-menu", withExtension: "svg") {
            print("Found menu icon via resource bundle API: \(logoPath.path)")
            logoURL = logoPath
        }

        // PRIORITY 2: Try SwiftPM resource bundle (production builds)
        // SwiftPM creates a separate bundle named "<Target>_<Target>.bundle"
        if logoURL == nil, let executableURL = Bundle.main.executableURL {
            let bundleName = "RadioformApp_RadioformApp.bundle"
            let resourceBundleURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName)
                .appendingPathComponent("Resources/icons/radioform-menu.svg")

            if fileManager.fileExists(atPath: resourceBundleURL.path) {
                print("Found logo in SwiftPM bundle: \(resourceBundleURL.path)")
                logoURL = resourceBundleURL
            }
        }

        // PRIORITY 3: Try main bundle's built-in resource lookup
        if logoURL == nil, let mainBundleURL = Bundle.main.url(forResource: "icons/radioform-menu", withExtension: "svg") {
            print("Found menu icon via main bundle: \(mainBundleURL.path)")
            logoURL = mainBundleURL
        }

        // PRIORITY 4: Try main bundle resources (alternative bundle structure)
        if logoURL == nil, let resourcePath = Bundle.main.resourcePath {
            let possiblePaths = [
                "\(resourcePath)/Resources/icons/radioform-menu.svg",
                "\(resourcePath)/icons/radioform-menu.svg"
            ]

            for path in possiblePaths {
                if fileManager.fileExists(atPath: path) {
                    print("Found logo in main bundle: \(path)")
                    logoURL = URL(fileURLWithPath: path)
                    break
                }
            }
        }

        // PRIORITY 5: Development - relative to executable
        if logoURL == nil, let executablePath = Bundle.main.executablePath {
            let executableDir = (executablePath as NSString).deletingLastPathComponent
            let sourcePath = (executableDir as NSString).appendingPathComponent("../../../Sources/Resources/icons/radioform-menu.svg")
            let normalizedPath = (sourcePath as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath) {
                print("Found logo in development Sources: \(normalizedPath)")
                logoURL = URL(fileURLWithPath: normalizedPath)
            }
        }

        // PRIORITY 6: Development - absolute path from repo root
        if logoURL == nil {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let absolutePath = "\(homeDir)/radioform/apps/mac/RadioformApp/Sources/Resources/icons/radioform-menu.svg"
            if fileManager.fileExists(atPath: absolutePath) {
                print("Found menu icon at absolute path: \(absolutePath)")
                logoURL = URL(fileURLWithPath: absolutePath)
            }
        }

        guard let url = logoURL else {
            print("Failed to find radioform-menu.svg in any location")
            return nil
        }

        // Load SVG (NSImage supports SVG on macOS 10.15+)
        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image from: \(url.path)")
            return nil
        }

        // Resize to appropriate menu bar size (typically 18-22px)
        let size = NSSize(width: 16, height: 16)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        resizedImage.unlockFocus()

        print("Successfully loaded and resized logo")
        return resizedImage
    }
    
    func registerCustomFont() {
        let fileManager = FileManager.default
        var fontURL: URL?

        // PRIORITY 1: Try using Bundle's resource API (works across bundle structures)
        if let resourceBundleURL = Bundle.main.url(forResource: "RadioformApp_RadioformApp", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let fontPath = resourceBundle.url(forResource: "fonts/SignPainterHouseScript", withExtension: "ttf") {
            print("Found font via resource bundle API: \(fontPath.path)")
            fontURL = fontPath
        }

        // PRIORITY 2: Try SwiftPM resource bundle (production builds)
        if fontURL == nil, let executableURL = Bundle.main.executableURL {
            let bundleName = "RadioformApp_RadioformApp.bundle"
            let resourceBundleURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName)
                .appendingPathComponent("Resources/fonts/SignPainterHouseScript.ttf")

            if fileManager.fileExists(atPath: resourceBundleURL.path) {
                print("Found font in SwiftPM bundle: \(resourceBundleURL.path)")
                fontURL = resourceBundleURL
            }
        }

        // PRIORITY 3: Try main bundle's built-in resource lookup
        if fontURL == nil, let mainBundleURL = Bundle.main.url(forResource: "fonts/SignPainterHouseScript", withExtension: "ttf") {
            print("Found font via main bundle: \(mainBundleURL.path)")
            fontURL = mainBundleURL
        }

        // PRIORITY 4: Try main bundle resources (alternative bundle structure)
        if fontURL == nil, let resourcePath = Bundle.main.resourcePath {
            let possiblePaths = [
                "\(resourcePath)/Resources/fonts/SignPainterHouseScript.ttf",
                "\(resourcePath)/fonts/SignPainterHouseScript.ttf"
            ]

            for path in possiblePaths {
                if fileManager.fileExists(atPath: path) {
                    print("Found font in main bundle: \(path)")
                    fontURL = URL(fileURLWithPath: path)
                    break
                }
            }
        }

        // PRIORITY 5: Development - relative to executable
        if fontURL == nil, let executablePath = Bundle.main.executablePath {
            let executableDir = (executablePath as NSString).deletingLastPathComponent
            let sourcePath = (executableDir as NSString).appendingPathComponent("../../../Sources/Resources/fonts/SignPainterHouseScript.ttf")
            let normalizedPath = (sourcePath as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath) {
                print("Found font in development Sources: \(normalizedPath)")
                fontURL = URL(fileURLWithPath: normalizedPath)
            }
        }

        // PRIORITY 6: Development - absolute path from repo root
        if fontURL == nil {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let absolutePath = "\(homeDir)/radioform/apps/mac/RadioformApp/Sources/Resources/fonts/SignPainterHouseScript.ttf"
            if fileManager.fileExists(atPath: absolutePath) {
                print("Found font at absolute path: \(absolutePath)")
                fontURL = URL(fileURLWithPath: absolutePath)
            }
        }

        guard let url = fontURL else {
            print("Failed to find SignPainterHouseScript.ttf in any location")
            return
        }

        var error: Unmanaged<CFError>?
        let result = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if result {
            print("Successfully registered custom font")
        } else if let error = error {
            print("Failed to register font: \(error.takeRetainedValue())")
        }
    }
    
    func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
                eventMonitor?.stop()
            } else {
                // Position the popover directly below the menu bar button
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Make popover window key immediately for proper glass effect
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.makeKeyAndOrderFront(nil)
                }

                // On macOS 15+ (Tahoe/Sequoia), NSPopover positioning can be off on external
                // monitors. Manually reposition if needed.
                if #available(macOS 15.0, *) {
                    if let popoverWindow = popover.contentViewController?.view.window,
                       let buttonWindow = button.window {
                        let buttonScreenFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
                        let popoverFrame = popoverWindow.frame

                        // Calculate where the popover should be: directly below the button
                        let targetY = buttonScreenFrame.minY - popoverFrame.height

                        // Only adjust if there's a significant gap (more than 10 pixels)
                        if abs(popoverFrame.maxY - buttonScreenFrame.minY) > 10 {
                            popoverWindow.setFrameOrigin(NSPoint(x: popoverFrame.origin.x, y: targetY))
                        }
                    }
                }

                eventMonitor?.start()
            }
        }
    }
}

// EventMonitor to detect clicks outside the popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// Main entry point - check for command-line flags before launching app
extension AppDelegate {
    static func main() {
        // Check for --reset-onboarding flag
        if CommandLine.arguments.contains("--reset-onboarding") {
            OnboardingState.reset()
            print("Onboarding reset - will show on next launch")
        }

        // Launch the app
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
