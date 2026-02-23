# Amp AdBlocker

A native, stealth-mode macOS utility designed to reclaim your terminal space while using the [Amp](https://ampcode.com) AI coding agent. It creates a floating, click-through "ghost" window that obscures the ad space above the input box without blocking your workflow.

![Ad Blocked](pics/ad-blocked.png)

## ✨ Features

* **🎯 Auto-Position Mode:**
    * Uses the macOS **Accessibility API** to read your terminal window's frame and automatically snap the blocker over the ad strip.
    * The blocker **follows your terminal** — it repositions itself whenever the terminal window is moved or resized.
    * **Multi-window support** — works across all open terminal windows. The blocker automatically appears on whichever window is running Amp and hides on non-Amp windows.
    * Fine-tune the vertical offset with **Nudge Up / Nudge Down** controls (`⌘+` / `⌘-`).
    * Auto-locks the blocker in place once positioned.
* **👻 Ghost Mode (Hover Reveal):**
    * **Locked:** The bar is 100% opaque and ignores all mouse clicks. You can type and click "through" it as if it isn't there.
    * **Unlocked:** The bar becomes interactive. Hovering over it turns it semi-transparent (10% opacity), allowing you to peek at the content behind it for precision alignment.
* **🔒 Persistence:** Automatically remembers its position, size, offset, and auto-position preference between sessions.
* **🧠 Smart Visibility:** Automatically detects your active application and whether Amp is running. The blocker **only** appears on terminal windows with an active Amp session and hides when you switch to other apps or non-Amp terminal windows.
* **🎨 Native Aesthetics:** Uses a solid dark overlay that fully obscures ad content, blending seamlessly with modern terminal themes.


## 🚀 Quick Start

### Option 1: Run as Script (Easiest)

You can run the app directly from your terminal without compiling.

1. Save the code as `AdBlocker.swift`.
2. Run it:

```bash
swift AdBlocker.swift
```


### Option 2: Compile as App (Recommended)

For better performance (<20MB RAM) and background usage:

1. **Compile the binary:**

```bash
swiftc AdBlocker.swift -o AmpBlocker
```

2. **Move to Applications (Optional):**

```bash
mv AmpBlocker /Applications/
```

3. **Run silently in background:**

```bash
nohup /Applications/AmpBlocker >/dev/null 2>&1 &
```


## 📖 Usage Guide

### Auto-Position Mode (Recommended)

1. **Launch**: Start the app. A solid dark bar will appear.
2. **Grant Accessibility Permission**: On first launch, you'll be prompted to grant Accessibility access in **System Settings > Privacy & Security > Accessibility**. This is required for auto-positioning.
3. **Enable Auto-Position**:
    * Click the **Eye Slash** icon in the macOS Menu Bar (top-right).
    * Select **Auto-Position** (`⌘A`).
    * The blocker will automatically snap to the ad area of your active terminal window and lock in place.
4. **Fine-Tune**: If the blocker is slightly off for your font size or terminal config:
    * Use **Nudge Up** (`⌘+`) or **Nudge Down** (`⌘-`) to adjust by 5px increments.
    * Your offset is saved automatically.

### Manual Mode (Fallback)

1. **Launch**: Start the app. A solid dark bar will appear.
2. **Position**:
    * Drag the bar to cover the ad strip at the bottom of your terminal.
    * *Pro Tip:* Hover over the bar to make it transparent so you can align it perfectly with the text lines.
3. **Lock**:
    * Click the **Eye Slash** icon in the macOS Menu Bar (top-right).
    * Select **Lock Position** (`⌘L`).
    * The bar will turn solid and non-interactive. You can now work freely.
4. **Unlock**: To move or resize the bar later, use the Menu Bar icon to "Unlock."

## ⚙️ Configuration

### Supported Terminals

The app automatically works with the following terminal emulators:

* Apple Terminal
* iTerm2
* VS Code
* Hyper
* Alacritty
* Warp
* Ghostty

**Using a different terminal?**
Open `AdBlocker.swift` and add your terminal's Bundle ID to the `terminalBundleIDs` list:

```swift
let terminalBundleIDs = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "YOUR.NEW.ID.HERE" // <--- Add this
]
```

*(Find a Bundle ID by running `osascript -e 'id of app "AppName"'` in your terminal)*.

### Menu Bar Controls

| Control | Shortcut | Description |
|---------|----------|-------------|
| Auto-Position | `⌘A` | Toggle automatic positioning based on terminal window frame |
| Nudge Up | `⌘+` | Move blocker up by 5px |
| Nudge Down | `⌘-` | Move blocker down by 5px |
| Lock / Unlock | `⌘L` | Toggle manual lock (click-through mode) |
| Quit | `⌘Q` | Exit the app |

## 🛠 System Requirements

* macOS 10.13 (High Sierra) or later.
* Swift 5.0+ (Pre-installed on macOS).
* **Accessibility permission** required for Auto-Position mode.
