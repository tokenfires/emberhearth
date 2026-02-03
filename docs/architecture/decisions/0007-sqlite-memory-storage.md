# ADR-0007: SQLite for Memory and Conversation Storage

## Status
**Accepted**

## Date
February 2026

## Context

EmberHearth needs persistent storage for:
- **Facts:** Learned information about the user
- **Conversation archive:** Historical conversation chunks
- **Session state:** Current conversation context
- **Preferences:** User settings and configuration

Requirements:
- Local-only (no cloud sync of personal data)
- Encrypted at rest
- Queryable (search facts, retrieve by date)
- Performant for read-heavy workloads
- Future: Vector similarity search for embeddings

## Decision

**Use SQLite as the primary storage engine.**

Storage layout:
```
~/Library/Application Support/EmberHearth/
├── personal/
│   ├── memory.db        # Facts database
│   ├── archive.db       # Conversation archive
│   └── session.json     # Current session state
├── work/
│   ├── memory.db
│   ├── archive.db
│   ├── session.json
│   └── audit.log        # Work context audit trail
└── shared/
    └── preferences.db   # Non-sensitive settings
```

Each context (personal/work) has isolated databases.

## Consequences

### Positive
- **Battle-tested:** SQLite is the most deployed database
- **No server:** Embedded, local-only
- **ACID:** Reliable transactions
- **Queryable:** Full SQL for complex queries
- **Tooling:** Excellent debugging/inspection tools
- **Apple-native:** Used throughout macOS/iOS
- **Vector support:** sqlite-vec extension for embeddings (future)

### Negative
- **Schema migrations:** Must handle upgrades between versions
- **Concurrent writes:** Single-writer limitation (fine for our use)
- **Binary format:** Not human-readable without tools

### Neutral
- **Encryption:** Use SQLCipher or macOS Data Protection
- **Backup:** User can backup Application Support folder

## Schema Design

### Facts Table (memory.db)
```sql
CREATE TABLE facts (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    category TEXT,              -- preference, relationship, event, etc.
    confidence REAL DEFAULT 1.0,
    emotional_intensity REAL DEFAULT 0.5,
    source_type TEXT,           -- conversation, calendar, inferred
    source_reference TEXT,
    created_at DATETIME,
    last_accessed DATETIME,
    access_count INTEGER DEFAULT 0,
    decay_factor REAL DEFAULT 1.0,
    is_deleted INTEGER DEFAULT 0,
    deleted_at DATETIME
);

CREATE INDEX idx_facts_category ON facts(category);
CREATE INDEX idx_facts_created ON facts(created_at);
```

### Conversation Archive (archive.db)
```sql
CREATE TABLE conversation_chunks (
    id TEXT PRIMARY KEY,
    start_time DATETIME,
    end_time DATETIME,
    summary TEXT,
    emotional_tone TEXT,
    message_count INTEGER,
    raw_messages TEXT,          -- JSON array
    embedding BLOB              -- Future: vector for similarity search
);

CREATE INDEX idx_chunks_time ON conversation_chunks(start_time);
```

## Encryption Strategy

**Option A: SQLCipher**
- AES-256 encryption
- Transparent to application code
- Cross-platform

**Option B: macOS Data Protection**
- Use FileProtection attributes
- Leverages Secure Enclave
- macOS-native

**Recommendation:** Use macOS Data Protection for MVP (simpler), consider SQLCipher if cross-platform becomes relevant.

## Migration Strategy

```swift
struct MigrationManager {
    static let currentVersion = 1

    func migrate(database: Connection) throws {
        let version = try database.userVersion

        if version < 1 {
            try migrateToV1(database)
        }
        // Future migrations...

        try database.setUserVersion(Self.currentVersion)
    }
}
```

## Alternatives Considered

### Core Data
- Apple's ORM
- Rejected: Overkill for our needs; SQLite gives more control

### JSON Files
- Simple, human-readable
- Rejected: Not queryable; poor performance at scale

### Realm
- Mobile-focused database
- Rejected: Additional dependency; SQLite is sufficient

### Cloud Database (Firebase, etc.)
- Sync across devices
- Rejected: Violates privacy-first principle; adds cloud dependency

## Future: Vector Search

When implementing semantic memory search:
- Use `sqlite-vec` extension
- Store embeddings as BLOB in archive.db
- Query: `SELECT * FROM chunks ORDER BY vec_distance(embedding, ?) LIMIT 10`

## References

- `docs/research/memory-learning.md` — Memory system design
- `docs/research/work-personal-contexts.md` — Context separation
- `docs/research/security.md` — Encryption requirements
