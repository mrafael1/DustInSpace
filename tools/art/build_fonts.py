"""Builds the bitmap fonts in assets/fonts/ from the glyph tables below.

Two fonts (docs/art-direction.md): 5x7 for primary counters and 3x5 for secondary numbers.
Each PNG is one row of cells, a glyph plus one blank spacing column, in GLYPHS order. Godot
imports them as image fonts (see the .png.import files), so Labels render them pixel for pixel.
Glyphs are white; Labels colour them. Only the characters the HUD needs so far are drawn.

Run: python tools/art/build_fonts.py   (needs Pillow)
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "fonts"

# Order matters: it must match character_ranges in the .png.import files.
GLYPHS = " 0123456789+-/×"

FONT_5X7 = {
    " ": ["....."] * 7,
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "×": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
}

FONT_3X5 = {
    " ": ["..."] * 5,
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "##."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    "-": ["...", "...", "###", "...", "..."],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "×": ["...", "#.#", ".#.", "#.#", "..."],
}


def build(font: dict[str, list[str]], name: str) -> None:
    width = len(font["0"][0])
    height = len(font["0"])
    cell = width + 1
    image = Image.new("RGBA", (cell * len(GLYPHS), height), (0, 0, 0, 0))
    for index, char in enumerate(GLYPHS):
        rows = font[char]
        assert len(rows) == height and all(len(r) == width for r in rows), char
        for y, row in enumerate(rows):
            for x, bit in enumerate(row):
                if bit == "#":
                    image.putpixel((index * cell + x, y), (255, 255, 255, 255))
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name)
    print(f"wrote {OUT / name} ({image.width}x{image.height}, {len(GLYPHS)} glyphs)")


if __name__ == "__main__":
    build(FONT_5X7, "font_5x7.png")
    build(FONT_3X5, "font_3x5.png")
