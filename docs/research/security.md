# macOS Security Primitives Research

**Status:** Complete
**Priority:** High (Phase 1)
**Last Updated:** February 2, 2026

---

## Executive Summary

macOS provides a comprehensive security architecture that EmberHearth should leverage fully. This document covers the key primitives:

| Technology | Purpose | EmberHearth Usage |
|------------|---------|-------------------|
| App Sandbox | Isolate app from system | Required for security |
| Hardened Runtime | Protect runtime integrity | Required for notarization |
| XPC Services | Process isolation | Separate privileged operations |
| Keychain Services | Secure credential storage | Store API keys |
| Secure Enclave | Hardware-backed keys | Encrypt local memory database |
| Code Signing | Verify app authenticity | Required for distribution |
| Notarization | Apple malware scan | Required for Gatekeeper |

**Key Recommendation:** EmberHearth should be distributed **outside the Mac App Store** (via Developer ID) to access Full Disk Access for iMessage integration, while still using App Sandbox, Hardened Runtime, and notarization for maximum security.

---

## 1. App Sandbox

### Overview

The App Sandbox confines each application to a restricted environment, preventing unauthorized access to system resources and user data. When enabled, an app:

- Cannot freely read/write files outside its container
- Has limited network access
- Cannot interact with other processes without explicit entitlements
- Runs with minimum necessary privileges

### Container Structure

Sandboxed apps operate within a container directory:

```
~/Library/Containers/com.emberhearth.app/
├── Data/
│   ├── Library/
│   │   ├── Application Support/
│   │   ├── Caches/
│   │   └── Preferences/
│   ├── Documents/
│   └── tmp/
```

### Enabling App Sandbox

In Xcode, add the entitlement to your `.entitlements` file:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

### Key Entitlements for EmberHearth

| Entitlement | Key | Purpose |
|-------------|-----|---------|
| Network (Outbound) | `com.apple.security.network.client` | Connect to LLM APIs |
| User-Selected Files (Read/Write) | `com.apple.security.files.user-selected.read-write` | Access user-approved files |
| Downloads (Read/Write) | `com.apple.security.files.downloads.read-write` | Save exports |
| Calendars | `com.apple.security.personal-information.calendars` | EventKit access |
| Contacts | `com.apple.security.personal-information.addressbook` | Contacts access |
| Location | `com.apple.security.personal-information.location` | Location services |
| Apple Events | `com.apple.security.automation.apple-events` | AppleScript (Messages.app) |
| Security-Scoped Bookmarks | `com.apple.security.files.bookmarks.app-scope` | Persistent file access |

### Sandbox Limitations for EmberHearth

**Critical Issue:** The `~/Library/Messages/chat.db` directory is protected. Sandboxed apps cannot access it even with entitlements.

**Solution:** Request **Full Disk Access** from users. This is a system-level permission that transcends the sandbox for specific protected directories. Apps distributed outside the App Store can request this.

### Temporary Exception Entitlements

If specific sandbox capabilities are missing, Apple provides temporary exceptions. However:
- Must be justified to App Review (if App Store)
- Should be avoided if possible
- May require filing a bug report with Apple

**Recommendation for EmberHearth:** Avoid temporary exceptions. Design around sandbox limitations or distribute outside App Store where Full Disk Access is viable.

---

## 2. Hardened Runtime

### Overview

The Hardened Runtime protects app runtime integrity by:
- Preventing code injection
- Blocking unauthorized library loading
- Protecting against memory manipulation
- Enforcing code signing at runtime

**Required for:** Notarization (and thus Gatekeeper approval)

### Enabling Hardened Runtime

In Xcode: Target → Signing & Capabilities → + Capability → Hardened Runtime

Or via command line:
```bash
codesign --sign "Developer ID Application: Your Name" \
         --options runtime \
         --timestamp \
         YourApp.app
```

### Runtime Exceptions (Entitlements)

The Hardened Runtime restricts certain behaviors. If needed, request specific exceptions:

| Entitlement | Key | Use Case |
|-------------|-----|----------|
| Allow Unsigned Executable Memory | `com.apple.security.cs.allow-unsigned-executable-memory` | JIT compilation |
| Allow DYLD Environment Variables | `com.apple.security.cs.allow-dyld-environment-variables` | Testing/debugging |
| Disable Library Validation | `com.apple.security.cs.disable-library-validation` | Load unsigned libraries |
| Disable Executable Memory Protection | `com.apple.security.cs.disable-executable-page-protection` | Rarely needed |
| Debugger | `com.apple.security.cs.debugger` | Debugging tools |
| Audio Input | `com.apple.security.device.audio-input` | Microphone access |
| Camera | `com.apple.security.device.camera` | Camera access |

