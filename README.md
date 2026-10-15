# Soundcheck

**Control each app’s volume from your Mac’s menu bar.**

Turn down your music, keep a video louder, or mute one app while the others keep playing—similar to the Windows volume mixer.

**[Download Soundcheck 0.4.0](https://raw.githubusercontent.com/yasinkarax/soundcheck/2bcbd282caa8185d9455670673295a75a9778147/downloads/Soundcheck-0.4.0.zip)**

For **Apple silicon Macs (M1 or newer)** running **macOS 14.2 or later**. This download does not support Intel Macs.

## 1. Install

1. Download the ZIP file using the link above.
2. Double-click the ZIP to unpack it.
3. Drag **Soundcheck.app** into your **Applications** folder.
4. Open **Soundcheck** from Applications.

**Updating?** Quit the older Soundcheck from its settings menu before replacing it with the new app. Check your version in **Soundcheck settings → About Soundcheck…**.

### If macOS says “Apple could not verify Soundcheck”

This beta has not been notarized by Apple, so macOS may block the first launch. If you trust this repository and the download:

1. Try opening Soundcheck once, then dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the **Security** section and click **Open Anyway** beside the Soundcheck message.
4. Confirm **Open** when asked.

macOS remembers this exception for that copy of the app. Work or school Macs may restrict this option. See [Apple’s opening instructions](https://support.apple.com/en-us/102445) if you get stuck.

## 2. Adjust your sound

1. Play music or a video in another app.
2. Click the **Soundcheck icon in the menu bar**, at the top of your screen. Soundcheck opens a small panel there.
3. Move an app’s slider to change its volume, or click its speaker button to mute it.
4. If macOS asks for access to system audio, allow Soundcheck so it can adjust the sound.

Apps should appear within a few seconds of playing audio.

### What the controls do

Open **Soundcheck settings** with the sliders icon at the top right of its panel.

- **App slider:** changes that app’s volume from 0% to 100%.
- **Speaker button:** mutes or unmutes that app.
- **Master volume:** changes your Mac’s current output volume. **Fixed** means that output does not support this control.
- **Reset app volumes:** clears app adjustments and unmutes the apps.
- **Turn off app controls:** restores normal app playback. Choose **Turn on app controls** to resume your adjustments.
- **Quit Soundcheck:** closes the app and restores normal app playback.

Master-volume changes remain in effect after you reset, turn off, or quit Soundcheck. Use your Mac’s volume controls to change them again.

Soundcheck follows your Mac’s speakers or headphones and its **Light, Dark, or Auto appearance**.

## Audio access and privacy

Soundcheck needs access to app audio to change its volume. macOS calls this recording access, but **Soundcheck does not save recordings or upload your audio**. All audio processing happens on your Mac.

If you previously denied access:

1. Open **System Settings → Privacy & Security → Screen & System Audio Recording**. The wording may vary by macOS version.
2. Enable **Soundcheck** in the system audio recording list.
3. Quit and reopen Soundcheck if macOS asks you to.

If Soundcheck says app controls are off, turn them on from its settings button.

See [Apple’s audio-access guide](https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac) for help finding this setting.

## Need help?

[Report a problem](https://github.com/yasinkarax/soundcheck/issues). Include your Mac model, macOS version, Soundcheck version, output device, and what happened.

## Current limits

- The download supports Apple silicon Macs only.
- Stereo output is required. Some stereo devices are unsupported; compatibility testing is still ongoing.
- Soundcheck cannot boost an app above 100% or send different apps to different outputs.
- App volume and mute settings are not saved between launches.
