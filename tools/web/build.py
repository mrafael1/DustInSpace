"""Build a release-only AloneLab site at build/alonelab and its deploy ZIP.

Requires Godot 4.7 and matching Web export templates. No Python dependencies.
Run: python tools/web/build.py [--godot PATH_TO_GODOT]
"""
import argparse
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "build" / "alonelab"


def run(godot, *args):
    result = subprocess.run([godot, "--headless", *map(str, args)],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end="")
    result.check_returncode()
    # Godot can report a GDScript import failure while returning exit code zero.
    if "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        raise RuntimeError("Godot reported an import/export error; see output above")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.7."):
        parser.error(f"Godot 4.7 required; found {version}")
    with tempfile.TemporaryDirectory(prefix="dust_web_") as temporary:
        staging = pathlib.Path(temporary)
        project = staging / "project"
        project.mkdir()
        # A clean staging project never overwrites a developer's Android/export settings
        # and cannot export tests, editor plugins, documentation or the website itself.
        for folder in ("game", "assets"):
            shutil.copytree(ROOT / folder, project / folder,
                            ignore=shutil.ignore_patterns("source"))
        settings = (ROOT / "project.godot").read_text(encoding="utf-8")
        settings = settings.replace('enabled=PackedStringArray("res://addons/gut/plugin.cfg")',
                                    'enabled=PackedStringArray()')
        (project / "project.godot").write_text(settings, encoding="utf-8")
        for resource in ROOT.glob("*.tres"):
            shutil.copy2(resource, project / resource.name)
        (project / "web").mkdir()
        shutil.copy2(ROOT / "web/game_shell.html", project / "web/game_shell.html")
        shutil.copy2(ROOT / "web/web_preset.cfg", project / "export_presets.cfg")
        site = staging / "site"
        shutil.copytree(ROOT / "web/site", site)
        game = site / "dust-in-space"
        game.mkdir()
        run(args.godot, "--path", project, "--import")
        run(args.godot, "--path", project, "--export-release", "Web", game / "index.html")
        for required in ("index.html", "index.js", "index.wasm", "index.pck"):
            if not (game / required).is_file():
                raise RuntimeError(f"Web export missing {required}")
        if "$GODOT_" in (game / "index.html").read_text(encoding="utf-8"):
            raise RuntimeError("Unexpanded Godot HTML placeholder")
        # Only replace this known generated directory, never an arbitrary user path.
        if OUTPUT.resolve() != ROOT / "build" / "alonelab" or OUTPUT.is_symlink():
            raise RuntimeError("Unsafe build output path")
        OUTPUT.parent.mkdir(exist_ok=True)
        if OUTPUT.exists():
            shutil.rmtree(OUTPUT)
        shutil.copytree(site, OUTPUT)
        archive = shutil.make_archive(str(ROOT / "build/alonelab-chapter-one"), "zip", site)
        print(f"Site: {OUTPUT}\nNetlify upload: {archive}")


if __name__ == "__main__":
    main()
