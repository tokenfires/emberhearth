# TokenFires Twitch Streaming Guide

**For:** EmberHearth Development Streams
**Date:** February 3, 2026
**Status:** Pre-Stream Planning

---

## The Pitch (Refined)

> **TokenFires** is building **EmberHearth**, a privacy-first AI assistant for Apple devices—live on Twitch.
>
> Using Claude (Anthropic's AI) to build an AI that lives in your iMessage. Like Moltbot/OpenClaw, but secure. Built the Apple way.
>
> Burning through tokens. Building something real.

**The hook:** You're using AI to build AI. Meta, but practical. Viewers watch the sausage get made.

---

## Part 1: Technical Setup

### OBS Settings (Recommended for Coding)

```
Video:
├── Base Resolution: 1920x1080 (your monitor)
├── Output Resolution: 1920x1080 (or 1280x720 if bandwidth limited)
├── FPS: 30 (for coding, 60fps is overkill and wastes bandwidth)

Output:
├── Encoder: Hardware (NVENC, QuickSync, or Apple VT for M-series)
├── Rate Control: CBR
├── Bitrate: 4500-6000 kbps (depending on your upload)
├── Keyframe Interval: 2
├── Preset: Quality (Intel) or P6 (NVIDIA)

Audio:
├── Sample Rate: 48kHz
├── Channels: Stereo
├── Bitrate: 160 kbps
```

**Apple Silicon Note:** OBS 32.0+ has an experimental Metal renderer for M-series Macs. Use "Apple VT H264 Hardware Encoder" for better performance.

### Scenes Setup

Create these scenes in OBS:

| Scene | When to Use | Sources |
|-------|-------------|---------|
| **Starting Soon** | Pre-stream countdown | Logo, countdown timer, music |
| **Coding** | Main development work | IDE window, webcam/avatar, chat |
| **Full Screen Code** | Deep focus moments | IDE only (full screen) |
| **iPhone Demo** | Testing EmberHearth | iPhone screen capture, webcam |
| **Chat Focus** | Engaging with viewers | Webcam large, chat overlay |
| **BRB** | Breaks | Logo, "Be Right Back" text, music |
| **End Screen** | Wrapping up | Raid target, socials, thank yous |

### Audio Setup

**Minimum viable:** Your Mac's built-in mic (surprisingly decent on Apple Silicon Macs)

**Better:** USB microphone. Recommendations:
- **Budget:** Blue Snowball (~$50)
- **Mid:** Audio-Technica AT2020 USB (~$100)
- **Best value:** Shure MV7 (~$250) — USB + XLR hybrid

**OBS Audio Filters (apply to mic):**
1. Noise Suppression (RNNoise if available)
2. Noise Gate (if background noise)
3. Compressor (evens out volume)
4. Limiter (prevents clipping)

### Video (Camera vs VTuber)

#### Option A: Webcam (Simple, Authentic)

You said you're 50 and demographics skew young. Here's the thing: **authenticity beats youth**. The coding community respects experience. Being a senior dev building something real is *more* interesting than another 20-something streamer.

Webcam setup:
- Position at eye level
- Good lighting (ring light or desk lamp in front, not behind)
- Clean background (or use OBS blur/virtual background)

**Recommendation:** Start with webcam. Your experience is an asset, not a liability.

#### Option B: VTuber (Privacy + Novelty)

If you really want to hide your face:

**Simplest (PNGTuber):**
1. Create 2 images: idle face, talking face
2. Use [Veadotube mini](https://olmewe.itch.io/veadotube-mini) (free)
3. Switches between images when you talk
4. Charming, low-effort, distinct

**More Animated (2D):**
1. Create avatar in VRoid Studio or commission one
2. Use VSeeFace (free) for face tracking
3. Capture in OBS via Spout2 plugin
4. Requires webcam for tracking (you just don't show it)

**My take:** PNGTuber with a fire/ember theme could work great with "TokenFires" branding. Maybe a stylized flame character?

### iPhone Demo Setup

When you need to show EmberHearth working on the iPhone:

**Method 1: USB + QuickTime (Easiest)**
1. Connect iPhone via Lightning/USB-C cable
2. Open QuickTime → File → New Movie Recording
3. Click dropdown next to record button → Select iPhone
4. In OBS: Add Window Capture → QuickTime Player

**Method 2: NDI (Wireless)**
1. Install NDI|HX Capture on iPhone ($20)
2. Start broadcasting in the app
3. In OBS: Add NDI Source → Select iPhone
4. Works over WiFi, slight latency

**Method 3: Dedicated Capture Card**
1. HDMI capture card + Lightning Digital AV Adapter
2. More complex but lowest latency
3. Overkill for testing demos

**Recommendation:** Start with USB + QuickTime. It's free and works.

**Important:** Enable Do Not Disturb on iPhone during demos!

---

## Part 2: Stream Structure

### Pre-Stream Checklist

```
[ ] Close unnecessary apps (especially Slack, Mail, Discord popups)
[ ] Set macOS to Do Not Disturb
[ ] Set iPhone to Do Not Disturb
[ ] Open OBS, verify all sources working
[ ] Test microphone levels
[ ] Prepare water/coffee
[ ] Have notes/tasks visible (second monitor or printed)
[ ] Tweet/Discord announcement: "Going live in 15 minutes!"
[ ] Start "Starting Soon" scene 5-10 minutes early
```

### Stream Flow Template

```
0:00 - Starting Soon scene (with countdown)
       Chat starts gathering, say hi to early arrivals

0:05 - Switch to main scene
       "Welcome to TokenFires! Today we're working on [X]"
       Brief recap of where we are

0:10 - Start coding
       Explain what you're doing as you do it
       Read chat between compile/test cycles

~2:00 - Mid-stream break (5-10 min)
        Switch to BRB scene
        Stretch, bathroom, refill drink

2:10 - Resume coding
       "Alright, we're back! Here's what we're tackling next..."

~3:00-4:00 - Wrap up
              "Okay, let's wrap up for today"
              Summarize what was accomplished
              Preview next stream
              Thank viewers by name
              Raid another streamer
```

### Content Pillars for EmberHearth Streams

| Episode Type | Description | Frequency |
|--------------|-------------|-----------|
| **Build Sessions** | Active coding | 2-3x/week |
| **Debug Sessions** | "It's broken, let's fix it" | As needed (high engagement!) |
| **Design Talks** | Discussing architecture, specs | 1x/week |
| **Demo Days** | Testing on iPhone, showing progress | After milestones |
| **Q&A / Chat** | Just talking about AI, security, Apple | Occasional |

---

## Part 3: Audience Engagement

### The Golden Rule

> **Chat is more important than code.**

If chat is active, they'll keep you motivated, help you debug, and come back next time. If you ignore chat, you're just coding with a camera on—boring.

### Engagement Techniques

**Greet everyone by name:**
```
"Hey TokenViewer123, welcome! First time here?"
```

**Ask for input:**
```
"So I'm thinking of naming this function 'processMessage'...
anyone have a better idea?"
```

**Explain your thinking:**
```
"Okay so I'm going to try using FSEvents instead of polling because...
[explain why]. Let's see if this works."
```

**Celebrate mistakes:**
```
"Aaand it crashed. Beautiful. Let's figure out why together."
```

**Use chat commands:** Set up a chatbot (Nightbot, StreamElements) with:
- `!project` — "EmberHearth is a privacy-first AI assistant for Apple devices"
- `!schedule` — "TokenFires streams Tue/Thu/Sat at 8pm EST"
- `!github` — Link to repo (when public)
- `!tokens` — "We've burned [X] tokens so far building this!"

### Handling Slow Chat

When nobody's talking:
- Narrate what you're doing anyway (future viewers watch VODs)
- Ask rhetorical questions
- Share random thoughts about the code
- Read error messages out loud and react

**It gets better:** The first few streams will be quiet. That's normal. Consistency builds audience.

### Managing Trolls/Negativity

- Use Twitch AutoMod (Settings → Moderation)
- Set up Nightbot for banned words/phrases
- Don't feed trolls — timeout/ban and move on
- For constructive criticism: "That's a fair point, let me think about it"

---

## Part 4: Growth Strategy

### Realistic Expectations

- **Month 1-3:** 0-5 average viewers. This is normal.
- **Month 3-6:** 5-15 viewers if consistent
- **Month 6+:** Growth compounds if you keep showing up

Don't expect overnight success. The stream builds your portfolio, your skills, and eventually your audience.

### Schedule (Crucial)

Pick times you can actually commit to. Examples:

| Option | Days | Times | Notes |
|--------|------|-------|-------|
| **Light** | Tue, Thu | 8-10pm | 4 hrs/week |
| **Moderate** | Tue, Thu, Sat | 7-10pm | 9 hrs/week |
| **Heavy** | Mon-Fri | 8-11pm | 15 hrs/week (risk of burnout) |

**Recommendation:** Start with 2 days/week, 2-3 hours each. Underpromise, overdeliver.

Put your schedule EVERYWHERE:
- Twitch bio/panels
- Stream title
- Twitter/X bio
- Discord
- Chat command

### Multi-Platform Amplification

Twitch is hard to discover organically. You need external traffic:

**YouTube (Long-form):**
- Upload VOD highlights
- "Building an AI Assistant from Scratch - Day 1"

**YouTube Shorts / TikTok / Reels:**
- Clip interesting moments (60 sec max)
- "Watch Claude help me debug this crash"
- "The moment EmberHearth sent its first message"

**Twitter/X:**
- Tweet when going live
- Share code snippets, progress screenshots
- Engage with #CodeNewbie, #100DaysOfCode, #SwiftLang communities

**Discord:**
- Create your own server for community
- Join related servers (Swift, Apple dev, AI/ML communities)

### Networking

**Raid other streamers:** At end of every stream, raid someone in your category (Science & Technology, Software and Game Development). They'll often raid back.

**Collaborate:** Once you have a few regular viewers, invite other streamers to code together.

**Don't:** Spam your link in other people's chats. That's how you get banned.

---

## Part 5: Your Unique Angle

### Why TokenFires is Interesting

1. **Meta:** Using AI (Claude) to build an AI assistant. Viewers see both sides.
2. **Real:** This isn't a tutorial. It's a real project with real stakes.
3. **Expertise:** 20 years of experience means you can explain *why*, not just *how*.
4. **Security-first:** The Apple/security angle is underserved in AI content.
5. **Open:** Building in public = transparency = trust.

### Potential Episode Ideas

**The Hits (High Engagement):**
- "First Light" — Prototype works for the first time
- "She's Alive" — Ember personality comes online
- "The iPhone Test" — First message sent/received live on stream
- "Security Showdown" — Testing injection attacks against Tron
- "Memory Palace" — Ember remembers something for the first time

**The Everyday (Still Valuable):**
- Debugging sessions (viewers love to help)
- Code reviews (explain your architecture)
- Planning sessions (whiteboard the next feature)
- Refactoring (satisfying to watch)

### The TokenFires Brand

- **Fire theme:** Burning tokens, EmberHearth, flames
- **Colors:** Warm oranges, reds, ember glows
- **Vibe:** Experienced dev, building something real, occasionally swearing at bugs

---

## Part 6: Tools & Resources

### Essential Software

| Tool | Purpose | Cost |
|------|---------|------|
| [OBS Studio](https://obsproject.com/) | Streaming | Free |
| [Nightbot](https://nightbot.tv/) | Chat bot | Free |
| [StreamElements](https://streamelements.com/) | Alerts, overlays | Free |
| [Veadotube mini](https://olmewe.itch.io/veadotube-mini) | PNGTuber (if wanted) | Free |
| [Canva](https://canva.com/) | Graphics (panels, overlays) | Free tier |

### Optional Upgrades

| Tool | Purpose | Cost |
|------|---------|------|
| [Streamlabs](https://streamlabs.com/) | Alternative to OBS | Free |
| [VSeeFace](https://www.vseeface.icu/) | 3D VTuber tracking | Free |
| [Touch Portal](https://www.touch-portal.com/) | Stream deck on phone | $15 |
| [NDI|HX Capture](https://apps.apple.com/app/ndi-hx-capture/id1592155499) | Wireless iPhone capture | $20 |

### Useful Links

- [Twitch Creator Dashboard](https://dashboard.twitch.tv/)
- [OBS Smartphone Camera Guide](https://obsproject.com/kb/smartphone-camera-guide)
- [Twitch Affiliate Requirements](https://help.twitch.tv/s/article/joining-the-affiliate-program)
- [SullyGnome](https://sullygnome.com/) — Stream analytics, find good time slots
- [TwitchTracker](https://twitchtracker.com/) — Channel statistics

---

## Part 7: Pre-Launch Checklist

### Before First Stream

```
[ ] Twitch account created and branded
[ ] OBS installed and configured
[ ] Test stream (private or to YouTube first)
[ ] Microphone tested (record yourself, listen back)
[ ] Camera/avatar working
[ ] At least 3 scenes set up (Starting Soon, Main, BRB)
[ ] Nightbot connected
[ ] Chat commands set up (!project, !schedule)
[ ] Twitch panels created (About, Schedule, Socials)
[ ] Schedule decided and posted
[ ] First stream topic/goal decided
```

### First Stream Goals

Don't try to do everything at once. First stream goals:

1. Go live without technical issues
2. Stream for at least 1 hour
3. Talk through what you're doing
4. End with a raid

That's it. Everything else is bonus.

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│                  STREAM QUICK REFERENCE                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Pre-Stream:                                            │
│  [ ] DND on Mac + iPhone                                │
│  [ ] Close Slack/Mail/Discord                           │
│  [ ] Test audio levels                                  │
│  [ ] Tweet "going live in 15"                           │
│                                                         │
│  During Stream:                                         │
│  [ ] Greet chatters by name                             │
│  [ ] Explain what you're doing                          │
│  [ ] Read chat between tasks                            │
│  [ ] Take break every ~2 hours                          │
│                                                         │
│  End of Stream:                                         │
│  [ ] Summarize progress                                 │
│  [ ] Preview next stream                                │
│  [ ] Thank viewers                                      │
│  [ ] Raid someone                                       │
│                                                         │
│  After Stream:                                          │
│  [ ] Clip best moments                                  │
│  [ ] Tweet recap                                        │
│  [ ] Note ideas for next time                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Final Thoughts

Streaming is a skill. Your first streams will be awkward. That's fine.

What matters:
1. **Show up consistently**
2. **Engage with chat**
3. **Make progress on the project**

The audience will come. The project will ship. And you'll have documented the entire journey.

Now go burn some tokens.

---

## Sources

- [Twitch Live Coding Setup (whitep4nth3r)](https://whitep4nth3r.com/blog/twitch-live-coding-setup-obs/)
- [Best OBS Settings (Nerd or Die)](https://nerdordie.com/resources/best-stream-settings-for-obs-studio/)
- [Lessons from First Year of Live Coding (Bomberbot)](https://www.bomberbot.com/programming/lessons-from-my-first-year-of-live-coding-on-twitch/)
- [Growing Your Twitch Stream in 2025](https://www.getailicia.com/post/growing-your-twitch-stream-in-2025)
- [How to Start VTubing (Viverse)](https://news.viverse.com/post/how-to-start-vtubing)
- [Top Free VTuber Tools (DubbingAI)](https://dubbingai.io/blog/top-free-tools-for-beginner-vtubers/)
- [OBS iPhone Camera Guide](https://obsproject.com/kb/smartphone-camera-guide)
- [NDI iOS Screen Sharing (DigiProTips)](https://digiprotips.com/share-any-pc-or-ios-screen-on-your-network-to-obs-studio-with-ndi/)
