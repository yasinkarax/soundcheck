# Soundcheck

A native macOS menu bar app for controlling each app’s volume independently, with per-app mute and lightweight Core Audio processing. Discover apps playing audio, adjust each app from 0–100%, and mute individually. Output follows the system default; no output routing UI.

## Build and run

Requires macOS 14.2+ and Apple’s Swift command line tools.

```sh
./scripts/build-app.sh
open dist/Soundcheck.app
```

Click the sliders icon in the menu bar, enable control, and play audio in another app. Adjusting its volume may trigger macOS’s system audio recording permission. Allow Soundcheck in System Settings → Privacy & Security → Screen & System Audio Recording if requested. Use the app bundle, not `swift run`, for permission attribution.

## Implementation

SwiftUI menu bar window; Core Audio process discovery; one private process tap and aggregate device per controlled app. The tap is muted only while being read. A C render callback applies an atomic gain value with a one-buffer ramp, without allocating or locking. Reset, turn off, and quit release taps and restore original playback. Audio never leaves memory; there is no recording or network code.

## Prototype limits

- Supports matching stereo float32 input/output stream layouts only. Unsupported devices fail before audio starts.
- Live permission behavior, audible volume, Bluetooth, and output changes require on-device testing; compilation and DSP tests do not establish these work.
- Apps with helper processes may appear as multiple entries. Browser tabs share their audio process.
- Devices and processes refresh every two seconds. Switching outputs can briefly restore original app volume while taps rebuild.
- Volume choices are session-only. Settings are not saved across launches.
- Ad-hoc signing is for local development, not distribution. Stable Developer ID signing and notarization remain future work.

## Verification

```sh
./scripts/test-audio.sh
```

The standalone C test harness runs with AddressSanitizer and UndefinedBehaviorSanitizer (no full Xcode install needed). DSP tests cover unity gain, attenuation, stereo ramping, mute, invalid gain values, and short input buffers. Manual checks: two apps playing simultaneously, mute/unmute independence, reset/off/quit restoration, permission denial, process restart, and output device changes.

Apple API reference: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
