# Dust In Space: Game Design

Living design reference. Numbers live in `game/config/balance.json`, not here.

## Pillars

1. **Keep the slot-machine feelings, not the slot machine.** The game should deliver anticipation, randomness, small interventions and satisfying payouts without spinning reels.
2. **Tactile and frequent.** Every few seconds the player does something small (launch, link, collect) and the sky reacts visibly.
3. **One central loop before any systems.** No extra currencies, progression layers or special cases until the core loop is fun. This is the main lesson from the previous project.

## Core loop: Restore the Sun (first playable)

The player wins by giving the Sun its light back before running out of packs and dust. The Sun visibly brightens as the run progresses.

1. Start with packs from the balance file (2 blue, 1 red), 0 dust and a dark Sun.
2. Pull back a planet-shaped pack in the slingshot and release it into the sky.
3. The pack bursts where it lands, and its stars scatter and settle within the playable sky.
4. Link exactly 3 stars into a valid combination by dragging through them, or by tapping them one at a time.
5. A valid link lights up, then dissolves: dust particles fly to the dust counter and light particles fly into the Sun.
6. Spend dust on more packs. Unused stars stay in the sky.

### Stars

There are three sizes: **small, medium and big**. Size and silhouette are the only way to tell them apart; stars show no numbers or pips.

### Combinations

| Combination | Meaning |
|---|---|
| 3 small / 3 medium / 3 big | Triples: mostly dust, to keep buying packs |
| 1 small + 1 medium + 1 big, in **any order** | Sequence: a lot of light, the main way to restore the Sun |

- An invalid link cancels and uses nothing up.
- Distance and crossings are ignored for now; spatial rules may come later.
- While a link is being drawn, show a small preview of its reward.

### Packs

| | Blue | Red |
|---|---|---|
| Role | Cheap and sustaining; favours small stars | Expensive; favours big stars; 4 stars; slightly higher Big Bang chance |

- Each star is drawn independently from the pack's weights.
- The slingshot controls **where** a pack bursts, never its contents.
- Buying a pack loads it into the launcher. The player chooses which owned pack to load.

### Legendary opening: Big Bang

- Rolled once per pack, before any stars are drawn.
- The opening starts out looking normal. Then the pack ruptures, every star in the sky collapses inward, there is a short silent pause, and the Big Bang goes off.
- It clears all stars and awards base dust plus a bonus for each star cleared. It gives no light, and light already earned is kept.
- A development-only trigger forces it (key **B** in debug builds).

### Win and loss

- **Win:** Sun light reaches the target. The Sun fully ignites and lights up the sky.
- **Loss:** the player has no packs left, not enough dust to buy one, **and** no valid combination remains in the sky. Always check for remaining combinations before ending the run.

## Balance snapshot (from `tools/balance/sim.py`)

| Strategy | Win % | Packs to win |
|---|---|---|
| Blue packs only | ~88% | ~8 |
| Red whenever affordable | ~87% | ~6 |

Both strategies should stay viable: red is faster, blue is safer. Rerun the simulator after every change to `balance.json`.

## Later, not now

- Run buffs, revealed with the exploding-star opening (hold to compress, release to explode, dust forms the buffs), plus a Big Bang reveal for legendaries.
- Chain reactions: a completed link makes a star explode, its dust forms a planet, and the planet's effect helps trigger the next link.
- Spatial link rules and longer combinations.
- Sound design, including the sound cutting out before the Big Bang.

## Concept references

- `docs/concept/html_prototype.html`: the playable rules prototype (tap to launch).
- `docs/concept/gameplay_mockup_4x.png`: the target look for the gameplay screen.
- `docs/art-direction.md`: the visual rules.
