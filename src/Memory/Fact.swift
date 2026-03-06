// Fact.swift
// EmberHearth
//
// Data model for a stored fact about the user.

import Foundation

struct Fact: Identifiable, Codable, Equatable {
    let id: Int64
    var content: String
    var category: FactCategory
    var source: FactSource
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date
    var lastAccessed: Date?
    var accessCount: Int
    var importance: Double
    var isDeleted: Bool

    static func create(
        content: String,
        category: FactCategory,
        source: FactSource = .extracted,
        confidence: Double = 0.8,
        importance: Double = 0.5
    ) -> Fact {
        let now = Date()
        return Fact(
            id: 0,
            content: content,
            category: category,
            source: source,
            confidence: confidence,
            createdAt: now,
            updatedAt: now,
            lastAccessed: nil,
            accessCount: 0,
            importance: importance,
            isDeleted: false
        )
    }
}

enum FactCategory: String, Codable, CaseIterable {
    case preference
    case relationship
    case biographical
    case event
    case opinion
    case contextual
    case secret
}

enum FactSource: String, Codable {
    case extracted
    case explicit
}
