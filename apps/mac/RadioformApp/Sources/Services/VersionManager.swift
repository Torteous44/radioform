import Foundation

/// Manages version reading and comparison across Radioform components
struct VersionManager {

	// MARK: - App Version

	/// Get current app version from bundle
	static func appVersion() -> String? {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
	}

	/// Get current app build number
	static func appBuildNumber() -> String? {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}

	// MARK: - Driver Versions

	/// Get installed driver version from /Library/Audio/Plug-Ins/HAL/
	static func installedDriverVersion() -> String? {
		let driverPath = "/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver/Contents/Info.plist"

		guard FileManager.default.fileExists(atPath: driverPath),
			  let plistData = FileManager.default.contents(atPath: driverPath),
			  let plist = try? PropertyListSerialization.propertyList(
				from: plistData,
				options: [],
				format: nil
			  ) as? [String: Any],
			  let version = plist["CFBundleShortVersionString"] as? String else {
			return nil
		}

		return version
	}

	/// Get bundled driver version (from app resources)
	static func bundledDriverVersion() -> String? {
		guard let driverPath = findBundledDriver() else {
			return nil
		}

		let plistPath = "\(driverPath)/Contents/Info.plist"

		guard FileManager.default.fileExists(atPath: plistPath),
			  let plistData = FileManager.default.contents(atPath: plistPath),
			  let plist = try? PropertyListSerialization.propertyList(
				from: plistData,
				options: [],
				format: nil
			  ) as? [String: Any],
			  let version = plist["CFBundleShortVersionString"] as? String else {
			return nil
		}

		return version
	}

	// MARK: - Driver Status

	/// Check if driver is installed at system level
	static func isDriverInstalled() -> Bool {
		let driverPath = "/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver"
		return FileManager.default.fileExists(atPath: driverPath)
	}

	/// Check if driver needs update (bundled version > installed version)
	static func driverNeedsUpdate() -> Bool {
		guard let installedVersion = installedDriverVersion(),
			  let bundledVersion = bundledDriverVersion() else {
			// If driver not installed, it needs installation (not update)
			return false
		}

		// Only update if bundled version is newer than installed version
		return isVersionOlder(installedVersion, than: bundledVersion)
	}

	// MARK: - Version Comparison

	/// Compare two semantic versions
	/// - Returns: true if v1 < v2, false otherwise
	static func isVersionOlder(_ v1: String, than v2: String) -> Bool {
		let components1 = v1.split(separator: ".").compactMap { Int($0) }
		let components2 = v2.split(separator: ".").compactMap { Int($0) }

		for i in 0..<max(components1.count, components2.count) {
			let c1 = i < components1.count ? components1[i] : 0
			let c2 = i < components2.count ? components2[i] : 0

			if c1 < c2 { return true }
			if c1 > c2 { return false }
		}

		return false
	}

	/// Compare two semantic versions for equality
	static func areVersionsEqual(_ v1: String, _ v2: String) -> Bool {
		return v1 == v2
	}

	// MARK: - Bundle Discovery

	/// Find bundled driver in app resources
	private static func findBundledDriver() -> String? {
		// Search in main bundle resources
		if let bundlePath = Bundle.main.resourcePath {
			let driverPath = "\(bundlePath)/RadioformDriver.driver"
			if FileManager.default.fileExists(atPath: driverPath) {
				return driverPath
			}
		}

		// Search using Bundle API
		if let resourcePath = Bundle.main.path(forResource: "RadioformDriver", ofType: "driver") {
			return resourcePath
		}

		// Development: Check relative path from project root
		let fm = FileManager.default
		if let currentPath = Bundle.main.executablePath {
			let projectRoot = (currentPath as NSString).deletingLastPathComponent
				.appending("/../../../../../packages/driver/build/RadioformDriver.driver")

			let normalizedPath = (projectRoot as NSString).standardizingPath
			if fm.fileExists(atPath: normalizedPath) {
				return normalizedPath
			}
		}

		return nil
	}

	// MARK: - Formatted Display

	/// Get formatted version string for display (e.g., "v1.0.15")
	static func formattedAppVersion() -> String {
		guard let version = appVersion() else {
			return "Unknown"
		}
		return "v\(version)"
	}

	/// Get detailed version string including build number
	static func detailedAppVersion() -> String {
		guard let version = appVersion() else {
			return "Unknown"
		}

		if let build = appBuildNumber(), build != "1" {
			return "v\(version) (build \(build))"
		}

		return "v\(version)"
	}
}
