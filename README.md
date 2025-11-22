# Amp AdBlocker

A native, stealth-mode macOS utility designed to reclaim your terminal space while using the [Amp](https://ampcode.com) AI coding agent. It creates a floating, click-through "ghost" window that obscures the ad space above the input box without blocking your workflow.

## ✨ Features

* **👻 Ghost Mode (Hover Reveal):**
    * **Locked:** The bar is 100% opaque and ignores all mouse clicks. You can type and click "through" it as if it isn't there.
    * **Unlocked:** The bar becomes interactive. Hovering over it turns it semi-transparent (10% opacity), allowing you to peek at the content behind it for precision alignment.
* **🔒 Persistence:** Automatically remembers its exact position and size between sessions.
* **🧠 Smart Visibility:** Automatically detects your active application. The blocker **only** appears when you are using a supported terminal (Terminal, iTerm2, VS Code, etc.) and hides itself when you switch to other apps.
* **🎨 Native Aesthetics:** Uses `NSVisualEffectView` with a "HUD" material (frosted dark glass) to blend seamlessly with modern terminal themes.


## 🚀 Quick Start

### Option 1: Run as Script (Easiest)

You can run the app directly from your terminal without compiling.

1. Save the code as `AmpBlockerPro.swift`.
2. Run it:

```bash
swift AmpBlockerPro.swift
```


### Option 2: Compile as App (Recommended)

For better performance (<20MB RAM) and background usage:

1. **Compile the binary:**

```bash
swiftc AmpBlockerPro.swift -o AmpBlocker
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

1. **Launch**: Start the app. A dark, frosted bar will appear.
2. **Position**:
    * Drag the bar to cover the ad strip at the bottom of your terminal.
    * *Pro Tip:* Hover over the bar to make it transparent so you can align it perfectly with the text lines.
3. **Lock**:
    * Click the **Eye Slash** icon in the macOS Menu Bar (top-right).
    * Select **Lock Position**.
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
Open `AmpBlockerPro.swift` and add your terminal's Bundle ID to the `terminalBundleIDs` list:

```swift
let terminalBundleIDs = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "YOUR.NEW.ID.HERE" // <--- Add this
]
```

*(Find a Bundle ID by running `osascript -e 'id of app "AppName"'` in your terminal)*.

## 🛠 System Requirements

* macOS 10.13 (High Sierra) or later.
* Swift 5.0+ (Pre-installed on macOS).