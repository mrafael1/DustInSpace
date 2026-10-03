# Chapter 1 on AloneLab

The current Godot game exports to `https://alonelab.com/dust-in-space/`.
The URL is the intended production destination; preparing this package does not deploy it.
Chapter 1 includes the chart, six stages, tutorial, encounters, saved progress and win/loss flow.
No gameplay or balance values are changed for the website.

## Build

Install Godot **4.7** and its matching Web export templates through the editor's
Manage Export Templates screen. Python 3 has no additional dependencies.

```sh
python tools/web/build.py
# If Godot is not on PATH, pass the actual Godot executable:
python tools/web/build.py --godot /path/to/godot
```

The script creates a temporary project from `game/`, `assets/` and the project settings.
It keeps the committed asset import settings (including bitmap fonts), disables the GUT
editor plugin in that temporary copy and uses `web/web_preset.cfg` there.
It never replaces your local `export_presets.cfg`, including Android/signing settings.
It uses `--export-release`: debug keys, preview unlocks, balance overlay and playtest logs
are disabled by the game's existing debug-build guards.

Output:

- `build/alonelab/`: complete site folder for Netlify, with `index.html`, `icon.png`,
  `_headers`, and the `dust-in-space/` export and all its runtime files.
- `build/alonelab-chapter-one.zip`: the same site with files at the ZIP root.

Generated binaries are ignored by Git. Rebuild the whole package after updating the game.
`web/site/index.html` and `web/site/icon.png` are the supplied AloneLab homepage and icon.
The existing `screenshot.jpg` and `phone-cute.png` were retrieved from the live site so their
homepage references keep working in the complete package.
The homepage gains a Dust In Space section and a navigation link. Airtime and Lobotomy remain.
Its space background is generated from Chapter 1's own `ChapterSelect.space_image`, using
the game's palette and crisp integer scaling. To regenerate it after an art update:

```sh
godot --headless --path . -s tools/web/export_space_background.gd
```

If the live homepage changes, update this source before rebuilding.

## Preview locally

```sh
python -m http.server 8765 --bind 127.0.0.1 --directory build/alonelab
```

Open `http://127.0.0.1:8765/`, follow PLAY CHAPTER 1, then click the game's launch button.
Opening `index.html` directly as a `file://` URL cannot load the WebAssembly game.

## Deploy to the existing Netlify site

1. Use the CLI command below to create a draft on the existing site and check its homepage
   and `/dust-in-space/`. Include existing files if the live site contains anything beyond
   the homepage and assets supplied in this package.
2. When ready to publish, open the Netlify site whose custom domain is **alonelab.com**,
   then its Deploys page.
3. Upload **the complete `build/alonelab/` folder** as a manual deploy. If using the ZIP,
   extract it first and upload that folder. Manual deployment replaces the production site.
4. Verify the custom-domain URL too. Keep the previous deploy for rollback.

For a CLI draft preview (requires the Netlify CLI and access to your existing site):

```sh
netlify deploy --dir build/alonelab --site YOUR_EXISTING_SITE_ID
```

The repository's `netlify.toml` sets the publish folder. There is no automatic Git-connected
build configured: that environment would need Godot 4.7 and matching Web templates installed
before running `tools/web/build.py`. Manual deployment avoids assuming your existing setup.

## Browser behavior and hosting

This export uses Compatibility/WebGL 2 and WebAssembly, with thread support and PWA disabled.
Single-threaded exports need HTTPS in production, but no COOP/COEP isolation headers.
The homepage's external Google Fonts therefore need no hosting changes.
`_headers` specifies WASM/PCK/JavaScript MIME types and revalidation for the game files,
so an update cannot silently reuse a stale runtime or pack. Do not add a catch-all SPA
rewrite that returns the homepage for missing game files.

The game opens full-window with its existing nearest filtering and integer viewport scaling.
Mouse clicks are emulated as touches by the existing project setting; phone controls use touch.
The launch button provides the first interaction; browsers may require another touch on the
game to activate audio. Use the browser's Back button to return to the site after launching.
The browser stores `user://` files in IndexedDB; progress and sound settings stay on the same
origin. A draft Netlify URL and alonelab.com have separate saves. Private browsing, blocked
storage, clearing site data or changing browsers/devices can remove or isolate progress.

Sources: [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
and [Web export settings](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html).
See also [Netlify manual deploys](https://docs.netlify.com/manage/projects/add-new-project/)
and [custom headers](https://docs.netlify.com/manage/routing/headers/).

## Release checks

- Confirm every runtime file loads with HTTP 200 and the expected MIME type on Netlify.
- Test loading, tutorial, mouse/touch launching and linking, combo table, purchases and audio.
- Complete a stage, return to the chart and reload; check completion, unlock and tutorial saves.
- Test loss/restart, replay, all six stages and final completion.
- Check narrow portrait, wide desktop and orientation changes; ensure the HUD remains reachable.
- Confirm debug keys and the three-finger debug overlay are unavailable in the release build.
- Test current desktop browsers and physical iOS Safari/Android Chrome; record actual results.

Issue #112 remains open until the production deployment and browser/device checks are complete.
