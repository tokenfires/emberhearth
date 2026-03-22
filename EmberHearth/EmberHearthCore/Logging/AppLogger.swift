// AppLogger.swift
// EmberHearth
//
// Central logging infrastructure using Apple's unified logging system (os.Logger).

import Foundation
import os

/// Log categories for EmberHearth's subsystems.
///
/// Each category maps to a unique os.Logger instance with a specific category string.
/// Use `AppLogger.logger(for:)` to get the appropriate logger.
///
/// View logs in Console.app by filtering on subsystem "com.emberhearth".
enum LogCategory: String, CaseIterable, Sendable {
    /// General application lifecycle events (launch, shutdown, state changes).
    case app = "app"

    /// Security events (injection detection, credential scanning, pipeline decisions).
    case security = "security"

    /// Message processing events (new message detected, response sent).
    /// NEVER log message content in this category.
    case messages = "messages"

    /// Memory system events (fact extraction, retrieval, storage).
    case memory = "memory"

    /// LLM provider events (API calls, streaming, errors).
    /// NEVER log API keys or response content.
    case llm = "llm"

    /// Network events (connectivity changes, request failures).
    case network = "network"
}

/// Central logging facility for EmberHearth.
///
/// Provides categorized os.Logger instances using Apple's unified logging system.
/// All logs go to the macOS unified log and can be viewed in Console.app.
///
/// ## Usage
/// ```swift
/// let logger = AppLogger.logger(for: .security)
/// logger.info("Pipeline check passed for number: ...4567")
/// logger.error("Injection detected: pattern PI-001")
/// ```
///
/// ## Security Rules
/// - NEVER log message content, API keys, or credentials at any log level
/// - NEVER log full phone numbers — use only the last 4 digits
/// - Use `.public` privacy only for non-sensitive values (pattern IDs, threat levels, counts)
/// - All log messages with user data default to `.private` (redacted in non-debug logs)
enum AppLogger {

    /// The subsystem identifier for all EmberHearth loggers.
    static let subsystem = "com.emberhearth"

    /// Cache of logger instances keyed by category.
    /// Using nonisolated(unsafe) because Logger is thread-safe and we only
    /// write during first access of each category.
    private nonisolated(unsafe) static var loggers: [LogCategory: Logger] = [:]

    /// Returns a logger for the specified category.
    ///
    /// Logger instances are cached after first creation.
    ///
    /// - Parameter category: The log category.
    /// - Returns: An os.Logger configured with the EmberHearth subsystem and category.
    static func logger(for category: LogCategory) -> Logger {
        if let cached = loggers[category] {
            return cached
        }
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
}
