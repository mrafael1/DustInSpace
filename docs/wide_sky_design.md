# Wide sky: implementation design (branch `feature/wide-sky`)

**Status (2026-10-19):** designed from a read-only audit of the code (8 areas plus a sweep); being built on `feature/wide-sky`. Plan: [release_plan.md](release_plan.md) track 1 (on `chore/release-plan`, PR #216).

Goal: on landscape windows the play sky widens to both sides and grows upward. Each constellation keeps its portrait layout, centred. Every mechanic works across the full width with the same stakes. Portrait phones stay byte-identical in behaviour.

One idea runs through every section. Each run has a **frame**: the portrait 180-column band that holds the constellation, stretched to the sky's height. On portrait the frame equals the sky, so any rule written against the frame does exactly what it does today. On a wide sky, rules that get their stakes from an edge or an area use the frame instead of the sky.

---

## 1. Screen model (`game/scenes/screen_zones.gd`)

Keep `SKY`, `SUN`, `LAND`, `HUD` and `SCREEN` unchanged. They stay the portrait frame. `fill_scale` and `fill_size` already choose the largest whole-number scale that still shows 180x320, and they stay as they are:

| Window | Scale | Visible game px | `game_offset` |
|---|---|---|---|
| 1920x1080 | 3 | 640x360 | (230, 40) |
| 1280x800 (Steam Deck) | 2 | 640x400 | (230, 80) |
| 1536x2048 (iPad, portrait) | 6 | 256x341 | (38, 21) |
| 2048x1536 (iPad, landscape) | 4 | 512x384 | (166, 64) |

New API:

```gdscript
const MAX_SKY_WIDTH := 640   # widest play sky: 16:9 at its biggest integer scale

static func sky_margin(visible: Vector2i) -> Vector2i:
    # x = extra columns on EACH side, y = extra rows above
    var offset := game_offset(visible)          # floor(extra.x / 2), extra.y
    var side := mini(offset.x, (MAX_SKY_WIDTH - SKY.size.x) / 2)   # cap at 230
    return Vector2i(side, offset.y)

static func play_sky(rows: int, side: int = 0) -> Rect2i:
    return Rect2i(SKY.position.x - side, SKY.position.y - rows,
                  SKY.size.x + 2 * side, SKY.size.y + rows)
```

- **Symmetric by construction.** Both sides get the same `side` value, which is `floor(extra.x / 2)`. When the extra width is odd, the leftover column stays backdrop. So `sky.get_center().x` is always 90, the window centre.
- **The 640 cap.** At 16:9, every integer scale gives 640 columns (1080p at 3x, 1440p at 4x, 4K at 6x), so 640 is the target. Wider windows such as 1366x768 (683 px) or 21:9 (853 px) keep a 640-wide sky; the Backdrop fills the rest. There is no cap on rows, because tall phones already grow upward without one.
- **`play_sky(rows)` with the default `side = 0` returns exactly today's rect.** The existing calls in `test_scorpio.gd:491,507` and `test_scorpio_view.gd:597` stay valid unchanged.
- **Main** (`game/scenes/main.gd`): `_extra: int` becomes `_margin: Vector2i`, set in `fit_visible` (line 274) from `ScreenZones.sky_margin(visible)`. `start_run` (line 211) calls `ScreenZones.play_sky(_margin.y, _margin.x)`. `sun_centre(_margin.y)` is unchanged.
- **Mid-run resize** (desktop only). The run keeps its sky, as today. Add `DisplayServer.window_set_min_size(1280, 720)` on desktop, which guarantees at least 640x360 visible. If the visible area still can't hold the run's sky, Main opens the pause panel until it can. This is open question Q1.
- **Window setup** (`project.godot`). Phones keep the 540x960 window and portrait-only orientation. Desktop gets a 1280x720 window through a `.pc` feature-tag override. Tablets get sensor orientation in the iPad/tablet export preset only.

## 2. Sky rect, figure centring, frame

- **`game/core/scorpio.gd:65`** becomes `shift = sky.get_center() - HOME_SKY.get_center()`. With a symmetric sky, `shift.x` is always 0. The 2D form is there for correctness. Update the comments at lines 48-53.
- **New `RunState.frame_rect`**, set in `_init`: `Rect2i(HOME_SKY.position.x + shift.x, sky_rect.position.y, HOME_SKY.size.x, sky_rect.size.y)`. On portrait it equals `sky_rect`; tested.
- **New helpers** `RunState.figure_middle()` = `HOME_SKY.get_center() + scorpio.shift` and `seam_middle()`, an alias. They replace every copy of that expression:
  - `run_state.gd` lines 469, 1624, 1713, 1853 and 1895, and `seam_view.gd:337`
  - the `sky_rect.get_center()` uses at `run_state.gd` lines 403 (ram column) and 2065 (`_ram_intro_burst`)
- **Negative-x "nothing found" bug.** These searches test `best.x < 0` against a `Vector2i(-1, -1)` marker, so a real spot at negative x would be thrown away. Each needs an explicit `found` bool:
  - `safe_launch_spot` (934-943)
  - `open_launch_spot` (964-982)
  - `ram_intro_layout` (2045-2052)
  - `_open_middle` (2306-2329)
- **`hole_intro_spots` (2445)** bounds its search by `2 * ScreenZones.SCREEN.x`. Change the bound to the sky's diagonal. This also removes a scenes constant from core.

## 3. Per-mechanic rules (⚠ = changes gameplay; each needs bot numbers in its commit)

| Mechanic | Rule on a wide sky | Code |
|---|---|---|
| Scatter, launch clamp, split points, link press | Follow `sky_rect`. No change. | `star_scatter.gd`, `run_state.launch`, `sky.gd:572` |
| Orion mark, volley pick, heat, breath, scythe, binding | Position-free, so they already act on the whole width. No change. | `orion.gd`, `volley.gd`, `star_heat.gd`, `star_harvest.gd` |
| Orion's corner | ⚠ Anchored to the frame's top-left, not the sky's, so he stands by the constellation. `Volley.intro_spots` takes an explicit `corner: Vector2i` (= `frame_rect.position`); `Hunt.mark` takes the frame itself and uses its top-left (since commit 7b). | `hunt.gd:74`, `volley.gd:69`, `run_state.gd:881,2241,2743` |
| Hunt circle | ⚠ Radius 38 is unchanged. The circle stays wholly inside the frame (`Hunt.mark(frame_rect, ...)`), so on a wide sky it lands by the constellation as on a phone; a loose star outside the frame is never circled (the user, 2026-10-19, Q3). | `hunt.gd`, `run_state.gd:881` |
| Seam, reflect, wave | Use `seam_middle()`. The halves extend across the whole width, and a wave still wipes exactly half the sky. A symmetric sky means the mirror of any aim lands on the sky. | see §2 |
| Current regions | ⚠ `_stage_area` (1574) also stretches sideways: a region with `end.x >= HOME_SKY.end.x` runs to `sky_rect.end.x`, and one with `position.x <= HOME_SKY.position.x` runs to `sky_rect.position.x`. On a 180-wide sky this does nothing. This fixes the Hand, Body and Legs. | `run_state.gd:1574`, comment at `star_map.gd:420` |
| Still strips on drain stages | ⚠ **Frame-edge rule:** on stages with a drain (Body, Legs, Stream, Jar, final box), a star outside `frame_rect` counts as drained at the next flow step. Portrait has no area outside the frame, so it is identical there. The preview ring already marks these stars red through `burst_drains_at`. | `StarCurrent.leaves(p, frame)` |
| Splash | ⚠ The loss edge is `frame_rect` instead of `sky_rect`: a star pushed out of the frame is lost. `splash_intro_spot` also measures from the frame's left edge. | `run_state.gd:1720,1782,1913`, `star_splash.gd:113,171` |
| Ram (Aries, hidden) | ⚠ `ram.charge(stars, frame_rect, ...)`: the ram starts at the frame's edge and butts stars out past the frame. ChargeView draws against the same rect. Can ship after the others while Aries is hidden. | `run_state.gd:1981,2087,2115,2000`, `charge_view.gd` |
| Black hole | ⚠ `StarGravity.step_at` uses `d_eff = min(d, reach)`, where `reach` is the farthest point of the home inner frame from that hole, worked out once per hole. On portrait `d` never exceeds `reach`, so nothing changes; outer stars fall at the frame-edge rate. The Legs twins stay at home + shift. | `star_gravity.gd:226`, `run_state.gd:387` |
| Fish cord (debug trial) | Ends that lie on a `HOME_SKY` edge extend along their arm to the sky edge. | `run_state.gd:2133` |
| Intros (volley, hunt, heat, breath, harvest, ram, splash, gauge, current) | Demo spots are limited to `inner_rect(frame_rect)`, so each demo plays by the figure. `_open_middle` scans the frame only. Intros pay nothing, so this changes no stakes. | `run_state.gd:2177,2295,2589,2672` |
| Guide spots | `open_launch_spot` and `safe_launch_spot` scan the frame only. This keeps the tutorial hand by the figure, matches portrait, and avoids a scan 3.5x larger. | `run_state.gd:918,950` |

`balance.json` is not touched. None of these rules adds a tuning value.

## 4. UI, HUD, chart and title

- **Already fine** (centred on x 90 or already using the visible rect): HUD corners, message line, tutorial line and TAP, end screen, menus, paytable, payout popups, Sun glow, collect targets, title, boss banner. The HUD row stays a centred cluster (`HUD_REACH 12`) and the telescope stays at (80, 300). This is Q5.
- **Orion views:**
  - `OrionView.setup` (`orion_view.gd:187`) takes `frame_rect.position`.
  - The arrow row `OVERHEAD_X` (482, 505) is measured from the frame.
  - `hud.gd:339` (volley counter) and `hud.gd:1151-1165` (encounter line and arrow footprint) use `run.frame_rect.position.x`.
- **Backdrop** (`backdrop.gd`):
  - `fit(visible, sky)` takes the run's sky.
  - The vignette's `OUTER_RADII.x` grows to `max(120, sky.size.x / 2 + 30)`, which is unchanged on portrait.
  - `margin_stars` and the 3 px glints skip the play sky's rect, so no decoration can be mistaken for a star.
- **Drain-stage frame edge.** On drain stages, CurrentView shades the sky outside the frame with the existing extinction pixels, so the frame-edge rule reads at a glance. Art check per the `art-direction.md` rules.
- **Animation timings** (each scales only above today's distance, so portrait is identical):
  - `HeatView.BREATH_TIME = max(0.55, far / BREATH_SPEED)`
  - `HarvestView` sweep at a fixed 300 px/s, i.e. `SWEEP_TIME * max(1, w / 180)`
  - telescope `FLIGHT_TIME` scaled by distance above today's maximum
  - `SeamView` sweep scaled by span
- **Debug controls.** `current_trial_controls.gd:51` anchors to `frame_rect.position + (8, 72) - (0, rows)`, inside the frame and clear of the outer columns.
- **Chart** (`chapter_select.gd`; every change gated on `_screen.size.x > SKY_SPAN`):
  - Open neighbours draw cool, with no AVAILABLE flare or ring (Q6).
  - Neighbour headings shrink to the faint name.
  - `sky_stars` keeps off neighbour charts.
  - The comet and reveal lift-off end at `min(_screen.end.x + 12, next crown)` (905, 1943).
  - Reveal sparkles are confined to the sign span.
  - The voyage swap matches the faint/charted state, and the comment at 1434 is fixed.
  - `space_image` is cached per size.
  - `SKY_SPAN`, `RING` and the seeds stay unchanged.
  - Making `chart_horizon.png` seamless is an `art/` branch, outside this one.

## 5. Input and aim

- `to_game`, world input and every clamp already handle negative x. Only the comments that say "180x320 grid" change: `screen_zones.gd:48`, `launcher.gd:56,110`, `telescope.gd:91,277,366`, `star_scatter.gd:3`, `link_gesture.gd:4`.
- **⚠ Slingshot reach** (`launcher.gd:22-27`). Compute in `setup(run)`: `_gain = max(AIM_GAIN, ceili((far - MIN_REACH) / float(MAX_PULL - MIN_PULL)))`, where `far` is the distance from the launcher to the farthest inner sky corner. On a 9:16 sky this stays 9, so portrait is identical. On 640x360 the corner is about 384 px away.
  - This also fixes today's unreachable corners on tall phones (above about 30 rows), which is a change on those phones (Q2).
  - The telescope (the default launcher) has no reach limit, so it needs no change.

## 6. Tests and bots

- **Portrait identity guard (commit 1, recorded on today's `main`).** `tests/test_portrait_identity.gd` plays every map with a fixed bot policy for seeds 1-20 on `Fixtures.SKY` and on `play_sky(102)`, and asserts a digest of positions, dust, light and outcome. Every later commit must pass it unchanged.
- **Fixtures.** `Fixtures.WIDE_SKY := Rect2i(-230, 38, 640, 212)`, and `Fixtures.run(overrides, seed, sky := SKY)`. The 16 local `SKY` copies stay.
- **New tests:**
  - `test_background`: the four windows in §1, the 640 cap (1366x768 → sky 640), and an odd extra width staying symmetric.
  - `test_scorpio`: wide `shift == (0, -20)`; `frame_rect == sky_rect` on portrait.
  - `test_main`: `fit_visible(640x360)` then restart gives the wide sky; the run in play keeps its own sky.
  - The four found-flag searches with a sky whose best spot is at x < 0.
  - `test_launcher`: wide corners reachable, portrait gain still 9.
  - `test_star_scatter` and `test_sky`: edges derived from the rect.
  - `test_tutorial:309`: fill the range from `sky_rect`.
  - Per mechanic on `WIDE_SKY`: outer-strip drains, splash loss at the frame, ram loss at the frame, `d_eff` cap, seam halves, fish-cord ends, Orion corner, intros inside the frame, `_stage_area` side stretch.
  - UI: HUD counter and encounter line follow the frame; payout bounds; vignette radius.
- **Bots.** A shared `tools/playtest_sky.gd` provides `parse_sky("--sky=640x360") -> Rect2i` through `ScreenZones.play_sky`. Wire it into `tools/{hunt,currents,heat,harvest,gravity,cords,reflect,ram}/playtest.gd` and `tools/rage/combo_share.gd`.
  - Fallback aims become `run.figure_middle()`. This fixes `hunt:112` and the `(90, 160)` fallbacks.
  - The sky size goes into the results file name.
  - Paired seeds, so each commit reports portrait vs wide side by side:

| Chapter | Bot | Maps |
|---|---|---|
| 1 Orion | hunt | tail, body, heart, claws, final |
| 2 Aquarius | currents | hand, body, legs, stream, jar, final |
| 3 Leo | heat | all stages |
| 4 Virgo | harvest | all stages |
| 5 Sagittarius | gravity | trial, arrow, bow, body, legs, head, final |
| 6 Pisces | reflect + cords | all stages, cord trial |
| 7 Aries | ram | horns |

  Acceptance: the wide win rate stays within ±3 points of portrait per stage, otherwise raise it as a question.
- **`sim.py`.** Add `--sky=WxH`. `INNER_SKY_AREA` is computed from it, default 180x320 so the portrait output is unchanged.

## 7. Commit order (every commit: GUT suite + identity guard pass; game runs)

1. `test:` portrait identity digest test, plus landscape `fill_size`/`game_offset` cases (no code change).
2. `fix:` explicit found flags in the four searches; `hole_intro_spots` bounded by the sky diagonal.
3. `feat:` `ScreenZones.sky_margin`, `MAX_SKY_WIDTH`, `play_sky(rows, side = 0)` (not wired yet).
4. `feat:` 2D `Scorpio.shift`, `RunState.frame_rect`, `figure_middle`/`seam_middle`, and the replaced call sites.
5. `chore:` bots and `sim.py` take `--sky`; shifted fallback aims; `Fixtures.WIDE_SKY` and `run(..., sky)`.
6. `feat:` `_stage_area` side stretch. Currents bot table.
7. `feat:` Orion anchored to the frame (core corner parameter, OrionView, HUD counter, encounter line, arrow row). Hunt bot table.
8. `feat:` intros and guide spots limited to the frame.
9. `feat:` frame-edge drain rule, plus the drain-edge shading. Currents bot table.
10. `feat:` splash loss at the frame edge. Reflect bot table.
11. `feat:` gravity `d_eff` cap. Gravity bot table.
12. `feat:` ram charges against the frame. Ram bot table.
13. `feat:` fish-cord ends snap to the sky edge.
14. `feat:` slingshot gain follows the sky.
15. `feat:` breath, sweep, flight and seam timings scale with distance.
16. `feat:` Backdrop vignette and margin stars follow the play sky.
17. `feat:` **the switch.** Main stores `_margin` and builds `play_sky(rows, side)`. Portrait gets `side = 0`, so it is identical.
18. `feat:` resize handling: desktop minimum window size, pause until the sky fits.
19. `chore:` `project.godot` desktop and tablet overrides.
20. `feat:` chart wide-window fixes (neighbours, comet, sky stars, sparkles, cache).
21. `fix:` debug current-trial controls anchored to the frame; `docs:` the "180x320 grid" comments.

## 8. Decisions (the user, 2026-10-19)

- **Q4 frame edge:** on drain, splash and ram stages, a star carried past the frame's sides is lost, as at a phone's sky edge; the sky outside the frame is shaded on those stages.
- **Q5 HUD:** the dust counter, planet slots and telescope stay a centred 180 px cluster; the corners go to the screen corners as today.
- **Q2 slingshot:** its reach follows the sky everywhere, tall phones included (they gain today's unreachable corners).
- **Q3 hunt circle:** "hunt should keep its circle inside the frame to prevent the stage from being too easy": the hunting circle stays wholly inside the frame (commit 7b). It was a default (measure first, ask past a 10% fall in strike coverage); commit 7's bot numbers went past it.
- Defaults taken (flagged in the PRs): **Q1** desktop minimum window 1280x720, the run keeps its sky and the game pauses until it fits; **Q6** the chart's neighbours drawn dimmed, not tappable; **Q7** the play sky caps at 640, the chart and title show more on ultrawide; **Q8** no decorative stars over the play sky; **Q9** the iPad's landscape sky follows the same rules.

## Build notes

Where the build differs from the plan above, or settles a detail it left open.

**Commit 1 (identity guard).**
- `tests/test_portrait_identity.gd` plays the 47 maps `StarMap.by_id` knows (the chapters' whole figures, every stage, `ram_trial`) plus the four debug trials it doesn't build (`current_trial`, `aquarius_flow`, `black_hole_trial`, `cord_trial`). Seeds 1-20, on `Fixtures.SKY` and `play_sky(102)`.
- The bot: Main's intros in Main's order, then the guide spots (`safe_launch_spot`, `open_launch_spot`, plus `ram_intro_layout` and `hole_intro_spots` where they apply) at the start and after the first launch, then the best link (landmarks first, then dust plus light) or a launch just up-left of the first unlit landmark (reflected), up to 300 actions. On hunt maps it also asks `safe_launch_spot` before every launch.
- The digest is wider than the plan's "positions, dust, light and outcome": every signal the run emits, with its arguments (stars by id, size and position; other objects by their script variables), and the end state. It is one md5 per map and sky. On a mismatch the test prints the new table.
- It plays the shipped `balance.json` (`Balance.load_file`), because that is what switches each stage's mechanics on. A deliberate balance change therefore needs the table recorded again. The wide-sky branch doesn't touch the balance.
- It was recorded on `feature/wide-sky` at `34b317b1` (main plus this doc), which has the same code as `main`. It adds about 50 s to the suite.
- `game_offset` takes the visible size as a `Vector2`, so the landscape cases in `test_background.gd` pass `fill_size(window)` through `Vector2(...)`. The table in §1 holds. 1366x768 gives 683x384 and an offset of (251, 64); the 640 cap there is commit 3's.

**Commit 2 (found flags, hole bound).**
- The tests (`tests/test_sky_searches.gd`) mostly use the 9:16 sky moved 200 px left, so every spot is at a negative x, rather than `WIDE_SKY`. This is because the figure doesn't move sideways until commit 4. Without a figure, `open_launch_spot` and `safe_launch_spot` must return exactly the 9:16 sky's spot moved 200 px. `_open_middle` (tested directly, though private) must land on the middle. `ram_intro_layout` must find its three stars. Each test failed on the old code.
- `WIDE_SKY` is a local constant in that test for now. It moves to `Fixtures` in commit 5.
- The hole bound is `ceili(Vector2(sky_rect.size).length())`, which is 249 on the 9:16 sky (was 360). For a hole inside the sky, a spot further out than the diagonal is off the sky either way, so the result doesn't change. The identity guard confirms this. A test builds a hole whose third demo star must stand over 400 px out and finds it on `WIDE_SKY`.
- Not fixed (unrelated, noted for later): `gauge_intro_spots` still reads `GravityView.RING_GAP`, a scene constant, from core.

**Commit 3 (sky margin).**
- `sky_margin` takes the visible size as a `Vector2`, like `game_offset` (Main passes the viewport's visible rect size), not a `Vector2i`.
- 1366x768 (683x384 visible) gives a margin of (230, 64): the 640 cap. A 1170x2532 phone gives (7, 102), so tall phones with a few spare columns now get them as sky once Main is switched (commit 17); until then nothing uses it.

**Commit 4 (2D shift, frame, figure middle).**
- `Scorpio.shift_in(sky)` is the static form of the shift; `RunState` uses it to set `frame_rect` before the Scorpio exists, so a run without a constellation has a frame too (the sky, on portrait). `figure_middle()` is `HOME_SKY.get_center() + shift_in(sky_rect)`, the same value as `+ scorpio.shift`, and works without a constellation.
- The ram's intro burst uses `figure_middle()` for both axes (the y one was `sky_rect.get_center().y`, always equal). `_ram_start_row`'s fallback `sky_rect.get_center().y` is left as it is (equal too).
- The 2D shift moves the figure with a sky moved sideways, so commit 2's `_open_middle` test ("the figure is far off") no longer holds: it now asserts the left sky's open middle is the home one moved 200 px left.

**Commit 5 (bots, sim, fixtures).**
- `tools/playtest_sky.gd` (preloaded, no `class_name`): `parse_sky`, `from_args`, `suffix`, `label`. `--sky=WxH` is the visible area in game px (640x360 for 1080p). Each bot prints the sky as its first line.
- The results file name gets `-sky<W>x<H>` (the play sky's size) only off the 9:16 sky, so portrait file names stay as they were. `combo_share.json` likewise.
- Fallback aims: the hunt bot's `HOME_SKY.get_center()` became `run.figure_middle()`; the `(90, 160)` fallbacks became `(90, 160) + run.scorpio.shift` rather than `figure_middle()` (90, 164), so portrait bot numbers stay exactly as before (checked: hunt heart and ram horns match `ws-step2-base` line for line). The hunt and cords bots' grid searches got found flags too.
- `sim.py --sky=WxH` takes the visible size and builds the play sky as `sky_margin`/`play_sky` do; the default 180x320 gives the old `INNER_SKY_AREA` (portrait output checked identical with a fixed seed). With `--sky=640x360` the sim's hunting circle takes 3.7% of loose stars (17.7% on portrait), because it assumes stars spread evenly over the sky; the spatial hunt bot is the real measure (Q3).
- `Fixtures.WIDE_SKY` and `Fixtures.run(overrides, seed, sky)`; `test_sky_searches.gd` uses them. `tests/test_playtest_sky.gd` covers the parser.
- Not fixed (pre-existing, also on `ws-step2-base`): the currents bot's probe errors with "Out of bounds get index" on `current_preview()` (`tools/currents/playtest.gd:182` and `:118`) on the hand map, portrait and wide alike.

**Commit 6 (`_stage_area` side stretch).**
- A region whose `end.x >= HOME_SKY.end.x` runs to `sky_rect.end.x`, and one whose `position.x <= HOME_SKY.position.x` from `sky_rect.position.x`, after the height stretch. On `WIDE_SKY` the Hand's flow is `(72, 38)` to x 410; the Body's and Legs' run from their drain at x 48 to x 410. The Stream, Jar and final box sit inside the home columns and don't stretch.
- Currents bot: the Hand, Body and Legs wide numbers barely move (the bot aims by the landmarks, so its stars rarely reach the stretched columns). The final's wide `+3.0`/`+8.5` was already there before this commit.

**Commit 7 (Orion anchored to the frame).**
- `Hunt.mark(sky, corner, loose, avoid)` and `Volley.intro_spots(inner, corner)`: the corner is the second, required parameter (the tests' calls pass `Fixtures.SKY.position`). `OrionView.setup` takes the frame rect itself (its top and bottom are the sky's), so the arrow row, its fall and the figure follow it without more changes. `Hud.encounter_block` works within `frame_rect`.
- **Q3, raised.** The hunt bot shows the hunting circle spreading over the wider sky: on the Heart, Claws and final, circles over the figure fall from 28-48% (portrait) to 6-17% (wide), stars struck a run by 26-72%, and wide win rates rise by 10-22 points (e.g. Heart naive 84.7 → 95.0, final careful 13.7 → 35.7). This commit itself moves the wide numbers by at most a few points; the gap comes from the circle being placed "as far off the constellation as the sky allows". Over the 10% line, so a question: should `Hunt.mark` keep its circles within the frame (or the frame grown by a radius)?

**Commit 7b (hunting circle in the frame).**
- The user, 2026-10-19, on Q3: "hunt should keep its circle inside the frame to prevent the stage from being too easy".
- Reading taken: the **whole circle** stays inside the frame (its centre in `frame_rect.grow(-radius)`), not just its centre. That is what `Hunt.mark` already did against the sky, so on the 9:16 sky (frame = sky) it is identical; a centre-only reading would have let portrait circles hang over the sky's edge. A loose star outside the frame is passed over as prey (no circle in the frame can cover it); with no reachable prey the circle goes anywhere in the frame, as before.
- `Hunt.mark(frame, loose, avoid)`: the separate `corner` parameter is gone, Orion's corner is the frame's top-left. Both call sites (the launch's mark and the hunt intro, which already passed the frame since commit 8) pass `frame_rect`. OrionView's arrow row and figure, the encounter line and `safe_launch_spot` already worked from the frame or the circle's centre, so nothing else changed.
- Tests (`tests/test_wide_sky.gd`): a star in the wide sky's corner is not circled; Orion's corner kept clear; on `WIDE_SKY` 200 seeds of random loose stars over the whole width all give a circle wholly inside the frame; 20 wide Heart runs launching into the outer columns mark every circle inside the frame; on the 9:16 sky the frame is the sky and the mark matches. Full suite 1465/1465, identity guard unchanged.
- Hunt bot, 300 paired seeds per stage, wide = `--sky=640x360` (play sky 640x212). Portrait numbers are unchanged from commit 7. Win % / circles over the figure % / stars struck a run:

| Stage | Policy | Portrait | Wide, commit 7 | Wide, 7b |
|---|---|---|---|---|
| Tail | naive | 100.0 / 0 / 0 | 100.0 / 0 / 0 | 100.0 / 0 / 0 |
| Tail | careful | 100.0 / 0 / 0 | 100.0 / 0 / 0 | 100.0 / 0 / 0 |
| Body | naive | 73.0 / 0 / 0 | 73.0 / 0 / 0 | 73.0 / 0 / 0 |
| Body | careful | 73.0 / 0 / 0 | 73.0 / 0 / 0 | 73.0 / 0 / 0 |
| Heart | naive | 84.7 / 28.2 / 6.40 | 95.0 / 8.2 / 4.75 | 88.3 / 18.8 / 5.44 |
| Heart | careful | 97.0 / 30.7 / 2.20 | 99.3 / 7.3 / 0.96 | 98.0 / 17.4 / 1.48 |
| Claws | naive | 79.7 / 30.1 / 6.34 | 93.7 / 6.0 / 4.91 | 85.0 / 20.4 / 5.80 |
| Claws | careful | 93.0 / 35.8 / 3.10 | 99.3 / 7.2 / 1.03 | 97.7 / 24.6 / 1.81 |
| Final | naive | 4.7 / 42.2 / 8.17 | 12.7 / 12.5 / 5.85 | 8.7 / 22.2 / 6.75 |
| Final | careful | 13.7 / 48.0 / 5.30 | 35.7 / 17.1 / 1.49 | 32.3 / 28.3 / 2.38 |

- The gap closes by roughly 55-65% on the Heart (both policies) and the Claws naive, but only by a quarter on the Claws careful (+6.3 to +4.7); wide is still easier than portrait by +1.0 to +5.3 points there, +4 on the final naive and **+18.6 on the final careful** (over §6's ±3). The rest of the gap: stars launched into the outer columns are now never struck (the careful bot aims clear of the circle and often lands them there), and the circle still sits "as far off the constellation as the frame allows". Not addressed here; options if it should close further: on hunt stages, also shrink the launch clamp or the scatter to the frame, or let the circle's prey include stars outside the frame with the circle clamped to the frame grown by a radius.
- `sim.py` is unchanged: it models stars spread evenly over the sky, so its circle share (circle area over the sky's inner area) doesn't see where the circle is placed.

**Commit 8 (intros and guide spots in the frame).**
- Limited to the frame: the volley, hunt (its circle too: `hunt.mark(frame_rect, ...)`), heat, breath, harvest, gauge, current and plain reflection intros, `_open_middle`, `open_launch_spot` and `safe_launch_spot`. `open_launch_spot` still computes a red's split points on the sky, as the launch does, and keeps those inside the frame.
- Left for later: the splash and ram intros (their demo is built on the edge rule commits 10 and 12 move to the frame), the wave intro (it wipes half the sky) and the hole intro (round the hole).
- No bot plays the intros or asks for a guide spot, so the bot numbers can't move (hunt bot checked: identical).

**Commit 9 (frame-edge drain rule, shading).**
- `StarCurrent.frame` (set from `frame_rect` for every current; the current intro's copy takes it too). On a draining flow: `stranded(at)` is "outside the frame"; `leaves(from, to)` is true for a stranded star, or for a step that leaves the region or the frame. A stranded star's destination is `off_frame`: one flow step further out from the frame (`outward`), so it is a move like any drained one; SkyView drains its view there rather than at the region's edge, and the at-risk arrow points outward.
- The shading: CurrentView draws the sky outside the frame with a 4x4 tile holding two S1 pixels (one pixel in eight, drawn as a repeating texture, not per-pixel), and the drain's dotted S3 line one column outside each frame side. Palette-locked; not yet looked at in a capture (art check still to do).
- The currents bot's aim is clamped to the inner frame, as the launch clamps an aim to a 9:16 sky (portrait numbers unchanged).
- **Raised: the drain stages are harder on the wide sky.** Currents bot (200 seeds), wide minus portrait win %: Body launch-owned-first -10.0; Legs link-first -3.5, launch-owned-first -7.0; Jar within 1; Stream within 1.5; final -14.5 (upstream aim) to -30.5. The cause: bursts near the frame's sides scatter past them and drain, where a 9:16 sky's edge clamps the scatter in (a human sees the red preview; the bot doesn't). Measured alternative (not built): on drain stages, a burst inside the frame scatters within the frame (`StarScatter.place(..., frame_rect, ...)`). It brings the Legs back to within 0.5 and the final to -6 to -14, the Body launch-owned-first stays at -10. Question: keep the design's rule, add the scatter clamp, or more?

**Commit 10 (splash loss at the frame edge).**
- `frame_rect` replaces `sky_rect` everywhere the splash decides a loss: `_splash` and its moves, `splash_preview`/`launch_splashes` (`_splash_chain`), and the splash intro. `StarSplash`'s code is unchanged (only its comments change): its `sky` parameter is now the loss edge, and RunState passes the frame. The splash intro, which commit 8 left for this commit, now throws its demo planet `SPLASH_INTRO_IN` (22) px in from the frame's edge (`splash_intro_spot` scans `inner_rect(frame_rect)`). Its demo burst is clamped to the frame and scatters inside it. The wave intro still works on the whole sky, since it wipes half of it.
- A lost star still drifts to where it was pushed and cuts out there. `SeamView.exit_point` clamps only at the sky's edge, so in a wide sky's outer columns the star cuts out at its destination. Only the function's comment changed.
- The shade: on a seam stage with a splash (the Circlet has none), SeamView draws the same sparse S1 tile outside the frame and the drain's dotted S3 line along the frame's sides. The helpers moved out of CurrentView's drain code into shared statics (`outside_frame`, `frame_side_pixels`, `draw_frame_shade`, `shade_tile`), and the drain's `frame_shade_rects`/`frame_edge_pixels` now call them. As with commit 9, nobody has checked this in a capture yet.
- Tests (`tests/test_wide_sky.gd`, `tests/test_wide_sky_views.gd`, 7 new):
  - A push past the frame's side loses the star even though the sky goes on, and a star the push leaves in the frame moves on.
  - A splash in the outer columns loses every star it pushes.
  - The aim's preview marks the same losses.
  - On the 9:16 sky the loss is at the sky's edge, as before.
  - The intro throws from the frame's edge, keeps its demo stars by the figure and loses exactly one.
  - The frame's sides are dotted on a wide splash stage. There is no shade and no dotted line without a splash or on the 9:16 sky.
  - The identity guard is unchanged.
- Reflect bot, 200 paired seeds, splash on. Wide = `--sky=640x360`, before = `ws-step4-base` (`162941aa`). Win % is portrait / wide before / wide after (after minus portrait). Lost a run counts the stars the splash and the wave took, portrait / wide before / wide after:

| Stage | Policy | Win % | Lost a run |
|---|---|---|---|
| Knot | link-first | 100.0 / 100.0 / 100.0 (+0.0) | 1.13 / 0.81 / 0.82 |
| Knot | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.00 / 0.00 / 0.00 |
| Knot | naive | 91.0 / 96.5 / 91.0 (+0.0) | 2.76 / 0.97 / 2.60 |
| Knot | careless | 100.0 / 100.0 / 100.0 (+0.0) | 1.60 / 1.05 / 1.13 |
| Knot | launch-first | 100.0 / 100.0 / 100.0 (+0.0) | 1.39 / 1.29 / 1.29 |
| East Cord | link-first | 96.5 / 96.5 / 96.5 (+0.0) | 2.07 / 1.87 / 1.93 |
| East Cord | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.02 / 0.01 / 0.01 |
| East Cord | naive | 91.5 / 95.0 / 94.5 (+3.0) | 2.76 / 1.67 / 2.15 |
| East Cord | careless | 91.5 / 92.0 / 91.0 (-0.5) | 2.89 / 2.40 / 2.52 |
| East Cord | launch-first | 94.0 / 93.5 / 93.5 (-0.5) | 1.86 / 1.66 / 1.72 |
| North Fish | link-first | 100.0 / 100.0 / 100.0 (+0.0) | 1.92 / 1.94 / 1.94 |
| North Fish | careful | 100.0 / 100.0 / 100.0 (+0.0) | 1.87 / 1.90 / 1.90 |
| North Fish | naive | 24.0 / 30.0 / 28.5 (**+4.5**) | 8.00 / 7.72 / 7.73 |
| North Fish | careless | 99.5 / 99.5 / 99.5 (+0.0) | 2.42 / 2.28 / 2.31 |
| North Fish | launch-first | 82.5 / 82.5 / 82.5 (+0.0) | 6.45 / 6.45 / 6.45 |
| Final | link-first | 93.0 / 94.5 / 94.5 (+1.5) | 6.34 / 6.13 / 6.19 |
| Final | careful | 98.0 / 97.0 / 97.0 (-1.0) | 5.39 / 5.70 / 5.66 |
| Final | naive | 26.5 / 36.5 / 31.0 (**+4.5**) | 13.03 / 13.08 / 13.42 |
| Final | careless | 80.5 / 83.5 / 82.5 (+2.0) | 8.69 / 8.53 / 8.75 |
| Final | launch-first | 3.0 / 3.0 / 3.0 (+0.0) | 9.32 / 9.33 / 9.34 |

- Packs a win stay within 0.5 of portrait's on every row. The frame edge brings the wide splash losses back to portrait's level (Knot naive: 0.97 rises to 2.60, against 2.76 on portrait). Every policy that plays the seam is within ±3.
- **Raised: "naive" stays +4.5 on the North Fish and the final.** The naive policy throws without regard to the seam, and both of these are wave stages. The commit blames the wave for the rest of the gap, not the splash: the wave still wipes half of the whole wide sky (§3). That split was not measured. Not addressed here.

**Commit 11 (gravity `d_eff` cap).**
- `StarGravity.frame` is set from `frame_rect` when the run builds its hole. `copy()` keeps it, so an intro's copy has it too. `step_at` divides the pull by `min(d, reach(hole))`, where `reach` is the distance from the hole to the farthest of the four corners of `inner_rect(frame)` (end corners at `end - 1`). With no frame set, there is no cap.
- Differs from the plan: `reach` is worked out on every call from where the hole is now, not once per hole from the home frame. This keeps it right for the Legs' twins as they drift. On any 9:16 sky the frame is the sky and every star stands within the reach, so nothing changes there.
- `pulls_to_swallow` (used for the hole intro's layout) counts with the same reach, measured from the main hole's centre. The hole intro's spots are still found around the hole, as commit 8 left them.
- Tests (`tests/test_wide_sky.gd`, 5 new):
  - A star out past the frame falls at the frame edge's rate, not at the slow uncapped rate.
  - Inside the frame the pull is unchanged.
  - On the portrait sky no star is past the reach.
  - The reach follows the drifting twins.
  - `pulls_to_swallow` counts with the reach.
  - The identity guard is unchanged.
- Gravity bot, 200 paired seeds, hole on, wide = `--sky=640x360`. The wide numbers before (`ws-step4-base`) and after this commit are identical, so the table has one wide column. Win % is portrait / wide (wide minus portrait). Swallowed a run is portrait / wide:

| Stage | Policy | Win % | Swallowed a run |
|---|---|---|---|
| Hole trial | link-first | 41.0 / 41.0 (+0.0) | 9.23 / 9.23 |
| Hole trial | launch-first | 7.0 / 6.5 (-0.5) | 9.54 / 9.52 |
| Hole trial | archer | 99.5 / 100.0 (+0.5) | 2.97 / 2.88 |
| Hole trial | archer-hoard | 86.0 / 86.0 (+0.0) | 6.43 / 6.37 |
| Arrow | link-first | 97.0 / 97.0 (+0.0) | 4.50 / 4.51 |
| Arrow | launch-first | 53.5 / 53.5 (+0.0) | 8.23 / 8.23 |
| Arrow | archer | 100.0 / 100.0 (+0.0) | 3.03 / 2.90 |
| Arrow | archer-hoard | 92.5 / 93.5 (+1.0) | 6.59 / 6.46 |
| Bow | link-first | 89.5 / 92.0 (+2.5) | 7.64 / 7.28 |
| Bow | launch-first | 45.5 / 52.0 (**+6.5**) | 9.94 / 9.70 |
| Bow | archer | 100.0 / 100.0 (+0.0) | 2.59 / 1.98 |
| Bow | archer-hoard | 85.0 / 95.5 (**+10.5**) | 7.35 / 6.34 |
| Body | link-first | 51.0 / 50.5 (-0.5) | 10.83 / 10.87 |
| Body | launch-first | 13.0 / 14.0 (+1.0) | 10.69 / 10.81 |
| Body | archer | 100.0 / 99.5 (-0.5) | 3.66 / 3.74 |
| Body | archer-hoard | 88.5 / 89.5 (+1.0) | 7.52 / 7.36 |
| Legs | link-first | 54.0 / 55.5 (+1.5) | 7.05 / 6.95 |
| Legs | launch-first | 0.0 / 0.0 (+0.0) | 4.09 / 4.10 |
| Legs | archer | 97.0 / 97.0 (+0.0) | 2.09 / 1.94 |
| Legs | archer-hoard | 0.0 / 0.0 (+0.0) | 4.72 / 4.72 |
| Head | link-first | 33.5 / 33.5 (+0.0) | 8.78 / 8.79 |
| Head | launch-first | 2.5 / 2.5 (+0.0) | 9.51 / 9.51 |
| Head | archer | 98.0 / 98.0 (+0.0) | 1.24 / 1.29 |
| Head | archer-hoard | 78.0 / 77.5 (-0.5) | 3.34 / 3.33 |
| Final | link-first | 26.5 / 26.0 (-0.5) | 8.83 / 8.84 |
| Final | launch-first | 0.0 / 0.0 (+0.0) | 8.76 / 8.76 |
| Final | archer | 86.5 / 76.5 (**-10.0**) | 3.68 / 3.69 |
| Final | archer-hoard | 0.0 / 0.0 (+0.0) | 6.06 / 6.05 |

- Packs a win stay within 0.15 of portrait's. The cap changes no bot number, because the bot aims by the landmarks and its stars never stand past the frame's reach.
- **Raised: three gaps over ±3 that existed before this commit**, so the cap didn't cause them:
  - The Bow is easier on the wide sky: archer-hoard +10.5 and launch-first +6.5, with fewer stars swallowed (7.35 drops to 6.34, and 9.94 to 9.70).
  - The final is harder for the archer: -10.0, with the same number of stars swallowed.
  - Nobody has looked into the cause on this branch. Question: should these be investigated before the switch (commit 17), or accepted?

**Commit 12 (ram charges against the frame).**
- `frame_rect` replaces `sky_rect` in every `ram.charge` call (`_charge_ram`, `charge_preview`, the ram intro). It also replaces it in the intro's layout, burst and scatter (`ram_intro_layout`, `_ram_intro_burst`, `_ram_intro_round`), which commit 8 left for this commit. The ram stands at the frame's edge, and a star it carries past the frame's far side is lost even though the sky goes on.
- Settled here: a star **behind** the ram (outside the frame on the ram's own side) is out of its way and stays (`StarCharge.behind(point, frame)`). A star ahead of the ram in its lane, out in the far outer columns, is carried on and lost. A ram charging down starts at the frame's top, which is the sky's top, so nothing can stand behind it.
- ChargeView draws the head, pips, prints and dust against `frame_rect`. Its pixels are still cut to the sky. A lost star cuts out where it was butted, because `exit_point` clamps only at the sky's edge, like SeamView's. CurrentView now also draws the frame shade and the dotted S3 sides on a ram stage, which has no current. It draws them under the stars, since ChargeView sits above the stars. Nobody has checked this in a capture yet.
- Tests (`tests/test_wide_sky.gd`, `tests/test_wide_sky_views.gd`, 7 new):
  - The ram butts a star out past the frame's far side.
  - A star the ram keeps in the frame is butted on.
  - Charging down or from the right, the ram leaves alone whatever stands behind it.
  - On the 9:16 sky the ram loses stars at the sky's edge, as before.
  - The ram intro plays inside the frame.
  - The ram and its lane are drawn within the frame.
  - A wide ram stage shades the sky outside the frame and dots the frame's sides.
  - The identity guard is unchanged.
- Ram bot, 200 paired seeds, ram on. Wide = `--sky=640x360`, before = `ws-step4-base`. Win % is portrait / wide before / wide after (after minus portrait). Lost a run is portrait / wide before / wide after:

| Stage | Policy | Win % | Lost a run |
|---|---|---|---|
| Horns | link-first | 100.0 / 100.0 / 100.0 (+0.0) | 2.52 / 0.00 / 2.52 |
| Horns | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.26 / 0.00 / 0.26 |
| Horns | careless | 95.0 / 100.0 / 95.0 (+0.0) | 3.77 / 0.04 / 3.76 |
| Horns | launch-first | 86.0 / 100.0 / 86.0 (+0.0) | 6.42 / 0.01 / 6.42 |
| Head | link-first | 48.0 / 100.0 / 48.0 (+0.0) | 8.37 / 0.20 / 8.37 |
| Head | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.53 / 0.00 / 0.48 |
| Head | careless | 30.5 / 96.5 / 30.5 (+0.0) | 10.07 / 0.71 / 10.07 |
| Head | launch-first | 34.0 / 93.0 / 34.0 (+0.0) | 8.68 / 0.66 / 8.68 |
| Fleece | link-first | 99.5 / 100.0 / 99.5 (+0.0) | 1.62 / 0.01 / 1.35 |
| Fleece | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.36 / 0.01 / 0.34 |
| Fleece | careless | 93.5 / 100.0 / 95.0 (+1.5) | 3.40 / 0.18 / 3.09 |
| Fleece | launch-first | 100.0 / 100.0 / 99.5 (-0.5) | 1.11 / 0.10 / 1.08 |
| Ram trial | link-first | 98.5 / 100.0 / 98.5 (+0.0) | 2.21 / 0.00 / 2.22 |
| Ram trial | careful | 100.0 / 100.0 / 100.0 (+0.0) | 0.02 / 0.00 / 0.02 |
| Ram trial | careless | 96.0 / 100.0 / 96.0 (+0.0) | 3.92 / 0.03 / 3.91 |
| Ram trial | launch-first | 95.0 / 100.0 / 95.0 (+0.0) | 5.17 / 0.01 / 5.17 |

- Before this commit, the wide ram ran 640 px to the sky's far edge and almost never lost a star, which made the Head up to 66 points easier. Now every wide number is within ±1.5 of portrait's. Packs a win match too, except on the Head careful row (3.92 portrait, 4.32 wide), where both skies win 100%.

**Commit 13 (fish-cord ends snap to the sky edge).**
- `_fish_cord` shifts the map's cord as before. Then each **end** whose home point lies on `HOME_SKY`'s left or right edge runs on along its arm (the segment leading into that end) to the same side of the sky (`_cord_end_to_side`, rounded to whole pixels). If the arm meets the sky's top or bottom first, the end stops there. Inner points don't move.
- Narrower than the plan's "ends on a `HOME_SKY` edge": only the left and right edges count. An end on the home top or bottom stays where the shift puts it, as it already does on a tall phone. On a 9:16 sky the side is already where the end is, so nothing changes.
- Example: on `WIDE_SKY` the cord trial's right end runs on from (179, 194) to (409, 246), so the cord still splits the outer columns. Its end on the home top stays at (166, 58), 20 px below the wide sky's top (y 38). Stars can therefore pass around that end through the strip above it, as on a tall phone today. Left as it is, since the plan covers only the sides.
- Tests (`tests/test_wide_sky.gd`, 3 new):
  - A side end runs on to the wide sky's side, and the cord crosses a step in the outer columns.
  - An arm that reaches the top first stops there, on the arm's line.
  - On the 9:16 sky and on `play_sky(102)`, the ends stay where they were.
  - The identity guard is unchanged (it plays `cord_trial`).
- No bot table: the cord trial is debug-only, and only `cord_trial` has a fish cord (`StarMap`), so no shipped stage moves.

**Commit 14 (slingshot gain follows the sky).**
- `Launcher.gain_for(launcher, sky)` is the spec's formula: `max(AIM_GAIN, ceili((far - MIN_REACH) / float(MAX_PULL - MIN_PULL)))`, `far` the distance from the launcher to the farthest of the four inner sky corners (`StarScatter.inner_rect`, end corner at `end - 1`, the same corners the clamp lands on). `setup(run)` stores it in `_gain` (`aim_gain()` reads it); `burst_preview` and the launch pass it to `aim_target(launcher, pull, gain = AIM_GAIN)`. AIM_GAIN, MIN_REACH and the pulls stay scene constants (aim feel, not balance).
- The formula checked against the mapping: a full pull reaches `MIN_REACH + (MAX_PULL - MIN_PULL) * gain`, so the ceiling makes that at least `far`, and a pull shorter than full reaches every nearer point along the same direction; anything past the sky is clamped by the core as before. No adjustment needed.
- Gains with the launcher at (90, 270): the 9:16 sky 9 (corner 201.4 px, a full pull 206); `WIDE_SKY` 18 (corner 384.1 px); a 1170x2532 phone (`play_sky(102, 7)`) 14 (299.5 px). The doc's "above about 30 rows" is loose: a top corner passes 206 px from about 6 extra rows (20 rows gives 10, 30 rows 11), so most tall phones get a slightly faster aim (Q2).
- The telescope overrides `burst_preview` and aims at the touch, so it is unchanged. No bot or the identity guard uses the slingshot (they call `RunState.launch` with a target), so there is no bot table and the guard can't move.
- Tests (`tests/test_launcher.gd`): the 9:16 sky keeps gain 9; every inner corner and edge midpoint of `WIDE_SKY` and of the tall phone's sky is within a full pull and the preview lands on it exactly (the tall phone's top corner was out of reach at gain 9); `gain_for` is the least gain reaching the farthest corner on four skies. Full suite 1469/1469.

**Commit 15 (breath, sweep, flight and seam timings scale with distance).**
- One rule for all four, settled here: each timing keeps its constant over the distance it covers on the run's **frame** (the portrait 180 columns at the sky's height), and past that it grows in proportion, so it keeps today's speed. Two helpers in `ScreenZones` carry it: `farthest_corner(from, rect)` (to the rect's corner pixels, `end - 1`) and `stretch(far, home) = max(1, far / home)`. On a portrait sky `sky_rect == frame_rect`, so every stretch is exactly 1. That holds on tall phones too (`play_sky(rows)`, side 0), not only on the 9:16 sky.
- How each one differs from the §4 wording:
  - **Breath:** `HeatView.breath_time(at, sky, frame) = BREATH_TIME * stretch(farthest_corner(at, sky), farthest_corner(at, frame))`. The plan's `max(0.55, far / BREATH_SPEED)` would have changed portrait: a breath from a portrait corner is 367 px from the far corner, but today's ring stops at 198 px. The ring still rolls at `BREATH_SPEED`. Each breath keeps its own duration (`_breath_lasts`). `breath_pixels` takes `lasts`, which defaults to `BREATH_TIME`. The stars' change delays were already distance / `BREATH_SPEED`, so they are unchanged.
  - **Sweep:** `HarvestView.sweep_time(sky) = SWEEP_TIME * stretch(sky.size.x, 180)`, which is the plan's 300 px/s. It is used by `sweep()`, `cut_delay`, the blade's progress, Sky's arrival hold (`sky.gd` `harvested`) and the HUD's arrival-card wait (`hud.gd` setup).
  - **Flight** (slingshot and telescope, through the shared `Launcher._start_flight`, for real and hunt-intro demo launches alike): `Launcher.flight_time(from, burst, frame) = FLIGHT_TIME * stretch(|burst - from|, farthest_corner(from, frame))`. `from` is the fork, or the telescope's mouth. "Today's maximum" is the frame's farthest corner from where the flight starts. Every portrait burst lies in the frame, so it is never farther than that corner. The sequencer hold, the arc and the tremble switch all read `_flight_lasts` (`flight_lasts()`).
  - **Seam:** `SeamView.rush_seconds(way) = SWEEP_TIME * stretch(span to the sky's edge, span to the frame's edge)`, worked out per side. Only left and right waves (the final's vertical line) stretch. Up and down waves keep `SWEEP_TIME`, because the frame is the sky's full height. `sweep_delay`, the drawn rush (`sweep_pixels(..., rush)`), the end of the view's sweep and Sky's hold and carry tweens use it. The great wave waits for its longer side (`sweep_wait()`). The static `sweep_hold()` stays the portrait value. `sweep_pixels` now draws nothing once its own side's crash is over, which only matters for a great wave with unequal sides. On portrait the view stops before that age.
- Not stretched (outside the plan's four): Orion's arrow `FLIGHT_TIME` (`orion_view.gd`), the wave's `WINDUP_TIME` and `CRASH_TIME`, and the splash's `RIPPLE_TIME`. The splash reach is a balance distance, so it is the same on every sky.
- All presentation, none in core, so the identity guard can't see it. `tests/test_wide_timings.gd` (14 new) pins portrait to the old constants: every 10th pixel of the 9:16 sky and `play_sky(102)` as a breath origin and as a flight burst from four launch points, every wave way on the North Fish and the final, and the great wave's wait. It also checks that wide timings stretch by the ratio and that the views run for that long. `tests/test_launcher.gd` (2 new): a portrait corner flight lasts `FLIGHT_TIME`, and a `WIDE_SKY` corner flight lasts `flight_time`, holds the sequencer and lands trembling on the burst. Full suite 1487/1487. No bot table, since bots don't use the scenes. Added after review (`tests/test_wide_timings.gd`, 3 more): what waits on these timings in the scenes, which the first tests didn't reach: Sky's wave hold (`sweep_wait`, both ways and great), Sky's Virgo arrival hold and the HUD's arrival-card wait, each the old value exactly on the 9:16 sky and the stretched one on `WIDE_SKY`. Full suite 1490/1490. Nobody has watched it in a capture yet. Measured on `WIDE_SKY`: with the launcher at (90, 270), a flight to either top inner corner takes 0.66 s (0.43 s on a phone). The sweep takes 2.13 s, and a side-wave rush on the final takes 1.49 s or 1.51 s (0.42 s on a phone). A breath from the frame's centre lasts 1.33 s, and one from (-220, 150) lasts 0.85 s (0.55 s on a phone).