**EmberHearth Requirements:**
- Audio Input — If voice input is planned
- No other runtime exceptions should be needed

### Hardened Runtime + Sandbox Interaction

These technologies are **independent but complementary**:
- Sandbox: Restricts what resources the app can access
- Hardened Runtime: Restricts how the app's code can execute

Both should be enabled for maximum security. They use separate entitlements but work together.

---

## 3. XPC Services

### Overview

XPC (XNU Inter-Process Communication) enables secure communication between processes. Key benefits:

- **Privilege Separation:** Each component runs with minimal permissions
- **Crash Isolation:** XPC service crashes don't affect the main app
- **Resource Efficiency:** Services launch on-demand, terminate when idle
- **Security Boundaries:** Validate connections via code signing

### Architecture Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                    EmberHearth Main App                      │
│                    (Minimal privileges)                      │
└──────────────┬────────────────────┬────────────────────────┘
               │ XPC                │ XPC
               ▼                    ▼
┌──────────────────────┐  ┌──────────────────────┐
│  MessageService.xpc   │  │  MemoryService.xpc   │
│  - Full Disk Access   │  │  - Database access   │
│  - Messages.app       │  │  - Encryption        │
└──────────────────────┘  └──────────────────────┘
```

### Implementation (Swift)

**Define Protocol:**
```swift
@objc protocol MessageServiceProtocol {
    func sendMessage(_ text: String, to recipient: String,
                     reply: @escaping (Bool, Error?) -> Void)
    func getNewMessages(since: Date,
                        reply: @escaping ([Message]?, Error?) -> Void)
}
```

**XPC Service (MessageService):**
```swift
class MessageService: NSObject, MessageServiceProtocol {
    func sendMessage(_ text: String, to recipient: String,
                     reply: @escaping (Bool, Error?) -> Void) {
        // Execute AppleScript to send via Messages.app
    }
}

// In main.swift of XPC service
let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
```

**Main App Connection:**
```swift
let connection = NSXPCConnection(serviceName: "com.emberhearth.MessageService")
connection.remoteObjectInterface = NSXPCInterface(with: MessageServiceProtocol.self)
connection.resume()

let service = connection.remoteObjectProxyWithErrorHandler { error in
    print("XPC error: \(error)")
} as? MessageServiceProtocol

