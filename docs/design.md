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
- When a link is collected, its dust floats up from it as "+n" until the dust lands on the counter (prototype, #59). There is no preview while tracing, and the Sun shows its light by its fill, not a number.

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

### Scorpio chapter chart (#62)

The game opens on Scorpio's chart: the constellation drawn as a pixel-art star chart over deep space. Its stars are split into five part stages, travelled from the tail: **Stinger** (Shaula, kappa, iota), **Tail** (theta, eta, zeta), **Body** (mu, epsilon, tau), **Heart** (Antares, sigma) and **Claws** (Dschubba, beta, pi). A crown point above the figure is the **final stage, the full Scorpio**.

- **Part stages are their own maps:** each is a small "false constellation" shaped like that part (a `StarMap`), with its own finished drawing. Winning one lights its stars and the strings between them on the chart. The **Stinger** is six stars running along the bottom of the sky, rising to the telson and hooking back into the sting. The first joint starts lit, leaving five to light (about 3.8 packs, all won).
- **The final** plays the full 14-star Scorpio (#61). While the parts are being built it's open for playtesting (`Chapter.FINAL_OPEN`); after that it opens once every part is won.
- **States:** a won part's stars are gold; the part to play next is warm, with a breathing ring round its point (its first star from the tail); locked parts are cool. Each part's point is its **main star**: a bigger 4-point star than the other chart stars and in its own tone, twinkling briefly on a beat of its own: icy blue while locked (the land ramp, unlike the chart's purple), white gold with diagonal glints once won. The point to play next is the biggest and flares brighter once a second, with longer, whiter arms and diagonal glints (solid steps, no fades). Numbers count the stages from the tail. The path is gold between won stars, warm through the part to play next, and a cool guide elsewhere. Tapping any star selects its part, and a comet travels there. Back from a win, the stage's point flashes as its stars light, then the comet travels to the stage it opened.
- **Living sky:** faint dust motes drift slowly up the milky way, about a third of the background stars twinkle (a brief M6 flash, each at its own time), and every 3 to 8 seconds a cool shooting star streaks down and sideways behind the chart.
- **Stage label:** no box: the selected stage's name sits between two thin rules tipped with little stars (warm when it can be played), with PLAY below in the game's button style (N0 fill, C2 border, C1 text).
- **Playing:** PLAY (REPLAY once won) opens the selected stage. Parts not built yet say "COMING SOON". In a stage, MAP (top-right, and on the end screen) goes back to the chart, and the end screen names the map ("STINGER COMPLETE").
- **Progression:** a stage counts as won as soon as the core decides it, and is saved on the device (`user://progress.json`). The chart's progress is separate from the constellation built inside a stage. No upgrades, currencies or buffs.
- **Built so far:** every part (the Stinger, the Tail, the Body, the Heart and the Claws) and the final.

### Tail stage: Orion the hunter (#64, a prototype)

The **Tail** is stage 2: six stars curling down the right of the sky and along the bottom (the first one starts lit, so five to light), with the top-left corner left to **Orion**, drawn there as a dim cool figure laid out like the real constellation (Meissa, Betelgeuse and Bellatrix, the slanted belt, Saiph and Rigel), with the Pi Orionis arc as his bow. He adds one twist to the stage:

- **The intro:** after launch 1's pack bursts, Orion marks one loose star in the sky: his figure and bow flash bright, a dotted ember sight line runs from his bow hand to the star, then an ember crosshair (unlike the warm selection ring and the landmarks' corner hints) closes on it and stays, jumping a pixel out and back once a second, while his bow stays a step brighter (drawn). The line above the launcher says "LINK IT NEXT OR ORION SHOOTS" (once per run).
- **The next link decides.** A successful link that uses the marked star saves it (it pays as usual). A successful link that leaves it behind pays as usual, then his figure lights up, his arrow flies to the marked star and breaks it: it pays nothing. Either way, once the link resolves, he marks a new loose star if any remain. The choice: build a combo that rescues the target, or sacrifice it for another combo. Launching packs to find a rescue is the cost.
- **Launches never fire.** A launch adds stars and keeps a standing mark; it marks a star only when none is marked (the intro, or after a Big Bang or a Sun clear emptied the sky). Invalid links, selecting, aiming, cancelled aims and purchases don't move Orion. Nothing marks before the intro launch. At most one mark at a time.
- **The bow warns before the release:** while the player traces a full, valid link that would leave the mark behind (and wouldn't clear the sky first), his figure and bow light up and the sight line holds from his bow to the target. Changing or cancelling the link stands the bow down. With two stars picked the target could still join, so the bow waits for the third.
- **Other ways a mark leaves:** a rekindled Sun clearing the sky, the completion, or a Big Bang take the mark with the star, and the arrow has nothing to hit. Orion marks loose sky stars only, never landmarks. There is no counterattack and no bonus.
- **Targets are random** (a seeded stream of their own, `run_seed ^ Orion.SEED_SALT`): some marks can't be saved (no combo for them in reach), and nothing quietly guarantees a rescue.
- **Win and loss:** after a link, the arrow flies before the check, so it can break the only combo left and lose the run; the new mark comes after the check (a mark never changes the sky), and only if the run goes on. A launch's check comes after its burst and mark.
- **Tuning:** `orion.first_mark_launch` (1) in `balance.json`. A map brings Orion (`StarMap.orion`), the balance says when he starts; without an `orion` block he never marks.
- **Simulator (`--map tail`):** the bots don't play around the mark; when a combo takes stars of its size they use the others first, so almost every combo sacrifices the target. Tail with Orion from launch 1: about 4.4 packs (blue only) / 4.2 (red when affordable), 99.7% / 99.9% won; `--orion-rescue` (the bots use the marked star first when a combo takes its size) gives 3.9 / 3.8, all won; from launch 2, 4.3 / 4.0; without Orion 3.8 / 3.7. The bots never launch to rescue or hold a combo back, so real play sits between the two.
- **Sound:** a low reject tone as he marks, a high whoosh as the arrow leaves, the burst sound as it hits (existing cues, pitched).

### Body stage: Orion's volley (#70, a prototype)

The **Body** is stage 3, unlocked by winning the Tail: nine stars, more connected than the Tail. A spine of five runs from the upper right down to the lower left, and its second and third stars each branch to a leg on either side, so two stars join four strings (eight strings in all). The spine's top star starts lit, so eight are left to light. Its finished drawing is the body's plated sides along the spine, a cross plate at each inner spine star, and a jointed claw past each leg star. Orion's figure keeps the top-left corner, and his twist here is the **volley**, which replaces the Tail's single mark:

- **The intro:** the stage opens with six random stars already in the sky, and after a beat Orion looses a volley that destroys them all, so the player sees what the volley does before playing. It pays nothing and doesn't count towards the next volley. Its stars come from the volley's own stream, so the packs and their layout are the same with or without it.
- **Every second successful link looses a volley.** The link resolves first (its combo pays, landmarks light, a full Sun rekindles and clears the sky). Then Orion's arrows destroy every loose sky star, for nothing. Landmarks and the constellation are never hit. An empty sky loses nothing. Either way the countdown starts again. (First playtest: half the sky every third link wasn't felt; now the whole sky every second link.)
- **What counts:** only successful links. Launches, purchases, aiming, invalid links and cancelled gestures don't advance the countdown, so launching stays the way to refill the sky. The link that completes the stage skips the volley (the run is won). A Sun rekindle clears the sky before the volley, so nothing is paid and destroyed twice.
- **No marks on the Body:** Orion doesn't mark single stars or fire the Tail's single shot here. The Claws (stage 5) are planned to combine every threat.
- **Countdown:** no number: a tiny constellation above Orion's head, one small star per link between volleys, joined by a faint dotted string. A counted link lights the next star (a white-hot heart with ember arms) and the string to it, hopping the row up two pixels and flashing white; on the last link the lit star glows between two embers (S4 / C3); when the volley fires every star lights, flashing and shaking a pixel side to side, stays ember while the arrows fly, then the row drops back in from above, unlit. His bow charges with it: at rest, then a fan of three arrows nocked and the bow blinking bright on the last link (with a longer interval, one arrow nocked in between). While the player traces a full link that would loose the volley, the bow holds steady and bright.
- **The volley:** the bow draws, then one arrow per victim leaves the bow hand, 0.05 s apart, and each victim bursts as its arrow lands, so every loss has a visible cause. The countdown resets once the last arrow lands.
- **Randomness:** victims come from their own seeded stream (`run_seed ^ Volley.SEED_SALT`), so packs and layout never shift.
- **Win and loss:** the volley comes before the loss check, so it can break the last combo and lose the run.
- **Tuning:** `volley.interval` (2), `volley.fraction` (1.0) and `volley.intro_stars` (6, optional) in `balance.json`. A map brings the volley (`StarMap.volley`); without a `volley` block there is none.
- **Simulator (`--map body`):** the bots don't play around the volley (they never hold a combo back or launch first to spread the loss). Body with the whole sky every second link: about 7.3 packs (blue only) / 6.3 (red when affordable), **97.3% / 73.8% won**; half the sky every third link (the first prototype), 6.4 / 5.7 (99.9% / 99.0%); without a volley, 6.1 / 5.4, all won. Buying red packs whenever affordable now often runs out of dust: the tuning is harsh, and the playtest decides whether to soften it. The bots link every combo at once, so the sky is usually thin when the volley lands; stars' positions and link reach aren't modelled, so real play can only do worse. A playtest decides whether half the sky is felt, and whether to try a full clear.
- **Sound:** the arrow's whoosh as the volley leaves, the burst sound as each star is hit (existing cues).

### Heart stage: Orion's hunting area (#71, a prototype)

The **Heart** is stage 4, unlocked by winning the Body: seven stars. A spine of five climbs from the lower left (towards the Body) through **Antares** (big, in the middle) and sigma to the upper right (towards the Claws), and Antares also branches up-left and down-right, so four strings meet at the heart (six strings). The lower-left star starts lit, so six are left to light. Its finished drawing is a heart round Antares, and a forked vessel out past each end star. Orion keeps the top-left corner, and his new twist here is the **hunting area**, which replaces the mark and the volley:

- **The intro:** like the Body's, the stage opens by playing the whole cycle once, so the player sees what the circle means and when it strikes. Three stars sit in the sky; after a beat Orion marks a circle round them: his figure flashes and a dotted ember sight line runs from his bow to it, then a dotted ember ring (S4: a midpoint circle, every third pixel, exactly symmetric) closes in with his marking tone, and the line above the launcher says "LAUNCH AND ORION SHOOTS HERE" (once per run). Then a demo planet of the loaded kind flies from the launcher into the circle and bursts; then his arrow strikes the circle and every star inside bursts, the demo's too. It pays nothing, uses no pack (the launcher keeps its planet) and leaves no circle. Its stars come from the hunt's own stream, so packs and layout are the same with or without it.
- **Marking:** after the first real launch's pack bursts, Orion marks a new circle the same way. The ring stays, jumping a pixel out and back once a second (the single mark's crosshair is four ticks; this is a ring). His bow stays a step brighter while it stands.
- **Every later launch strikes it.** The pack bursts first, then his arrow flies to the ring's centre and every loose sky star inside bursts as it lands, **the new pack's stars too**, for nothing. Then he marks a new circle. So before launching, the player links out the stars worth keeping from the ring, and aims the pack away from it.
- **What never strikes:** links (successful or not), purchases, aiming and cancelled gestures. They don't move the ring either; it waits for the next launch. Landmarks and the constellation are never hit. A Big Bang launch clears the sky first, so its strike finds nothing, and a new ring follows.
- **Placement:** a circle of `hunt.radius` px, wholly inside the sky and clear of Orion's figure, always **round a loose star** (playtest: a far-off circle wasn't a threat). He picks a loose star at random and the centre lands anywhere within the radius of it, so that star is always inside. A star no such circle can reach (tucked beside his figure, or deep in a far corner of the sky) is passed over for another; with none left (an empty sky, as after a Big Bang or in the intro) the circle goes anywhere. Drawn from its own seeded stream (`run_seed ^ Hunt.SEED_SALT`), so packs and layout never shift.
- **Win and loss:** the launch's loss check comes after the strike and the new ring, so a strike can break the last combo and lose the run. The stage is won by a link, never by a launch.
- **Tuning:** `hunt.radius` (40, about a fifth of the sky) and `hunt.intro_stars` (3, optional; 0 = no intro) in `balance.json`. A map brings the hunt (`StarMap.hunt`); without a `hunt` block there is none.
- **Simulator (`--map heart`):** the circle's prey (a random loose star when it's marked) is always taken if it's still there; where the other stars are isn't modelled, so each loose star (new ones too) is lost at the circle's share of the sky (19.6% at 40 px) on every launch from the second. The bots never link the prey out first nor aim away, so this is pessimistic. Blue only / red when affordable: about 6.2 / 5.3 packs, **52.2% / 52.5% won** (a circle anywhere: 89.9% / 89.1%; no hunt: 4.7 / 4.2, all won). Other radii with prey: 24 px, 83.7% / 83.4%; 32 px, 71.0% / 70.6%. The playtest decides the radius.
- **Sound:** the reject tone as he marks, the whoosh as the arrow leaves, the burst sound for each star it breaks (existing cues).

