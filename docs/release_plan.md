# First release: Android, iOS and Steam

**Status (2026-10-19): plan only, nothing built yet.** The user wants to prepare the first release. Decisions taken (2026-10-19):

- **Scope:** chapters 1-6 (Scorpio to Pisces) are playable. **Aries is a locked teaser** on the chart ("coming soon"), and the stages already built for it stay out of the release build.
- **Desktop:** a **wide sky, same figures**. On a landscape screen the play sky widens up to 16:9, every mechanic runs across the whole width, the HUD moves out to the sides, and each constellation keeps its portrait shape, centred. The paintings are reused as they are.
- **Paintings:** **Scorpio's clean line** for chapters 2-6 (an unbroken 1 px line round each part, dense stardust inside: [art-direction.md](art-direction.md)).
- **Stores, in this push:** export presets and builds, Steam integration, and store page assets.

[design.md](design.md) stays the rules reference. Each track below is its own branch and PR (AGENTS.md), and every design guess is flagged in its PR.

## What the user provides

These block the store tracks, not the game work:

| Need | For | Notes |
|---|---|---|
| Google Play developer account and an upload keystore | Android | The keystore never goes in the repo |
| Apple Developer Program and **a Mac** (or a cloud Mac) | iOS, macOS | Godot exports an Xcode project; building, signing and notarizing need macOS |
| Steamworks partner account, the app fee and an **App ID** | Steam | Also the depot IDs for Windows, macOS and Linux |
| A privacy policy URL, pricing, age rating answers (IARC and Apple) | All stores | The analytics upload must be off (or opt-in and disclosed) in release builds: see track 4 |

## Track 1: the wide sky (desktop, Steam Deck, tablets)

Branch `feature/wide-sky`. Today `ScreenZones` fills a taller phone by growing the game upward (the Sun rises and the play sky grows by `_extra` rows); a wider screen only shows the backdrop at the sides. The plan grows it **sideways the same way**:

1. **The game area:** at the largest whole-number scale that still shows at least 180x320 game px, everything the window shows is game: a 1920x1080 monitor at 3x is 640x360, a 1280x720 one at 2x is 640x360, the Steam Deck (1280x800) at 2x is 640x400. The extra rows go up (the Sun rises, as on tall phones) and the extra columns go to both sides. Portrait phones are unchanged.
2. **The play sky** (`RunState.sky_rect`) widens with it. The constellation stays centred through `scorpio.shift` (this already exists for the taller sky), and stars scatter, launches aim and the burst rings land across the whole width.
3. **Every mechanic that reads the sky's edges** gets audited and tested on a wide sky: Orion's volley and hunting area (1), the current and the drain (2), the heat (3), the harvest and scythe (4), the black hole (5), the reflection seam, the cords and the wave (6), and the ram, kept for the Aries build. Where a rule means "the sky's middle" or "the far edge", the wide sky must keep the same stakes; the bots check it.
4. **The HUD, the Sun and the launcher:** the counters and buttons move to the screen's sides (they already anchor to the real screen's edges), the Sun stays top centre, the telescope/slingshot stays bottom centre. Mouse input: click to launch, click or drag to link, the wheel unused. Keyboard: Escape is already back.
5. **The chart and the title** fill the width: the zodiac sky is already one long voyage, so a wide window shows more of it.
6. **Desktop basics:** a window that resizes and keeps integer scaling, fullscreen toggle (F11 and an OPTIONS line), the mouse cursor in the game's style, pause on focus loss (already there).
7. **Proof:** GUT tests for the sky's size per window size and per mechanic on a wide sky; the bots re-run on every chapter's stages at 16:9 next to the portrait numbers; Movie Maker captures of one stage per chapter at 16:9.

Risk: some stage layouts were tuned for a 180 px wide sky (spacing to the edges, intro layouts that place demo stars by the edge). The audit lists them; any re-tune is flagged.

## Track 2: final paintings for chapters 2-6

One branch per chapter (`art/<chapter>-painting`), the approved Scorpio as the template (`tools/art/clean_line.py`, `semi_hollow`, as `build_scorpio_figure.py` calls it). Each chapter needs:

- the **whole figure** (`<chapter>_figure.png`), shown when the final is won;
- the **five chart pieces** that cut it up exactly (`<chapter>_piece_<part>.png`);
- the **part stages' paintings** (`<chapter>_part_<stage>.png`, fitted to each stage's own layout).

| Chapter | Today | Start from |
|---|---|---|
| 2 Aquarius | old style figure, pieces and parts | draft `aq8_d` (v2 concept), on hold in #202 |
| 3 Leo | old style figure, pieces and parts | draft `leo11_d` (v2 concept), on hold in #202 |
| 4 Virgo | **none** | draft `vi12_d` (v2 concept: raised arm, no wing), on hold in #202 |
| 5 Sagittarius | **none** | research brief first (atlas plates, the archer's pose against our stars) |
| 6 Pisces | **none** | research brief first (the two fish and the cord knot) |

Process per chapter (as agreed after the Stardust Myth paintings): research brief, then a side-by-side draft sheet with a 5x zoom row, the user's verdict, then wired into the builder and every chapter test. Closed shapes only; the game's stars never move. The part stages' paintings: the plan is to redo them in the clean line too, so a chapter looks the same from stage 1 to its final (**flagged**: today's art direction says part stages keep the older shaded style "for now").

