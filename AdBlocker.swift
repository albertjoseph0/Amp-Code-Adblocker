import Cocoa

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
        
        setupMenu()
        checkActiveApplication()
    }
    
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
            } else {
                window.orderOut(nil)
            }
        }
    }
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Blocker")
        }
        
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Lock Position", action: #selector(toggleLock), keyEquivalent: "l")
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
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
