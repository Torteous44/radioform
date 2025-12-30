import SwiftUI
import Foundation
import Darwin
import AppKit
import CoreText
import CoreGraphics

@main
struct RadioformApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Check for --reset-onboarding flag
        if CommandLine.arguments.contains("--reset-onboarding") {
            OnboardingState.reset()
            print("🔄 Onboarding reset - will show on next launch")
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var hostProcess: Process?
    var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register custom font
        registerCustomFont()
        
    var onboardingCoordinator: OnboardingCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if onboarding is needed
        if !OnboardingState.hasCompleted() {
            showOnboarding()
            return
        }

        // Launch audio host if not already running
        launchHostIfNeeded()

        // Set up menu bar UI
        setupMenuBar()
    }

    func showOnboarding() {
        // Switch to regular activation policy to show window properly
        NSApp.setActivationPolicy(.regular)

        // Create and show onboarding
        onboardingCoordinator = OnboardingCoordinator()
        onboardingCoordinator?.show(onComplete: { [weak self] in
            print("📝 Onboarding completion callback called")
            self?.launchHostIfNeeded()
            self?.setupMenuBar()
            print("✓ Host and menu bar setup complete")
        })

        print("✓ Showing onboarding")
    }

    func setupMenuBar() {
        print("📝 setupMenuBar() called")

        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        print("📝 Activation policy set to .accessory")

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("📝 Status bar item created: \(statusItem != nil)")

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
            print("📝 Status bar button configured with waveform icon")
        } else {
            print("❌ Could not get status bar button!")
        }

        // Create popover with menu content
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 600)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
        
        // Set up event monitor to dismiss popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.popover?.performClose(event)
            }
        }
        print("✓ Menu bar setup complete - icon should be visible")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the host process when app quits
        hostProcess?.terminate()
    }

    func checkAndLoadDriverIfNeeded() {
        // Check if Radioform driver is already loaded
        if isDriverLoaded() {
            print("✓ Radioform driver already loaded, no need to restart coreaudiod")
            return
        }

        print("⚠️  Radioform driver not detected, attempting to load...")

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
            print("✓ coreaudiod restarted successfully")
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
        var logoURL: URL?
        let fileManager = FileManager.default
        
        // Try bundle resources first (production)
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = (resourcePath as NSString).appendingPathComponent("Resources/logo.svg")
            if fileManager.fileExists(atPath: bundlePath) {
                logoURL = URL(fileURLWithPath: bundlePath)
            }
        }
        
        // Fall back to source directory (development)
        if logoURL == nil {
            if let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent
                let sourcePath = (executableDir as NSString).appendingPathComponent("../../../Sources/Resources/logo.svg")
                let normalizedPath = (sourcePath as NSString).standardizingPath
                if fileManager.fileExists(atPath: normalizedPath) {
                    logoURL = URL(fileURLWithPath: normalizedPath)
                }
            }
        }
        
        // Try absolute path as last resort (development from repo root)
        if logoURL == nil {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let absolutePath = "\(homeDir)/radioform-1/apps/mac/RadioformApp/Sources/Resources/logo.svg"
            if fileManager.fileExists(atPath: absolutePath) {
                logoURL = URL(fileURLWithPath: absolutePath)
            }
        }
        
        guard let url = logoURL else {
            return nil
        }
        
        // Load SVG (NSImage supports SVG on macOS 10.15+)
        if let image = NSImage(contentsOf: url) {
            // Resize to appropriate menu bar size (typically 18-22px)
            let size = NSSize(width: 16, height: 16)
            let resizedImage = NSImage(size: size)
            resizedImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
            resizedImage.unlockFocus()
            return resizedImage
        }
        
        return nil
    }
    
    func registerCustomFont() {
        var fontPath: String?
        let fileManager = FileManager.default
        
        // Try bundle resources first (production)
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = (resourcePath as NSString).appendingPathComponent("Resources/fonts/SignPainterHouseScript.ttf")
            if fileManager.fileExists(atPath: bundlePath) {
                fontPath = bundlePath
            }
        }
        
        // Fall back to source directory (development)
        if fontPath == nil {
            if let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent
                let sourcePath = (executableDir as NSString).appendingPathComponent("../../../Sources/Resources/fonts/SignPainterHouseScript.ttf")
                let normalizedPath = (sourcePath as NSString).standardizingPath
                if fileManager.fileExists(atPath: normalizedPath) {
                    fontPath = normalizedPath
                }
            }
        }
        
        // Try absolute path as last resort (development from repo root)
        if fontPath == nil {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
            let absolutePath = "\(homeDir)/radioform-1/apps/mac/RadioformApp/Sources/Resources/fonts/SignPainterHouseScript.ttf"
            if fileManager.fileExists(atPath: absolutePath) {
                fontPath = absolutePath
            }
        }
        
        guard let path = fontPath, let url = URL(fileURLWithPath: path) as URL? else {
            return
        }
        
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
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
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
