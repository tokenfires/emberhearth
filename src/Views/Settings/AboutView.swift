// AboutView.swift
// EmberHearth
//
// About tab: app info, version, links, system information.

import SwiftUI

/// About tab showing app information, version, links, and system info.
///
/// ## Accessibility
/// - All text supports Dynamic Type
/// - Links have accessibility labels and hints
/// - System info is grouped for VoiceOver
struct AboutView: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            // App Icon and Name
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                Text("EmberHearth")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Version \(appVersion), build \(buildNumber)")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("EmberHearth, version \(appVersion)")

            Text("A personal AI assistant for macOS")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Links
            VStack(spacing: 12) {
                if let repoURL = URL(string: "https://github.com/robault/emberhearth") {
                    Link(destination: repoURL) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .accessibilityHidden(true)
                            Text("View on GitHub")
                        }
                    }
                    .accessibilityLabel("View EmberHearth on GitHub")
                    .accessibilityHint("Opens the project repository in your browser")
                }

                if let issuesURL = URL(string: "https://github.com/robault/emberhearth/issues") {
                    Link(destination: issuesURL) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .accessibilityHidden(true)
                            Text("Report an Issue")
                        }
                    }
                    .accessibilityLabel("Report an issue")
                    .accessibilityHint("Opens the GitHub issues page in your browser")
                }
            }

            Divider()
                .padding(.horizontal, 40)

            // System Info
            VStack(alignment: .leading, spacing: 6) {
                systemInfoRow(label: "macOS", value: macOSVersion)
                systemInfoRow(label: "Build", value: buildNumber)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("System information")

            Spacer()

            Text("Made with care by TokenFires")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// A single row in the system info section.
    private func systemInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .monospaced()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// The app version string from the bundle.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// The build number from the bundle.
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// The macOS version string.
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
