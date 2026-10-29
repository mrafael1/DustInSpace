"""Build a 24-second 1080x1920 ad from the real Godot capture (Pillow + FFmpeg).

Usage: python tools/media/build_ad.py [--out output/media/ad] [--cta "DOWNLOAD NOW"]
Gameplay remains authentic pixel art; the ad composition and type are authored
directly at HD resolution. Requires a lossless PNG/WAV Godot movie capture.
The musical bed is original synthesized audio, with no third-party music.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import math
from pathlib import Path
import random
import struct
import subprocess
import wave

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FPS, SECONDS = 30, 24
SIZE = (1080, 1920)
PALETTE = {"sky": "#07091F", "line": "#3E3F8A", "cool": "#9FB0EE",
           "white": "#D9E2FF", "gold": "#FFE59A", "dim": "#151D4A"}
FONT_DIR = Path("C:/Windows/Fonts")
# The same Scorpio geometry as game/core/scorpio.gd, drawn as HD linework for
# the marketing card only. No in-game sprites or artwork are transformed.
LANDMARKS = [(146, 90), (160, 112), (158, 138), (134, 122), (110, 134),
             (100, 158), (95, 182), (92, 207), (88, 233), (62, 236),
             (36, 232), (14, 214), (28, 192), (52, 184)]
SEGMENTS = [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (5, 6), (6, 7),
            (7, 8), (8, 9), (9, 10), (10, 11), (11, 12), (12, 13)]


@lru_cache(maxsize=32)
def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = ["segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else [
        "segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"]
    for name in names:
        for folder in [FONT_DIR, Path("/usr/share/fonts/truetype/dejavu")]:
            path = folder / name
            if path.exists():
                return ImageFont.truetype(str(path), size)
    raise FileNotFoundError("No suitable font found; pass --font-dir PATH")


def text(im: Image.Image, value: str, y: int, size: int = 40,
         color: str = PALETTE["white"], x: int = 540, bold: bool = False) -> None:
    """Antialiased type is rendered at delivery resolution, never enlarged."""
    draw = ImageDraw.Draw(im)
    face = font(size, bold)
    if draw.textlength(value, font=face) > 900:
        raise ValueError(f"Caption exceeds the HD safe area: {value!r}")
    draw.text((x, y), value, font=face, fill=color, anchor="mt")


def tracked(im: Image.Image, value: str, y: int) -> None:
    draw = ImageDraw.Draw(im)
    face = font(26, True)
    widths = [draw.textlength(letter, font=face) for letter in value]
    x = (1080 - sum(widths) - (len(value) - 1) * 7) / 2
    for letter, width in zip(value, widths):
        draw.text((round(x), y), letter, font=face, fill=PALETTE["cool"], anchor="lt")
        x += width + 7


def background(frame: int) -> Image.Image:
    im = Image.new("RGB", SIZE, PALETTE["sky"])
    draw = ImageDraw.Draw(im)
    rng = random.Random(24)
    for index in range(105):
        x, y = rng.randrange(48, 1032), rng.randrange(75, 1790)
        color = PALETTE["cool"] if (index + frame // 18) % 23 == 0 else PALETTE["line"]
        radius = 2 if index % 7 == 0 else 1
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    return im


def gameplay_card(game: Image.Image, frame: int) -> Image.Image:
    im = background(frame)
    draw = ImageDraw.Draw(im)
    tracked(im, "DUST IN SPACE", 88)
    captions = [("The night", "needs you.", "Launch a planet. Scatter the stars."),
                ("Three stars.", "One connection.", "Link the stars. Collect the stardust."),
                ("A little dust.", "A lot of light.", "Watch the Sun come back to life."),
                ("Restore", "the Sun.", "One more launch. One brighter sky.")]
    stage = min(frame // (5 * FPS), 3)
    first, second, footer = captions[stage]
    text(im, first, 158, 70, bold=True)
    text(im, second, 238, 70, PALETTE["gold"], bold=True)
    for i in range(4):
        x = 180 + i * 184
        draw.rounded_rectangle((x, 322, x + 166, 326), radius=2,
                               fill=PALETTE["gold"] if i == stage else PALETTE["line"])
    # 4x gameplay is kept square-pixel sharp; the surrounding device, captions,
    # stars and frame are independent HD artwork. The complete game stays visible.
    draw.rounded_rectangle((162, 342, 918, 1658), radius=34,
                           fill="#0E1438", outline=PALETTE["line"], width=2)
    draw.line((159, 484, 159, 562), fill=PALETTE["cool"], width=3)
    draw.line((921, 508, 921, 618), fill=PALETTE["cool"], width=3)
    im.paste(game.resize((720, 1280), Image.Resampling.NEAREST), (180, 360))
    text(im, footer, 1700, 32, PALETTE["cool"])
    return im


def store_card(frame: int, cta: str) -> Image.Image:
    im = background(frame)
    draw = ImageDraw.Draw(im)
    tracked(im, "A SKY WORTH RESTORING", 146)
    text(im, "DUST IN", 263, 126, bold=True)
    text(im, "SPACE", 395, 154, PALETTE["gold"], bold=True)
    text(im, "A little stardust. A brighter sky.", 586, 37, PALETTE["cool"])
    # Antialiased vector constellation: no enlarged bitmap on the HD end card.
    layer = Image.new("RGBA", (2160, 3840))
    lines = ImageDraw.Draw(layer)
    points = [(round((x - 87) * 3.1 + 540) * 2,
               round((y - 163) * 3.1 + 942) * 2) for x, y in LANDMARKS]
    reveal = min(1.0, (frame / FPS - 20) / 0.7)
    for index, (a, b) in enumerate(SEGMENTS):
        lines.line((points[a], points[b]), fill=PALETTE["gold"] if index / 13 <= reveal
                   else PALETTE["line"], width=4)
    for index, (x, y) in enumerate(points):
        radius = 15 if index in (4, 10, 13) else 9
        lines.ellipse((x - radius * 2, y - radius * 2, x + radius * 2, y + radius * 2),
                      outline=PALETTE["line"], width=2)
        lines.ellipse((x - radius, y - radius, x + radius, y + radius), fill=PALETTE["gold"])
    im.paste(layer.resize(SIZE, Image.Resampling.LANCZOS), (0, 0),
             layer.resize(SIZE, Image.Resampling.LANCZOS))
    text(im, cta.title(), 1274, 65, PALETTE["gold"], bold=True)
    for label, small, center in [("Google Play", "GET IT ON", 348),
                                 ("App Store", "DOWNLOAD ON THE", 732)]:
        draw.rounded_rectangle((center - 174, 1402, center + 174, 1520), radius=20,
                               fill="#0E1438", outline=PALETTE["cool"], width=2)
        text(im, small, 1420, 17, PALETTE["cool"], center)
        text(im, label, 1450, 36, x=center, bold=True)
    text(im, "Launch. Link. Restore the Sun.", 1634, 31, PALETTE["cool"])
    return im


def music(path: Path) -> None:
    rate = 48000
    notes = [48, 55, 60, 62, 67, 62, 60, 55, 50, 57, 62, 64, 69, 64, 62, 57]
    samples = bytearray()
    for i in range(rate * SECONDS):
        t = i / rate
        value = 0.0
        for back in range(4):
            beat = math.floor(t / 0.5) - back
            if beat < 0:
                continue
            age = t - beat * 0.5
            midi = notes[beat % len(notes)]
            hz = 440.0 * 2 ** ((midi - 69) / 12)
            env = min(1.0, age / 0.025) * math.exp(-age * 2.9)
            value += (math.sin(2 * math.pi * hz * age) +
                      0.18 * math.sin(2 * math.pi * hz * 2 * age)) * env * 0.085
        value += math.sin(2 * math.pi * 130.8128 * t) * 0.012
        value *= min(1.0, t / 0.3, (SECONDS - t) / 1.1)
        sample = int(max(-1, min(1, value)) * 32767)
        samples.extend(struct.pack("<hh", sample, sample))
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(samples)


def run(args: list[str]) -> None:
    subprocess.run(args, check=True)


def main() -> None:
    global FONT_DIR
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "output/media/ad")
    parser.add_argument("--cta", default="DOWNLOAD NOW", choices=["DOWNLOAD NOW", "COMING SOON"])
    parser.add_argument("--font-dir", type=Path, default=FONT_DIR)
    parser.add_argument("--capture-dir", type=Path, default=ROOT / "output/media/lossless")
    parser.add_argument("--preview", action="store_true", help="Render a contact sheet without encoding")
    args = parser.parse_args()
    FONT_DIR = args.font_dir
    font(40)
    font(70, True)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    capture = args.capture_dir
    for frame in range(20 * FPS):
        if not (capture / f"gameplay{frame:08d}.png").exists():
            raise FileNotFoundError(f"Lossless gameplay capture missing frame {frame}")
    audio = capture / "gameplay.wav"
    if not audio.exists():
        raise FileNotFoundError(audio)

    def render(frame: int) -> Image.Image:
        if frame >= 20 * FPS:
            return store_card(frame, args.cta)
        with Image.open(capture / f"gameplay{frame:08d}.png") as game:
            if game.size != (180, 320):
                raise ValueError(f"Expected native 180x320 gameplay, got {game.size}")
            return gameplay_card(game.convert("RGB"), frame)

    # Preview and poster are authored with exactly the same render path as the MP4.
    sheet = Image.new("RGB", (1080, 960), PALETTE["sky"])
    for index, second in enumerate([1, 4, 6, 9, 12, 16, 21, 23]):
        thumb = render(second * FPS).resize((270, 480), Image.Resampling.LANCZOS)
        sheet.paste(thumb, ((index % 4) * 270, (index // 4) * 480))
    sheet.save(out / "review-sheet.jpg", quality=96)
    render(21 * FPS).save(out / "poster.png")
    render(6 * FPS).save(out / "gameplay-preview.png")
    if args.preview:
        return
    music(out / "original-ambience.wav")
    silent = out / "silent-hd.mp4"
    # Stream full-resolution RGB frames, avoiding hundreds of temporary HD PNGs.
    encoder = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
         "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1080x1920",
         "-framerate", str(FPS), "-i", "pipe:0", "-an", "-c:v", "libx264",
         "-preset", "medium", "-crf", "14", "-pix_fmt", "yuv420p", str(silent)], stdin=subprocess.PIPE)
    try:
        for frame in range(SECONDS * FPS):
            im = render(frame)
            encoder.stdin.write(im.tobytes())
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise RuntimeError("HD video encoding failed")
    except BaseException:
        encoder.kill()
        encoder.wait()
        raise
    destination = out / "dust-in-space-vertical-ad.mp4"
    run(["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
         "-i", str(silent), "-i", str(audio), "-i", str(out / "original-ambience.wav"),
         "-filter_complex", "[1:a]atrim=0:20,afade=t=out:st=19:d=1,apad=whole_dur=24[g];"
         "[g][2:a]amix=inputs=2:normalize=0,alimiter=limit=0.89[a]",
         "-map", "0:v", "-map", "[a]", "-t", str(SECONDS), "-c:v", "copy", "-c:a", "aac",
         "-b:a", "192k", "-movflags", "+faststart", str(destination)])
    silent.unlink()
    print(destination)


if __name__ == "__main__":
    main()
