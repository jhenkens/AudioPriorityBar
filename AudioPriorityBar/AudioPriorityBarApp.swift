import SwiftUI
import CoreAudio
import AppKit

@main
struct AudioPriorityBarMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        // Start as regular app to ensure proper menu bar initialization
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        
        // Switch to accessory after menu bar is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            app.setActivationPolicy(.accessory)
            NSLog("AudioPriorityBar: Switched to accessory mode")
        }
        
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var audioManager: AudioManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item IMMEDIATELY
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let img = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Audio")?
                .withSymbolConfiguration(config) {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "🔊"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        NSLog("AudioPriorityBar: Status item created")
        
        // Delay popover initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.setupPopover()
        }
    }
    
    @MainActor
    private func setupPopover() {
        NSLog("AudioPriorityBar: Setting up popover...")
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 500)
        popover?.behavior = .transient
        popover?.animates = true

        audioManager = AudioManager()
        if let audioManager, let popover {
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView().environmentObject(audioManager)
            )
        }
        
        NSLog("AudioPriorityBar: Popover ready")
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else {
            NSLog("AudioPriorityBar: Popover not ready")
            return
        }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Use button bounds directly, show below
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // After showing, manually adjust the window position down by icon height
            if let popoverWindow = popover.contentViewController?.view.window {
                var frame = popoverWindow.frame
                frame.origin.y -= button.bounds.height
                popoverWindow.setFrame(frame, display: true)
            }
            
            popover.contentViewController?.view.window?.makeKey()
            NSLog("AudioPriorityBar: Popover shown")
        }
    }
}

struct MenuBarLabel: View {
    let volume: Float
    let isOutputMuted: Bool
    let isInputMuted: Bool
    let isCustomMode: Bool
    let mode: OutputCategory
    let micFlash: Bool

    var body: some View {
        HStack(spacing: 2) {
            if isInputMuted {
                Image(systemName: micFlash ? "mic.fill" : "mic.slash.fill")
            }
            if isCustomMode {
                Image(systemName: "hand.raised.fill")
            } else if mode == .headphone {
                Image(systemName: "headphones")
            }
            if isOutputMuted {
                Image(systemName: "speaker.slash.fill")
            } else {
                Image(systemName: "speaker.wave.3.fill", variableValue: Double(volume))
            }
        }
    }
}

struct VolumeMeterView: View {
    let volume: Float
    let isMuted: Bool
    private let barCount = 4
    private let barSpacing: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let barWidth = (size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)
            let filledBars = isMuted ? 0 : Int(ceil(Double(volume) * Double(barCount)))
            for i in 0..<barCount {
                let x = CGFloat(i) * (barWidth + barSpacing)
                let barHeight = size.height * CGFloat(i + 1) / CGFloat(barCount)
                let y = size.height - barHeight
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = Path(roundedRect: rect, cornerRadius: 1)
                if i < filledBars {
                    context.fill(path, with: .color(isMuted ? .red : .primary))
                } else {
                    context.fill(path, with: .color(.primary.opacity(0.25)))
                }
            }
        }
    }
}

