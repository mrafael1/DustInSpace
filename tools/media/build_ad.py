"""Build a 24-second 1080x1920 ad from the real Godot capture (Pillow + FFmpeg).

Usage: python tools/media/build_ad.py [--out output/media/ad] [--cta "DOWNLOAD NOW"]
Gameplay, palette and typography come from the project. The quiet musical bed is
an original synthesized pentatonic cue; no stock assets or third-party music.
"""
from __future__ import annotations

import argparse
import importlib.util
import math
from pathlib import Path
import random
import struct
import subprocess
import wave

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FPS, SECONDS = 30, 24
PALETTE = {"sky": "#07091F", "line": "#3E3F8A", "cool": "#9FB0EE",
           "white": "#D9E2FF", "gold": "#FFE59A", "dim": "#151D4A"}
spec = importlib.util.spec_from_file_location("fonts", ROOT / "tools/art/build_fonts.py")
fonts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fonts)


def text(im: Image.Image, value: str, y: int, scale: int = 1,
         color: str = PALETTE["white"], x: int | None = None) -> None:
    """Typeset existing bitmap glyphs on an integer pixel grid."""
    width = (len(value) * 6 - 1) * scale
    x = (216 - width) // 2 if x is None else x
    draw = ImageDraw.Draw(im)
    for i, letter in enumerate(value):
        for row, line in enumerate(fonts.FONT_5X7[letter]):
            for col, pixel in enumerate(line):
                if pixel == "#":
                    a, b = x + (i * 6 + col) * scale, y + row * scale
                    draw.rectangle((a, b, a + scale - 1, b + scale - 1), fill=color)


def background(frame: int) -> Image.Image:
    im = Image.new("RGB", (216, 384), PALETTE["sky"])
    draw = ImageDraw.Draw(im)
    rng = random.Random(24)
    for index in range(85):
        x, y = rng.randrange(12, 204), rng.randrange(18, 350)
        color = PALETTE["cool"] if (index + frame // 12) % 13 == 0 else PALETTE["line"]
        draw.point((x, y), fill=color)
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "output/media/ad")
    parser.add_argument("--cta", default="DOWNLOAD NOW", choices=["DOWNLOAD NOW", "COMING SOON"])
    args = parser.parse_args()
    out = args.out.resolve()
    frames = out / "frames"
    raw = out / "raw"
    frames.mkdir(parents=True, exist_ok=True)
    raw.mkdir(exist_ok=True)
    capture = ROOT / "output/media/gameplay.avi"
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(capture),
         "-t", "20", "-vf", "fps=30", str(raw / "%04d.png")])
    captions = [("THE NIGHT NEEDS YOU", "LAUNCH A PLANET"),
                ("A LITTLE STARDUST", "LINK THREE STARS"),
                ("ONE MORE CONNECTION", "BRING BACK THE LIGHT"),
                ("RESTORE THE SUN", "ONE STAR AT A TIME")]
    figure = Image.open(ROOT / "assets/art/scorpio_figure.png").convert("RGBA")
    figure = figure.crop(figure.getbbox())
    for frame in range(SECONDS * FPS):
        im = background(frame)
        draw = ImageDraw.Draw(im)
        if frame < 20 * FPS:
            game = Image.open(raw / f"{frame + 1:04d}.png").convert("RGB")
            im.paste(game, (18, 40))
            draw.rectangle((17, 39, 198, 360), outline=PALETTE["line"])
            top, sub = captions[min(frame // (5 * FPS), 3)]
            text(im, top, 13, color=PALETTE["gold"])
            text(im, sub, 26)
            text(im, "DUST IN SPACE", 368, color=PALETTE["cool"])
        else:
            text(im, "DUST IN", 46, 3, PALETTE["white"])
            text(im, "SPACE", 75, 4, PALETTE["gold"])
            text(im, "A SKY WORTH RESTORING", 113, color=PALETTE["cool"])
            im.paste(figure, ((216 - figure.width) // 2, 121), figure)
            # Readable store names are deliberately typeset, not unofficial badge artwork.
            draw.rectangle((27, 270, 189, 346), fill=PALETTE["sky"])
            text(im, args.cta, 274, 2, PALETTE["gold"])
            for label, y in [("GOOGLE PLAY", 301), ("APP STORE", 327)]:
                draw.rectangle((35, y - 6, 180, y + 13), fill=PALETTE["dim"], outline=PALETTE["cool"])
                text(im, label, y, color=PALETTE["white"])
        # Exact 5x nearest scaling preserves the game's native pixel clusters.
        im.resize((1080, 1920), Image.Resampling.NEAREST).save(frames / f"{frame:04d}.png")
    music(out / "original-ambience.wav")
    destination = out / "dust-in-space-vertical-ad.mp4"
    run(["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
         "-framerate", str(FPS), "-i", str(frames / "%04d.png"),
         "-i", str(capture), "-i", str(out / "original-ambience.wav"),
         "-filter_complex", "[1:a]atrim=0:20,afade=t=out:st=19:d=1,apad=whole_dur=24[g];"
         "[g][2:a]amix=inputs=2:normalize=0,alimiter=limit=0.89[a]",
         "-map", "0:v", "-map", "[a]", "-t", str(SECONDS), "-c:v", "libx264",
         "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-c:a", "aac",
         "-b:a", "192k", "-movflags", "+faststart", str(destination)])
    # A poster and a chronological contact sheet make the deliverable easy to review.
    Image.open(frames / "0630.png").save(out / "poster.png")
    sheet = Image.new("RGB", (1080, 960), PALETTE["sky"])
    for index, second in enumerate([1, 4, 6, 9, 12, 16, 20, 23]):
        thumb = Image.open(frames / f"{second * FPS:04d}.png")
        thumb = thumb.resize((270, 480), Image.Resampling.NEAREST)
        sheet.paste(thumb, ((index % 4) * 270, (index // 4) * 480))
    sheet.save(out / "review-sheet.jpg", quality=95)
    print(destination)


if __name__ == "__main__":
    main()
