import SwiftUI
import CoreAudio
import AudioToolbox

@available(macOS 14.2, *)
@MainActor
final class MixerModel: ObservableObject {
    @Published var apps: [AudioApp] = []
    @Published var enabled = true
    @Published var error: String?
    @Published var outputName = "System output"
    @Published var volumes: [String: Double] = [:]
    @Published var muted: Set<String> = []
    @Published var showingOutput = false
    @Published var masterVolume: Double = 1
    @Published var masterAvailable = false
    private var volumeBeforeMute: Double = 0.5
    private var sessions: [String: AudioSession] = [:]
    private var timer: Timer?
    private var output: AudioObjectID = 0
    private let isPreview: Bool

    init(preview: Bool = false) {
        isPreview = preview
        if preview {
            enabled = true; masterAvailable = true; masterVolume = 0.72
            outputName = "MacBook Pro speakers"
            let samples: [(name: String, icon: String, subtitle: String)] = [
                ("Spotify", "preview-spotify", "Nights · Frank Ocean"),
                ("Chrome", "preview-chrome", "YouTube · Design in motion"),
                ("Hades II", "preview-hades", "Game audio"),
                ("Discord", "preview-discord", "Muted")
            ]
            apps = samples.map { sample in
                AudioApp(id: sample.name, name: sample.name, icon: Self.previewIcon(sample.icon), processes: [], active: true, subtitle: sample.subtitle)
            }
            volumes = ["Spotify": 0.65, "Chrome": 0.38, "Hades II": 0.82, "Discord": 0.8]
            muted = ["Discord"]
            return
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        guard !isPreview else { return }
        do {
            let nextOutput = try readValue(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(0))
            if output != nextOutput { sessions.removeAll(); output = nextOutput }
            outputName = (try? readString(output, kAudioObjectPropertyName)) ?? "System output"
            refreshMaster()
            let discovered = try discoverApps()
            apps = discovered.filter { $0.active || sessions[$0.id] != nil || volumes[$0.id] != nil }
            let existing = Set(discovered.map(\.id))
            for id in Array(sessions.keys) where !existing.contains(id) { sessions.removeValue(forKey: id) }
            if enabled {
                for app in apps where sessions[app.id] != nil {
                    if sessions[app.id]?.processes != app.processes { sessions.removeValue(forKey: app.id) }
                }
                for app in apps where volumes[app.id] != nil || muted.contains(app.id) { try apply(app) }
            }
        } catch { fail(error) }
    }
    private func refreshMaster() {
        var key = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var settable: DarwinBoolean = false
        var volume: Float32 = 1
        var size = UInt32(MemoryLayout<Float32>.size)
        masterAvailable = AudioObjectIsPropertySettable(output, &key, &settable) == noErr && settable.boolValue && AudioObjectGetPropertyData(output, &key, 0, nil, &size, &volume) == noErr
        if masterAvailable { masterVolume = Double(volume) }
    }
    func setMaster(_ value: Double) {
        guard masterAvailable else { return }
        if isPreview { masterVolume = min(1, max(0, value)); return }
        var key = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var volume = Float32(min(1, max(0, value)))
        let status = AudioObjectSetPropertyData(output, &key, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
        if status == noErr { masterVolume = Double(volume) }
        else { error = "This output device could not change its volume. Use your Mac’s sound controls."; refreshMaster() }
    }
    func toggleMasterMute() {
        if masterVolume > 0 { volumeBeforeMute = masterVolume; setMaster(0) }
        else { setMaster(volumeBeforeMute) }
    }
    func enable() { enabled = true; error = nil; refresh() }
    func disable() { sessions.removeAll(); enabled = false }
    func volume(for id: String) -> Double { volumes[id] ?? 1 }
    func setVolume(_ app: AudioApp, _ value: Double) {
        volumes[app.id] = value
        do { try apply(app) } catch { fail(error) }
    }
    func toggleMute(_ app: AudioApp) {
        if muted.contains(app.id) { muted.remove(app.id) } else { muted.insert(app.id) }
        do { try apply(app) } catch { fail(error) }
    }
    func reset() { sessions.removeAll(); volumes = [:]; muted = []; error = nil }
    private func apply(_ app: AudioApp) throws {
        guard enabled, !isPreview else { return }
        let value = muted.contains(app.id) ? 0 : Float(volume(for: app.id))
        if value == 1 { sessions.removeValue(forKey: app.id); return }
        if let session = sessions[app.id] { session.setVolume(value) }
        else { sessions[app.id] = try AudioSession(processes: app.processes, output: output, volume: value) }
    }
    private func fail(_ issue: Error) {
        disable()
        error = issue.localizedDescription
    }

    private static func previewIcon(_ name: String) -> NSImage {
        let artwork = DesignIcon.image(name)
        return NSImage(size: NSSize(width: 30, height: 30), flipped: false) { bounds in
            var artworkBounds = bounds
            let background: NSColor?
            switch name {
            case "preview-chrome":
                background = NSColor(srgbRed: 245 / 255, green: 245 / 255, blue: 247 / 255, alpha: 1)
                artworkBounds = bounds.insetBy(dx: 1, dy: 1)
            case "preview-hades":
                background = NSColor(srgbRed: 96 / 255, green: 70 / 255, blue: 52 / 255, alpha: 1)
                artworkBounds = bounds.insetBy(dx: 6.75, dy: 6.75)
            case "preview-discord":
                background = NSColor(srgbRed: 88 / 255, green: 101 / 255, blue: 242 / 255, alpha: 1)
                artworkBounds = bounds.insetBy(dx: 6.75, dy: 6.75)
            default: background = nil
            }
            if let background {
                background.setFill()
                NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
            }
            artwork.draw(in: artworkBounds)
            return true
        }
    }
}


@main
struct SoundcheckApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        if let flag = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > flag + 1 {
            let preview = MixerModel(preview: true)
            let view = TransparentMixerHostingView(rootView: MixerView(model: preview))
            let size = view.fittingSize
            view.frame = NSRect(origin: .zero, size: size)
            let window = MixerPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
            do { try png.write(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { fputs("Preview export failed: \(error)\n", stderr); exit(1) }
        }
        let delegate = SoundcheckAppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