service?.sendMessage("Hello", to: "+1234567890") { success, error in
    // Handle result
}
```

### Security: Code Signing Requirements

**Critical:** Always verify the connecting process via code signing:

```swift
// In XPC Service delegate
func listener(_ listener: NSXPCListener,
              shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

    // Verify the connection comes from our main app
    let requirement = "identifier \"com.emberhearth.app\" and anchor apple generic"

    var code: SecCode?
    SecCodeCopyGuestWithAttributes(nil,
        [kSecGuestAttributePid: newConnection.processIdentifier] as CFDictionary,
        [], &code)

    var requirement: SecRequirement?
    SecRequirementCreateWithString(requirement as CFString, [], &requirement)

    let status = SecCodeCheckValidity(code!, [], requirement)
    return status == errSecSuccess
}
```

**Recommended Library:** [SecureXPC](https://github.com/trilemma-dev/SecureXPC) — Simplifies secure XPC communication in pure Swift.

### XPC Service Entitlements

Each XPC service can have its own entitlements file, separate from the main app. This enables:
- Main app: Minimal entitlements
- MessageService.xpc: Full Disk Access, Automation
- MemoryService.xpc: Only file access to its container

### Lifecycle Management

- XPC services are managed by `launchd`
- Launched on-demand when connection is requested
- Terminated after idle timeout (configurable)
- Automatically restarted if crashed

---

## 4. Keychain Services

### Overview

The Keychain is Apple's secure credential storage system. It provides:
- Hardware-backed encryption (Secure Enclave on supported devices)
- Persistence across app reinstalls
- Optional iCloud synchronization
- Access control via biometrics or passcode

### What to Store in Keychain

| Data Type | Store in Keychain? |
|-----------|-------------------|
| API Keys | Yes |
| OAuth Tokens | Yes |
| Passwords | Yes |
| Encryption Keys | Yes (or Secure Enclave) |
| User Preferences | No (use UserDefaults) |
| Large Data | No (encrypt and store in files) |

### Accessibility Levels

Choose based on when the data needs to be accessed:

| Level | Constant | Use Case |
|-------|----------|----------|
| When Unlocked | `kSecAttrAccessibleWhenUnlocked` | Most credentials |
| After First Unlock | `kSecAttrAccessibleAfterFirstUnlock` | Background services |
| When Passcode Set | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | Highest security |
| Always (deprecated) | `kSecAttrAccessibleAlways` | **Never use** |

**EmberHearth Recommendation:** Use `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` for API keys. This:
- Requires device passcode to be set
- Prevents iCloud sync (stays on device)
- Provides maximum security

### Implementation (Swift)

**Store a credential:**
```swift
func storeAPIKey(_ key: String, service: String) throws {
    let data = key.data(using: .utf8)!

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "api-key",
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    ]

    // Delete existing item if present
    SecItemDelete(query as CFDictionary)

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.unableToStore(status)
    }
}
```

**Retrieve a credential:**
```swift
func retrieveAPIKey(service: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "api-key",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let key = String(data: data, encoding: .utf8) else {
        if status == errSecItemNotFound { return nil }
        throw KeychainError.unableToRetrieve(status)
    }

    return key
}
```

### Recommended Libraries

The raw Keychain API is verbose and error-prone. Consider:

- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) — Simple Swift wrapper
- [Valet](https://github.com/square/Valet) — Square's secure storage library
- [SwiftSecurity](https://github.com/dm-zharov/swift-security) — Modern Swift framework

### Best Practices

1. **Never log Keychain data** — Even in debug builds
2. **Handle errors gracefully** — Keychain can fail (locked, full, etc.)
3. **Use specific accessibility** — Don't default to "always accessible"
4. **Delete on logout** — Clean up credentials when user signs out
5. **Avoid iCloud sync for secrets** — Use `ThisDeviceOnly` variants
6. **Rotate keys periodically** — Implement key expiration if applicable

---

## 5. Secure Enclave

### Overview

The Secure Enclave is a hardware-based security coprocessor isolated from the main CPU. It provides:

- Hardware-isolated key storage
- Keys never leave the enclave
- Protected against software attacks, even with root access
- Available on Apple Silicon Macs and Intel Macs with T1/T2 chips

### Capabilities

| Feature | Supported |
|---------|-----------|
| Key Types | P-256 elliptic curve only |
| Operations | Sign, verify, key agreement |
| Storage | ~4MB for keys |
| Key Export | **Not possible** (by design) |

### Use Cases for EmberHearth

1. **Encrypt Memory Database:** Generate a key in Secure Enclave, use for SQLite encryption
2. **Sign Requests:** Cryptographically sign API requests (if needed)
3. **Biometric Protection:** Require Face ID/Touch ID to access keys

### Implementation (CryptoKit)

**Check availability:**
```swift
import CryptoKit

if SecureEnclave.isAvailable {
    // Secure Enclave is available
}
```

**Generate a key:**
```swift
let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// Store the private key representation (encrypted blob, not actual key)
let keyData = privateKey.dataRepresentation
// Save keyData to Keychain for later retrieval
```

**Sign data:**
```swift
let dataToSign = "Important message".data(using: .utf8)!
let signature = try privateKey.signature(for: dataToSign)

// Verify signature (can be done anywhere with public key)
let isValid = publicKey.isValidSignature(signature, for: dataToSign)
```

**Key Agreement (for encryption):**
```swift
let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey()
let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: otherPublicKey)

// Derive symmetric key
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data(),
    sharedInfo: Data(),
    outputByteCount: 32
)
```

### Important Warnings

1. **Device-Specific:** Keys cannot be transferred between devices
2. **No Backup:** If the device dies, keys are lost forever
3. **Clean Install Wipes Keys:** Factory reset destroys all Secure Enclave data
4. **P-256 Only:** No RSA, no other curves

**EmberHearth Strategy:**
- Use Secure Enclave for local encryption only
- Implement a recovery mechanism (e.g., user-provided password as backup key)
- Warn users that device loss = data loss without backup

---

## 6. Code Signing & Notarization

### Code Signing Overview

Code signing verifies:
- **Identity:** App comes from a known developer
- **Integrity:** App hasn't been modified since signing

### Certificate Types

| Certificate | Use Case | Distribution |
|-------------|----------|--------------|
| Apple Development | Development/testing | Local only |
| Apple Distribution | App Store submission | App Store |
| Developer ID Application | Direct distribution | Outside App Store |
| Developer ID Installer | PKG installers | Outside App Store |

**EmberHearth:** Use **Developer ID Application** for distribution outside App Store.

### Signing Command

```bash
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
         --options runtime \
         --timestamp \
         --deep \
         EmberHearth.app
