# Files & iCloud Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

File management via FileManager and iCloud Drive allows EmberHearth to help users organize, find, and manage their documents through conversation.

## User Value

| Capability | User Benefit |
|------------|--------------|
| File organization | "Organize my Downloads folder" |
| Search files | "Find all PDFs from last month" |
| iCloud sync | Access files across devices |
| Backup suggestions | Identify important files for backup |
| Storage management | "What's taking up space?" |

---

## Technical Approach: FileManager

FileManager is Foundation's API for file system operations.

### Key Directories

| Directory | Purpose | Access |
|-----------|---------|--------|
| Documents | User documents | Full access |
| Downloads | Downloaded files | Full access |
| Desktop | Desktop files | Requires permission |
| iCloud Drive | Cloud-synced files | Requires capability |
| Application Support | App data | App-specific |

### Directory URLs

```swift
import Foundation

class FileService {
    private let fileManager = FileManager.default

    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var downloadsURL: URL {
        fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    var desktopURL: URL {
        fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    var iCloudURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
}
```

---

## Implementation

### Listing Files

```swift
func listFiles(in directory: URL, recursive: Bool = false) throws -> [URL] {
    let options: FileManager.DirectoryEnumerationOptions = recursive ? [] : [.skipsSubdirectoryDescendants]

    guard let enumerator = fileManager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
        options: options
    ) else {
        throw FileError.cannotEnumerate
    }

    var files: [URL] = []
    for case let fileURL as URL in enumerator {
        files.append(fileURL)
    }

    return files
}

func getFileInfo(_ url: URL) throws -> FileInfo {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)

    return FileInfo(
        name: url.lastPathComponent,
        path: url.path,
        size: attributes[.size] as? Int64 ?? 0,
        modificationDate: attributes[.modificationDate] as? Date,
        isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory
    )
}
```

### Searching Files

```swift
func searchFiles(
    in directory: URL,
    matching query: String,
    extensions: [String]? = nil
) throws -> [URL] {

    let allFiles = try listFiles(in: directory, recursive: true)

    return allFiles.filter { url in
        let matchesQuery = url.lastPathComponent.localizedCaseInsensitiveContains(query)

        if let extensions = extensions {
            let matchesExtension = extensions.contains(url.pathExtension.lowercased())
            return matchesQuery || matchesExtension
        }

        return matchesQuery
    }
}

func findLargeFiles(in directory: URL, largerThan bytes: Int64) throws -> [URL] {
    let allFiles = try listFiles(in: directory, recursive: true)

    return allFiles.filter { url in
        guard let size = try? getFileInfo(url).size else { return false }
        return size > bytes
    }.sorted { url1, url2 in
        let size1 = (try? getFileInfo(url1).size) ?? 0
        let size2 = (try? getFileInfo(url2).size) ?? 0
        return size1 > size2
    }
}

func findRecentFiles(in directory: URL, within days: Int) throws -> [URL] {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    let allFiles = try listFiles(in: directory, recursive: true)

    return allFiles.filter { url in
        guard let modDate = try? getFileInfo(url).modificationDate else { return false }
        return modDate > cutoffDate
    }
}
```

### Organizing Files

```swift
func createFolder(at url: URL) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func moveFile(from source: URL, to destination: URL) throws {
    try fileManager.moveItem(at: source, to: destination)
}

func copyFile(from source: URL, to destination: URL) throws {
    try fileManager.copyItem(at: source, to: destination)
}

func deleteFile(at url: URL) throws {
    try fileManager.removeItem(at: url)
}

// Organize by file type
func organizeByType(directory: URL) throws -> [String: [URL]] {
    let files = try listFiles(in: directory, recursive: false)

    var organized: [String: [URL]] = [:]

    for file in files {
        let category = categorizeFile(file)
        organized[category, default: []].append(file)
    }

    return organized
}

func categorizeFile(_ url: URL) -> String {
    let ext = url.pathExtension.lowercased()

    switch ext {
    case "pdf", "doc", "docx", "txt", "rtf", "pages":
        return "Documents"
    case "jpg", "jpeg", "png", "gif", "heic", "webp":
        return "Images"
    case "mp4", "mov", "avi", "mkv":
        return "Videos"
    case "mp3", "m4a", "wav", "aac":
        return "Audio"
    case "zip", "rar", "7z", "tar", "gz":
        return "Archives"
    case "dmg", "pkg", "app":
        return "Applications"
    default:
        return "Other"
    }
}
```

### iCloud Drive