The draft PR #202 and its branch get rebased on main and split per chapter.

## Track 3: review and polish

Branch per finding (`fix/`, `tune/`, `art/`). First a **review pass** that writes a punch list (an issue per finding), then fixes in order of how much a player would feel them.

1. **A full playthrough per chapter** at phone size and at 16:9, recorded with Movie Maker: every stage's opening intro, rule line, win, loss and end screen; the chart's voyage; the tutorial from a fresh save.
2. **The difficulty curve:** one bot table for all ~36 stages of chapters 1-6 (link-first, careful, careless), so no stage spikes or sags out of its chapter's ladder. The known open threads: the payout spike, the Scorpio final (~17% for the spatial bot).
3. **Every text** fits and reads (the 5x7 font, 24 characters, no comma), and every rule says what the player does.
4. **Feel:** sound levels across chapters, haptics on Android and iOS, reduced motion on every new effect since #150.
5. **Robustness:** the save survives a crash mid-run, an update and a reset; no error in the log over a full run; the debug overlay, debug keys and trials stay out of release builds (`OS.is_debug_build()`).
6. **Performance:** a low-end Android phone at 60 fps through the Big Bang and the busiest stages.
7. **Release hygiene:** the stale PRs decided (#105 debug overlay, #106 CI tests, #113 web export, #202 paintings), the CI test run on every PR, a version number and a changelog.

## Track 4: platforms and stores

Branch `chore/release-builds`, then `feature/steam`.

1. **Export presets:** Android (AAB, the target API Google Play needs now, portrait, icons and adaptive icon), iOS (Xcode project, portrait, iPhone and iPad), Windows, macOS (universal) and Linux. Version and build numbers from one place. Release builds strip the debug features and the trials (and Aries's stages: only its locked chart entry ships).
2. **Analytics:** `AnalyticsUpload` posts playtest records when `game/config/analytics.json` has an endpoint. The release builds ship **without** an endpoint (or with an opt-in OPTIONS line and the privacy policy saying so). **Flagged**, the user's call.
3. **Steam:** GodotSteam (the GDExtension for Godot 4.7, to verify it exists for 4.7), the overlay, **cloud saves** (the save under `user://`), and **achievements** (a list to agree: say one per chapter won and one per Big Bang seen; **flagged**, a design question). Steam Deck: the wide sky at 1280x800, controller or touch input (a controller is **out of scope** unless the user wants it: Deck players can use the touch screen).
4. **Store page assets:** screenshots for each store's sizes (phone 9:16, tablet, 16:9 desktop), the Steam capsules (header, small, main, hero, library), the app icons, a short trailer cut from Movie Maker captures, and the short and long descriptions. Capsules and the icon may carry the game's name as a logo (the "no baked text" rule is for in-game art).

## Order

Track 1 and track 2 run side by side (they don't touch the same files: the paintings are reused on the wide sky). Track 4's export presets come early, so the game can be tested on real phones and the Deck during track 3. Track 3's review pass runs once tracks 1 and 2 are in, and the store assets come last, from the polished game.

| Step | Tracks | Output |
|---|---|---|
| 1 | 1 (wide sky) and 2 (Aquarius, Leo, Virgo from the drafts; Sagittarius and Pisces research briefs) | PRs, draft sheets for the user's verdict |
| 2 | 4.1 export presets, Aries teaser lock | test builds on a phone and on desktop |
| 3 | 2 (Sagittarius, Pisces) and 3 (review pass) | paintings, the punch list |
| 4 | 3 (fixes), 4.2-4.3 (analytics, Steam) | release candidate builds |
| 5 | 4.4 store assets | store pages ready |

## Open questions (the user's)

1. **Monetization:** premium (one price), free with something, or free? It changes the store setup, not the game.
2. **iPad and 4:3 tablets:** the wide sky handles them (wider than 9:16, narrower than 16:9). Fine, or portrait-only on tablets too?
3. **Big monitors at 3x:** a 1920x1080 screen shows 640x360 game px at 3x, with pixels 3x bigger than on a 1280x720 one at 2x showing the same area. Fine, or should a big monitor show the same 2x pixels and a wider sky (960x540)? The plan caps the sky's width so the constellation stays the focus; to tune in track 1.
4. **Part stages' paintings:** redo in the clean line (the plan) or keep the shaded style?
5. **Achievements:** which ones (track 4.3)?
6. **A controller** on Steam: out of scope for the first release?
