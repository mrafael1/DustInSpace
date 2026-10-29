# Vertical video ad

[`vertical-ad.mp4`](vertical-ad.mp4) is a 30-second English ad for TikTok and
YouTube Shorts: 1080 x 1920, 30 fps, H.264 with AAC stereo.
[`vertical-ad-title-loop.mp4`](vertical-ad-title-loop.mp4) is the separate,
silent 4.8-second closing loop.

## Edit

| Time | Footage |
|---|---|
| 0-10 s | Quiet Scorpio gameplay: planet launches, a three-star link, dust/light payouts |
| 10-13 s | Aquarius: currents carrying stars, including a drain |
| 13-16 s | Leo: stars growing in the heat |
| 16-19 s | Sagittarius: the hungry black hole pulling stars in |
| 19-23 s | Scorpio chart's existing completion reveal and painted scorpion |
| 23-30 s | Animated in-game title, Scorpio painting, Download Now and store names |

The opening uses seed 7 on main at `1595a230`. The later chapters' existing
in-game introductions demonstrate their rules. The Scorpio reveal uses the
chart's existing completion preview on an unsaved in-memory chapter; it is not
presented as the end of the opening run. No gameplay rules, rewards, balance,
or user save data are changed for recording.

The ending extracts the actual animated title pixels from lossless footage,
including letter sparkles and the central twinkling star. The original Scorpio
painting is shown below it with animated landmark glints from the chart footage.
Navigation, stage numbers and TAP TO START are omitted from the closing card.
The 4.8-second cycle dissolves back to its first frame over its final 0.4 seconds;
the final section repeats that cycle. The title is not retyped or recreated.

The owner selected Download Now. Google Play and App Store are plain typeset
names rather than official store badges. Store URLs were not supplied; put
them in the social post or paid-ad destination. This task does not publish.

## Image and audio

The marketing composition is authored directly at HD resolution, with crisp
system-font captions and device framing. All gameplay is captured as lossless
PNG/WAV and shown at exactly 4x nearest scale. The game and title retain their
intentional pixel art. No assets in the game are modified. H.264 uses CRF 14;
adding audio copies the encoded video without another encode.

Audio follows each edit from its own captured WAV, over the original synthesized
pentatonic musical cue. There is no voiceover or third-party music. System fonts
are not bundled: Segoe UI/Arial on Windows, with a DejaVu Sans fallback on Linux.

## Rebuild

Requires Godot 4.7, Python with Pillow, FFmpeg and a supported system font. From
the repo root, create `output/media/lossless`, `aquarius`, `leo`, `gravity`,
`title` and `painting` directories under `output/media/` and import the project.

```powershell
godot --headless --editor --import --quit --log-file output/media/import.log
godot --path . --log-file output/media/capture.log --windowed --resolution 540x960 --fixed-fps 30 --write-movie output/media/lossless/gameplay.png --script tools/media/capture_ad.gd
```

Repeat the capture command with the output directory, user arguments and lengths
below (user arguments follow `--`):

| Directory | User arguments |
|---|---|
| aquarius | `--map=aquarius_body --length=7` |
| leo | `--map=leo_haunch --length=7` |
| gravity | `--map=sagittarius_body --length=7` |
| title | `--mode=title --length=8` |
| painting | `--mode=painting --length=8` |

Then run `python tools/media/build_ad.py`. The builder writes the ad, title loop,
poster, review sheet and musical cue under `output/media/ad/`. `--out PATH`
changes that directory; `--preview` makes stills without encoding; `--cta
"COMING SOON"` changes the store call to action. `--font-dir` and `--capture-dir`
override the local dependencies. Captures remain local build intermediates.

## Validation

- Reviewed the chapter footage, full-resolution closing card, chronological
  contact sheet and decoded frames from the final video.
- FFprobe confirmed 30.000 seconds, 1080 x 1920, H.264, 30 fps and stereo AAC;
  the separate silent closing loop is 4.800 seconds.
- FFmpeg decoded both complete exports without errors.
- Confirmed the closing loop's first and last source frames match exactly and
  that its middle frames animate.
- Python compilation and git diff checks passed. No gameplay tests or balance
  simulation are applicable to this media-only change.
