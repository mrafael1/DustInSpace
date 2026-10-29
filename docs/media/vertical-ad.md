# Vertical gameplay ad

[`vertical-ad.mp4`](vertical-ad.mp4) is a 30-second, 1080 x 1920, 30 fps
H.264/AAC ad intended to repeat as a whole video.

## Final direction

Full-screen game footage with a few HD captions over it. There is no phone
mockup, inset footage, chapter card, progress bar or separate outro loop.
The actual animated title begins the video: its star leaves the logo and
travels down to the constellation. After gameplay, mechanics glimpses and
the Scorpio painting, the same captured journey runs in reverse to return
to the opening title state. The last source frame matches the first exactly.
The store line fades away before the title returns, so it cannot pop at replay.

| Time | Footage |
|---|---|
| 0.0-3.4 s | Actual title screen, star departure and camera descent to the chart |
| 2.8-13.6 s | Slow Scorpio gameplay: launches, linking and payouts |
| 13.0-16.5 s | Aquarius: stars carried by a current |
| 15.9-19.4 s | Leo: stars growing in the heat |
| 18.8-22.3 s | Sagittarius: the hungry black hole |
| 21.7-26.8 s | Scorpio's existing chart completion reveal and painting |
| 26.2-30.0 s | Reverse star journey, reconnecting to the opening title |

Adjacent clips overlap for 0.6 seconds with an eased dissolve, and their
captured audio fades at the edits. Captions do not announce each cut: one
sentence spans the mechanics montage. Download Now and plain Google Play /
App Store names appear over the Scorpio reveal. Store URLs were not supplied;
put them in the social post or paid-ad destination. Nothing is published.

## Source and presentation

The seed-7 opening and later chapter introductions use the existing game
presentation at main revision `1595a230`. Scorpio's reveal is the chart's
completion preview on an unsaved in-memory chapter, not a claim that the
opening run completed it. The return to the title is an editorial reversal
of the captured opening animation. No game rules, balance, art or user saves
are changed. The capture script hides teaching messages, chart navigation
labels, stage numbers and TAP TO START for a cleaner cinematic presentation.
`tools/media/ad_chart.gd` subclasses the existing chart only during capture
to omit menu plaques, selection brackets, navigation and the final-stage crown;
its sky, animated title, star journey and painting reveal remain the game's.

All footage is lossless PNG/WAV and enlarged exactly 6x with nearest filtering
to fill 1080 x 1920. Pixel art retains its actual pixels; only the ad's captions
are rendered directly at HD resolution. System fonts are not redistributed.
H.264 uses CRF 14, and muxing audio copies the encoded video without re-encoding.

Captured sound follows each footage clip. The original synthesized musical
bed repeats over the full 30-second cycle, including ringing notes from the
previous cycle, so there is no fade to silence at the replay seam. No voiceover
or third-party music is used.

## Rebuild

Requires Godot 4.7, Python with Pillow, FFmpeg and a supported system font
(Segoe UI/Arial on Windows; DejaVu Sans on Linux). Create these directories
under `output/media/`: `lossless`, `aquarius`, `leo`, `gravity`, `painting`,
`voyage`. Import the project, then capture the opening gameplay:

```powershell
godot --headless --editor --import --quit --log-file output/media/import.log
godot --path . --log-file output/media/capture.log --windowed --resolution 540x960 --fixed-fps 30 --write-movie output/media/lossless/gameplay.png --script tools/media/capture_ad.gd
```

Repeat the capture command with the directory and user arguments below
(user arguments follow `--`):

| Directory | User arguments |
|---|---|
| aquarius | `--map=aquarius_body --length=7` |
| leo | `--map=leo_haunch --length=7` |
| gravity | `--map=sagittarius_body --length=7` |
| painting | `--mode=painting --length=8` |
| voyage | `--mode=voyage --length=5` |

Run `python tools/media/build_ad.py`. It writes `dust-in-space-looping-ad.mp4`,
a poster, review sheet, loop boundary stills and musical cue under
`output/media/ad/`. Options: `--out PATH`, `--preview`, `--font-dir PATH`,
`--media-dir PATH`, and `--cta "COMING SOON"`. Native captures remain local
build intermediates. The obsolete separate title-loop artifact is removed.

## Validation

- Reviewed the title/star journey, full-screen gameplay, mechanics footage,
  Scorpio reveal, chronological contact sheet and dissolve boundaries.
- Confirmed all 900 frames have footage, with no gaps or more than two clips
  overlapping. The opening and closing source frames match exactly.
- Confirmed the musical signal meets continuously at the 30-second boundary.
- FFprobe confirmed 30.000 seconds, 1080 x 1920, 30 fps and stereo AAC.
- FFmpeg decoded the whole export without errors; checked encoded frames
  around transitions and the title seam.
- Python compilation and git diff checks passed. Gameplay unit tests and
  balance simulation are not applicable to this media-only change.
