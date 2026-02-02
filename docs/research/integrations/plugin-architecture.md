# Plugin Architecture Research

**Status:** Complete
**Priority:** Medium (Future)
**Last Updated:** February 2, 2026

---

## Overview

A plugin architecture would allow third-party developers and power users to extend EmberHearth's capabilities. This is key to building an ecosystem and supporting apps that EmberHearth doesn't natively integrate with.

## Goals

| Goal | Description |
|------|-------------|
| **Extensibility** | Support apps EmberHearth doesn't know about |
| **Security** | Plugins can't compromise user data |
| **Simplicity** | Easy for developers to create plugins |
| **Discoverability** | Users can find and install plugins easily |

---

## Plugin Capabilities

### What Plugins Should Be Able To Do

| Capability | Example |
|------------|---------|
| Add new commands | "Check my Todoist tasks" |
| Integrate third-party apps | Notion, Slack, Spotify |
| Custom automations | Company-specific workflows |
| Data providers | Custom news sources, APIs |
| Action handlers | Send to custom destinations |

### What Plugins Should NOT Be Able To Do

| Restriction | Reason |
|-------------|--------|
| Access all user data | Privacy |
| Execute arbitrary shell commands | Security |
| Modify core EmberHearth | Stability |
| Access other plugins' data | Isolation |
| Network without permission | Privacy |

---

## Architecture Options

### Option 1: Swift Package Plugins

Plugins as Swift packages loaded at runtime.

**Pros:**
- Native performance
- Type safety
- Full Swift capabilities

**Cons:**
- Requires developer tools to create
- Security sandboxing is complex
- Hard to distribute

### Option 2: JavaScript/TypeScript Plugins

Plugins run in a JavaScript sandbox (like VS Code extensions).

**Pros:**
- Large developer ecosystem
- Easy to sandbox
- Cross-platform potential

**Cons:**
- Performance overhead
- Need to embed JS runtime
- Different language than core app

### Option 3: Declarative Plugins (JSON/YAML)

Plugins defined as configuration files with limited capabilities.

**Pros:**
- Very simple to create
- Inherently limited (secure)
- No code execution

**Cons:**
- Limited capabilities
- Can't handle complex logic
- Not really "plugins"

### Option 4: XPC-Based Plugins (Recommended)

Plugins run as separate XPC services, communicating with EmberHearth via defined protocol.

**Pros:**
- Process isolation (crash safety)
- Sandboxable independently
- Native Swift
- Apple's recommended pattern

**Cons:**
- More complex to develop
- Need to define clear protocol
- Distribution challenges

---

## Recommended Approach: XPC Plugin Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    EmberHearth Core App                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Plugin Manager                        │   │
│  │  - Discovers installed plugins                           │   │
│  │  - Manages XPC connections                               │   │
│  │  - Routes commands to appropriate plugin                 │   │
│  │  - Enforces permissions                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │ XPC
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  Todoist Plugin  │ │  Notion Plugin   │ │  Slack Plugin    │
│  (XPC Service)   │ │  (XPC Service)   │ │  (XPC Service)   │
│                  │ │                  │ │                  │
│  Permissions:    │ │  Permissions:    │ │  Permissions:    │
│  - Network       │ │  - Network       │ │  - Network       │
│  - Keychain      │ │  - Keychain      │ │  - Keychain      │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

---

## Plugin Protocol

### Swift Protocol Definition

```swift
import Foundation

/// Protocol that all EmberHearth plugins must implement
@objc public protocol EmberHearthPlugin {

    /// Plugin metadata
    static var pluginName: String { get }
    static var pluginVersion: String { get }
    static var pluginAuthor: String { get }

    /// Capabilities this plugin provides
    static var capabilities: [PluginCapability] { get }

    /// Commands this plugin handles
    static var commands: [PluginCommand] { get }

    /// Initialize the plugin
    func initialize(config: PluginConfig, completion: @escaping (Bool, Error?) -> Void)

    /// Handle a command from the user
    func handleCommand(_ command: String, parameters: [String: Any],
                       completion: @escaping (PluginResult) -> Void)

    /// Cleanup when plugin is unloaded
    func shutdown()
}

public struct PluginCapability: Codable {
    let identifier: String
    let description: String
    let requiredPermissions: [Permission]
}

public struct PluginCommand: Codable {
    let trigger: String           // "todoist", "notion"
    let description: String       // "Manage Todoist tasks"
    let examplePhrases: [String]  // ["check my tasks", "add task"]
}

public enum PluginResult {
    case success(message: String)
    case failure(error: PluginError)
    case needsInput(prompt: String)
    case action(PluginAction)
}

public enum PluginAction {
    case sendMessage(String)
    case openURL(URL)
    case showNotification(title: String, body: String)
}
```

