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
| Orion's corner | ⚠ Anchored to the frame's top-left, not the sky's, so he stands by the constellation. `Hunt.mark` and `Volley.intro_spots` take an explicit `corner: Vector2i` (= `frame_rect.position`). | `hunt.gd:71`, `volley.gd:69`, `run_state.gd:863,2177,2677` |
| Hunt circle | ⚠ Radius 38 is unchanged and the circle may land anywhere in the sky (it is placed round a random loose star). Risk: players spread stars wider, so each strike hits fewer stars as collateral. Measure with the hunt bot. Q3 covers what to do if strike coverage falls more than 10%. | `hunt.gd` |
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
- Defaults taken (flagged in the PRs): **Q1** desktop minimum window 1280x720, the run keeps its sky and the game pauses until it fits; **Q3** measure the hunt with its bot first, and ask if strike coverage falls more than 10%; **Q6** the chart's neighbours drawn dimmed, not tappable; **Q7** the play sky caps at 640, the chart and title show more on ultrawide; **Q8** no decorative stars over the play sky; **Q9** the iPad's landscape sky follows the same rules.

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

**Commit 8 (intros and guide spots in the frame).**
- Limited to the frame: the volley, hunt (its circle too: `hunt.mark(frame_rect, ...)`), heat, breath, harvest, gauge, current and plain reflection intros, `_open_middle`, `open_launch_spot` and `safe_launch_spot`. `open_launch_spot` still computes a red's split points on the sky, as the launch does, and keeps those inside the frame.
- Left for later: the splash and ram intros (their demo is built on the edge rule commits 10 and 12 move to the frame), the wave intro (it wipes half the sky) and the hole intro (round the hole).
- No bot plays the intros or asks for a guide spot, so the bot numbers can't move (hunt bot checked: identical).

**Commit 9 (frame-edge drain rule, shading).**
- `StarCurrent.frame` (set from `frame_rect` for every current; the current intro's copy takes it too). On a draining flow: `stranded(at)` is "outside the frame"; `leaves(from, to)` is true for a stranded star, or for a step that leaves the region or the frame. A stranded star's destination is `off_frame`: one flow step further out from the frame (`outward`), so it is a move like any drained one; SkyView drains its view there rather than at the region's edge, and the at-risk arrow points outward.
- The shading: CurrentView draws the sky outside the frame with a 4x4 tile holding two S1 pixels (one pixel in eight, drawn as a repeating texture, not per-pixel), and the drain's dotted S3 line one column outside each frame side. Palette-locked; not yet looked at in a capture (art check still to do).
- The currents bot's aim is clamped to the inner frame, as the launch clamps an aim to a 9:16 sky (portrait numbers unchanged).
- **Raised: the drain stages are harder on the wide sky.** Currents bot (200 seeds), wide minus portrait win %: Body launch-owned-first -10.0; Legs link-first -3.5, launch-owned-first -7.0; Jar within 1; Stream within 1.5; final -14.5 (upstream aim) to -30.5. The cause: bursts near the frame's sides scatter past them and drain, where a 9:16 sky's edge clamps the scatter in (a human sees the red preview; the bot doesn't). Measured alternative (not built): on drain stages, a burst inside the frame scatters within the frame (`StarScatter.place(..., frame_rect, ...)`). It brings the Legs back to within 0.5 and the final to -6 to -14, the Body launch-owned-first stays at -10. Question: keep the design's rule, add the scatter clamp, or more?
