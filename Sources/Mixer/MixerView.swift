import SwiftUI

// Raw colors from Figma node 2:3587. The requested design is dark-only.
enum MixerTheme {
    static let background = Color(red: 0.043, green: 0.059, blue: 0.078)
    static let surface = Color.white.opacity(0.06)
    static let output = Color.white.opacity(0.05)
    static let text = Color(red: 0.945, green: 0.949, blue: 0.957)
    static let secondary = Color(red: 0.698, green: 0.714, blue: 0.753)
    static let muted = Color(red: 0.467, green: 0.490, blue: 0.533)
    static let accent = Color(red: 0.659, green: 0.780, blue: 1)
    static let track = Color(red: 0.267, green: 0.282, blue: 0.314)
}

struct DesignIcon: View {
    let name: String
    var size: CGFloat = 16
    static func image(_ name: String) -> NSImage {
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources")!
        return NSImage(contentsOf: url)!
    }
    var body: some View {
        Image(nsImage: Self.image(name)).resizable().scaledToFit().frame(width: size, height: size)
    }
}

// NSSlider supplies native mouse, keyboard, and accessibility behavior; the cell
// draws the slimmer track and circular thumb from the Figma design.
final class MixerSliderCell: NSSliderCell {
    var isMuted = false
    override var knobThickness: CGFloat { controlSize == .regular ? 16 : 12 }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let bar = NSRect(x: rect.minX, y: rect.midY - 2, width: rect.width, height: 4)
        NSColor(MixerTheme.track).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 2, yRadius: 2).fill()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        if !isMuted && isEnabled {
            NSColor(MixerTheme.accent).setFill()
            NSBezierPath(roundedRect: NSRect(x: bar.minX, y: bar.minY, width: bar.width * fraction, height: 4), xRadius: 2, yRadius: 2).fill()
        }
    }
    override func drawKnob(_ rect: NSRect) {
        let diameter = knobThickness
        let knob = NSRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter)
        (isMuted || !isEnabled ? NSColor(MixerTheme.secondary) : NSColor(MixerTheme.text)).setFill()
        NSBezierPath(ovalIn: knob).fill()
    }
}
struct VolumeControl: NSViewRepresentable {
    @Binding var value: Double
    var muted = false
    var enabled = true
    var large = false
    let label: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.cell = MixerSliderCell()
        slider.minValue = 0; slider.maxValue = 1; slider.isContinuous = true
        slider.target = context.coordinator; slider.action = #selector(Coordinator.changed(_:))
        return slider
    }
    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        slider.doubleValue = muted ? 0 : value
        slider.isEnabled = enabled
        slider.controlSize = large ? .regular : .small
        (slider.cell as? MixerSliderCell)?.isMuted = muted
        slider.setAccessibilityLabel(label)
        slider.needsDisplay = true
    }
    final class Coordinator: NSObject {
        var parent: VolumeControl
        init(_ parent: VolumeControl) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) { parent.value = sender.doubleValue }
    }
}

