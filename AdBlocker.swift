import Cocoa
import ApplicationServices

// 1. Custom View to Handle Hovering
class HoverView: NSVisualEffectView {
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // Track mouse entering/exiting the view
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // GHOST MODE: Fade out when mouse hovers over (to see behind it)
        // Only works if the window is NOT ignoring mouse events
        if !self.window!.ignoresMouseEvents {
            animator().alphaValue = 0.1 // Almost invisible
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Restore opacity when mouse leaves
        if !self.window!.ignoresMouseEvents {
            animator().alphaValue = 1.0
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let defaults = UserDefaults.standard
    var hoverView: HoverView!
    
    // Auto-position state
    var autoPositionEnabled = false
    var bottomOffset: CGFloat = 95  // Distance from bottom of terminal window to bottom of blocker (skips footer + input row)
    var blockerHeight: CGFloat = 50 // Height of the ad section
    var horizontalMargin: CGFloat = 2
    var trackedTerminalPID: pid_t = 0
    var axObserver: AXObserver?
    var trackedWindowRef: AXUIElement?
    
    // List of Terminal App Bundle IDs
    let terminalBundleIDs = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode",
        "co.zeit.hyper", "io.alacritty", "dev.warp.Warp-Stable", "com.mitchellh.ghostty"
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. RESTORE SAVED FRAME
        let savedFrameString = defaults.string(forKey: "windowFrame")
        let initialFrame = savedFrameString != nil 
            ? NSRectFromString(savedFrameString!) 
            : NSRect(x: 100, y: 100, width: 600, height: 50)
        
        // Restore auto-position preference
        autoPositionEnabled = defaults.bool(forKey: "autoPositionEnabled")
        if let savedOffset = defaults.object(forKey: "bottomOffset") as? CGFloat {
            bottomOffset = savedOffset
        }
        
        window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 2. SETUP VISUALS (Blur + Hover)
        hoverView = HoverView()
        hoverView.material = .hudWindow // Dark frosted glass
        hoverView.state = .active
        hoverView.blendingMode = .behindWindow
        window.contentView = hoverView
        
        // Window Settings
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true
        
        // Setup Notification for Hiding/Showing
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        
        // Save position listeners
        NotificationCenter.default.addObserver(self, selector: #selector(saveState), name: NSWindow.didMoveNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(saveState), name: NSWindow.didResizeNotification, object: window)
        
        // Check accessibility permission
        requestAccessibilityIfNeeded()
        
        setupMenu()
        checkActiveApplication()
    }
    
    // MARK: - Accessibility Permission
    
    func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("AdBlocker: Accessibility permission required for auto-positioning. Please grant access in System Settings > Privacy & Security > Accessibility.")
        }
    }
    
    // MARK: - AXObserver for Terminal Window Tracking
    
    func startTrackingTerminalWindow(pid: pid_t) {
        // Don't re-track the same PID
        if pid == trackedTerminalPID && axObserver != nil { return }
        
        // Clean up previous observer
        stopTrackingTerminalWindow()
        
        guard AXIsProcessTrusted() else { return }
        
        let appRef = AXUIElementCreateApplication(pid)
        
        // Get the windows array
        var windowListValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowListValue)
        guard result == .success, let windowList = windowListValue as? [AXUIElement], let firstWindow = windowList.first else {
            return
        }
        
        trackedTerminalPID = pid
        trackedWindowRef = firstWindow
        
        // Create AXObserver
        var observer: AXObserver?
        let callbackPtr: AXObserverCallback = { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            appDelegate.repositionBlocker()
        }
        
        guard AXObserverCreate(pid, callbackPtr, &observer) == .success, let obs = observer else {
            return
        }
        
        axObserver = obs
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        AXObserverAddNotification(obs, firstWindow, kAXMovedNotification as CFString, refcon)
        AXObserverAddNotification(obs, firstWindow, kAXResizedNotification as CFString, refcon)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
        
