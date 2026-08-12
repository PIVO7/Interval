# Ambient audio files

Drop the seven audio files listed below into this folder. They are picked up
automatically because the whole `Interval/` directory is included as
sources in `project.yml`. Run `xcodegen generate` after adding them so Xcode
sees the new resources.

## Required files

| Filename            | Used as           | Suggested length | Max size |
| ------------------- | ----------------- | ---------------- | -------- |
| `rain.mp3`          | Regen             | 60–90 s loop     | < 1.5 MB |
| `ocean.mp3`         | Oceaangolven      | 60–90 s loop     | < 1.5 MB |
| `forest.mp3`        | Bos / vogels      | 60–90 s loop     | < 1.5 MB |
| `lofi.mp3`          | Lo-fi beats       | 90–180 s loop    | < 3 MB   |
| `white_noise.mp3`   | White noise       | 30–60 s loop     | < 1 MB   |
| `brown_noise.mp3`   | Brown noise       | 30–60 s loop     | < 1 MB   |

Filenames must match the `AmbientSound.rawValue` cases in `Audio/AudioSettings.swift`
(case-sensitive). `.wav` is also accepted as a fallback by the player.

## Format

- **Codec:** MP3, 128 kbps mono (or 96 kbps for noise tracks)
- **Sample rate:** 44.1 kHz
- **Loop:** seamless — the file is played with `numberOfLoops = -1`. Trim leading
  silence and ensure the tail crossfades cleanly back to the head, otherwise
  the loop boundary will be audible.
- **Loudness:** normalise around -18 LUFS so signal tones can sit cleanly on top.

## Licensing — must be royalty-free for commercial use

Pick from one of these sources and keep the license URL + author in a
`CREDITS.md` next to the file (or in the App Store listing). Suggested sources:

- **Pixabay Music / Sound Effects** (https://pixabay.com/sound-effects/) —
  Pixabay Content License, free for commercial use, no attribution required.
- **Freesound** (https://freesound.org) — filter for `Creative Commons 0`
  (public domain). CC-BY also OK if you credit the author.
- **Zapsplat** (https://www.zapsplat.com) — free with free account, requires
  attribution unless you upgrade.
- **Mixkit** (https://mixkit.co/free-stock-music/) — free for commercial use,
  no attribution.

For the noise tracks (`white_noise`, `brown_noise`) you can generate them in
Audacity (Generate → Noise) and export — no licensing concerns.

## Verifying a file is picked up

After adding files and running `xcodegen generate`, run the app. The
`AudioEngine.isAvailable(_:)` helper returns `true` once a file is bundled
correctly. The Account screen's sound picker can be wired to grey out
unavailable options using that helper if desired.

The `AudioEngine` logs `Ambient file not bundled — skipping playback: <name>`
to the console if a file is missing.