### Example Plugin Implementation

```swift
import Foundation
import EmberHearthPluginSDK

class TodoistPlugin: NSObject, EmberHearthPlugin {

    static var pluginName = "Todoist"
    static var pluginVersion = "1.0.0"
    static var pluginAuthor = "EmberHearth Community"

    static var capabilities: [PluginCapability] = [
        PluginCapability(
            identifier: "todoist.tasks",
            description: "Manage Todoist tasks",
            requiredPermissions: [.network, .keychain]
        )
    ]

    static var commands: [PluginCommand] = [
        PluginCommand(
            trigger: "todoist",
            description: "Manage Todoist tasks",
            examplePhrases: ["check my todoist", "add task to todoist", "what's on my todoist"]
        )
    ]

    private var apiToken: String?

    func initialize(config: PluginConfig, completion: @escaping (Bool, Error?) -> Void) {
        // Load API token from Keychain
        apiToken = config.getSecret("todoist_api_token")
        completion(apiToken != nil, nil)
    }

    func handleCommand(_ command: String, parameters: [String: Any],
                       completion: @escaping (PluginResult) -> Void) {

        if command.contains("check") || command.contains("list") {
            fetchTasks { tasks in
                let message = self.formatTasks(tasks)
                completion(.success(message: message))
            }
        } else if command.contains("add") {
            // Extract task from command
            if let taskText = parameters["task"] as? String {
                addTask(taskText) { success in
                    if success {
                        completion(.success(message: "Added task: \(taskText)"))
                    } else {
                        completion(.failure(error: .apiError("Failed to add task")))
                    }
                }
            } else {
                completion(.needsInput(prompt: "What task would you like to add?"))
            }
        }
    }

    func shutdown() {
        // Cleanup
    }

    // MARK: - Private

    private func fetchTasks(completion: @escaping ([Task]) -> Void) {
        // Call Todoist API
    }

    private func addTask(_ text: String, completion: @escaping (Bool) -> Void) {
        // Call Todoist API
    }

    private func formatTasks(_ tasks: [Task]) -> String {
        // Format for display
    }
}
```

---

## Permission System

### Permission Types

```swift
public enum Permission: String, Codable {
    case network            // Make HTTP requests
    case keychain           // Store/retrieve secrets
    case notifications      // Show notifications
    case calendar           // Access calendar (via EmberHearth)
    case contacts           // Access contacts (via EmberHearth)
    case files              // Access user-selected files
    case clipboard          // Read/write clipboard
}
```

### Permission Request Flow

```
1. User installs plugin
   ↓
2. EmberHearth reads plugin manifest
   ↓
3. EmberHearth shows permission dialog:
   "Todoist Plugin requests:
    ☑ Network access (to connect to Todoist)
    ☑ Keychain access (to store your API token)"
   ↓
4. User approves or denies
   ↓
5. Permissions stored, plugin loaded with granted permissions
```

### Enforcing Permissions

```swift
class PluginSandbox {
    private let grantedPermissions: Set<Permission>

    func checkPermission(_ permission: Permission) throws {
        guard grantedPermissions.contains(permission) else {
            throw PluginError.permissionDenied(permission)
        }
    }

    func makeNetworkRequest(url: URL) async throws -> Data {
        try checkPermission(.network)
        // Proceed with request
    }

    func storeSecret(key: String, value: String) throws {
        try checkPermission(.keychain)
        // Store in plugin-specific keychain
    }
}
```

---

## Plugin Distribution

### Option A: Plugin Directory (Recommended)

EmberHearth hosts a curated plugin directory:

