import Foundation

/// Errors that can occur when reading from the iMessage chat.db database.
enum ChatDatabaseError: LocalizedError {
    /// The chat.db file was not found at the expected path.
    /// This typically means Full Disk Access has not been granted.
    case databaseNotFound(path: String)

    /// The database file exists but could not be opened.
    /// May indicate corruption or an incompatible format.
    case databaseOpenFailed(underlyingError: Error)

    /// A SQL query failed to execute.
    case queryFailed(query: String, underlyingError: Error)

    /// The database is currently locked by another process.
    /// This can happen if Messages.app is actively writing.
    case databaseLocked

    /// A required column was missing from the query result.
    /// This may indicate a schema change in a newer macOS version.
    case schemaMismatch(details: String)

    /// The message date could not be converted from Apple's timestamp format.
    case dateConversionFailed(rawValue: Int64)

    var isDatabaseLocked: Bool {
        if case .databaseLocked = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "iMessage database not found at \(path). Please grant Full Disk Access in System Settings > Privacy & Security."
        case .databaseOpenFailed(let error):
            return "Failed to open iMessage database: \(error.localizedDescription)"
        case .queryFailed(let query, let error):
            return "Database query failed (\(query)): \(error.localizedDescription)"
        case .databaseLocked:
            return "iMessage database is temporarily locked. Will retry."
        case .schemaMismatch(let details):
            return "iMessage database schema mismatch: \(details)"
        case .dateConversionFailed(let rawValue):
            return "Failed to convert message date from raw value: \(rawValue)"
        }
    }
}
