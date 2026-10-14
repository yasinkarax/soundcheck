# Soundcheck

**Turn down one app without turning down your whole Mac.**

Soundcheck is a small app that lives in your Mac’s menu bar. It gives each app its own volume slider and mute button—similar to the Windows volume mixer. The compact dark interface also includes a master-volume slider for your current output.

For example, you can lower your music, keep a video louder, or mute one app while the others keep playing.

## What you need

- A Mac running **macOS 14.2 or later**.
- Speakers or headphones with stereo output. Some audio devices are not supported yet.

Soundcheck is an early version. If you already have **Soundcheck.app**, skip to **Using Soundcheck** below. Otherwise, [download Soundcheck 0.3.0 for macOS](https://github.com/yasinkarax/soundcheck/raw/refs/heads/main/downloads/Soundcheck-0.3.0.zip?download=1) or follow **Build the app** at the end of this page.

## Using Soundcheck

If you are replacing an older build, quit Soundcheck first, then open the newly downloaded app. You can check its version from the settings button → **About Soundcheck**.

1. Open **Soundcheck.app**. Look for the **dial icon** in the menu bar at the top of your screen—it does not open a regular app window.
2. Play music or a video in another app. It should appear in Soundcheck within a few seconds.
3. Move the slider next to an app to change its volume. Click its speaker button to mute or unmute it.
4. macOS may show its own system privacy prompt the first time Soundcheck adjusts app audio. This is required by macOS; Soundcheck does not show a separate permission step.

### What the buttons do

- **Volume slider:** adjusts that app from 0% to 100%. It does not boost audio above its normal volume.
- **Speaker button:** mutes or unmutes just that app.
- **Master volume:** changes your output device’s volume. If the device does not support this, it shows “Fixed.”
- **Settings button** (top right): opens reset, turn-off, and quit actions.
- **Reset app volumes:** clears Soundcheck’s adjustments and unmutes all apps controlled by Soundcheck.
- **Turn off:** stops controlling audio and restores normal playback.
- **Quit:** closes Soundcheck and restores normal playback.

Soundcheck uses your Mac’s current speakers or headphones. It does not choose a different output for each app.

## macOS audio access

Soundcheck needs access to an app’s sound to change its volume. macOS calls this audio recording access, even though **Soundcheck does not save recordings or upload your audio**. All audio processing happens on your Mac.

If you denied access, open **System Settings → Privacy & Security** and look for **Screen & System Audio Recording** or **System Audio Recording**. The wording depends on your macOS version. Allow Soundcheck, then quit and reopen it if prompted.

## If something is not working

**An app is missing**

Start playing sound in that app and wait a few seconds. Soundcheck shows apps that are playing audio, along with apps you have already adjusted.

**The slider does not change the sound**

Make sure app controls are turned on from the settings button and macOS has granted audio access. Check any error message shown in Soundcheck.

**My headphones or speakers are not supported**

Try your Mac’s built-in speakers. This early version supports a limited set of stereo audio layouts.

**One app appears more than once**

Some apps use separate background processes for audio. These can appear as separate entries. Browser tabs may share one volume control.

**My volume settings disappeared**

Settings are kept only while Soundcheck is running. They are not saved when you quit.

**I changed speakers and the volume briefly changed**

Soundcheck follows your Mac’s output device. It may take a few seconds to apply your adjustments again after a change.

## Build the app

This section is for people comfortable using **Terminal**. You only need to build the app once to try it, and again when you want a newer version.

### 1. Install Apple’s developer tools

Open **Terminal** from Applications → Utilities, paste this command, and press Return:

```sh
xcode-select --install
```

Follow the installation prompts. If the tools are already installed, continue to the next step.

### 2. Download and build Soundcheck

Run these commands one at a time in Terminal:

```sh
git clone https://github.com/yasinkarax/soundcheck.git
cd soundcheck
./scripts/build-app.sh
```

Wait for the build to finish. It creates **Soundcheck.app** inside the project’s **dist** folder.

### 3. Open it

```sh
open dist/Soundcheck.app
```

Then follow **Using Soundcheck** above. You can also open the app from Finder.

The build is intended for local use. A signed, notarized installer for wider distribution is not available yet.

## For developers

Soundcheck uses SwiftUI for the menu bar interface and Core Audio process taps for per-app audio control. A C audio callback applies volume changes without allocating memory or taking locks on the audio thread.

The build also creates **dist/Soundcheck.zip**, containing the app and its bundled design assets. Unzip it and open **Soundcheck.app**. This local build is not notarized.

Run the audio-processing checks from the project folder:

```sh
./scripts/test-audio.sh
```

These checks cover volume changes, mute, invalid values, and short audio buffers, with memory-safety checks enabled. Per-app volume and mute have also been tested by the project owner on their Mac. Compatibility across different Macs, Bluetooth devices, permission states, and output changes still needs broader testing.

[Apple’s documentation on Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
