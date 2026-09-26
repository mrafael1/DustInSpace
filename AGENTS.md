# AGENTS.md: Dust In Space

Instructions for any coding agent (Claude Code, Codex, Cursor…) working in this repo.

## Git workflow

- **Never commit directly to `main`.** `main` must always open and run.
- **One branch per feature or bug**, created from an up-to-date `main`:
  - Feature: `feature/<short-name>` (e.g. `feature/star-linking`)
  - Bug: `fix/<short-name>` (e.g. `fix/stars-outside-sky`)
  - Balance-only change: `tune/<short-name>`
  - Art-only change: `art/<short-name>`
  - Docs or tooling: `chore/<short-name>`
- Before starting: `git switch main && git pull && git switch -c feature/<name>`.
- Keep a branch to one topic. If you find an unrelated bug, note it and don't fix it on the same branch.
- Commit in small steps with the matching prefix: `feat:`, `fix:`, `tune:`, `art:`, `test:`, `docs:`, `chore:`.
- When done, push the branch and open a pull request into `main` with:
  - what changed
  - how it was tested (test output; simulator table if balance changed)
  - anything not done or any design guess made
- Never merge, force-push or delete branches unless the user asks.

## The game in one paragraph

Dust In Space is a portrait pixel-art mobile game made in **Godot 4.7 (GDScript)**. The player slingshots planet-shaped star packs into a night sky. Each pack bursts into random small, medium and big stars. The player links 3 stars into combinations (three of a size, or one of each size in any order) to earn **dust**, which buys more packs, and **light**, which restores a dying Sun. A rare legendary opening, the **Big Bang**, collapses and clears the sky for a large dust payout. The game should feel like a slot machine (anticipation, randomness, satisfying payouts) delivered through tactile interaction instead of reels.

Read before any gameplay work: `docs/design.md`. Read before any visual work: `docs/art-direction.md`.

## Current milestone

**First playable: Restore the Sun.** One short run with no meta-progression and no run buffs. It needs:

- Packs, star drawing, linking, rewards, purchases, and win/loss.
- Slingshot launch, star scatter, link tracing.
- Feedback: particles to the counters, Sun brightening, the normal opening and the Big Bang.
- A debug overlay to edit balance values and force a Big Bang.

Anything outside this list needs the user's approval first.

## Hard rules

1. **Balance values live only in `game/config/balance.json`.** The game and `tools/balance/sim.py` both read it. Never hard-code a cost, chance, reward or target in a script. After changing it, run the simulator and report the win rates.
2. **Keep game logic separate from presentation.** `game/core/` holds pure GDScript classes (`RefCounted`, no nodes, no scene tree) that can be tested headless. Scenes observe that logic through signals and never own rules.
3. **Randomness is injectable.** Core classes take a `RandomNumberGenerator` so tests and replays can use a seed.
4. **Pixel-perfect only.** The viewport is 180×320 with integer scaling, nearest filtering and snapping to pixels. Keep every position integer, never rotate or scale sprites by fractions, and use no smooth shaders or blur.
5. **Palette-locked art.** Every colour must come from `assets/palettes/stellar_sun.gpl`. Warm colours are reserved for interactive or valuable things.
6. **Text is never baked into art.** Numbers and labels use the bitmap font through Label nodes on the UI layer.
7. **Don't grow systems early.** Add no new currencies, progression, inventories or special cases unless the user asks for them.
8. **Don't guess on design questions.** If a rule is ambiguous, ask, or pick the simplest option and flag it in your summary.

## Repo layout

```
project.godot            viewport 180x320, portrait, integer scale, nearest filter
game/
  config/balance.json    all tuning values (single source of truth)
  core/                  pure logic: balance.gd, run_state.gd, combos.gd, pack_opener.gd
  scenes/                main.tscn, sky, sun, launcher, hud (presentation only)
  fx/                    particles, bursts, Big Bang sequence
  ui/                    HUD, reward preview, debug overlay
assets/
  art/                   exported PNGs (flattened or frame strips)
  art/source/            .aseprite source files (committed)
  palettes/              stellar_sun.gpl / .hex
  fonts/                 bitmap fonts (5x7, 3x5)
  audio/
tests/                   GUT tests for game/core
tools/balance/sim.py     Monte Carlo balance check
tools/art/               concept-art generator (reference only)
docs/                    design.md, art-direction.md, concept/
```

## Code conventions

- GDScript 2 with **static typing everywhere** (`var dust: int`, `func link(stars: Array[Star]) -> ComboResult`).
- Files and folders are `snake_case`. Classes use `class_name PascalCase`. Constants are `UPPER_SNAKE`.
- Signals are named in the past tense for things that already happened (`pack_burst`, `combo_collected`, `big_bang_started`, `run_won`).
- Order inside a script: signals, enums, constants, exports, public vars, private vars (`_x`), `_ready` and other built-ins, public funcs, private funcs.
- Keep functions small and name them after game concepts from `docs/design.md` (pack, star, link, combo, dust, light, Big Bang).
- Scenes stay small and composable, and nodes talk upward through signals, not by reaching into their parents.
- Debug-only features are gated with `OS.is_debug_build()`.

## Commands

```bash
# Open / import check (headless)
godot --headless --path . --import
godot --headless --path . --quit

# Unit tests (GUT 9.7.1, committed in addons/gut from the bitwes/Gut release)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Balance check (Python 3, no dependencies)
python tools/balance/sim.py
python tools/balance/sim.py --set packs.red.cost=6 --runs 50000
```

If `godot` isn't on the PATH, say so. Don't claim that tests pass unless you ran them.

## Definition of done

- The feature matches `docs/design.md`, and any gap is stated.
- Core logic has GUT tests covering both the happy path and the edge cases (an invalid link uses nothing up; the loss check looks for remaining combos first).
- Any balance change comes with the simulator output.
- Any visual change keeps to the palette and pixel grid.
- Changes are committed in small commits with messages that describe the change (`feat: star linking by drag and tap`).

## Skills in this repo

Found in `.claude/skills/`:

- `godot-feature`: how to add a gameplay feature end to end.
- `balance-check`: how to change tuning safely and report it.
- `pixel-art`: how to make or review sprites to match the art direction.
- `game-feel`: feedback, juice and the Big Bang sequence.