        // Do an initial positioning
        repositionBlocker()
    }
    
    func stopTrackingTerminalWindow() {
        if let obs = axObserver, let winRef = trackedWindowRef {
            AXObserverRemoveNotification(obs, winRef, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(obs, winRef, kAXResizedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        axObserver = nil
        trackedWindowRef = nil
        trackedTerminalPID = 0
    }
    
    // MARK: - Auto-Positioning Logic
    
    func repositionBlocker() {
        guard autoPositionEnabled, let winRef = trackedWindowRef else { return }
        
        // Read terminal window position (screen coords, top-left origin)
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(winRef, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(winRef, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return
        }
        
        var termPos = CGPoint.zero
        var termSize = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &termPos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &termSize)
        
        // AX uses top-left origin; convert to AppKit's bottom-left origin
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        
        // Terminal window bottom edge in AppKit coords
        let termBottomY = screenHeight - (termPos.y + termSize.height)
        
        // Blocker's bottom edge sits bottomOffset pixels above the terminal's bottom edge
        let blockerY = termBottomY + bottomOffset
        let blockerX = termPos.x + horizontalMargin
        let blockerWidth = termSize.width - (horizontalMargin * 2)
        
        let newFrame = NSRect(x: blockerX, y: blockerY, width: blockerWidth, height: blockerHeight)
        window.setFrame(newFrame, display: true, animate: false)
        saveState()
    }
    
    // MARK: - State
    
    @objc func saveState() {
        defaults.set(NSStringFromRect(window.frame), forKey: "windowFrame")
    }
    
    @objc func activeAppDidChange(_ notification: Notification) {
        checkActiveApplication()
    }
    
    func checkActiveApplication() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier {
            if terminalBundleIDs.contains(bundleID) {
                window.orderFront(nil)
                if autoPositionEnabled {
                    startTrackingTerminalWindow(pid: frontApp.processIdentifier)
                }
            } else {
                window.orderOut(nil)
                if autoPositionEnabled {
                    stopTrackingTerminalWindow()
                }
            }
        }
    }
    
    // MARK: - Menu
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Blocker")
        }
        
        let menu = NSMenu()
        
        // Auto-position toggle
        let autoItem = NSMenuItem(title: "Auto-Position", action: #selector(toggleAutoPosition), keyEquivalent: "a")
        autoItem.state = autoPositionEnabled ? .on : .off
        menu.addItem(autoItem)
        
        // Offset adjustment
        menu.addItem(NSMenuItem(title: "Nudge Up", action: #selector(nudgeUp), keyEquivalent: "+"))
        menu.addItem(NSMenuItem(title: "Nudge Down", action: #selector(nudgeDown), keyEquivalent: "-"))
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Lock Position", action: #selector(toggleLock), keyEquivalent: "l")
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func toggleAutoPosition(_ sender: NSMenuItem) {
        autoPositionEnabled.toggle()
        sender.state = autoPositionEnabled ? .on : .off
        defaults.set(autoPositionEnabled, forKey: "autoPositionEnabled")
        
        if autoPositionEnabled {
            // Start tracking if a terminal is already active
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               let bundleID = frontApp.bundleIdentifier,
               terminalBundleIDs.contains(bundleID) {
                startTrackingTerminalWindow(pid: frontApp.processIdentifier)
            }
            // Auto-lock when auto-positioning
            lockBlocker()
        } else {
            stopTrackingTerminalWindow()
        }
    }
    
    @objc func nudgeUp(_ sender: NSMenuItem) {
        bottomOffset += 5
        defaults.set(bottomOffset, forKey: "bottomOffset")
        repositionBlocker()
    }
    
    @objc func nudgeDown(_ sender: NSMenuItem) {
        bottomOffset -= 5
        defaults.set(bottomOffset, forKey: "bottomOffset")
        repositionBlocker()
    }
    
    func lockBlocker() {
        window.ignoresMouseEvents = true
        window.styleMask.remove(.resizable)
        window.alphaValue = 1.0
        hoverView.alphaValue = 1.0
        
        // Update menu item if it exists
        if let menu = statusItem.menu,
           let lockItem = menu.items.first(where: { $0.action == #selector(toggleLock) }) {
            lockItem.title = "Unlock to Move"
            lockItem.state = .on
        }
    }
    
    @objc func toggleLock(_ sender: NSMenuItem) {
        let isLocked = window.ignoresMouseEvents
        if isLocked {
            // UNLOCK
            window.ignoresMouseEvents = false
            window.styleMask.insert(.resizable)
            window.alphaValue = 1.0 
            // Ensure view is visible again
            hoverView.alphaValue = 1.0
            
            sender.title = "Lock Position"
            sender.state = .off
        } else {
            // LOCK
            window.ignoresMouseEvents = true
            window.styleMask.remove(.resizable)
            
            // When locked, ensure it's fully opaque (no hover effect)
            window.alphaValue = 1.0
            hoverView.alphaValue = 1.0
            
            sender.title = "Unlock to Move"
            sender.state = .on
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