### Claws stage: all three of Orion's threats (#74, a prototype)

The **Claws** are stage 5, unlocked by winning the Heart: seven stars. A neck climbs from the lower left (towards the Heart) to **Dschubba** (the head, big), which forks into two arms: one up to **beta**, one down to **pi** (six strings, 31-37 px). The neck's first star starts lit, so six are left to light. Its finished drawing opens a pincer past each claw star, with a bulb on each arm. Orion keeps the top-left corner and brings **every threat at once**: the single mark (Tail), the volley (Body) and the hunting area (Heart), each with its own stage's tuning and its own seeded stream.

- **No intro.** Each threat was introduced on its own stage, so the Claws open on an empty sky (`StarMap.intros = false`). The volley's countdown shows above Orion from the start; the first launch's burst brings the ring, then the crosshair. The line above the launcher is the ring's ("LAUNCH AND ORION SHOOTS HERE"), once per run, as on the Heart; the mark's line isn't shown again.
- **After a successful link:** the combo pays (landmarks light; a full Sun rekindles and clears the sky), then the **single arrow** if the mark was left behind, then the **volley** on what's left, then the **loss check**, then a **new mark** if the run goes on. A link never strikes or moves the circle.
- **After a launch:** the pack bursts (a Big Bang clears the sky first), then the **circle's strike** (the new pack's stars too), then a **new circle** round a loose star, then a **new mark** if none stands, then the loss check. A launch never shoots the mark nor looses the volley, and never counts towards it.
- **A mark inside the circle:** the strike takes it like any star there (no reward). It wasn't "left behind": the next link's arrow can't shoot it, and Orion marks a new star on the same launch, from what the strike left. The circle doesn't avoid the mark, so a launch can be the way the mark is lost: link it out before launching to save it.
- **The volley and the circle stay independent:** the volley counts links, the circle launches, so they never fire on the same action. Rescuing the mark still counts for the volley; launches don't.
- **No star is hit or paid twice:** each leaves once, by a combo, an arrow, the volley, the strike, a Sun clear or a Big Bang. Landmarks are never hit, marked or struck.
- **Completion:** the link that lights the last landmark clears the sky for nothing and wins; no arrow, volley, mark or strike follows.
- **Tuning:** the shared blocks, unchanged: `orion.first_mark_launch` (1), `volley` (every 2 links, the whole sky; the Claws name the same block, `StarMap.volley`, so they can get their own later) and `hunt.radius` (40).
- **Simulator (`--map claws`):** the volley and the mark as on their stages; on a launch a standing mark is struck as the circle's prey, or else at the circle's share of the sky. It doesn't model where stars are, the reach, aiming away, or linking a threatened star out first, so it's pessimistic. Blue only / red when affordable: about 6.5 / 5.6 packs, **28.6% / 25.3% won**. With `--orion-rescue` 35.5% / 31.6%. Radius 32: 42.0% / 37.8%; radius 24: 54.4% / 49.0%. The volley's tuning hardly moves it (interval 3: 30.8% / 27.8%; fraction 0.5: 29.1% / 25.5%): the bots link every combo at once, so its sky is mostly empty. The playtest decides keep, revise or abandon, and which threat to soften.
- **Readability:** the three cues sit apart: the countdown above Orion's head, the crosshair on a star, the dotted ring in the open sky (always clear of his figure). Whether that's too busy is for the playtest.

