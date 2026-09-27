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

An experiment to learn whether building a constellation makes the loop more fun and more challenging. It's on for playtesting (`scorpio.enabled` in `balance.json`); set it to `false` to play the plain stage.

- **Objective:** the constellation, not the Sun. Lighting every landmark wins.
- **The map:** 8 fixed landmark stars trace Scorpio, head to stinger. Each is small, medium or big, drawn with the same star art as the sky stars, so its size reads the same way: cool while unlit, gold once lit. Strings join neighbouring landmarks: dotted while waiting, lit when both ends are lit, with a small glint running along them. The head's string starts lit, so **6 strings** are left to build. An unlit landmark, which can be picked, also shows four small corner brackets in dim C5/C4 that slowly swap: a quiet cue that background stars and lit landmarks never have.
- **Lighting a landmark:** an unlit landmark stands in for a star in a combo. Link it with two sky stars that make a valid combo with its size (tap or drag, any order). The combo pays as usual, the two sky stars are used up, and the landmark stays and lights up. When both ends of a string are lit, the string forms.
- **Reach:** each step of a link, from one star to the next in the order they're picked, is at most `scorpio.max_link_distance` (56 px) long. The limit is per step, not for the whole link, so a link can still span two reaches, but not the whole map: packs have to be launched near the landmark to light. While tracing, a dotted M5 ring around the last star picked shows the reach, and the line to the finger turns into sparse dots past it. A star out of reach doesn't join: its step shakes in ember with the reject buzz, and the link so far stays. A link out of reach uses nothing up, and the loss check only counts combos that can be linked within reach. 56 px keeps every burst's own three stars linkable, and a landmark reachable when a pack is aimed within about 60 px of it.
- **One landmark per combo:** picking a second landmark in the same link is refused at once, with the red shake and buzz of a wrong link, and the link is dropped. A lit landmark can't be picked again.
- **Previews:** while tracing, the picked landmark shows gold, the strings the link would form are dashed, and the reward plaque shows the combo as usual.
- **A full Sun:** it fills at `scorpio.sun_target` (50 light, against 100 on the plain stage) and doesn't win here. It plays its ignition, comes back at 0 light, lights one landmark (the first unlit one next to a lit one), and pays `sun_dust_per_star` dust for every sky star on screen: each of those stars flares and throws a ring in turn, and its dust flies to the counter. Light above the target is lost. The combo that lights the last landmark doesn't also rekindle the Sun.
- **Completion:** once every dust and light payout has landed, the constellation plays itself: string by string from the bottom of the sky to the top, each flashing and vibrating as it sounds the next note of a rising pentatonic tune. Then a drawing of the scorpion (pincers, body, legs, tail, stinger) is traced around the lit stars and stays. The Sun doesn't ignite for this win. The end screen says SCORPIO COMPLETE and the strings formed.
- **Loss:** the usual check (no packs, no dust for one, no combo), where a combo may use one unlit landmark.
- **Big Bang:** clears the sky stars as usual; lit landmarks stay lit.

Simulator (it doesn't model where stars are, so it ignores the reach): with the Sun full at 50 it's about 3.9 packs (blue only) or 3.8 (red when affordable); the rest of this paragraph is for the Sun at 100. With combos that light a landmark paying as usual, Scorpio is won in every run, in about 4.5 packs (blue only) or 4.1 (red when affordable), against about 88% / 87% in 8 / 6 packs on the plain stage. It's much easier; the playtest decides whether that's a problem. `--lighting-pays` shows what-ifs: half the dust and no light gives about 72%, dust only about 100%, light only about 17%, nothing about 3%. A one-off bot on the real core with real burst geometry (aiming each pack at the next landmark to light, up to 12 or 40 px off) also won every run: 4.3 packs with no reach and the Sun at 100; 4.1–4.2 with the 56 px reach and the Sun at 50 (4.3–4.4 at 48 px). The reach costs about 0.3 packs and the smaller Sun saves about 0.5, so Scorpio stays much easier than the plain stage.

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
