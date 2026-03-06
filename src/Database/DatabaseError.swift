// DatabaseError.swift
// EmberHearth
//
// Database error types for the memory storage system.

import Foundation

enum DatabaseError: LocalizedError {
    case databaseNotFound(path: String)
    case failedToCreate(reason: String)
    case migrationFailed(fromVersion: Int, toVersion: Int, reason: String)
    case queryFailed(sql: String, reason: String)
    case corruptDatabase(reason: String)
    case invalidParameter(name: String, reason: String)
    case connectionClosed
    case backupFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "Database not found at path: \(path)"
        case .failedToCreate(let reason):
            return "Failed to create database: \(reason)"
        case .migrationFailed(let from, let to, let reason):
            return "Migration from v\(from) to v\(to) failed: \(reason)"
        case .queryFailed(let sql, let reason):
            return "Query failed (\(sql)): \(reason)"
        case .corruptDatabase(let reason):
            return "Database appears corrupt: \(reason)"
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .connectionClosed:
            return "Database connection is not open"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        }
    }
}