### Scorpio constellation (prototype, #40)

An experiment to learn whether building a constellation makes the loop more fun and more challenging. It's on for playtesting (`scorpio.enabled` in `balance.json`); set it to `false` to play the plain stage.

- **Objective:** the constellation, not the Sun. Lighting every landmark wins.
- **The map:** the 14 stars of Scorpius's usual figure (#61) are the landmarks, spread out to at least 24 px apart so each can be picked, keeping the shape: the claw arc up on the right (beta, Dschubba, pi) branching from the head, sigma and Antares (the heart) to its left, a body falling steeply, and a tail that curls left along the bottom and hooks back up to the stinger (Shaula). Sizes follow the stars' brightness: Antares, Shaula and theta are big; Dschubba, beta, epsilon and kappa medium; the rest small. 13 strings join them (the head branches three ways). The finished drawing opens a pincer at each claw star. Each is small, medium or big, drawn with the same star shape as the sky stars, so its size reads the same way. Unlit, each size has its own cool tint: small pink, medium lavender, big blue. Lit, every landmark is the same gold, so gold only ever means lit. Strings join neighbouring landmarks: dotted while waiting, lit when both ends are lit, with a small glint running along them. The claw arc (three landmarks, two strings) starts lit, so **11 landmarks and 11 strings** are left to build. An unlit landmark, which can be picked, also shows four small corner brackets in dim C5/C4 that slowly swap: a quiet cue that background stars and lit landmarks never have.
- **Lighting a landmark:** an unlit landmark stands in for a star in a combo. Link it with two sky stars that make a valid combo with its size (tap or drag, any order). The combo pays as usual, the two sky stars are used up, and the landmark stays and lights up. When both ends of a string are lit, the string forms.
- **Reach:** each step of a link, from one star to the next in the order they're picked, is at most `scorpio.max_link_distance` (56 px) long. The limit is per step, not for the whole link, so a link can still span two reaches, but not the whole map: packs have to be launched near the landmark to light. While tracing, a dotted M5 ring around the last star picked shows the reach, and the line to the finger turns into sparse dots past it. A star out of reach doesn't join: its step shakes in ember with the reject buzz, and the link so far stays. A link out of reach uses nothing up, and the loss check only counts combos that can be linked within reach. 56 px keeps every burst's own three stars linkable, and a landmark reachable when a pack is aimed within about 60 px of it.
- **One landmark per combo:** picking a second landmark in the same link is refused at once, with the red shake and buzz of a wrong link, and the link is dropped. A lit landmark can't be picked again.
- **Previews:** while tracing, the picked landmark shows gold, and the strings the link would form are dashed.
- **A full Sun:** it fills at `scorpio.sun_target` (75 light, against 100 on the plain stage) and doesn't win here. It plays its ignition, then its light leaves as a sunbeam, a small comet flying from the Sun to the landmark it lights (the first unlit one next to a lit one), while the Sun still shines. The landmark lights as the beam lands, with a flash, a spreading ring and a burst's sparks; then every star left in the sky bursts, bottom to top, each paying `sun_dust_per_star` (1) dust that flies to the counter as it bursts, leaving a clean sky; then the Sun is back at 0 light. Light above the target is lost. The combo that lights the last landmark doesn't also rekindle the Sun. If the Sun lights the last landmark, that's the completion too, and it plays as usual.
- **Completion:** every sky star still on screen bursts, one after another from the bottom of the sky to the top, with a pack burst's sparks and sound; they pay nothing (the run is won), and the sky is left clean. Then, once every dust and light payout has landed, the constellation plays itself: string by string from the bottom of the sky to the top, each flashing and vibrating as it sounds the next note of a rising pentatonic tune. Then a drawing of the scorpion (pincers, body, legs, tail, stinger) is traced around the lit stars and stays. The Sun doesn't ignite for this win. The end screen says SCORPIO COMPLETE and the strings formed.
- **Loss:** the usual check (no packs, no dust for one, no combo), where a combo may use one unlit landmark.
- **Big Bang:** clears the sky stars as usual; lit landmarks stay lit.

