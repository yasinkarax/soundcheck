import SwiftUI
import CoreAudio

@available(macOS 14.2, *)
@MainActor
final class MixerModel: ObservableObject {
    @Published var apps: [AudioApp] = []
    @Published var enabled = false
    @Published var error: String?
    @Published var outputName = "System output"
    @Published var volumes: [String: Double] = [:]
    @Published var muted: Set<String> = []
    private var sessions: [String: AudioSession] = [:]
    private var timer: Timer?
    private var output: AudioObjectID = 0

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        do {
            let nextOutput = try readValue(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(0))
            if output != nextOutput { sessions.removeAll(); output = nextOutput }
            outputName = (try? readString(output, kAudioObjectPropertyName)) ?? "System output"
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
        guard enabled else { return }
        let value = muted.contains(app.id) ? 0 : Float(volume(for: app.id))
        if value == 1 { sessions.removeValue(forKey: app.id); return }
        if let session = sessions[app.id] { session.setVolume(value) }
        else { sessions[app.id] = try AudioSession(processes: app.processes, output: output, volume: value) }
    }
    private func fail(_ issue: Error) {
        disable()
        error = issue.localizedDescription
    }
}

@available(macOS 14.2, *)
struct MixerView: View {
    @ObservedObject var model: MixerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "slider.vertical.3").font(.title).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Soundcheck").font(.title2.bold())
                    Text("A little balance for your Mac.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(model.enabled ? Color.mint : Color.secondary).frame(width: 7, height: 7)
                Text(model.enabled ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "speaker.wave.2")
                Text(model.outputName).lineLimit(1)
                Spacer()
                Text("CURRENT OUTPUT").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            .font(.callout).padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !model.enabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your apps. Your volume.").font(.headline)
                    Text("Control each app separately. macOS may ask for system audio recording access when you first adjust a slider. Audio stays on your Mac and is never saved.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Enable app volume control") { model.enable() }
                        .buttonStyle(.borderedProminent).tint(.mint).controlSize(.large)
                }
            }
            HStack {
                Text("APPLICATIONS").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.apps.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if model.apps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("Waiting for a little sound").font(.headline)
                    Text("Play music or a video to see its app here.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 26)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(model.apps) { app in
                            appRow(app)
                        }
                    }
                }.frame(maxHeight: 360)
            }
            Divider()
            HStack {
                Button("Reset volumes") { model.reset() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if model.enabled {
                    Button("Turn off") { model.disable() }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Button("Quit") { model.disable(); NSApplication.shared.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.font(.caption)
        }
        .padding(24).frame(width: 400).tint(.mint)
    }
    private func appRow(_ app: AudioApp) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 28, height: 28) }
                else { Image(systemName: "app.fill").font(.title2).frame(width: 28) }
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer()
                Text(model.muted.contains(app.id) ? "Muted" : "\(Int(model.volume(for: app.id) * 100))%")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button { model.toggleMute(app) } label: {
                    Image(systemName: model.muted.contains(app.id) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 22)
                }.buttonStyle(.plain).accessibilityLabel("\(model.muted.contains(app.id) ? "Unmute" : "Mute") \(app.name)")
                Slider(value: Binding(get: { model.volume(for: app.id) }, set: { model.setVolume(app, $0) }), in: 0...1)
                    .accessibilityLabel("\(app.name) volume")
            }.disabled(!model.enabled)
        }.padding(13).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

@main
struct SoundcheckApp: App {
    @StateObject private var model = MixerModel()
    var body: some Scene {
        MenuBarExtra("Soundcheck", systemImage: "slider.vertical.3") {
            MixerView(model: model)
        }.menuBarExtraStyle(.window)
    }
}
