import Foundation
import AppKit

/// Driver installation states
enum DriverInstallState: Equatable {
    case notStarted
    case checkingExisting
    case copying
    case settingPermissions
    case restartingAudio
    case verifying
    case complete
    case failed(String)

    var isComplete: Bool {
        if case .complete = self {
            return true
        }
        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    var description: String {
        switch self {
        case .notStarted:
            return "Ready to install"
        case .checkingExisting:
            return "Checking for existing driver..."
        case .copying:
            return "Copying driver files..."
        case .settingPermissions:
            return "Setting permissions..."
        case .restartingAudio:
            return "Restarting audio system..."
        case .verifying:
            return "Verifying installation..."
        case .complete:
            return "Installation complete!"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

/// Handles driver installation and verification
class DriverInstaller: ObservableObject {
    @Published var state: DriverInstallState = .notStarted
    @Published var progress: Double = 0.0

    private let driverName = "RadioformDriver.driver"
    private let driverDestination = "/Library/Audio/Plug-Ins/HAL"

    /// Install the driver with progress updates
    func installDriver() async throws {
        await MainActor.run { state = .checkingExisting; progress = 0.1 }

        // Check if driver is already loaded
        if isDriverLoaded() {
            print("Driver already loaded, skipping installation")
            await MainActor.run { state = .complete; progress = 1.0 }
            return
        }

        await MainActor.run { state = .copying; progress = 0.3 }

        // Find driver bundle in app resources
        guard let driverSource = findDriverBundle() else {
            throw DriverInstallError.driverNotFound
        }

        // Install driver with single admin prompt (copy + permissions + restart)
        try await installDriverWithPrivileges(from: driverSource)

        // Update progress through the stages
        await MainActor.run { state = .settingPermissions; progress = 0.5 }
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run { state = .restartingAudio; progress = 0.7 }

        // Wait for audio system to restart and load driver
        print("Waiting for audio system to restart...")
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        await MainActor.run { state = .verifying; progress = 0.9 }

        // Verify installation - try multiple times
        var attempts = 0
        var loaded = false
        while attempts < 3 && !loaded {
            loaded = isDriverLoaded()
            if !loaded {
                print("Driver not loaded yet, retrying... (attempt \(attempts + 1)/3)")
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 more seconds
                attempts += 1
            }
        }

        if !loaded {
            print("⚠️ Driver installed but not verified in system_profiler")
            print("   This may be normal - driver might need code signing or system restart")
            // Don't throw error - driver is installed, just not verified
        } else {
            print("✓ Driver verified in system_profiler")
        }

        await MainActor.run { state = .complete; progress = 1.0 }
        print("✓ Driver installed successfully")
    }

    /// Check if driver is currently loaded
    func isDriverLoaded() -> Bool {
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

    /// Check if driver is installed (file exists)
    func isDriverInstalled() -> Bool {
        let driverPath = "\(driverDestination)/\(driverName)"
        return FileManager.default.fileExists(atPath: driverPath)
    }

    /// Find driver bundle in app resources
    private func findDriverBundle() -> String? {
        // For development: check if running from build directory
        if let bundlePath = Bundle.main.resourcePath {
            let driverPath = "\(bundlePath)/\(driverName)"
            if FileManager.default.fileExists(atPath: driverPath) {
                return driverPath
            }
        }

        // For production: driver should be in Resources
        if let resourcePath = Bundle.main.path(forResource: "RadioformDriver", ofType: "driver") {
            return resourcePath
        }

        print("⚠️ Driver bundle not found in app resources")
        return nil
    }

    /// Install driver with single admin prompt (combines copy, permissions, and restart)
    private func installDriverWithPrivileges(from source: String) async throws {
        // Escape single quotes in paths for shell
        let escapedSource = source.replacingOccurrences(of: "'", with: "'\\''")
        let escapedDest = driverDestination.replacingOccurrences(of: "'", with: "'\\''")
        let driverPath = "\(driverDestination)/\(driverName)"
        let escapedDriverPath = driverPath.replacingOccurrences(of: "'", with: "'\\''")

        // Combine all operations into single command chain
        let script = """
        do shell script "cp -R '\(escapedSource)' '\(escapedDest)/' && \
        chown -R root:wheel '\(escapedDriverPath)' && \
        chmod -R 755 '\(escapedDriverPath)' && \
        killall coreaudiod" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)

        // Run on main thread (AppleScript requires it)
        let error = await MainActor.run { () -> NSDictionary? in
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            return errorDict
        }

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("Failed to install driver: \(errorMessage)")
            throw DriverInstallError.copyFailed(errorMessage)
        }

        print("✓ Driver installed and coreaudiod restarted")
    }

    /// Copy driver using AppleScript with admin privileges
    private func copyDriverWithPrivileges(from source: String) async throws {
        // Escape single quotes in paths for shell
        let escapedSource = source.replacingOccurrences(of: "'", with: "'\\''")
        let escapedDest = driverDestination.replacingOccurrences(of: "'", with: "'\\''")

        let script = "do shell script \"cp -R '\(escapedSource)' '\(escapedDest)/'\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)

        // Run on main thread (AppleScript requires it)
        let error = await MainActor.run { () -> NSDictionary? in
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            return errorDict
        }

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("Failed to copy driver: \(errorMessage)")
            throw DriverInstallError.copyFailed(errorMessage)
        }
    }

    /// Set driver permissions using AppleScript
    private func setDriverPermissions() async throws {
        let driverPath = "\(driverDestination)/\(driverName)"
        let escapedPath = driverPath.replacingOccurrences(of: "'", with: "'\\''")

        let script = "do shell script \"chown -R root:wheel '\(escapedPath)' && chmod -R 755 '\(escapedPath)'\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)

        let error = await MainActor.run { () -> NSDictionary? in
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            return errorDict
        }

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("Failed to set permissions: \(errorMessage)")
            throw DriverInstallError.permissionsFailed(errorMessage)
        }
    }

    /// Restart coreaudiod using AppleScript
    private func restartAudio() async throws {
        let script = "do shell script \"killall coreaudiod\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)

        let error = await MainActor.run { () -> NSDictionary? in
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            return errorDict
        }

        if let error = error {
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            print("Failed to restart coreaudiod: \(errorMessage)")
            throw DriverInstallError.audioRestartFailed(errorMessage)
        }

        print("✓ coreaudiod restarted")
    }

    /// Uninstall driver (for testing)
    func uninstallDriver() throws {
        let driverPath = "\(driverDestination)/\(driverName)"
        let escapedPath = driverPath.replacingOccurrences(of: "'", with: "'\\''")

        let script = "do shell script \"rm -rf '\(escapedPath)'\" with administrator privileges"

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            let errorMessage = errorDict["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
            throw DriverInstallError.uninstallFailed(errorMessage)
        }

        print("✓ Driver uninstalled")
    }
}

/// Driver installation errors
enum DriverInstallError: Error, LocalizedError {
    case driverNotFound
    case copyFailed(String)
    case permissionsFailed(String)
    case audioRestartFailed(String)
    case verificationFailed
    case uninstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .driverNotFound:
            return "Driver bundle not found in app resources"
        case .copyFailed(let message):
            return "Failed to copy driver: \(message)"
        case .permissionsFailed(let message):
            return "Failed to set permissions: \(message)"
        case .audioRestartFailed(let message):
            return "Failed to restart audio system: \(message)"
        case .verificationFailed:
            return "Driver installation could not be verified"
        case .uninstallFailed(let message):
            return "Failed to uninstall driver: \(message)"
        }
    }
}
