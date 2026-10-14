# Chapters 4 to 6: ideas to test

**Status: Virgo is built with the scythe and bound sheaves (step D: kept, revised), 2026-10-08.** **Sagittarius's black hole is kept (step D, 2026-10-12); stages 1-4 are built (the Arrow, the Bow, the Body with the hungry hole, the Legs with twin holes that merge in a Big Bang: [design.md](design.md), chapter 5). Stage 5, the Head, is built too: the hole drinks half of each link's light into a gauge and bangs when it's full. The final is built: twin holes merge in a Big Bang, then the merged hole grows and drinks the light; winning ends in the Big Bang. Sagittarius is complete but for its paintings.** All six stages are in [design.md](design.md) (chapter 4); paintings to come. The harvest that paid dust failed its stakes gate; bound sheaves with a tighter economy passed it (step C, below). The user chose three mechanics from a shortlist: **Virgo, the harvest**; **Sagittarius, the black hole**; **Pisces, the cord**. Chapter 6 is a chapter like the others (its own mechanic; the campaign can keep growing after it), not a finale. Nothing here is committed: every rule below is a proposal that has to pass its gates, as Aquarius's current and Leo's heat did ([chapter_2_3_plan.md](chapter_2_3_plan.md)). [design.md](design.md) remains the rules reference. **Pisces's cords: stages 1-2 are built (the Circlet with link cords; the West Cord with the fish's cord from the start), 2026-10-14; the user chose to build on before the stakes gate passed, so the later stages still need a lever that makes careless play lose ([design.md](design.md), chapter 6).**

## Direction and stakes

Each chapter puts the pressure somewhere new:

| Chapter | Pressure on | The decision |
|---|---|---|
| 1 Scorpio | **who** takes your stars (Orion, an enemy) | protect the stars a landmark needs |
| 2 Aquarius | **where** they are (the current, the drain) | link a cluster now, or let the flow bring a better one and risk it |
| 3 Leo | **what** they are (the heat, sizes) | link now, or let it ripen and risk the burn |
| 4 Virgo | **when** they pay (the harvest) | link for the constellation, or leave stars standing for the harvest's pay |
| 5 Sagittarius | **where** they fall (the black hole) | link before the pull takes them, or aim into orbit and wait |
| 6 Pisces | **how** you link (the cords) | which link first, since every link walls off the sky |

Rules carried over from chapters 2 and 3:

- **Each chapter has its own mechanic with a real loss.** Orion stays chapter 1's; none of his threats is reskinned.
- **Linking everything first must not be the safe answer.** Leo's lesson: on its part stages every heat rule only destroyed stars the player hadn't used, so linking at once never lost and only hoarding did. Aquarius's drain worked because a waiting pair drifted away while the player launched for its third. Each concept below says why linking first doesn't save you; the bots have to confirm it.
- Keep the three sizes, three-star combos, one landmark per link, the packs' roles, dust, light and the constellation objective. No new currency, upgrade or inventory.
- A mechanic that only helps has no stakes. A higher win rate is not a better mechanic.
- Readability is an early pass/fail: the busiest aiming state must read in one look at 180x320 on a phone.

## The sky: the zodiac becomes a ring

The chapters sit at their signs on one sky, and forward (the next chapter) is to the right. Scorpio, Aquarius and Leo already run left to right. Virgo is the sign after Leo, but Sagittarius and Pisces lie back to the left of it. So the sky closes into a **ring**: after Leo come Virgo and Libra, then Scorpio again, and the campaign goes on east round it on a second lap.

- Chapter 4, **Virgo**: one sign after Leo.
- Chapter 5, **Sagittarius**: three signs on (Libra, then Scorpio passes, then Sagittarius).
- Chapter 6, **Pisces**: three more (Capricornus, Aquarius passes, Pisces).

Voyages stay at their pace (0.6 s plus 0.28 s a sign: 0.88 s, then 1.44 s twice). Passing your own earlier chapters on the way is the reward of the ring.

**Built (2026-10-12):** Libra as a passing figure, the ring (world x repeats every 12 signs, `ChapterSelect.CHAPTER_LAPS`), chapter figures as passing ones on other laps, and background stars that wrap. Ophiuchus is left out. The original note: Virgo and Libra as passing figures; the ring (world x wraps every 12 signs; each chapter's place is its sign plus its lap); and the **chapters' own constellations drawn as passing figures**. Today a voyage from Scorpio to Leo crosses Aquarius's place empty, because chapter figures aren't drawn as passing ones. The background stars wrap with the ring.

## Chapter 4: Virgo, the harvest

Virgo is the maiden holding the ear of wheat, Spica, at the end of summer, when the Sun has burned through Leo. Her chapter answers Leo's open question, "nothing rewards waiting", with the oldest push-your-luck there is: the harvest.

### Proposed rule (step A, not committed)

- **A harvest clock:** every `H` launches (balance.json, first guess 3), once the launch has resolved, the **harvest** comes. The sky shows how many launches are left (a sheaf counter, or the wheat ripening from green to gold).
- **The harvest pays and reaps:** every loose star still in the sky pays its dust (a first guess: small 1, medium 2, big 3; balance.json), flying to the counter as a link's does, and is **reaped**, gone. No light: the Sun and the constellation are only fed by links.
- Landmarks never change. Lit constellation stars stay. Buying, linking and refused actions don't advance the clock.
- **The trade:** a star links for light and the constellation, or stands for the harvest's dust. A star waiting for its link's third is reaped too.

### Why it should make decisions

- **Waiting finally pays.** On Leo, holding stars only risked them. Here, stars left standing at the harvest are worth dust, and dust buys the packs the stage needs. The pay per star must beat its share of a link's dust (a big triple pays 6 dust, 2 a star; a reaped big would pay 3), so leaving stars standing is a real economic choice, not a mistake.
- **Linking first costs you the harvest.** A player who links everything at once never loses stars, but goes into each harvest with an empty field and runs short of dust and packs. That's the stake for link-first: an economy, not a destroyed star.
- **Hoarding costs you the constellation.** A pair waiting for its third when the harvest comes is reaped, and the landmark waits another cycle.
- **The clock is a slot reel.** The launch just before the harvest is the anticipation beat: one more burst, then the payout rolls in, star by star, like a jackpot.

Risk to check first: whether one policy dominates (always reap, or always link). The bots decide; the pay values are the main dial.

### One conflict to show (paper)

One launch before the harvest. A medium landmark needs two mediums; the sky holds two mediums (A, B) in reach of it, a big (C) and two smalls.

- **Link now** (A, B with the landmark): the landmark lights. The harvest reaps C and the smalls for 5 dust.
- **Launch first:** the burst might bring the third star for another combo, and the harvest pays for everything standing, A and B included (4 more dust). But the landmark waits a whole cycle.

Which is right depends on the dust, the packs left and how close the constellation is.

### Readability

- The clock: a small sheaf of wheat counter by the dust (or the Sun's bar) with one ear per launch left, ripening to gold on the last.
- While aiming on the last launch before the harvest, each loose star shows its harvest pay (a small "+n" in D0 over it, the floating payout's look) so the trade reads in one look.
- The harvest itself: a sweep of gold across the sky (a scythe's arc, solid steps), each star bursting into dust as it's reaped.

### Possible stage ladder

Teach the gain first, then the cost, then twists:

1. The harvest pays, and the constellation is easy: learn that standing stars are worth dust.
2. A tighter clock or a dearer constellation: the harvest takes waiting pairs.
3. **The swath:** only a band of the sky is reaped, moving each harvest.
4. **Gleaning:** a reaped big leaves a small behind (a seed).
5. **The harvest moon:** one harvest in the cycle pays double.
6. Final, the whole Virgo: to decide once 1-5 are measured.

### Payout spike

The harvest is the chapter's spike, on a clock the player can see coming. A rare **golden harvest** (all reaped stars pay double) is the slot-machine jackpot on top.

**Status (2026-10-09, #149):** the paying harvest failed its stakes gate (step C below), so the scythe reaps for nothing and the golden harvest has nothing to double: it needs rethinking (paying for something that rewards the binding, not for standing stars, so the failed farm economy doesn't come back). Open, with the other chapters' spikes ([design.md](design.md), Later, not now).

### Step C: the harvest fails the stakes gate (2026-10-08)

Built in the core, off by default (`StarHarvest`, the `harvest` block in balance.json, `StarMap.harvest`), and measured with bots (`tools/harvest/playtest.gd`) on Leo's Haunch layout with its heat off: 200-300 paired seeds, a harvest every 3 launches. Policies: link at once; launch every pack first (hoard); link only for the constellation; glean (let the field stand and link for the constellation just before the harvest); sheaf (leave same-size triples standing for the harvest).

| Rule | Link at once | Hoard | Best of the rest |
|---|---|---|---|
| Harvest dust on top of link dust, pay 1/2/3 | 100% | 100% | 100% |
| Links pay light only, the harvest is the dust: pay 1/2/3 | 20% | 87% | 36% |
| Same, pay 1/1/2 | 11% | 28% | 15% |
| Same, every 2, pay 1/1/2 | 11% | 14% | 12% |
| Sheaves x2 (a standing same-size triple in reach pays double its combo's dust, the rest nothing), links keep their dust | 100% | 100% | 100% |
| Sheaves x2, links pay light only | 3.5% | 70.5% | 20% |
| Sheaves x3, links pay light only | 3.5% | 90% | 22.5% |
| Pay 1/2/3 capped at 7 a harvest, links pay light only | 18.5% | 0% | 34% |
| Same, capped at 4 | 12% | 0% | 16% |

What it shows:

- **While links keep their dust, the harvest only takes stars nobody used**, so linking at once is always safe. That is Leo's structural flaw again: a rule that only removes unused stars punishes hoarding, never linking.
- **When the harvest is the dust, it's a farm or a tax.** Reaped stars worth more than their pack make launch-and-reap the dominant answer (red packs, mostly bigs, are the engine). Worth less, or capped, and nobody wins. No pay table, clock or cap left room for judgement to beat both extremes, and the bot that played in between (glean) did worse than either.
- The Sun's rekindle already clears the sky for dust, which undercuts the harvest's role.

The rule changes also showed the gate the next mechanic must pass up front: **it has to act on the links themselves** (their order, place or cost), not only on stars left standing.

### Revisions that act on links (2026-10-08)

Both reap the standing stars for nothing at the harvest (pay 0) and keep links' dust. Bots as above, plus *ripe* (waits for ripe links until the harvest is next) and *bound* / *bound-strict* (light constellation stars next to the lit figure first; strict never lights one that isn't while the harvest is next). 200 paired seeds.

- **Ripe links** (a link whose loose stars have all stood through a launch pays double light): fails. Linking at once still wins every run, in fewer packs than waiting for ripe links (Haunch 4.2 against 5.06, whole Leo 6.62 against 9.38). Hoarding loses (1-2% won) only because the scythe reaps for nothing.
- **Bound sheaves** (at each harvest, a constellation star lit since the last one goes dark unless lit strings join it to the figure lit before): acts on the order of links and rewards skill, on branching figures. Every policy still wins (links keep paying dust, so slowing down never starves), but careless linking costs packs:

| Layout, clock | No harvest | Link at once | Bound | Bound-strict | Hoard |
|---|---|---|---|---|---|
| Leo's Haunch (a chain), 3 | 4.18 | 4.22 (0.09 put out) | 4.22 | | 1% won |
| Whole Leo, 3 | 6.57 | 10.23 (8.6 put out) | 8.58 (5.3) | 8.67 (5.1) | 2% won |
| Whole Leo, 2 | 6.57 | 12.47 (14.0) | 8.19 (4.1) | 8.52 (3.1) | |
| Whole Aquarius, 2 | 6.48 | 7.24 (1.5) | 6.96 (0.7) | 7.03 (0.1) | |
| Whole Scorpio, 2 | 6.00 | 6.83 (2.4) | 6.41 (1.2) | 6.53 (0.3) | |

Packs per win (constellation stars put out a run). Bound sheaves is the candidate to keep: a figure that branches and a short clock make it bite. Turning its pack cost into lost runs needs a tighter economy on Virgo's stages, still to measure.

### Step C passes with bound sheaves and a tighter economy (2026-10-08)

Links pay a percent of their dust under the harvest (`harvest.link_dust_percent`, rounded down: 90% is one dust less a link; since #149 it's `harvest.link_dust_cut`: 1, the same payouts). Whole Leo (12 to light, branching), reaping for nothing, 200 paired seeds, won %:

| Clock, link dust | Careless (link at once) | Hoard | Bound (next to the figure first) | Bound-strict |
|---|---|---|---|---|
| 2, 90% | 37 | 20 | **80.5** | 62.5 |
| 2, 80% | 30.5 | 14 | **78** | 55 |
| 2, 70% | 26 | 6 | **72** | 46 |
| 2, 60% | 0 | 0 | 1 | 0.5 |
| 3, 90% | 55 | 0 | **80** | 75.5 |
| 3, 80% | 51 | 0 | **74** | 70.5 |
| 3, 70% | 42.5 | 0 | **66.5** | 60.5 |
| 2, 90%, **no binding** (control) | 85 | 50.5 | 85.5 | |

The binding makes the stakes: without it careless linking wins 85%; with it, 37%. Both extremes lose and reading the figure wins, which is the gate. Below about 60% the economy breaks for everyone.

On part-sized layouts (5-7 to light) at clock 2 and 90%, it barely bites: careless 94-100%, bound 95-100%, 0.5-1.2 constellation stars put out a run (Leo's Head and Mane, Aquarius's Body, Scorpio's Body and Heart). Virgo's part stages have to be drawn to tempt careless linking (far landmarks easy to light before the near ones, several arms from the lit star), and the final carries the full stake, as Leo's did.

## Chapter 5: Sagittarius, the black hole

Sagittarius, the archer, aims at the heart of the galaxy, where a black hole sits. Its chapter is gravity: the pull you liked in the Big Bang's collapse (stars slowing and reddening near the hole, a lensed arc), made into a rule.

### Proposed rule (concept)

- A **black hole** at a fixed point in the sky. After each launch, every loose star falls toward it a step that grows the closer it is (a first guess: `pull / distance`, clamped; balance.json). A star that crosses the **event horizon** (a radius) is swallowed, lost for nothing.
- Landmarks are fixed and don't fall. Stars flow round what's in their way, as the current's do (reuse `StarCurrent`'s path rule and its preview).
- **Why linking first doesn't save you:** a waiting pair falls further every launch, faster as it nears the hole. Aquarius's drain worked the same way.
- **The skill:** a burst that lands far out falls slowly and lasts. Aiming into the outer sky, or beyond the landmarks so stars fall toward them, is the archer's skill.

### Twists for the ladder

The hole grows by a pixel for each star it swallows. Two holes. A hole that moves on an orbit. Accretion: a swallowed star feeds a disc, and a full disc flares.

### Readability

Falling stars preview as short trails toward the hole, like the current's. The horizon is a dark disc with a lensed C-ring.

Stars must keep their size colours near the hole: reddening can only touch their trail or halo, never their body, since colour codes size.

The Big Bang already has a black hole in its collapse, so this one must look clearly different (persistent, smaller, with its ring) so the rare Big Bang keeps its signature.

### Step B: the debug trial (2026-10-12)

Built in the core, debug only (`StarGravity`, balance.json's `black_hole` block, `StarMap.black_hole`, `StarMap.black_hole_trial`). Once each launch has burst (the new stars too), every loose star falls toward the hole by `pull` / its distance, at least 1 px and at most `max_step`. A star whose fall reaches `horizon` px from the hole is swallowed for nothing. Landmarks never fall. A blocked star flows round what's in its way, as the current's do, and never moves further from the hole. As with the current, the falls of the stars already in the sky are reserved before the burst, so the aim's preview is exact. Aiming draws no random numbers, and a Big Bang clears the sky with no fall.

On the chart, G opens the trial and shift+G opens it with the hole off; HOLE ON/OFF replays the same seed. The layout is Scorpio's Heart without Orion's hunt, with the hole at (90, 164) inside the figure, just left of Antares. The cues are minimal: an N0 disc the size of the horizon in a cool ring whose bright arc orbits, flaring ember as it swallows. While aiming, each star's fall shows as a dotted trail (ember into the hole), and the scatter ring turns ember where landing stars would fall in. While not aiming, two ember dots mark each star the next launch swallows. Tuning: pull 1000, max step 24, horizon 8.

### Step C: spatial bots (2026-10-12)

`tools/gravity/playtest.gd`, paired seeds. The policies:
- *link-first* links everything first and aims at the first unlit landmark (careless).
- *launch-first* hoards.
- *archer* links first and aims 26 px past that landmark on the side away from the hole, so its stars fall toward it.
- *archer-hoard* aims as the archer and hoards.

The trial's layout, 300 seeds:

| | Hole off | Hole on | Packs/win (on) | Swallowed/run (of them on landing) |
|---|---|---|---|---|
| Careless (link-first) | 100% | 43.7% | 4.97 | 9.24 (7.87) |
| Hoard (launch-first) | 100% | 7.0% | 5.71 | 9.51 (6.59) |
| Archer | | **99.7%** | 4.21 | 2.92 (2.09) |
| Archer, hoarding | | 85.3% | 5.21 | 6.53 (2.27) |

A sweep (150 seeds; Leo's Haunch, Aquarius's Body, Scorpio's Heart; holes in the middle, low, left and right; pull 1000/24, 1500/30, 2500/40) showed:

- **The hole has to sit inside the figure.** Low or at the side, almost every policy wins nearly every run, and the hole only tidies up stars nobody used, which was Leo's flaw. In the middle of a figure that surrounds it (the Heart), stars waiting for a landmark fall past it.
- **The stake is the aim and the timing together.** Aiming past the landmark, so the fall carries stars onto it, wins. Aiming carelessly loses, mostly to bursts landing in the hole, which a human reading the ember ring would avoid. Hoarding loses even with a good aim (85% against 99.7%), because a waiting pair keeps falling.
- **Linking first with a good aim is safe.** As with Aquarius's drain (aiming upstream), the skill is in where you launch more than in when you link. The chapter's ladder has to make waiting tempting, for example with landmarks the fall can feed.
- Pull is a steep dial: on the Heart, 1500 drops the archer to 97% and careless play to 10%; at 2500 even the archer wins only 51%.

### Step D: kept (2026-10-12)

The user played the trial and kept the black hole. Later stages can add a reaction when the hole has swallowed too much, or on another condition: the plan's hungry hole, the accretion disc and the quasar below.

**The swallow** (playtest: a loss moment gets its own punch, as the drain did): the star drifts to the horizon. Its white-hot core pinches to a point there, and its light stretches into the disc as a cool streak. The disc gulps a pixel wider and the ring flashes ember. Then two ember sparks race round the ring both ways from the entry, and six specks of sky dust fall straight in, dimming from M6 to M4 as they near the hole. It lasts 0.45 s and doesn't block input. Its sound is its own cue, `swallow` (`tools/audio/build_sfx.py`): air rushing inward and rising, a glassy blip falling as it crosses, and a deep drop that warps as it sinks (0.44 s, -7 dBFS). None of it uses the Big Bang's signatures: no freeze, silence, shake, spiral or warm C2 photon ring.

**Idle** (playtest: the hole needed one; the user picked motes and infall together from a side-by-side mock): five motes orbit in a disc seen at a tilt, the inner ones faster (Keplerian). The far half passes behind the hole and the near half crosses in front. Five specks of sky dust drift straight in from 22-28 px out, speeding up and dimming M6 → M4, each at a fresh angle every 1.8 s. All of it is on the cool M ramp (M3-M6), under the stars. The ring's bright arc keeps orbiting.

**The final ends with the Big Bang** (the user's idea, 2026-10-12; they chose the final only, so it stays rare): when Sagittarius's final is won, the hole swallows every star left in the sky. It implodes and bangs (the Big Bang's script: the freeze, the silence, the flash), then the figure rises in the new sky as usual. Nothing is left to wipe at that point, which is why the Big Bang is off on chapter stages (#148). Its dust and any payout are to decide with the quasar. Part stages keep the usual finish.

Still to do: the readability check at 180x320 on a phone (the at-risk marks are first-pass), the stage ladder below, and the ring chore before Sagittarius goes on the chart.

**Possible stage ladder** (each twist measured with bots, as Virgo's were):

1. The hole alone, with a gentle pull. The stage opens by showing a few demo stars falling in.
2. A stronger pull, with the hole placed so waiting for a third star is tempting.
3. **The hungry hole:** its horizon grows a pixel for each star it swallows.
4. Two holes.
5. A hole on an orbit.
6. Final, the whole Sagittarius: the accretion disc fills as it swallows, and a full disc fires the quasar (the payout spike, below; its own branch and balance report). Winning it ends in the Big Bang (above).

The sweep says bigger figures need a stronger pull (the whole Virgo at 2500: careless 6%, hoarding 0%, archer 84%), so pull is a per-stage dial.

### Payout spike

**The quasar:** a hole fed past a threshold fires a jet that throws a rich burst of stars into the sky. It's rare, earned, and turns the threat into a jackpot.

## Chapter 6: Pisces, the cord

Pisces is two fish tied by a long cord, knotted at Alrescha. Most of the constellation is cord. Its chapter is about the geometry of links.

### Proposed rule (concept)

- Every successful link leaves its string in the sky as a **cord** (for the rest of the stage, or for some launches: to test). **A traced link can't cross a cord**: the trace refuses at the crossing, with the existing refused-pick feedback.
- Bursts and stars cross cords freely. Only links are blocked.
- **The loss:** stars walled into a pocket where they can't form a combo are **stranded**, as good as lost. The loss check must count only combos that can be traced.
- **Why linking first doesn't save you:** each link walls off part of the sky. Linking the nearest combo at once can cut a landmark off from the stars it needs. The order and shape of links is the decision.

### Twists for the ladder

The cord tying the fish is in the sky from the start, splitting it. Cords that snap after a few launches. A cord that tightens and drags its pocket's stars. Linking across your own cord's knot.

### Readability

The cords must not look like the constellation's strings, which are gold once lit. Try a dim rope (N5/N6, dashed) that glows only while a trace touches it. While tracing, a crossing shows where it would be refused before the release.

### Payout spike

To find. One idea is **the net**: a closed pocket of cords whose stars all link out in one sweep. This must not auto-complete landmarks.

### Step B: the debug trial (2026-10-14)

Built in the core, debug only (`StarCords`, `StarMap.cords`, `StarMap.cord_trial`). A successful link leaves its two steps, in pick order, as a cord. A link step that properly crosses a cord is refused: the trace refuses at that star (the step's shake and `link_reject`), and `link()` rejects it, using nothing up. Touching a cord doesn't block: a shared end, a star standing on a cord, a step through a cord's knot, or a collinear overlap. Cords last until the sky clears (Sun rekindle, completion or any Big Bang), so the link that rekindles the Sun leaves none. Bursts and stars cross cords freely, and cords draw no random numbers. The loss check counts only combos that can be traced: a trio links if some choice of middle star gives two steps in reach that cross no cord.

On the chart, P opens the trial and shift+P opens it with cords off; CORD ON/OFF replays the same seed. The layout is the Heart without its hunt, as the hole's trial was. The cues are minimal:
- A cord is laid solid C2 from the first star as the link's flash fades, then rests as a dashed old-gold rope (C2/C4) with knots, drawn under the figure and the stars. It started as a cool N6/N5 rope; the user chose old gold (option A of four) on 2026-10-14, a darker gold than the pale C1/C0 of the links and lit strings.
- While dragging, the line to the finger breaks at the first crossing (the reach's spark and dots), and the cord it would cross glows ember. A tapped step a cord refuses flashes that cord with the shake.
- The rule line shows as the trial opens: EVERY LINK LEAVES A CORD / NO LINK CAN CROSS ONE.

### Step C: spatial bots (2026-10-14)

`tools/cords/playtest.gd`, paired seeds, with these policies:
- *link-first*: gravity's scoring.
- *careless*: the first link found.
- *launch-first*: hoards.
- *planner*: links first and scores each link and each choice of middle star by the traceable links and landmarks its cord would cut off. It aims on a clear line to the landmark.
- *planner-hoard*: the planner's choices with hoarding.

The trial's layout, 300 seeds. Every bot wins 100% with cords off:

| | Won (on) | Packs/win off → on | Links blocked per board (on) |
|---|---|---|---|
| Link-first | 100% | 4.01 → 4.37 | 4.1 |
| Careless | 99.0% | 6.87 → 7.48 | 7.9 |
| Hoard (launch-first) | 100% | 4.83 → 4.97 | 7.4 |
| Planner | 100% | 4.26 | 3.5 |
| Planner, hoarding | 100% | 4.71 | 0.4 |

With cords kept for the whole stage (`--keep-cords`, a what-if in the tool), careless wins 94.3%, hoarding 99.7%, and the rest 100%. A sweep at 150 seeds (Aquarius's Body, Leo's Haunch, the whole Virgo, the whole Scorpio) gave the same picture. Only careless lost (95-99%), and all of its losses were to cords. Bigger figures cost more packs (link-first +0.9 packs on the whole Scorpio), and the planner won back about half of that.

**The gate fails on stakes.** On a threat-free figure, the cords cost good play packs but never the run. Every loss came from careless linking, and planning cut blocked links a lot without moving a win rate. That is Virgo's step C result (the harvest needed a tighter economy and bound sheaves to bite). Levers to try next, one at a time with the bots:
- a tighter economy;
- cords that last the stage;
- a cord that blocks a step passing within a pixel or two;
- the plan's twists, such as the fish's cord splitting the sky from the start.

### Lever: the fish's cord (2026-10-14)

The user picked the fish's cord: the cord tying the fish is in the sky from the start, splitting it.

**The rule.** A map can carry a fixed cord, `StarMap.fish_cord`: a polyline in home-layout coordinates, shifted with the map. It only counts when the map's cords are on, so cords off is still the baseline. It blocks a traced step as a link's cord does: a proper crossing is refused, touching is allowed. It never clears, not with the sky, not with a Big Bang. Link cords still clear as before. It draws no random numbers, and bursts and stars cross it freely. The loss check, hints and previews follow through `can_step`.

**The look.** It is there as the stage opens. An unbroken old-gold rope, C2 and C4 by turns, a step stronger than a link's dashed rope. A 3x3 knot sits at Alrescha (C1 heart, C2 arms, C4 corners); the loose ends have none. A step that would cross it turns the crossed arm and the knot ember (S4/S3). The first pass was N6/N5, and its N5 pixels vanished over the horizon haze; the second was N7/N6, then the user chose old gold for every cord.

**The placement.** A wedge V with its knot at the figure's foot: `166,78; 56,186; 179,214`. One arm rises past the spine to the top edge, the other runs to the right edge. Landmarks 1, 2, 3, 4 and 6 lie inside the wedge. The lit foot (0) and 5 lie outside, so it cuts strings 0-1 and 2-5. No landmark sits within 10 px of it. Landmark 1 is the tight spot: only 32% of its reach is open on its own side.

**The sweep.** 16 placements, 150 paired seeds, cords on, won % / packs per win. The None and N rows come from a 150-seed run whose result files (`results-cord_trial-fish_none.json`, `results-cord_trial-fish_166-78_56-186_179-214.json` in `tools/cords/out`) the 300-seed runs below overwrote; the other rows match their files. With cords off every bot wins 100% (link-first 4.06, careless 7.00, launch-first 4.83).

| | Polyline | Shape | Link-first | Careless | Launch-first | Planner | Planner, hoarding |
|---|---|---|---|---|---|---|---|
| None | | | 100 / 4.40 | 100 / 7.39 | 100 / 5.02 | 100 / 4.26 | 100 / 4.77 |
| A | 0,128; 98,176; 179,132 | first placeholder, knot under Antares | 100 / 5.04 | 96.7 / 7.76 | 98.0 / 5.60 | 100 / 4.71 | 100 / 5.25 |
| B | 2,78; 173,249 | diagonal through string 1-2 | 99.3 / 4.88 | 94.7 / 7.92 | 98.0 / 5.47 | 100 / 4.86 | 100 / 5.37 |
| C | 50,78; 179,207 | diagonal through string 2-3 | 100 / 4.72 | 97.3 / 7.66 | 99.3 / 5.21 | 100 / 4.62 | 100 / 4.80 |
| D | 30,78; 90,164; 179,214 | V, knot between 1 and 2 | 98.0 / 5.15 | 96.0 / 8.08 | 98.0 / 5.67 | 100 / 5.10 | 99.3 / 5.58 |
| E | 166,78; 0,244 | line along the spine | 98.0 / 6.50 | 97.3 / 8.95 | 97.3 / 6.53 | 98.7 / 5.42 | 98.7 / 5.62 |
| E2 | 162,78; 40,200; 179,236 | wedge round the spine | 98.0 / 5.82 | 95.3 / 8.71 | 98.7 / 6.12 | 100 / 5.02 | 100 / 5.31 |
| F | 110,78; 96,176; 179,160 | V, knot low left | 97.3 / 6.19 | 92.0 / 9.08 | 97.3 / 6.21 | 97.3 / 5.16 | 98.7 / 5.67 |
| G | 0,200; 116,144; 150,249 | Λ, knot between 2 and 3 | 99.3 / 5.37 | 94.0 / 8.23 | 99.3 / 5.72 | 97.3 / 4.84 | 100 / 5.29 |
| H | 0,170; 110,140; 179,249 | V opening down right | 100 / 4.93 | 97.3 / 8.01 | 100 / 5.39 | 98.0 / 4.89 | 100 / 5.11 |
| I | 0,120; 100,249; 179,120 | big U, knot on the bottom edge | 99.3 / 4.44 | 95.3 / 7.89 | 100 / 5.07 | 99.3 / 4.35 | 100 / 4.77 |
| J | 0,96; 100,148; 179,80 | V, knot above Antares | 98.0 / 6.45 | 96.7 / 8.97 | 96.7 / 6.55 | 98.0 / 5.20 | 100 / 5.43 |
| L | 40,78; 150,196; 179,100 | pocket holding 3 and 4 | 98.7 / 5.06 | 94.7 / 7.85 | 98.0 / 5.52 | 98.7 / 4.82 | 100 / 4.99 |
| M | 150,78; 0,236 | steeper line along the spine | 99.3 / 5.25 | 94.7 / 8.23 | 96.0 / 5.52 | 99.3 / 4.82 | 100 / 5.12 |
| **N** | **166,78; 56,186; 179,214** | **wedge, knot at the foot** | 98.0 / 6.65 | 94.0 / 9.06 | 95.3 / 6.76 | 98.7 / 5.74 | 98.0 / 5.82 |
| N2 | 162,78; 54,184; 179,206 | tighter N | 98.7 / 6.00 | 96.0 / 8.78 | 98.0 / 6.25 | 98.0 / 5.44 | 98.7 / 5.48 |
| N4 | 170,78; 40,206; 179,226 | lower knot | 95.3 / 6.82 | 92.0 / 9.14 | 96.7 / 6.94 | 96.7 / 5.43 | 100 / 5.63 |

N won: it's a real Pisces V, and it is among the costliest for link-first. F, N4, J, E2, D, G, H, I and L bite as hard or less but pass within about 5 px of a landmark (F is the widest, 5.1 px from landmark 2; N keeps 10 px), which would put a star on the cord.

N at 300 seeds (cords kept for the stage in brackets, `--keep-cords`):

| | Won | Packs/win off → on | Links blocked per board |
|---|---|---|---|
| Link-first | 98.3% (96.3%) | 4.01 → 6.58 | 17.2 |
| Careless | 92.3% (85.3%) | 6.87 → 9.10 | 18.7 |
| Hoard (launch-first) | 97.0% (96.0%) | 4.83 → 6.67 | 27.6 |
| Planner | 99.3% (99.3%) | 5.61 | 17.2 |
| Planner, hoarding | 98.7% (97.3%) | 5.75 | 29.2 |

Every loss was to cords. Without the fish's cord, at 300 seeds: link-first 100% on 4.37, careless 99.0% on 7.48.

**The gate still fails on stakes.** Careless play wins 92.3% (85.3% with kept cords), where the target is about 40-75%. The fish's cord costs packs, not runs: link-first goes from 4.01 to 6.58 packs a win (+64%). The planner saves about a pack a win (5.61 against 6.58) but wins about as often (99.3% against 98.3%). Hoarding does slightly worse than linking first, but not by a real margin. One fixed cord splits the sky into two big regions. Stars stranded on the far side still pair with later stars there, and combos keep paying for packs, so the run stalls but doesn't end. As in Virgo's step C, losing runs needs a tighter economy. Next with the bots: N with the economy lever, or N with cords kept for the stage (the only change that roughly doubled losses).

## Steps and gates

As before, one experiment at a time. Chapter 5 and 6 work waits until chapter 4 has passed or been dropped.

| Step | Work | Gate |
|---|---|---|
| A | Virgo on paper (this sketch), a mockup of the last aim before a harvest at 180x320, one conflict drawn on it. | The clock, the harvest pay and the trade read in one look on a phone. |
| B | A debug-only harvest trial on a threat-free layout (harvest on/off, same seed). The rule is pure core with tests; minimal cues. | Harvest off reproduces the baseline; previews match execution; RNG untouched. |
| C | Spatial bots (link-first, launch-first, and a harvest-aware bot that leaves stars standing on the last launch) plus human play. The Python simulator reports the economy (the harvest changes dust). | Stakes for both link-first and hoarding; no dominant answer; a harvest-aware skill that pays. |
| D | Keep, revise or drop. Then Virgo's stages, chart, figure and paintings, as Leo's. | As for the current and the heat. |
| After D | The ring chore (above), then Sagittarius from step A, then Pisces. | Each passes its own A-D. |

## Open questions

- Virgo: the harvest's pay values, the clock length, and whether reaped dust counts toward a stage's economy the same as link dust. All tuning goes in balance.json, with simulator output.
- Virgo: does a forced debug Big Bang still clear the sky, or does it become the golden harvest?
- Sagittarius: pull curve, horizon size, and how strongly stars flow round landmarks near the hole.
- Pisces: whether cords last the whole stage, and whether a cord blocks only crossing or also passing within a pixel.
- The ring: what Ophiuchus (between Scorpio and Sagittarius on the real ecliptic) is on the sky, if anything. For now it's left out.
