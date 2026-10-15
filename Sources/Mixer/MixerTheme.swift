import AppKit
import SwiftUI

/// Dynamic colors shared by SwiftUI and the AppKit slider cell.
enum MixerTheme {
    static let panel = adaptive(light: 0xF4F5F7, dark: 0x1E2227)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF, darkAlpha: 0.06)
    static let output = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF, darkAlpha: 0.05)
    static let text = adaptive(light: 0x20242C, dark: 0xF1F2F4)
    static let secondary = adaptive(light: 0x4D5868, dark: 0xB2B6C0)
    static let muted = adaptive(light: 0x657083, dark: 0x8B929E)
    static let error = adaptive(light: 0xA34406, dark: 0xFFB86B)
    static let panelBorder = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.12)
    static let surfaceBorder = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.09)
    static let separator = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.07)

    static let accentColor = adaptiveColor(light: 0x2862BA, dark: 0xA8C7FF)
    static let accent = Color(nsColor: accentColor)
    static let trackColor = adaptiveColor(light: 0xCDD3DC, dark: 0x444850)
    static let thumbColor = adaptiveColor(light: 0xFFFFFF, dark: 0xF1F2F4)
    static let inactiveThumbColor = adaptiveColor(light: 0x98A2B1, dark: 0xB2B6C0)
    static let thumbBorderColor = adaptiveColor(light: 0x000000, dark: 0x000000, lightAlpha: 0.16, darkAlpha: 0)

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: adaptiveColor(light: light, dark: dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    private static func adaptiveColor(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let rgb = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        }
    }
}