Simulator (it doesn't model where stars are, so it ignores the reach): with the full 14-star Scorpius (11 landmarks to light), the Sun full at 75 and a rekindle clearing the sky, it's about 7.7 packs (blue only) or 6.8 (red when affordable), all won. With the earlier 8-landmark map (6 to light) it was 4.4 / 4.2, all won (4.5 / 4.2 at 50) (it was 3.9 / 3.8 when the rekindle paid 1 dust per sky star and left them in the sky); the rest of this paragraph is for the Sun at 100. With combos that light a landmark paying as usual, Scorpio is won in every run, in about 4.5 packs (blue only) or 4.1 (red when affordable), against about 88% / 87% in 8 / 6 packs on the plain stage. It's much easier; the playtest decides whether that's a problem. `--lighting-pays` shows what-ifs: half the dust and no light gives about 72%, dust only about 100%, light only about 17%, nothing about 3%. A one-off bot on the real core with real burst geometry (aiming each pack at the next landmark to light, up to 12 or 40 px off) also won every run: 4.3 packs with no reach and the Sun at 100; 4.1–4.2 with the 56 px reach and the Sun at 50 (4.3–4.4 at 48 px). The reach costs about 0.3 packs and the smaller Sun saves about 0.5, so Scorpio stays much easier than the plain stage.

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