```

Flags:
- `--options runtime`: Enable Hardened Runtime
- `--timestamp`: Include secure timestamp (required for notarization)
- `--deep`: Sign nested code (frameworks, XPC services)

### Notarization

Notarization is Apple's automated malware scan. Required for:
- Apps distributed outside the App Store (macOS 10.15+)
- Gatekeeper to recognize the app as safe

**Process:**
1. Build and sign app with Developer ID
2. Upload to Apple's notary service
3. Apple scans for malware
4. Receive ticket (or rejection)
5. Staple ticket to app

**Using notarytool (Xcode 14+):**
```bash
# Submit for notarization
xcrun notarytool submit EmberHearth.zip \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# Staple the ticket
xcrun stapler staple EmberHearth.app
```

### Notarization Requirements

1. **Hardened Runtime** must be enabled
2. **Timestamp** must be included in signature
3. **No** `com.apple.security.get-task-allow` entitlement (debug only)
4. **All code signed** — including frameworks, plugins, XPC services
5. **Developer ID certificate** — not Apple Development

### Gatekeeper Behavior

| Scenario | Gatekeeper Response |
|----------|-------------------|
| Signed + Notarized | Opens immediately |
| Signed, not notarized | Warning, user can override |
| Not signed | Blocked by default |
| Signature invalid/modified | Blocked, cannot override |

---

## 7. App Transport Security (ATS)

### Overview

ATS enforces secure network connections by default:
- HTTPS required (no HTTP)
- TLS 1.2 or later
- Forward secrecy required
- Strong cipher suites only

### Default Requirements

| Requirement | Specification |
|-------------|---------------|
| TLS Version | 1.2 or later |
| Certificate | SHA-256+, 2048-bit RSA or 256-bit ECC |
| Cipher Suites | ECDHE_ECDSA_AES or ECDHE_RSA_AES (GCM) |
| Forward Secrecy | Required |

### EmberHearth Compliance

All LLM API providers (Anthropic, OpenAI, etc.) use HTTPS with modern TLS. **No ATS exceptions should be needed.**

### If Exceptions Are Needed

Add to `Info.plist` (avoid if possible):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Never use** `NSAllowsArbitraryLoads` — this disables ATS entirely.

---

## 8. Security-Scoped Bookmarks

### Overview

Security-scoped bookmarks allow persistent access to user-selected files/folders across app launches. When a user selects a file via `NSOpenPanel`, you can:

1. Create a bookmark (encrypted reference)
2. Store the bookmark data
3. Resolve the bookmark later to regain access

### Required Entitlements

```xml
<!-- For files anywhere on the system -->
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>

