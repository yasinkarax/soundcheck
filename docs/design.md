# Interface reference

The native menu bar popover follows [Figma node 2:3587](https://www.figma.com/design/pjPHD13UAhd8kfOLiO6vC8/Untitled?node-id=2-3587).

- 360-point dark popover, 16-point padding, pale blue controls.
- Native Mac system font, as requested by the project owner.
- Dial, settings, speaker, muted-speaker, laptop, and chevron assets exported from the supplied design. Original SVGs and 4× PNG renders are bundled in `Sources/Mixer/Resources`.
- Real running-app icons replace the design's sample apps. Playback status replaces example track titles; track metadata is not collected.
- Native accessible NSSlider controls use a custom cell for the design's track and thumb.
- The menu bar and popover window are provided by macOS; the mockup's Wi-Fi, battery, time, and pointer are not duplicated inside the app.
- Master volume uses the current output's Core Audio virtual main volume when available. Fixed-volume outputs are displayed honestly as “Fixed.”
- The output menu opens macOS Sound Settings. Per-app output routing remains outside this version's scope.

For a deterministic native layout snapshot without starting audio taps:

```sh
/path/to/Soundcheck.app/Contents/MacOS/Soundcheck --render-preview /tmp/soundcheck-preview.png
```

This diagnostic mode uses sample application names and volumes and exits after writing the image. Normal launches always discover real audio processes.
