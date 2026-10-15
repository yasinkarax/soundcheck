import SwiftUI

struct DesignIcon: View {
    let name: String
    var size: CGFloat = 16
    var tint: Color = MixerTheme.secondary
    static func image(_ name: String) -> NSImage {
        let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources")!
        return NSImage(contentsOf: url)!
    }
    var body: some View {
        let image = Self.image(name)
        image.isTemplate = true
        return Image(nsImage: image).renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).foregroundStyle(tint)
    }
}

struct BrandLogoMark: View {
    var width: CGFloat = 16

    private let logoWidth: CGFloat = 69.25
    private let logoHeight: CGFloat = 56.25

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / logoWidth
            ZStack(alignment: .topLeading) {
                layer("logo-vinyl", width: 53.5, height: 53.5, scale: scale)
                    .position(x: 26.75 * scale, y: 29.5 * scale)
                layer("logo-groove", width: 34, height: 34, scale: scale)
                    .position(x: 26.75 * scale, y: 29.5 * scale)
                layer("logo-spindle", width: 6, height: 6, scale: scale)
                    .position(x: 26.75 * scale, y: 29.5 * scale)
                layer("logo-tonearm", width: 20.5, height: 44.5, scale: scale)
                    .position(x: 57.25 * scale, y: 24 * scale)
                layer("logo-stylus", width: 11, height: 11, scale: scale)
                    .position(x: 49.25 * scale, y: 44 * scale)
                layer("logo-pivot", width: 7, height: 7, scale: scale)
                    .position(x: 65.75 * scale, y: 3.5 * scale)
            }
        }
        .frame(width: width, height: width * logoHeight / logoWidth)
        .accessibilityHidden(true)
    }

    private func layer(_ name: String, width: CGFloat, height: CGFloat, scale: CGFloat) -> some View {
        Image(nsImage: DesignIcon.image(name))
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: width * scale, height: height * scale)
            .foregroundStyle(name == "logo-vinyl" || name == "logo-groove" ? MixerTheme.accent : MixerTheme.text)
    }
}