<!-- For files associated with specific documents -->
<key>com.apple.security.files.bookmarks.document-scope</key>
<true/>
```

### Implementation

**Create bookmark:**
```swift
func createBookmark(for url: URL) throws -> Data {
    return try url.bookmarkData(
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
}
```

**Resolve bookmark:**
```swift
func resolveBookmark(_ data: Data) throws -> URL {
    var isStale = false
    let url = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    if isStale {
        // Bookmark needs refresh — re-request access from user
        throw BookmarkError.stale
    }

    // CRITICAL: Start accessing before using
    guard url.startAccessingSecurityScopedResource() else {
        throw BookmarkError.accessDenied
    }

    return url
}

// When done with the resource
func releaseAccess(to url: URL) {
    url.stopAccessingSecurityScopedResource()
}
```

### Recent Vulnerability (CVE-2025-31191)

A sandbox escape vulnerability was discovered and patched in 2025. The issue:
- Attackers could manipulate keychain entries used to sign bookmarks
- Allowed escaping sandbox without user interaction

**Mitigation:** Keep macOS updated. Apple patched this in macOS 15.4 and 14.7.5.

### EmberHearth Usage

Security-scoped bookmarks are useful for:
- Remembering user-selected export locations
- Accessing configuration files outside the container
- **Not needed for** iMessage (requires Full Disk Access instead)

---

## 9. Work/Personal Context Security

**Related:** `docs/research/work-personal-contexts.md`

EmberHearth maintains strict separation between work and personal contexts. This has significant security implications.

### Dual Database Isolation

Each context maintains a completely separate encrypted database:

```swift
// Separate storage paths
let personalDBPath = "~/Library/Application Support/EmberHearth/personal/memory.db"
let workDBPath = "~/Library/Application Support/EmberHearth/work/memory.db"

// Separate encryption keys (both in Secure Enclave)
let personalEncryptionKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
    accessControl: .biometryCurrentSet
)
let workEncryptionKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
    accessControl: .biometryCurrentSet
)
```

**Critical:** Even if one context is compromised, the other remains protected with a different key.

### Separate Keychain Access Groups

Use Keychain access groups to isolate credentials per context:

```swift
// Personal context credentials
let personalKeychainQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.emberhearth.personal",
    kSecAttrAccessGroup as String: "TEAM_ID.com.emberhearth.personal",
    // ...
]

// Work context credentials
let workKeychainQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.emberhearth.work",
    kSecAttrAccessGroup as String: "TEAM_ID.com.emberhearth.work",
    // ...
]
```

This prevents accidental cross-context credential access and provides cleaner audit boundaries.

### Per-Context LLM API Keys

Users may have different API configurations per context:

| Context | Typical Configuration |
|---------|----------------------|
| Personal | Claude API with user's personal key |
| Work | Local-only (corporate policy) or company-provided API key |

```swift
struct ContextLLMConfig {
    var context: Context
    var provider: LLMProvider
    var apiKey: String?  // nil for local-only
    var allowCloudAPI: Bool
    var localModelPath: String?
}

// Stored separately in respective Keychain access groups
let personalLLMKey = Keychain.get(service: "com.emberhearth.personal.llm")
let workLLMKey = Keychain.get(service: "com.emberhearth.work.llm")
```

### Audit Logging (Work Context)

Work context may require audit trails for compliance:

```swift
struct AuditLog {
    let context: Context = .work  // Only for work
    let dbPath: String

    func log(action: AuditAction) {
        // Append-only log, signed for integrity
        let entry = AuditEntry(
            timestamp: Date(),
            action: action.type,
            summary: action.sanitizedSummary,  // No sensitive content
            dataCategories: action.dataCategories,
            llmProvider: action.llmProvider
        )

        // Sign entry for tamper detection
        let signature = try signWithAuditKey(entry)
        appendToLog(entry, signature: signature)
    }
}

// Personal context does NOT log by default (privacy)
```

### Cross-Context Security Rules

| Rule | Enforcement |
|------|-------------|
| No cross-context database queries | Code architecture (separate DB connections) |
| No cross-context memory access | Context parameter required on all memory APIs |
| No cross-context LLM calls | Context determines which API key is used |
| Explicit confirmation for cross-context actions | UI prompt with what will be shared |

```swift
// Example: Cross-context action requires explicit user approval
func requestCrossContextAction(_ action: CrossContextAction) async -> Bool {
    let confirmation = await showConfirmationDialog(
        title: "Share to \(action.targetContext)?",
        message: "Only this will be shared:\n\(action.sanitizedSummary)",
        destructive: false
    )

    if confirmation {
        auditLog?.log(action: .crossContextShare(action))
    }

    return confirmation
}
```

### Work Context Policy Enforcement

Work context may have stricter security requirements:

```swift
struct WorkSecurityPolicy: Codable {
    // LLM restrictions
    var requireLocalLLM: Bool = true          // No cloud APIs
    var allowedProviders: [LLMProvider] = [.localMLX]

    // Data restrictions
    var maxRetentionDays: Int? = 90           // Auto-delete after 90 days
    var requireAuditLog: Bool = true          // Mandatory audit trail
    var allowExport: Bool = false             // Cannot export work data

    // Session restrictions
    var autoLockMinutes: Int? = 15            // Lock after inactivity
    var requireBiometricUnlock: Bool = true   // Biometric to access

