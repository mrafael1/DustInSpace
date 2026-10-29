# Vertical video ad

[`vertical-ad.mp4`](vertical-ad.mp4) is a 24-second English ad for TikTok and
YouTube Shorts: 1080 x 1920, 30 fps, H.264 with AAC stereo.

The first 20 seconds show actual gameplay recorded from main at `1595a230`
with seed 7: telescope launches, three-star tap links, payouts, and Sun
rekindling. No gameplay rules, rewards, balance, or progress were modified for
the recording. The last four seconds show an HD Scorpio constellation, game title,
and **Download Now / Google Play / App Store**, as requested by the owner.
The store names are plain typeset text, not official store badges. Store links
were not supplied; add them to the social post or paid-ad destination settings.
This task does not upload or publish the ad.

The owner requested a sharper presentation after reviewing the first version.
The revised composition is authored directly at 1080 x 1920: antialiased system
fonts, HD stars and device frame, and vector constellation linework. The first
version's enlarged pixel-font captions and 216 x 384 marketing composition are
replaced. This typography exception applies to the ad only; game assets and
their art rules are unchanged.

The gameplay is now captured as lossless PNG/WAV, avoiding the first version's
MJPEG artifacts. The full 180 x 320 game remains visible at exactly 4x nearest
scale inside a 720 x 1280 device frame. Its authentic pixel art is preserved;
no extra gameplay detail is invented. H.264 uses CRF 14, and the encoded video
stream is copied when adding audio, avoiding another encode.

Audio combines actual game sound with a quiet original synthesized pentatonic
cue. There is no voiceover or third-party music. Segoe UI/Arial system fonts
are used on Windows, with a DejaVu Sans fallback on Linux. Font files are not
bundled or redistributed.

## Rebuild

Requires Godot 4.7, Python with Pillow, FFmpeg and a supported system font.
From the repo root:

```powershell
New-Item -ItemType Directory -Force output/media/lossless | Out-Null
godot --headless --editor --import --quit --log-file output/media/import.log
godot --path . --log-file output/media/capture-hd.log --windowed --resolution 540x960 --fixed-fps 30 --write-movie output/media/lossless/gameplay.png --script tools/media/capture_ad.gd
python tools/media/build_ad.py
```

The builder writes the MP4, poster, gameplay preview, review sheet and original
musical cue under `output/media/ad/`. HD frames stream directly to FFmpeg.
`--out PATH` changes the output directory; `--cta "COMING SOON"` produces a
pre-release variant; `--preview` makes stills without encoding. `--font-dir PATH`
and `--capture-dir PATH` override the local dependencies. The capture
bot uses supported input handlers and valid links; it never injects stars or
forces a Big Bang. Aim coordinates and timings are capture choreography,
not game tuning.

## Validation

- Godot rendered 960 lossless gameplay frames at 30 fps.
- Reviewed full-resolution gameplay and end-card previews, a chronological
  contact sheet, and decoded frames from the encoded MP4.
- FFprobe confirmed 24.000 seconds, 1080 x 1920, H.264, 30 fps, AAC stereo at 48 kHz.
- FFmpeg decoded the entire final MP4 without errors.
- Python compilation and `git diff --check` passed.
- No gameplay or balance files changed; gameplay unit tests and the balance
  simulator are not applicable to this media-only change.

Godot reported shutdown resource diagnostics after successfully writing the
lossless movie. They did not prevent capture or affect final-file decoding.
