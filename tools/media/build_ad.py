"""Render a full-screen, 30-second ad whose ending reconnects to its opening.

Lossless game footage stays at native pixels, enlarged exactly 6x. HD captions
are composited over it. No device mockup, chapter cards or separate outro loop.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from functools import lru_cache
import importlib.util
import math
from pathlib import Path
import struct
import subprocess
import wave

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FPS, SECONDS = 30, 30
SIZE = (1080, 1920)
FONT_DIR = Path('C:/Windows/Fonts')
WHITE, GOLD, DARK = '#D9E2FF', '#FFE59A', '#07091F'
_glyph_spec = importlib.util.spec_from_file_location('game_bitmap_font', ROOT / 'tools/art/build_fonts.py')
_glyphs = importlib.util.module_from_spec(_glyph_spec)
_glyph_spec.loader.exec_module(_glyphs)


@dataclass(frozen=True)
class Shot:
    folder: str
    start: int
    count: int
    offset: int = 6

    @property
    def end(self) -> int:
        return self.start + self.count

    def source_frame(self, local: int) -> int:
        return self.offset + local


SHOTS = [
    Shot('voyage', 0, 102),                 # 0.0-3.4: title -> travelling star -> chart
    Shot('lossless', 84, 324, 0),           # 2.8-13.6: quiet launches and linking
    Shot('aquarius', 390, 105),             # 13.0-16.5: current
    Shot('leo', 477, 105),                  # 15.9-19.4: heat
    Shot('gravity', 564, 105),              # 18.8-22.3: black hole
    Shot('title', 651, 249),                # 21.7-30.0: title and store CTA, no Scorpio art
]


@lru_cache(maxsize=32)
def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = ['segoeuib.ttf', 'arialbd.ttf', 'DejaVuSans-Bold.ttf'] if bold else [
        'segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf']
    for name in names:
        for folder in [FONT_DIR, Path('/usr/share/fonts/truetype/dejavu')]:
            path = folder / name
            if path.exists():
                return ImageFont.truetype(str(path), size)
    raise FileNotFoundError('No suitable font found; pass --font-dir PATH')


def smooth(value: float) -> float:
    value = max(0, min(1, value))
    return value * value * (3 - 2 * value)


def envelope(t: float, start: float, end: float, fade: float = 0.65) -> float:
    return smooth(min((t - start) / fade, (end - t) / fade))


def text(image: Image.Image, value: str, y: int, size: int = 48,
         color: str = WHITE, bold: bool = False) -> None:
    draw = ImageDraw.Draw(image)
    face = font(size, bold)
    if draw.textlength(value, font=face) > 900:
        raise ValueError(f'Caption exceeds safe area: {value!r}')
    draw.text((540, y), value, font=face, fill=color, anchor='mt',
              stroke_width=3, stroke_fill=DARK)


def bitmap_text(image: Image.Image, value: str, y: int, color: str) -> None:
    """Use the game's exact 5x7 glyphs at the footage's native 6x pixel scale."""
    scale = 6
    x = (SIZE[0] - (len(value) * 6 - 1) * scale) // 2
    draw = ImageDraw.Draw(image)
    for dx, dy, fill in [(scale, scale, DARK), (0, 0, color)]:
        for index, letter in enumerate(value):
            for row, pattern in enumerate(_glyphs.FONT_5X7[letter]):
                for col, pixel in enumerate(pattern):
                    if pixel == '#':
                        left = x + (index * 6 + col) * scale + dx
                        top = y + row * scale + dy
                        draw.rectangle((left, top, left + scale - 1, top + scale - 1), fill=fill)


def footage(folder: Path, frame: int) -> Image.Image:
    with Image.open(folder / f'gameplay{frame:08d}.png') as image:
        if image.size != (180, 320):
            raise ValueError(f'Expected 180x320 footage, got {image.size}')
        return image.convert('RGB')


def native_frame(frame: int, media: Path) -> Image.Image:
    active = [shot for shot in SHOTS if shot.start <= frame < shot.end]
    if not active:
        raise ValueError(f'No shot covers frame {frame}')
    images = [footage(media / shot.folder, shot.source_frame(frame - shot.start))
              for shot in active]
    result = images[0]
    if len(active) == 2:
        old, new = active
        overlap = old.end - new.start
        weight = smooth((frame - new.start) / (overlap - 1))
        result = Image.blend(images[0], images[1], weight)
    # Join the closing title's animated sky to the exact opening title state.
    # The CTA is already gone, so the whole ad still repeats without a jump.
    if frame >= 882:
        result = Image.blend(result, footage(media / 'voyage', 6), smooth((frame - 882) / 17))
    return result


def render(frame: int, media: Path, cta: str) -> Image.Image:
    im = native_frame(frame, media).resize(SIZE, Image.Resampling.NEAREST)
    t = frame / FPS
    # One sentence can bridge multiple mechanics; captions do not announce edits.
    for start, end, label in [
        (4.1, 7.8, 'A little stardust.'),
        (8.3, 12.5, 'A little light.'),
        (14.0, 21.0, 'A sky full of surprises.'),
    ]:
        strength = envelope(t, start, end)
        if strength:
            overlay = im.copy()
            text(overlay, label, 88, 51, bold=True)
            im = Image.blend(im, overlay, strength)
    strength = envelope(t, 22.5, 29.4, 0.7)
    if strength:
        overlay = im.copy()
        bitmap_text(overlay, cta, 1122, GOLD)
        bitmap_text(overlay, 'GOOGLE PLAY', 1260, WHITE)
        bitmap_text(overlay, 'APP STORE', 1356, WHITE)
        im = Image.blend(im, overlay, strength)
    return im


NOTES = [48, 55, 60, 62, 67, 62, 60, 55, 50, 57, 62, 64, 69, 64, 57]


def music_sample(t: float) -> float:
    # Fifteen half-second notes repeat four times in 30 seconds. Include tails
    # from the previous cycle so the musical bed is continuous at the video seam.
    value = 0.0
    for back in range(8):
        beat = math.floor(t / 0.5) - back
        age = t - beat * 0.5
        hz = 440.0 * 2 ** ((NOTES[beat % len(NOTES)] - 69) / 12)
        env = min(1.0, age / 0.025) * math.exp(-age * 2.9)
        value += (math.sin(2 * math.pi * hz * age) +
                  0.18 * math.sin(4 * math.pi * hz * age)) * env * 0.065
    value += math.sin(2 * math.pi * 130.8 * t) * 0.009
    return value


def music(path: Path) -> None:
    rate = 48000
    samples = bytearray()
    for i in range(rate * SECONDS):
        sample = int(max(-1, min(1, music_sample(i / rate))) * 32767)
        samples.extend(struct.pack('<hh', sample, sample))
    with wave.open(str(path), 'wb') as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(samples)


def main() -> None:
    global FONT_DIR
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=ROOT / 'output/media/ad')
    parser.add_argument('--cta', default='DOWNLOAD NOW', choices=['DOWNLOAD NOW', 'COMING SOON'])
    parser.add_argument('--font-dir', type=Path, default=FONT_DIR)
    parser.add_argument('--media-dir', type=Path, default=ROOT / 'output/media')
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    FONT_DIR = args.font_dir
    font(51, True)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    media = args.media_dir
    # Preflight every referenced native frame before starting a long encode.
    for shot in SHOTS:
        for local in range(shot.count):
            path = media / shot.folder / f'gameplay{shot.source_frame(local):08d}.png'
            if not path.exists():
                raise FileNotFoundError(path)
    first, last = render(0, media, args.cta), render(899, media, args.cta)
    if first.tobytes() != last.tobytes():
        raise ValueError('The end of the ad must match the opening title exactly')
    if abs(music_sample(0) - music_sample(30)) > 1e-9:
        raise ValueError('The musical bed does not meet at the loop seam')
    sheet = Image.new('RGB', (1080, 960), DARK)
    for index, second in enumerate([0.5, 2, 7, 14.5, 17.5, 20.5, 25, 29.5]):
        thumb = render(round(second * FPS), media, args.cta).resize((270, 480), Image.Resampling.LANCZOS)
        sheet.paste(thumb, ((index % 4) * 270, (index // 4) * 480))
    sheet.save(out / 'review-sheet.jpg', quality=96)
    render(25 * FPS, media, args.cta).save(out / 'poster.png')
    render(210, media, args.cta).save(out / 'gameplay-preview.png')
    first.save(out / 'loop-start.png')
    last.save(out / 'loop-end.png')
    if args.preview:
        return
    music(out / 'original-ambience.wav')
    silent = out / 'silent-hd.mp4'
    encoder = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y',
        '-f', 'rawvideo', '-pixel_format', 'rgb24', '-video_size', '1080x1920',
        '-framerate', '30', '-i', 'pipe:0', '-an', '-c:v', 'libx264',
        '-preset', 'medium', '-crf', '14', '-pix_fmt', 'yuv420p', str(silent)], stdin=subprocess.PIPE)
    try:
        for frame in range(900):
            encoder.stdin.write(render(frame, media, args.cta).tobytes())
        encoder.stdin.close()
        if encoder.wait() != 0:
            raise RuntimeError('HD encoding failed')
    except BaseException:
        encoder.kill()
        encoder.wait()
        raise
    audio_shots = SHOTS[1:5]
    inputs = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-i', str(silent)]
    filters = []
    for index, shot in enumerate(audio_shots, 1):
        inputs += ['-i', str(media / shot.folder / 'gameplay.wav')]
        length = shot.count / FPS
        delay = round(shot.start / FPS * 1000)
        filters.append(f'[{index}:a]atrim=start={shot.offset / FPS}:duration={length},'
            f'asetpts=PTS-STARTPTS,afade=t=in:d=0.3,afade=t=out:st={length - .3}:d=0.3,'
            f'adelay={delay}|{delay}[s{index}]')
    inputs += ['-i', str(out / 'original-ambience.wav')]
    labels = ''.join(f'[s{i}]' for i in range(1, 5))
    filters.append(labels + '[5:a]amix=inputs=5:normalize=0,alimiter=limit=0.89[a]')
    destination = out / 'dust-in-space-looping-ad.mp4'
    subprocess.run(inputs + ['-filter_complex', ';'.join(filters), '-map', '0:v', '-map', '[a]',
        '-t', '30', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
        '-movflags', '+faststart', str(destination)], check=True)
    silent.unlink()
    print(destination)


if __name__ == '__main__':
    main()