    // Future: Admin-managed policies
    // var policyURL: URL?                    // Remote policy fetch
    // var policySignature: Data?             // Verify policy authenticity
}
```

### XPC Service Context Awareness

XPC services must be context-aware:

```swift
// MessageService.xpc
@objc protocol MessageServiceProtocol {
    func sendMessage(_ text: String,
                     to recipient: String,
                     context: String,  // "personal" or "work"
                     reply: @escaping (Bool, Error?) -> Void)

    func getNewMessages(since: Date,
                        context: String,  // Filters by phone number
                        reply: @escaping ([Message]?, Error?) -> Void)
}

// MemoryService.xpc
@objc protocol MemoryServiceProtocol {
    func storeMemory(_ memory: MemoryData,
                     context: String,  // Determines which DB
                     reply: @escaping (Bool, Error?) -> Void)

    func retrieveMemories(query: String,
                          context: String,  // Only searches one DB
                          reply: @escaping ([MemoryData]?, Error?) -> Void)
}
```

---

## Recommended Security Architecture for EmberHearth

### Distribution Strategy

**Distribute outside Mac App Store** via Developer ID because:
- Full Disk Access is required for iMessage integration
- App Store apps cannot reliably request Full Disk Access
- Direct distribution allows more flexibility

Still apply:
- App Sandbox (with appropriate entitlements)
- Hardened Runtime
- Notarization
- Code signing

### Process Architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                       EmberHearth.app (Main Process)                       │
│  Entitlements:                                                             │
│  - App Sandbox                                                             │
│  - Network Client                                                          │
│  - Calendars, Contacts (as needed)                                        │
│                                                                            │
│  Responsibilities:                                                         │
│  - UI rendering                                                            │
│  - User interaction                                                        │
│  - Context routing (personal vs work)                                      │
│  - Coordinate XPC services                                                 │
└────────────────┬───────────────────────┬───────────────────────┬──────────┘
                 │ XPC                   │ XPC                   │ XPC
                 ▼                       ▼                       ▼
┌────────────────────────┐ ┌────────────────────────┐ ┌─────────────────────┐
│  MessageService.xpc     │ │  MemoryService.xpc     │ │  LLMService.xpc     │
│                         │ │                        │ │                     │
│  Entitlements:          │ │  Entitlements:         │ │  Entitlements:      │
│  - Automation           │ │  - App Sandbox         │ │  - Network Client   │
│  - (Inherits FDA)       │ │                        │ │  - App Sandbox      │
│                         │ │  Responsibilities:     │ │                     │
│  Responsibilities:      │ │  - Context-scoped DB   │ │  Responsibilities:  │
│  - Read chat.db         │ │  - Personal memory.db  │ │  - Cloud API calls  │
│  - Route by phone #     │ │  - Work memory.db      │ │  - Local MLX runtime│
│  - Send via Messages    │ │  - Encryption per ctx  │ │  - Context routing  │
│  - Detect context       │ │  - Audit log (work)    │ │  - Policy enforce   │
└────────────────────────┘ └────────────────────────┘ └─────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
          ┌─────────────────────┐             ┌─────────────────────┐
          │  personal/          │             │  work/              │
          │  └── memory.db      │             │  └── memory.db      │
          │  └── conversations  │             │  └── conversations  │
          │  └── (Cloud OK)     │             │  └── audit.log      │
          │                     │             │  └── (Local only?)  │
          └─────────────────────┘             └─────────────────────┘
```

### Credential Storage Strategy

**Per-Context Credential Isolation:**

| Credential | Context | Storage Location | Accessibility |
|------------|---------|------------------|---------------|
| Personal LLM API Key | Personal | Keychain (personal group) | `WhenPasscodeSetThisDeviceOnly` |
| Work LLM API Key | Work | Keychain (work group) | `WhenPasscodeSetThisDeviceOnly` |
| Personal Memory DB Key | Personal | Secure Enclave | Biometric-protected |
| Work Memory DB Key | Work | Secure Enclave | Biometric-protected |
| User Preferences | Shared | UserDefaults | N/A (not sensitive) |
| Work Audit Log Key | Work | Secure Enclave | Append-only signing |

**Keychain Access Groups:**
```
TEAM_ID.com.emberhearth.personal  — Personal context credentials
TEAM_ID.com.emberhearth.work      — Work context credentials
TEAM_ID.com.emberhearth.shared    — Non-sensitive shared data
```

### Onboarding Security Flow

