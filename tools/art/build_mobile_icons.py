"""Temporary test-build icons derived from the existing lit star, on the game's pixel grid.

Run: python tools/art/build_mobile_icons.py (requires Pillow).
These reuse production art; a final store icon remains an art review task.
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art"
OUT = ART / "mobile"


def build() -> None:
    metadata = json.loads((ART / "stars_big.json").read_text())
    width, height = metadata["frame_size"]
    index = metadata["frames"].index("lit")
    with Image.open(ART / "stars_big.png") as strip:
        star = strip.convert("RGBA").crop((index * width, 0, (index + 1) * width, height))
    palette = {tuple(bytes.fromhex(value)) for value in (ROOT / "assets/palettes/stellar_sun.hex").read_text().split()}
    background = tuple(bytes.fromhex("07091F")) + (255,)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, size, scale, transparent in [
        ("icon_android", 192, 8, False),
        ("icon_ios", 1024, 40, False),
        ("icon_foreground", 432, 12, True),
        ("icon_background", 432, 0, False),
    ]:
        icon = Image.new("RGBA", (size, size), (0, 0, 0, 0) if transparent else background)
        if scale:
            large = star.resize((width * scale, height * scale), Image.Resampling.NEAREST)
            icon.alpha_composite(large, ((size - large.width) // 2, (size - large.height) // 2))
        assert all(pixel[3] in (0, 255) and (pixel[3] == 0 or pixel[:3] in palette) for pixel in icon.getdata())
        icon.save(OUT / f"{name}.png")
        print(f"Built assets/art/mobile/{name}.png")


if __name__ == "__main__":
    build()
