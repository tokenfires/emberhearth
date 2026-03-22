import Foundation

/// Application version information.
///
/// Update these constants for each release. Values must match
/// CFBundleShortVersionString and CFBundleVersion in Info.plist.
enum AppVersion {
    /// User-facing version number (semantic versioning).
    static let version = "1.0.0"

    /// Internal build number, incremented with each release build.
    static let build = "1"

    /// Combined display string, e.g. "1.0.0 (1)".
    static var displayString: String {
        "\(version) (\(build))"
    }
}