```swift
func saveToiCloud(_ data: Data, filename: String) throws {
    guard let iCloudURL = iCloudURL else {
        throw FileError.iCloudNotAvailable
    }

    // Ensure iCloud Documents folder exists
    if !fileManager.fileExists(atPath: iCloudURL.path) {
        try fileManager.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
    }

    let fileURL = iCloudURL.appendingPathComponent(filename)
    try data.write(to: fileURL)
}

func listiCloudFiles() throws -> [URL] {
    guard let iCloudURL = iCloudURL else {
        throw FileError.iCloudNotAvailable
    }

    return try listFiles(in: iCloudURL)
}
```

### Storage Analysis

```swift
func analyzeStorage(directory: URL) throws -> StorageAnalysis {
    let files = try listFiles(in: directory, recursive: true)

    var totalSize: Int64 = 0
    var byCategory: [String: Int64] = [:]

    for file in files {
        guard let info = try? getFileInfo(file), !info.isDirectory else { continue }

        totalSize += info.size
        let category = categorizeFile(file)
        byCategory[category, default: 0] += info.size
    }

    return StorageAnalysis(
        totalSize: totalSize,
        fileCount: files.count,
        byCategory: byCategory
    )
}

func formatSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
```

---

## Permissions Required

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| User-Selected Files | Access user-chosen directories | NSOpenPanel |
| Downloads | Access Downloads folder | Entitlement |
| Desktop | Access Desktop folder | User permission |
| iCloud | iCloud Drive access | Capability + entitlement |
| Full Disk Access | Unrestricted file access | System Settings |

**Entitlements:**
```xml
<!-- User-selected files -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- iCloud -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
</array>
```

---

## EmberHearth Integration Design

### Conversation Examples

**User:** "What's taking up space in my Downloads?"
**EmberHearth:** "Your Downloads folder is using 8.2 GB:

**By Category:**
- Videos: 4.5 GB (3 files)
- Archives: 2.1 GB (12 files)
- Applications: 1.2 GB (5 DMGs)
- Documents: 0.4 GB (47 files)

**Largest Files:**
1. movie-backup.mp4 (2.1 GB)
2. project-files.zip (1.8 GB)
3. Xcode.dmg (1.2 GB)

Would you like me to help clean up?"

**User:** "Find all PDFs from last week"
**EmberHearth:** "I found 8 PDFs modified in the last 7 days:
1. Invoice-2026-02.pdf (Downloads)
2. Meeting-notes.pdf (Documents)
3. Contract-v2.pdf (Desktop)
[...]

Want me to organize these into a folder?"

**User:** "Organize my Downloads folder"
**EmberHearth:** "I can organize your Downloads into these folders:
- Documents (47 files)
- Images (23 files)
- Videos (3 files)
- Archives (12 files)
- Applications (5 files)
- Other (8 files)

This won't delete anything—just move files into organized folders. Proceed?"

**User:** "Back up my important documents to iCloud"
**EmberHearth:** "I'll copy your Documents folder to iCloud Drive:
- 234 files (1.2 GB total)
- Destination: iCloud Drive/Backups/Documents-2026-02-02

This will use 1.2 GB of your iCloud storage. Continue?"

### Proactive Suggestions

```
"Your Downloads folder is over 10 GB. Would you like me to help identify files you can safely remove?"

"I noticed 5 DMG installer files in your Downloads. These apps are already installed—want me to move them to Trash?"
```

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Sandbox restrictions | Limited directory access | Request specific entitlements |
| Desktop/Documents | Requires permission prompt | Guide user through grant |
| iCloud sync delays | Files may not be immediately available | Check download status |
| Large operations | Can be slow | Show progress, run async |

---

## Security Considerations

1. **Never delete without confirmation**
2. **Show exactly what will be moved/deleted**
3. **Offer undo for organizational changes**
4. **Don't access sensitive directories without explicit permission**
5. **Log file operations for user review**

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| List files | High | Low |
| Search files | High | Low |
| Storage analysis | Medium | Low |
| Create folders | Medium | Low |
| Move files | Medium | Low |
| iCloud backup | Low | Medium |
| Auto-organize | Low | Medium |

---

## Resources

- [FileManager Documentation](https://developer.apple.com/documentation/foundation/filemanager)
- [iCloud Drive Documentation](https://developer.apple.com/icloud/icloud-drive/)
- [App Sandbox File Access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

---

## Recommendation

**Feasibility: MEDIUM**

File management is useful but constrained by sandboxing. Benefits:

1. Real utility for organization
2. Standard Foundation APIs
3. iCloud integration for cross-device

**Challenges:**
- Permissions are complex
- Users may not grant Full Disk Access
- Careful UX needed for destructive operations

Focus on Downloads and Documents folders initially, which have more relaxed permission requirements.
