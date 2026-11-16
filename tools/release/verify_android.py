"""Verify APK/AAB runtime data, development-file exclusions and 16 KB ELF alignment.

Usage: python tools/release/verify_android.py exports/android/dust-in-space-test.apk
Also run the SDK's apksigner verify, aapt dump badging, and zipalign -c -P 16 4.
"""

import argparse
from pathlib import Path
import struct
import sys
import zipfile


def load_alignments(elf: bytes) -> list[int]:
    if elf[:6] != b"\x7fELF\x02\x01":
        raise ValueError("Expected a little-endian ELF64 native library")
    table = struct.unpack_from("<Q", elf, 32)[0]
    size, count = struct.unpack_from("<HH", elf, 54)
    return [struct.unpack_from("<Q", elf, table + index * size + 48)[0]
            for index in range(count)
            if struct.unpack_from("<I", elf, table + index * size)[0] == 1]


def verify(path: Path) -> None:
    with zipfile.ZipFile(path) as apk:
        names = set(apk.namelist())
        bundle = path.suffix == ".aab"
        assets = "assetPackInstallTime/assets/" if bundle else "assets/"
        required = {assets + name for name in ["game/config/balance.json", "assets/art/stars_big.json",
                                              "assets/art/pack_blue.json", "assets/art/pack_red.json"]}
        missing = required - names
        if missing:
            raise ValueError("Missing runtime data: " + ", ".join(sorted(missing)))
        prefixes = tuple(assets + folder + "/" for folder in
                         ["addons", "tests", "tools", "docs", "Claude outputs", "output", "out"])
        unwanted = {name for name in names if name.startswith(prefixes)}
        unwanted |= names & {assets + "game/config/analytics.json"}
        if unwanted:
            raise ValueError("Development/analytics files shipped: " + ", ".join(sorted(unwanted)))
        libraries = sorted(name for name in names if name.endswith(".so"))
        if not libraries:
            raise ValueError("No native libraries found")
        for name in libraries:
            if not name.startswith(("base/" if bundle else "") + "lib/arm64-v8a/"):
                raise ValueError("Unexpected architecture: " + name)
            alignments = load_alignments(apk.read(name))
            if not alignments or any(value < 16384 or value % 16384 for value in alignments):
                raise ValueError(f"{name}: incompatible PT_LOAD alignments {alignments}")
            print(f"{name}: 16 KB ELF alignment OK")
    print("Runtime JSON present; development files and analytics configuration absent")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    try:
        verify(args.apk)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error) as error:
        print(f"APK verification: {error}", file=sys.stderr)
        sys.exit(1)
