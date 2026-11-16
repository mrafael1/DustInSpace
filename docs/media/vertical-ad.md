# Vertical gameplay ad

[`vertical-ad.mp4`](vertical-ad.mp4) is a full-screen, 30-second, 1080 x 1920,
30 fps H.264/AAC ad intended to repeat as a whole video.

## Final edit

The actual animated title opens the video. Its star leaves the logo and travels
down to the constellation. Quiet gameplay leads into brief current, heat and
gravity glimpses, then dissolves directly to the animated title screen with
Download Now, Google Play and App Store. There is no Scorpio painting/reveal,
phone mockup, chapter card, progress bar or separate outro loop.

| Time | Footage |
|---|---|
| 0.0-3.4 s | Title, star departure and camera descent to the chart |
| 2.8-13.6 s | Slow Scorpio gameplay: launches, linking and payouts |
| 13.0-16.5 s | Aquarius: stars carried by a current |
| 15.9-19.4 s | Leo: stars growing in the heat |
| 18.8-22.3 s | Sagittarius: the hungry black hole |
| 21.7-30.0 s | Animated title screen and store call to action |

Adjacent clips overlap for 0.6 seconds with eased dissolves and audio fades.
A few HD captions fade over the footage; one sentence spans the mechanics
montage. The final call to action uses the game's exact 5x7 glyphs at the same
6x pixel scale as the footage, with a native one-pixel shadow and palette colors.
The title lettering and its sparkles are actual game footage, not a recreation.

The store text fades before the last 0.6 seconds, when the title sky dissolves
to the exact opening state. The final source frame matches the first exactly.
The musical bed repeats continuously across the same 30-second boundary.

Google Play and App Store are plain text rather than official store badges.
The owner selected Download Now; destination URLs were not supplied and belong
in the social post or paid-ad configuration. No social upload occurred.

## Source and presentation

The seed-7 opening and later chapter introductions use the existing game
presentation at main revision `1595a230`. No rules, balance, game assets or user
saves change. The capture script hides teaching messages, chart labels, stage
numbers and TAP TO START. `tools/media/ad_chart.gd` is a capture-only subclass
which omits menu plaques, selection brackets, navigation and the stage crown.
The production scene and its script are unchanged.

Footage is lossless PNG/WAV enlarged exactly 6x with nearest filtering. Its
intentional pixel art is preserved. Marketing captions use system fonts
(Segoe UI/Arial on Windows, DejaVu Sans on Linux); store text uses existing game
glyph tables. Font files are not redistributed. H.264 uses CRF 14, and audio
muxing copies the video stream rather than encoding it again.

Captured sound follows each gameplay edit. The original synthesized music
includes ringing notes from its previous cycle and repeats without fading to
silence at the video seam. No voiceover or third-party music is used.

## Rebuild

Requires Godot 4.7, Python with Pillow, FFmpeg and a supported system font.
Create these directories under `output/media/`: `lossless`, `aquarius`, `leo`,
`gravity`, `title`, `voyage`. Import, then capture the opening gameplay:

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
| title | `--mode=title --length=10` |
| voyage | `--mode=voyage --length=5` |

Run `python tools/media/build_ad.py`. It writes `dust-in-space-looping-ad.mp4`,
a poster, contact sheet, loop boundary stills and musical cue under
`output/media/ad/`. Options: `--out PATH`, `--preview`, `--font-dir PATH`,
`--media-dir PATH`, and `--cta "COMING SOON"`.

## Validation

- Reviewed full-resolution title/store typography, the direct mechanics-to-title
  dissolve, the contact sheet and encoded video frames.
- All 900 frames have footage, with no painted Scorpio shot in the timeline.
- Opening and closing source frames match exactly; the musical signal also
  meets at the 30-second boundary.
- FFprobe confirmed 30.000 seconds, 1080 x 1920, 30 fps and stereo AAC;
  FFmpeg decoded the full export without errors.
- Python compilation and git diff checks passed. Gameplay tests and balance
  simulation are not applicable to this media-only change.
