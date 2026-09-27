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
- In the HUD, tapping a pack's icon **loads** it if the player owns one (free, never a purchase), or **buys** it if they own none and can afford it.
- Under each icon, a **buy button** ("+◆cost") always buys one more, however many are owned. It's drawn as a small plate with a "+", so it reads as a button without being explained. Its border is warm when the dust is there and cool when it isn't. It lightens while pressed, flashes when the buy plays, and turns red with a refused tap (the icon nudges too). A buy charges the cost once, adds one pack and loads it.
- The icon is lit and spinning while at least one is owned, and grey and still at ×0, even when the dust would buy one (tapping it then buys the first; the buy button shows the dust is there). A lit icon hops now and then while the dust can buy another.
- Tap targets are 44 pt (22 native px) each: the icon's reaches up into the land strip, the button's runs to the bottom of the screen.

### Legendary opening: Big Bang

- Rolled once per pack, before any stars are drawn.
- The opening starts out looking normal. Then the pack ruptures, every star in the sky collapses inward, there is a short silent pause, and the Big Bang goes off.
- It clears all stars and awards base dust plus a bonus for each star cleared. It gives no light, and light already earned is kept.
- A development-only trigger forces it (key **B** in debug builds).

### Win and loss

- **Win:** Sun light reaches the target. The Sun fully ignites and lights up the sky.
- **Loss:** the player has no packs left, not enough dust to buy one, **and** no valid combination remains in the sky. Always check for remaining combinations before ending the run.

### Scorpio constellation (prototype, #40)

An experiment to learn whether building in space makes the loop more fun and more challenging. It's on for playtesting (`scorpio.enabled` in `balance.json`); set it to `false` to play the plain stage. All numbers are in the `scorpio` block.

- **Objective:** on the Scorpio map the goal is the constellation, not the Sun. Building its last gap wins the run. Combos still fill the Sun with light, but a full Sun doesn't win there; it will give a bonus, still to be designed.
- **The map:** 8 fixed landmark stars trace Scorpio, head to stinger. They're bigger and brighter than the background stars. Most of the outline is given (solid N6). **4 gaps** are brighter dotted lines: those are what the player builds.
- **Aiming:** a burst scatters its stars on a ring 18–30 px out from the burst point and leaves the centre empty, so on this map the slingshot's reticle also shows that landing ring. Lay the ring across a gap. Aiming at the gap itself drops a star in it about 2% of the time; aiming 16–22 px beside it, about 65% per pack.
- **Building a gap:** link the two landmarks at its ends with one sky star that sits in the gap, using the usual link gesture (tap or drag, any order). A star counts if it's within `segment_reach` px of the line between the landmarks, so a near miss works. The star is used up and stays as the gap's lit bridge; it pays `segment_dust`. The choice: combine that star now for dust and light, or keep it for the constellation.
- **Previews:** stars sitting in an open gap carry faint corner ticks. Picking a landmark lights it and marks the stars that could bridge its gaps. Picking a star too shows the gap it would fill. Three picks that build nothing show the no-combo cross, and nothing is used up.
- **Sting:** every valid combo's last-traced star stings the nearest other star within `sting_reach` px (ties: the oldest) and collects it for `sting_dust`. While tracing a valid combo, a dashed line previews the target; with no target, a dotted circle shows the reach. Landmarks and bridges are never stung.
- **Completion:** building the last gap sends a pulse along the whole outline, then the run is won (the Sun ignites and the end screen says SCORPIO COMPLETE with the gaps built).
- **Loss:** the usual check (no packs, no dust for one, no combo), and also no sky star left in an open gap.
- **Big Bang:** clears the sky stars as usual; landmarks and built gaps stay.

Simulator (no geometry: it assumes a 30% sting hit and a chance per star of landing in a gap; the bots build with gap stars their combos don't need): at 25% per star, Scorpio wins about 96% (blue only) and 74% (red when affordable); at 15%, about 80% / 40%; at 35%, 99% / 91%. The plain stage is about 88% / 87%. Aim is what the playtest measures.

### Sound

Sound effects only, no music. Soft chiptune: square and triangle voices, bell-like chimes for payouts. The sounds are synthesized by `tools/audio/build_sfx.py` into `assets/audio/`.

- Every interaction answers: pack load, buy and refused tap; a small two-note chime when a pack becomes buyable, together with its flash; slingshot pull (a creak per gem as it grows), cancel and launch; the tremble, then the burst; each star in a link rings up a triad; the link collects or buzzes.
- Payouts sound when the particles land, not when they're earned. Dust ticks climb a semitone per landing, like a slot count-up. Voice limits keep a stream of particles from piling up.
- Big Bang: it opens with the normal burst sound. The collapse draws in, then everything goes silent from the implosion to the bang, which is the loudest sound in the game.
- Sun ignition, then a win jingle or a falling loss phrase when the end screen appears, and a chime on restart. A restart cuts every sound and lifts the silence.
- The speaker in the top-left corner cycles on, low and mute, and is remembered between sessions. Muted play keeps every visual.

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
- Music.

## Concept references

- `docs/concept/html_prototype.html`: the playable rules prototype (tap to launch).
- `docs/concept/gameplay_mockup_4x.png`: the target look for the gameplay screen.
- `docs/art-direction.md`: the visual rules.