// NSSlider supplies native mouse, keyboard, and accessibility behavior; the cell
// draws the slimmer track and circular thumb from the Figma design.
final class MixerSliderCell: NSSliderCell {
    var isMuted = false
    override var knobThickness: CGFloat { controlSize == .regular ? 16 : 12 }
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let bounds = controlView?.bounds ?? rect
        let thickness: CGFloat = controlSize == .regular ? 6 : 4
        let bar = NSRect(x: rect.minX, y: bounds.midY - thickness / 2, width: rect.width, height: thickness)
        MixerTheme.trackColor.setFill()
        NSBezierPath(roundedRect: bar, xRadius: thickness / 2, yRadius: thickness / 2).fill()
        let fraction = CGFloat((doubleValue - minValue) / max(0.001, maxValue - minValue))
        if !isMuted && isEnabled {
            MixerTheme.accentColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: bar.minX, y: bar.minY, width: bar.width * fraction, height: thickness), xRadius: thickness / 2, yRadius: thickness / 2).fill()
        }
    }
    override func drawKnob(_ rect: NSRect) {
        let diameter = knobThickness
        let centerY = controlView?.bounds.midY ?? rect.midY
        let knob = NSRect(x: rect.midX - diameter / 2, y: centerY - diameter / 2, width: diameter, height: diameter)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(controlSize == .regular ? 0.2 : 0.12)
        shadow.shadowBlurRadius = controlSize == .regular ? 3 : 1
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        (isMuted || !isEnabled ? MixerTheme.inactiveThumbColor : MixerTheme.thumbColor).setFill()
        NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
        MixerTheme.thumbBorderColor.setStroke()
        let outline = NSBezierPath(ovalIn: knob.insetBy(dx: 0.25, dy: 0.25))
        outline.lineWidth = 0.5
        outline.stroke()
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
        slider.focusRingType = .none
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
                BrandLogoMark(width: 16)
                Text("Soundcheck").font(.system(size: 14, weight: .semibold))
                Spacer()
                Menu {
                    Button("Reset app volumes") { model.reset() }
                    Button(model.enabled ? "Turn off app controls" : "Turn on app controls") {
                        if model.enabled { model.disable() } else { model.enable() }
                    }
                    Divider()
                    Button("About Soundcheck…") { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
                    Button("Quit Soundcheck") { model.disable(); NSApplication.shared.terminate(nil) }
                } label: { DesignIcon(name: "settings").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityLabel("Soundcheck settings")
            }.frame(height: 24)
            masterVolume
            outputSelector
            if let error = model.error {
                Text(error).font(.system(size: 11)).foregroundStyle(MixerTheme.error).fixedSize(horizontal: false, vertical: true)
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
                }.font(.system(size: 10)).frame(height: 14).padding(.top, 2).padding(.bottom, 4)
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
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: min(CGFloat(model.apps.count * 87 + max(model.apps.count - 1, 0)), 351))
                }
            }
            separator
        }
        .padding(16).frame(width: 360)
        .foregroundStyle(MixerTheme.text)
        .background(MixerTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(MixerTheme.panelBorder))
    }
    private var separator: some View { Rectangle().fill(MixerTheme.separator).frame(height: 1) }
    private var outputSelector: some View {
            Button { model.showingOutput.toggle() } label: {
                HStack(spacing: 9) {
                    DesignIcon(name: "laptop", size: 17, tint: MixerTheme.accent)
                    Text(model.outputName).font(.system(size: 12)).lineLimit(1)
                    Spacer(minLength: 0)
                    DesignIcon(name: "chevron", size: 14)
                }.padding(.horizontal, 12).frame(height: 40)
                .background(MixerTheme.output, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MixerTheme.surfaceBorder))
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
                DesignIcon(name: "master-speaker", tint: MixerTheme.accent)
                Text("Master volume").font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.masterAvailable {
                    (Text("\(Int(model.masterVolume * 100))").font(.system(size: 20, weight: .medium)) + Text("%").font(.system(size: 12)).foregroundColor(MixerTheme.secondary)).monospacedDigit()
                } else { Text("Fixed").font(.system(size: 12)).foregroundStyle(MixerTheme.secondary) }
            }.frame(height: 24)
            HStack(spacing: 12) {
                Button { model.toggleMasterMute() } label: {
                    DesignIcon(name: model.masterVolume == 0 ? "muted" : "speaker", tint: model.masterVolume == 0 ? MixerTheme.accent : MixerTheme.secondary).frame(width: 30, height: 30)
                }.buttonStyle(.plain).focusEffectDisabled().disabled(!model.masterAvailable)
                .accessibilityLabel(model.masterVolume == 0 ? "Unmute master volume" : "Mute master volume")
                VolumeControl(value: Binding(get: { model.masterVolume }, set: { model.setMaster($0) }), enabled: model.masterAvailable, large: true, label: "Master volume").frame(height: 24)
            }
        }.padding(16)
        .background(MixerTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MixerTheme.surfaceBorder))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }
    private func appRow(_ app: AudioApp) -> some View {
        let isMuted = model.muted.contains(app.id)
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().interpolation(.high).scaledToFit().frame(width: 30, height: 30)
                } else {
                    Image(systemName: "waveform.app").font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(MixerTheme.accent)
                        .background(MixerTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        .frame(height: 17, alignment: .leading)
                    Text(isMuted ? "Muted" : (app.subtitle ?? (app.active ? "Playing audio" : "Not playing")))
                        .font(.system(size: 10)).foregroundStyle(isMuted ? MixerTheme.accent : MixerTheme.muted)
                        .lineLimit(1).frame(height: 14, alignment: .leading)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button { model.toggleMute(app) } label: {
                    DesignIcon(name: isMuted ? "muted" : "speaker", tint: isMuted ? MixerTheme.accent : MixerTheme.secondary).frame(width: 24, height: 24)
                        .background(isMuted ? MixerTheme.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).focusEffectDisabled().disabled(!model.enabled)
                .accessibilityLabel("\(isMuted ? "Unmute" : "Mute") \(app.name)")
                VolumeControl(value: Binding(get: { model.volume(for: app.id) }, set: {
                    if isMuted { model.muted.remove(app.id) }
                    model.setVolume(app, $0)
                }), muted: isMuted, enabled: model.enabled, label: "\(app.name) volume").frame(width: 232, height: 24)
                Text("\(isMuted ? 0 : Int(model.volume(for: app.id) * 100))%")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(isMuted ? MixerTheme.muted : MixerTheme.secondary)
                    .frame(width: 34, alignment: .trailing)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 12)
    }
}
