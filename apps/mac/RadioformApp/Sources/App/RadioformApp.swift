import SwiftUI
import Foundation

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
        // Find the host executable
        let possiblePaths = [
            "/Users/mattporteous/radioform/packages/host/.build/release/RadioformHost",
            "/Users/mattporteous/radioform/packages/host/.build/debug/RadioformHost"
        ]

        guard let hostPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("ERROR: Could not find RadioformHost executable")
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