@available(macOS 14.2, *)
struct MixerView: View {
    @ObservedObject var model: MixerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                DesignIcon(name: "dial", size: 15).frame(width: 16, height: 16)
                Text("Soundcheck").font(.system(size: 14, weight: .semibold))
                Spacer()
                Menu {
                    Button("Reset app volumes") { model.reset() }
                    Button(model.enabled ? "Turn off app controls" : "Turn on app controls") {
                        if model.enabled { model.disable() } else { model.enable() }
                    }
                    Divider()
                    Button("Quit Soundcheck") { model.disable(); NSApplication.shared.terminate(nil) }
                } label: { DesignIcon(name: "settings").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityLabel("Soundcheck settings")
            }.frame(height: 24)
            masterVolume
            outputSelector
            if let error = model.error {
                Text(error).font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if !model.enabled {
                Text("App controls are off. Turn them on in settings.")
                    .font(.system(size: 11)).foregroundStyle(MixerTheme.secondary)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("APPLICATIONS").foregroundStyle(MixerTheme.muted)
                    Spacer()
                    Text("\(model.apps.filter { $0.active && !model.muted.contains($0.id) }.count) playing")
                        .foregroundStyle(MixerTheme.secondary)
                }.font(.system(size: 10)).padding(.top, 2).padding(.bottom, 4)
                if model.apps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform").font(.title2)
                        Text("Play music or a video to see its app here.").font(.system(size: 12))
                    }.foregroundStyle(MixerTheme.secondary).frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.apps) { app in
                                appRow(app)
                                if app.id != model.apps.last?.id { separator }
                            }
                        }
                    }.frame(height: min(CGFloat(model.apps.count) * 88, 352))
                }
            }
            separator
        }
        .padding(16).frame(width: 360)
        .foregroundStyle(MixerTheme.text)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).fill(MixerTheme.background.opacity(0.62)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .preferredColorScheme(.dark)
    }
    private var separator: some View { Rectangle().fill(.white.opacity(0.05)).frame(height: 1) }
    private var outputSelector: some View {
            Button { model.showingOutput.toggle() } label: {
                HStack(spacing: 9) {
                    DesignIcon(name: "laptop", size: 17)
                    Text(model.outputName).font(.system(size: 12)).lineLimit(1)
                    Spacer(minLength: 0)
                    DesignIcon(name: "chevron", size: 14)
                }.padding(.horizontal, 12).frame(height: 40)
                .background(MixerTheme.output, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.09)))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }.buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel("Output: \(model.outputName)")
            .popover(isPresented: $model.showingOutput, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Follows your Mac’s current output").font(.system(size: 12))
                    Button("Open Sound Settings…") {
                        model.showingOutput = false
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
                    }
                }.padding(16)
            }
    }
    private var masterVolume: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                DesignIcon(name: "master-speaker")
                Text("Master volume").font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.masterAvailable {
                    (Text("\(Int(model.masterVolume * 100))").font(.system(size: 20, weight: .medium)) + Text("%").font(.system(size: 12)).foregroundColor(MixerTheme.secondary)).monospacedDigit()
                } else { Text("Fixed").font(.system(size: 12)).foregroundStyle(MixerTheme.secondary) }
            }
            HStack(spacing: 12) {
                Button { model.toggleMasterMute() } label: {
                    DesignIcon(name: model.masterVolume == 0 ? "muted" : "speaker").frame(width: 30, height: 30)
                }.buttonStyle(.plain).focusEffectDisabled().disabled(!model.masterAvailable)
                .accessibilityLabel(model.masterVolume == 0 ? "Unmute master volume" : "Mute master volume")
                VolumeControl(value: Binding(get: { model.masterVolume }, set: { model.setMaster($0) }), enabled: model.masterAvailable, large: true, label: "Master volume").frame(height: 24)
            }
        }.padding(16)
        .background(MixerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.09)))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }
    private func appRow(_ app: AudioApp) -> some View {
        let isMuted = model.muted.contains(app.id)
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Image(systemName: "waveform.app").font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(MixerTheme.accent)
                        .background(MixerTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(isMuted ? "Muted" : (app.active ? "Playing audio" : "Not playing"))
                        .font(.system(size: 10)).foregroundStyle(isMuted ? MixerTheme.accent : MixerTheme.muted)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button { model.toggleMute(app) } label: {
                    DesignIcon(name: isMuted ? "muted" : "speaker").frame(width: 24, height: 24)
                        .background(isMuted ? MixerTheme.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).focusEffectDisabled().disabled(!model.enabled)
                .accessibilityLabel("\(isMuted ? "Unmute" : "Mute") \(app.name)")
                VolumeControl(value: Binding(get: { model.volume(for: app.id) }, set: {
                    if isMuted { model.muted.remove(app.id) }
                    model.setVolume(app, $0)
                }), muted: isMuted, enabled: model.enabled, label: "\(app.name) volume").frame(height: 24)
                Text("\(isMuted ? 0 : Int(model.volume(for: app.id) * 100))%")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(isMuted ? MixerTheme.muted : MixerTheme.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }.padding(.vertical, 12)
    }
}
