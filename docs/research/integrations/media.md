# Media Apps Integration Research

**Status:** Complete
**Priority:** Medium
**Last Updated:** February 2, 2026

---

## Overview

This document covers integration with Apple's media apps: Music, TV, Podcasts, and Books. Each has different levels of API support.

---

# Music (Apple Music)

## User Value

| Capability | User Benefit |
|------------|--------------|
| Playback control | "Play my workout playlist" |
| Music discovery | "Find songs like this" |
| Library management | "Add this to my library" |
| Now playing | "What song is this?" |

## Technical Approach: MusicKit

MusicKit is Apple's official framework for Apple Music integration.

### Capabilities

| Feature | Support |
|---------|---------|
| Search catalog | Yes |
| Play music | Yes |
| User library access | Yes |
| Create playlists | Yes (iOS), Limited (macOS) |
| Recommendations | Yes |

### Implementation

```swift
import MusicKit

class MusicService {

    func requestAuthorization() async -> MusicAuthorization.Status {
        return await MusicAuthorization.request()
    }

    func search(query: String) async throws -> MusicItemCollection<Song> {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 10
        let response = try await request.response()
        return response.songs
    }

    func play(song: Song) async throws {
        let player = ApplicationMusicPlayer.shared
        player.queue = [song]
        try await player.play()
    }

    func getCurrentlyPlaying() -> MusicPlayer.Queue.Entry? {
        return ApplicationMusicPlayer.shared.queue.currentEntry
    }

    func getUserPlaylists() async throws -> MusicItemCollection<Playlist> {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()
        return response.items
    }
}
```

### Limitations

- **macOS Write APIs:** Creating/deleting playlists has issues on macOS
- **Apple Music subscription required** for catalog access
- **Local library only** without subscription

### Recommendation: **MEDIUM** feasibility due to macOS API limitations

---

# TV App

## User Value

| Capability | User Benefit |
|------------|--------------|
| New release alerts | "New episode of my show!" |
| Watch list management | Track what to watch |
| Content discovery | "Find shows like Breaking Bad" |

## Technical Approach

**Bad news:** The TV app has **very limited** automation support.

### AppleScript

- Basic AppleScript dictionary exists
- **Broken in macOS Tahoe** (current version)
- Limited to basic playback control

### Reality

- No API for watch lists
- No API for content catalog
- No notifications for new episodes
- Cannot query viewing history

### Workaround Ideas

1. **Use TV app URL schemes** to open specific content
2. **Scrape Apple TV+ website** for new releases (fragile)
3. **Use third-party APIs** (TMDB, TVDB) for show tracking

### Recommendation: **LOW** feasibility - No usable API exists

---

# Podcasts

## User Value

| Capability | User Benefit |
|------------|--------------|
| Episode updates | "Any new episodes today?" |
| Show discovery | "Find podcasts about AI" |
| Playback control | "Play latest episode of X" |

## Technical Approach

**No AppleScript support** for the Podcasts app.

### Current State

- No scripting dictionary
- Database accessible but undocumented
- Location: `~/Library/Group Containers/group.com.apple.podcasts/`

### Workarounds

1. **Podcast RSS feeds** - Parse feeds directly
2. **Apple Podcasts API** - For discovery (limited)
3. **Third-party apps** - Overcast, Pocket Casts have better automation

### Implementation (RSS-based)

```swift
func getLatestEpisodes(feedURL: URL) async throws -> [PodcastEpisode] {
    let (data, _) = try await URLSession.shared.data(from: feedURL)
    let parser = PodcastFeedParser(data: data)
    return parser.parseEpisodes()
}
```

### Recommendation: **LOW** feasibility for app automation, **MEDIUM** for RSS-based tracking

---

# Books

## User Value

| Capability | User Benefit |
|------------|--------------|
| Reading progress | "Where was I in my book?" |
| Book recommendations | "Find books like this" |
| Read-aloud | Accessibility feature |

## Technical Approach

**Limited automation support.**

### AppleScript

- Minimal scripting dictionary
- Cannot access reading progress
- Cannot control text-to-speech

### Native Text-to-Speech

macOS has system-wide TTS:

```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: "Text to read")
synthesizer.speak(utterance)
```

But this doesn't integrate with Books app content.

### Recommendation: **LOW** feasibility

---

# Voice Memos

## User Value

| Capability | User Benefit |
|------------|--------------|
| Transcription | Convert voice to text |
| Summarization | Condense long recordings |
| Search | Find recordings by content |

## Technical Approach

### macOS Sequoia+ Features

- **Native transcription** built into Voice Memos
- Files stored in `~/Library/Group Containers/group.com.apple.VoiceMemos/`

### SpeechAnalyzer (WWDC25)

New API for speech-to-text:

```swift
import Speech

// SpeechAnalyzer is the new API replacing SFSpeechRecognizer
// Available in iOS 26 / macOS 26
let analyzer = SpeechAnalyzer()
let transcription = try await analyzer.transcribe(audioURL)
```

### Current Workaround

```swift
import Speech

func transcribeAudio(url: URL) async throws -> String {
    let recognizer = SFSpeechRecognizer()
    let request = SFSpeechURLRecognitionRequest(url: url)

    return try await withCheckedThrowingContinuation { continuation in
        recognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let result = result, result.isFinal {
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
```

### Recommendation: **MEDIUM** feasibility with speech APIs

---

# Summary Table

| App | API Support | Feasibility | Notes |
|-----|-------------|-------------|-------|
| **Music** | MusicKit | Medium | macOS write APIs limited |
| **TV** | None | Low | AppleScript broken |
| **Podcasts** | None | Low | Use RSS feeds instead |
| **Books** | Minimal | Low | No useful automation |
| **Voice Memos** | Speech APIs | Medium | Transcription possible |

---

## Recommended Approach

### For Music
- Implement playback control and search
- Skip playlist creation on macOS
- Focus on "play this" use cases

### For TV/Podcasts
- Track shows via external APIs (TMDB, TVDB)
- Parse RSS feeds for podcasts
- Don't try to automate the apps directly

### For Voice Memos
- Use Speech framework for transcription
- Summarize transcripts with LLM
- Don't try to control the app

---

## Resources

- [MusicKit Documentation](https://developer.apple.com/documentation/musickit)
- [Apple Music API](https://developer.apple.com/documentation/applemusicapi)
- [Speech Framework](https://developer.apple.com/documentation/speech)
- [WWDC25: SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)