```
1. First Launch
   └── Check for passcode → Warn if not set (required for Keychain security)

2. Context Mode Selection
   └── Choose: Personal only / Work only / Both (recommended)
   └── If both: Explain two-session model

3. Phone Number Configuration (if both contexts)
   └── Assign personal iMessage number
   └── Assign work iMessage number
   └── Verify both are reachable

4. Account Mapping (if both contexts)
   └── Map email accounts to contexts
   └── Map calendars to contexts
   └── Map contact groups to contexts

5. API Key Setup (per context)
   └── Personal: Enter API key → Store in personal Keychain group
   └── Work: Enter API key OR select local-only → Store in work Keychain group

6. Permissions Setup
   └── Request Full Disk Access → Guide user through System Settings
   └── Test Messages.app automation → Request Automation permission

7. Database Setup (per context)
   └── Generate encryption key in Secure Enclave (separate keys!)
   └── Create personal/memory.db and work/memory.db
   └── Store key references in respective Keychain groups
   └── (Work) Initialize audit log if required by policy

8. Work Policy Configuration (if work context enabled)
   └── Configure retention period
   └── Enable/disable audit logging
   └── Set LLM restrictions (local-only, etc.)
```

---

## Security Checklist for EmberHearth

### Before Development

- [ ] Obtain Developer ID certificate from Apple
- [ ] Configure code signing in Xcode
- [ ] Enable Hardened Runtime
- [ ] Enable App Sandbox
- [ ] Define minimal entitlements
- [ ] Design Keychain access group structure (personal/work/shared)

### During Development

- [ ] Never log sensitive data (API keys, message content)
- [ ] Use Keychain for all credentials
- [ ] Validate all XPC connections via code signing
- [ ] Handle all Keychain/Secure Enclave errors gracefully
- [ ] Test with sandbox enabled (not just debug mode)
- [ ] Ensure context isolation (no cross-context data access)
- [ ] Pass context parameter to all memory/LLM operations
- [ ] Implement separate encryption keys per context

### Work/Personal Context Security

- [ ] Create separate database paths per context
- [ ] Generate separate Secure Enclave keys per context
- [ ] Use separate Keychain access groups per context
- [ ] Implement audit logging for work context
- [ ] Enforce LLM routing policies per context
- [ ] Require explicit confirmation for cross-context actions
- [ ] Test context isolation (verify no data leakage)

### Before Release

- [ ] Remove `get-task-allow` entitlement
- [ ] Verify all code is signed (including XPC services)
- [ ] Run notarization
- [ ] Staple notarization ticket
- [ ] Test on clean macOS installation
- [ ] Verify Gatekeeper accepts the app
- [ ] Test dual-context setup end-to-end

### Ongoing

- [ ] Monitor for macOS security updates
- [ ] Update dependencies for security patches
- [ ] Review entitlements periodically (remove unused)
- [ ] Test permission flows after macOS updates
- [ ] Verify work context audit logs are intact
- [ ] Confirm retention policy enforcement (work context)

---

## Resources

### Official Apple Documentation

- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [SecureEnclave (CryptoKit)](https://developer.apple.com/documentation/cryptokit/secureenclave)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)
- [Developer ID](https://developer.apple.com/developer-id/)

### Third-Party Resources

- [SecureXPC](https://github.com/trilemma-dev/SecureXPC) — Secure Swift XPC framework
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) — Swift Keychain wrapper
- [Valet](https://github.com/square/Valet) — Square's Keychain library
- [The Eclectic Light Company](https://eclecticlight.co/) — Excellent macOS security articles
- [XPC Services Tutorial](https://rderik.com/blog/xpc-services-on-macos-apps-using-swift/) — Swift XPC guide

### Security Research

- [Abusing & Securing XPC in macOS apps](https://github.com/securing/SimpleXPCApp) — Objective by the Sea talk
- [CVE-2025-31191 Analysis](https://www.microsoft.com/en-us/security/blog/2025/05/01/analyzing-cve-2025-31191-a-macos-security-scoped-bookmarks-based-sandbox-escape/) — Security-scoped bookmarks vulnerability

---

## Next Steps

1. **Set up Xcode project** with proper code signing and entitlements
2. **Implement Keychain wrapper** for API key storage
3. **Create XPC service architecture** for privilege separation
4. **Build permission onboarding flow** with clear user guidance
5. **Test security boundaries** — verify sandbox enforcement, XPC isolation