@MainActor
class AudioManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var speakerDevices: [AudioDevice] = []
    @Published var headphoneDevices: [AudioDevice] = []
    @Published var hiddenInputDevices: [AudioDevice] = []
    @Published var hiddenSpeakerDevices: [AudioDevice] = []
    @Published var hiddenHeadphoneDevices: [AudioDevice] = []
    @Published var currentInputId: AudioObjectID?
    @Published var currentOutputId: AudioObjectID?
    @Published var currentMode: OutputCategory = .speaker
    @Published var volume: Float = 0
    @Published var isEditMode: Bool = false
    @Published var isCustomMode: Bool = false
    @Published var mutedDeviceIds: Set<AudioObjectID> = []
    @Published var isActiveOutputMuted: Bool = false
    @Published var isActiveInputMuted: Bool = false
    @Published var micFlashState: Bool = false

    private let deviceService = AudioDeviceService()
    private var micFlashTimer: Timer?
    let priorityManager = PriorityManager()
    private var connectedDeviceUIDs: Set<String> = []

    var menuBarIcon: String {
        currentMode.icon
    }

    func refreshVolume() {
        volume = deviceService.getOutputVolume()
    }

    func refreshMuteStatus() {
        var muted: Set<AudioObjectID> = []
        for device in inputDevices where device.isConnected {
            if deviceService.isDeviceMuted(device.id, type: .input) {
                muted.insert(device.id)
            }
        }
        for device in speakerDevices where device.isConnected {
            if deviceService.isDeviceMuted(device.id, type: .output) {
                muted.insert(device.id)
            }
        }
        for device in headphoneDevices where device.isConnected {
            if deviceService.isDeviceMuted(device.id, type: .output) {
                muted.insert(device.id)
            }
        }
        mutedDeviceIds = muted
        if let outputId = currentOutputId {
            isActiveOutputMuted = muted.contains(outputId)
        } else {
            isActiveOutputMuted = false
        }
        if let inputId = currentInputId {
            isActiveInputMuted = muted.contains(inputId)
        } else {
            isActiveInputMuted = false
        }
        if isActiveInputMuted && micFlashTimer == nil {
            micFlashTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.micFlashState.toggle()
                }
            }
        } else if !isActiveInputMuted && micFlashTimer != nil {
            micFlashTimer?.invalidate()
            micFlashTimer = nil
            micFlashState = false
        }
    }

    func isDeviceMuted(_ device: AudioDevice) -> Bool {
        mutedDeviceIds.contains(device.id)
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        deviceService.setOutputVolume(newVolume)
    }

    var activeOutputDevices: [AudioDevice] {
        switch currentMode {
        case .speaker: return speakerDevices
        case .headphone: return headphoneDevices
        }
    }

    init() {
        currentMode = priorityManager.currentMode
        isCustomMode = priorityManager.isCustomMode
        refreshDevices()
        refreshVolume()
        refreshMuteStatus()
        setupDeviceChangeListener()
        setupMuteVolumeListener()
        if !isCustomMode {
            applyHighestPriorityInput()
            applyHighestPriorityOutput()
        }
    }

    private func setupMuteVolumeListener() {
        deviceService.onMuteOrVolumeChanged = { [weak self] in
            Task { @MainActor in
                self?.handleMuteOrVolumeChange()
            }
        }
    }

    private func handleMuteOrVolumeChange() {
        refreshMuteStatus()
        refreshVolume()
    }

    func refreshDevices() {
        let allConnectedDevices = deviceService.getDevices()
        connectedDeviceUIDs = Set(allConnectedDevices.map { $0.uid })
        for device in allConnectedDevices {
            priorityManager.rememberDevice(device.uid, name: device.name, isInput: device.type == .input)
        }
        let connectedInputs = allConnectedDevices.filter { $0.type == .input }
        let connectedOutputs = allConnectedDevices.filter { $0.type == .output }

        if isEditMode {
            let knownDevices = priorityManager.getKnownDevices()
            var allInputs: [AudioDevice] = connectedInputs
            for stored in knownDevices where stored.isInput {
                if !connectedDeviceUIDs.contains(stored.uid) {
                    allInputs.append(.disconnected(uid: stored.uid, name: stored.name, type: .input))
                }
            }
            var allOutputs: [AudioDevice] = connectedOutputs
            for stored in knownDevices where !stored.isInput {
                if !connectedDeviceUIDs.contains(stored.uid) {
                    allOutputs.append(.disconnected(uid: stored.uid, name: stored.name, type: .output))
                }
            }
            inputDevices = priorityManager.sortByPriority(allInputs, type: .input)
            hiddenInputDevices = []
            let speakers = allOutputs.filter { priorityManager.getCategory(for: $0) == .speaker }
            let headphones = allOutputs.filter { priorityManager.getCategory(for: $0) == .headphone }
            speakerDevices = priorityManager.sortByPriority(speakers, category: .speaker)
            headphoneDevices = priorityManager.sortByPriority(headphones, category: .headphone)
            hiddenSpeakerDevices = []
            hiddenHeadphoneDevices = []
        } else {
            let visibleInputs = connectedInputs.filter { !priorityManager.isHidden($0) }
            let hiddenInputs = connectedInputs.filter { priorityManager.isHidden($0) }
            inputDevices = priorityManager.sortByPriority(visibleInputs, type: .input)
            hiddenInputDevices = hiddenInputs
            let speakers = connectedOutputs.filter { priorityManager.getCategory(for: $0) == .speaker }
            let headphones = connectedOutputs.filter { priorityManager.getCategory(for: $0) == .headphone }
            let visibleSpeakers = speakers.filter { !priorityManager.isHidden($0, inCategory: .speaker) }
            let hiddenSpeakers = speakers.filter { priorityManager.isHidden($0, inCategory: .speaker) }
            let visibleHeadphones = headphones.filter { !priorityManager.isHidden($0, inCategory: .headphone) }
            let hiddenHeadphones = headphones.filter { priorityManager.isHidden($0, inCategory: .headphone) }
            speakerDevices = priorityManager.sortByPriority(visibleSpeakers, category: .speaker)
            headphoneDevices = priorityManager.sortByPriority(visibleHeadphones, category: .headphone)
            hiddenSpeakerDevices = hiddenSpeakers
            hiddenHeadphoneDevices = hiddenHeadphones
        }
        currentInputId = deviceService.getCurrentDefaultDevice(type: .input)
        currentOutputId = deviceService.getCurrentDefaultDevice(type: .output)
    }

    func toggleEditMode() {
        isEditMode.toggle()
        refreshDevices()
    }

    func isDeviceConnected(_ device: AudioDevice) -> Bool {
        connectedDeviceUIDs.contains(device.uid)
    }

    func setMode(_ mode: OutputCategory) {
        currentMode = mode
        priorityManager.currentMode = mode
        if !isCustomMode {
            applyHighestPriorityOutput()
        }
    }

    func toggleMode() {
        let newMode: OutputCategory = currentMode == .speaker ? .headphone : .speaker
        setMode(newMode)
    }

    func setCustomMode(_ enabled: Bool) {
        isCustomMode = enabled
        priorityManager.isCustomMode = enabled
        if !enabled {
            applyHighestPriorityInput()
            applyHighestPriorityOutput()
        }
    }

    func setCategory(_ category: OutputCategory, for device: AudioDevice) {
        priorityManager.setCategory(category, for: device)
        refreshDevices()
        if !isCustomMode {
            applyHighestPriorityOutput()
        }
    }

    func hideDevice(_ device: AudioDevice, category: OutputCategory? = nil) {
        if device.type == .input {
            priorityManager.hideDevice(device)
        } else if let cat = category {
            priorityManager.hideDevice(device, inCategory: cat)
        } else {
            priorityManager.hideDevice(device)
        }
        refreshDevices()
        if !isCustomMode {
            if device.type == .input {
                applyHighestPriorityInput()
            } else {
                applyHighestPriorityOutput()
            }
        }
    }

    func hideDeviceEntirely(_ device: AudioDevice) {
        priorityManager.hideDevice(device, inCategory: .speaker)
        priorityManager.hideDevice(device, inCategory: .headphone)
        refreshDevices()
        if !isCustomMode {
            applyHighestPriorityOutput()
        }
    }

    func unhideDevice(_ device: AudioDevice, category: OutputCategory? = nil) {
        if device.type == .input {
            priorityManager.unhideDevice(device)
        } else if let cat = category {
            priorityManager.unhideDevice(device, fromCategory: cat)
        } else {
            priorityManager.unhideDevice(device)
        }
        refreshDevices()
    }

    func isDeviceIgnored(_ device: AudioDevice, inCategory category: OutputCategory? = nil) -> Bool {
        if device.type == .input {
            return priorityManager.isHidden(device)
        } else if let cat = category {
            return priorityManager.isHidden(device, inCategory: cat)
        } else {
            return priorityManager.isHidden(device)
        }
    }

    func moveInputDevice(from source: IndexSet, to destination: Int) {
        inputDevices.move(fromOffsets: source, toOffset: destination)
        priorityManager.savePriorities(inputDevices, type: .input)
        if !isCustomMode {
            applyHighestPriorityInput()
        }
    }

    func moveSpeakerDevice(from source: IndexSet, to destination: Int) {
        speakerDevices.move(fromOffsets: source, toOffset: destination)
        priorityManager.savePriorities(speakerDevices, category: .speaker)
        if !isCustomMode && currentMode == .speaker {
            applyHighestPriorityOutput()
        }
    }

    func moveHeadphoneDevice(from source: IndexSet, to destination: Int) {
        headphoneDevices.move(fromOffsets: source, toOffset: destination)
        priorityManager.savePriorities(headphoneDevices, category: .headphone)
        if !isCustomMode && currentMode == .headphone {
            applyHighestPriorityOutput()
        }
    }

    func setInputDevice(_ device: AudioDevice) {
        applyInputDevice(device)
    }

    func setOutputDevice(_ device: AudioDevice) {
        applyOutputDevice(device)
    }

    private func applyInputDevice(_ device: AudioDevice) {
        deviceService.setDefaultDevice(device.id, type: .input)
        currentInputId = device.id
    }

    private func applyOutputDevice(_ device: AudioDevice) {
        deviceService.setDefaultDevice(device.id, type: .output)
        currentOutputId = device.id
    }

    private func applyHighestPriorityInput() {
        if let first = inputDevices.first(where: { $0.isConnected }) {
            applyInputDevice(first)
        }
    }

    private func applyHighestPriorityOutput() {
        let devices = activeOutputDevices
        if let first = devices.first(where: { $0.isConnected }) {
            applyOutputDevice(first)
        }
        refreshMuteStatus()
    }

    private func setupDeviceChangeListener() {
        deviceService.onDevicesChanged = { [weak self] in
            Task { @MainActor in
                self?.handleDeviceChange()
            }
        }
        deviceService.startListening()
    }

    private func handleDeviceChange() {
        refreshDevices()
        refreshMuteStatus()
        if !isCustomMode {
            applyHighestPriorityInput()
            applyHighestPriorityOutput()
        }
    }
}
