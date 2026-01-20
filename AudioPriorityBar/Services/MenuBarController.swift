import AppKit
import SwiftUI

/// Controls the menu bar item and handles click events
@MainActor
class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let audioManager: AudioManager
    private let isQuickSwitchEnabled: Bool
    private var updateTimer: Timer?
    
    init(audioManager: AudioManager, isQuickSwitchEnabled: Bool) {
        self.audioManager = audioManager
        self.isQuickSwitchEnabled = isQuickSwitchEnabled
        setupMenuBar()
        setupUpdateTimer()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateButton()
            
            if isQuickSwitchEnabled {
                // Quick switch mode: left click toggles, right click shows menu
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.action = #selector(handleClick(_:))
                button.target = self
            } else {
                // Normal mode: any click shows menu
                button.action = #selector(handleClick(_:))
                button.target = self
            }
        }
        
        // Create popover for menu content
        let popover = NSPopover()
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(audioManager)
        )
        popover.behavior = .transient
        self.popover = popover
    }
    
    private func setupUpdateTimer() {
        // Update the menu bar icon periodically to reflect state changes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateButton()
            }
        }
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if isQuickSwitchEnabled {
            if event.type == .rightMouseUp {
                // Right click: show menu
                showPopover(sender)
            } else if event.type == .leftMouseUp {
                // Left click: toggle mode
                audioManager.toggleMode()
                updateButton()
            }
        } else {
            // Normal mode: show menu
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    func updateButton() {
        guard let button = statusItem?.button else { return }
        
        // Build icon using SF Symbols based on state
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        var symbols: [NSImage] = []
        
        // Input mute indicator
        if audioManager.isActiveInputMuted {
            let micIcon = audioManager.micFlashState ? "mic.fill" : "mic.slash.fill"
            if let image = NSImage(systemSymbolName: micIcon, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                symbols.append(image)
            }
        }
        
        // Custom mode indicator
        if audioManager.isCustomMode {
            if let image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                symbols.append(image)
            }
        }
        
        // Output indicator - headphone in headphone mode, speaker in speaker mode
        if audioManager.currentMode == .headphone {
            // Headphone icon
            if let image = NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                symbols.append(image)
            }
        } else {
            // Speaker icon with volume indication
            let speakerIcon: String
            if audioManager.isActiveOutputMuted {
                speakerIcon = "speaker.slash.fill"
            } else {
                // Use variable speaker icon based on volume
                let volume = audioManager.volume
                if volume > 0.66 {
                    speakerIcon = "speaker.wave.3.fill"
                } else if volume > 0.33 {
                    speakerIcon = "speaker.wave.2.fill"
                } else if volume > 0 {
                    speakerIcon = "speaker.wave.1.fill"
                } else {
                    speakerIcon = "speaker.fill"
                }
            }
            
            if let image = NSImage(systemSymbolName: speakerIcon, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                symbols.append(image)
            }
        }
        
        // Combine symbols into one image
        if !symbols.isEmpty {
            let spacing: CGFloat = 2
            let totalWidth = symbols.map { $0.size.width }.reduce(0, +) + CGFloat(symbols.count - 1) * spacing
            let maxHeight = symbols.map { $0.size.height }.max() ?? 16
            
            let combinedImage = NSImage(size: NSSize(width: totalWidth, height: maxHeight))
            combinedImage.lockFocus()
            
            var xOffset: CGFloat = 0
            for symbol in symbols {
                let yOffset = (maxHeight - symbol.size.height) / 2
                symbol.draw(at: NSPoint(x: xOffset, y: yOffset), from: .zero, operation: .sourceOver, fraction: 1.0)
                xOffset += symbol.size.width + spacing
            }
            
            combinedImage.unlockFocus()
            combinedImage.isTemplate = true
            button.image = combinedImage
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
