import SwiftUI
import Foundation
import Darwin

@main
struct RadioformApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch audio host if not already running
        launchHostIfNeeded()

        // Hide from Dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Radioform")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover with menu content
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the host process when app quits
        hostProcess?.terminate()
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
        
        // Get possible base paths
        var possibleBasePaths: [String] = []
        
        // Try to find relative to app bundle
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
        
        // Build possible paths
        var possiblePaths: [String] = []
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
        
        // Also try absolute path based on current user (most reliable)
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
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
