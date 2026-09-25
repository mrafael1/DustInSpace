---
name: godot-feature
description: Add or change a gameplay feature in Dust In Space (Godot 4) end to end, from the logic in game/core through tests to the scenes and feedback. Use for any new mechanic, rule change or gameplay bug fix.
---

# Adding a gameplay feature

## 1. Pin down the rule
- Find the rule in `docs/design.md`. If it isn't there or is ambiguous, ask the user before coding, or implement the simplest version and flag it.
- Write the rule as 2–4 testable sentences, for example: "An invalid link consumes nothing and emits `link_rejected`."

## 2. Logic first, in `game/core/`
- Use pure `RefCounted` classes with static typing, and no `Node`, scene tree, timers or rendering.
- Read every number from `Balance`, which loads `game/config/balance.json`. Hard-code nothing.
- Take a `RandomNumberGenerator` as a parameter wherever randomness is involved.
- Expose results as return values or signals, e.g. `combo_collected(kind, dust, light)`, `pack_burst(pack, stars)`, `big_bang_started(cleared)`.

Core responsibilities:
| Class | Owns |
|---|---|
| `Balance` | Loading and validating balance.json |
| `Combos` | Evaluating 3 star sizes into triple / sequence / invalid (a sequence is any order) |
| `PackOpener` | Rolling the Big Bang once per pack, then drawing each star independently from weights |
| `RunState` | Dust, light, owned packs, stars in the sky, purchase, link, win/loss checks |

## 3. Test it with GUT in `tests/`
- Name files `test_<class>.gd`. Use a seeded RNG, and cover the edge cases:
  - An invalid link consumes nothing.
  - The loss check looks for remaining combos before ending the run.
  - A Big Bang with an empty sky still pays base dust.
  - Launch positions near the edge keep every star inside the sky.
- Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

## 4. Presentation in `game/scenes/`, `game/fx/` and `game/ui/`
- Scenes call core methods and react to its signals. They never decide rules.
- Positions are integers on the 180×320 grid, and sprites keep their original size.
- Add the feedback using the `game-feel` skill, and make the art with the `pixel-art` skill.

## 5. Finish
- If any balance value was touched, run `python tools/balance/sim.py` and paste the table.
- Commit in small steps with messages like `feat:` / `fix:` / `test:` / `art:` / `tune:`.
- Summarise what the player can now do, what isn't done, and any design question you had to guess.