1. Developer submits plugin
2. EmberHearth team reviews for:
   - Security vulnerabilities
   - Malicious behavior
   - Quality standards
3. Approved plugins listed in directory
4. Users browse and install from within EmberHearth

**Pros:** Centralized trust, quality control
**Cons:** Review bottleneck, maintenance burden

### Option B: Direct Installation

Users can install plugins directly from files:

1. Download `.emberplugin` bundle
2. Double-click to install
3. EmberHearth prompts for permissions
4. Plugin loaded

**Pros:** No review delay, flexibility
**Cons:** Security risk, users must trust sources

### Option C: Hybrid (Recommended)

- Curated directory for most users
- "Developer mode" for direct installation
- Clear warnings for non-directory plugins

---

## Plugin Manifest

```json
{
  "name": "Todoist Integration",
  "identifier": "com.example.emberhearth.todoist",
  "version": "1.0.0",
  "minEmberHearthVersion": "1.0.0",
  "author": {
    "name": "John Developer",
    "email": "john@example.com",
    "website": "https://example.com"
  },
  "description": "Manage your Todoist tasks through EmberHearth",
  "permissions": [
    "network",
    "keychain"
  ],
  "commands": [
    {
      "trigger": "todoist",
      "description": "Manage Todoist tasks",
      "examples": [
        "check my todoist",
        "add task buy milk to todoist"
      ]
    }
  ],
  "settings": [
    {
      "key": "todoist_api_token",
      "type": "secret",
      "label": "Todoist API Token",
      "description": "Get this from Todoist settings → Integrations"
    }
  ],
  "executable": "TodoistPlugin"
}
```

---

## Security Considerations

### Code Signing

All plugins must be signed:

```swift
func verifyPluginSignature(_ pluginURL: URL) throws {
    var staticCode: SecStaticCode?
    SecStaticCodeCreateWithPath(pluginURL as CFURL, [], &staticCode)

    var requirement: SecRequirement?
    SecRequirementCreateWithString(
        "anchor apple generic and certificate leaf[subject.O] = \"EmberHearth Plugins\"" as CFString,
        [], &requirement
    )

    let status = SecStaticCodeCheckValidity(staticCode!, [], requirement)
    guard status == errSecSuccess else {
        throw PluginError.invalidSignature
    }
}
```

### Sandboxing

Each plugin runs in its own sandbox:
- Separate container directory
- No access to other plugins' data
- No access to EmberHearth internals
- Network access restricted to declared domains (optional)

### Audit Logging

```swift
class PluginAuditLog {
    func logAction(plugin: String, action: String, details: [String: Any]) {
        // Log for user review
        // "Todoist Plugin accessed network: api.todoist.com"
    }
}
```

---

## Implementation Phases

### Phase 1: Internal Plugin System
- Plugin protocol definition
- XPC communication layer
- Permission system
- Basic plugin loading

### Phase 2: Developer SDK
- Plugin SDK package
- Documentation
- Example plugins
- Developer tools

### Phase 3: Plugin Directory
- Review process
- Hosting infrastructure
- In-app plugin browser
- Update mechanism

### Phase 4: Advanced Features
- Plugin settings UI
- Inter-plugin communication (limited)
- Plugin analytics (opt-in)
- Enterprise plugin deployment

---

## Resources

- [Apple: Plug-in Architectures](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/LoadingCode/Concepts/Plugins.html)
- [XPC Services Guide](https://developer.apple.com/documentation/xpc)
- [SecureXPC](https://github.com/trilemma-dev/SecureXPC)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [VS Code Extension Architecture](https://code.visualstudio.com/api/extension-guides/overview) - Inspiration

---

## Recommendation

**Feasibility: HIGH (but complex)**

A plugin architecture is absolutely achievable and would significantly expand EmberHearth's value. However:

1. **Don't build for v1** - Focus on core functionality first
2. **Design for it** - Keep the architecture plugin-friendly from the start
3. **Start simple** - Phase 1 could be internal-only plugins
4. **Security first** - Never compromise on sandboxing and permissions

The XPC-based approach is recommended because:
- Native to macOS
- Process isolation = crash safety
- Separate sandboxes = security
- Apple's endorsed pattern

Plan for plugins, but implement them in v2 or v3 once the core product is stable.
