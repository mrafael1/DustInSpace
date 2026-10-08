# Chapters 4 to 6: ideas to test

**Status: Virgo is being built with the scythe and bound sheaves (step D: kept, revised), 2026-10-08.** Its first two stages are in [design.md](design.md) (chapter 4). The harvest that paid dust failed its stakes gate; bound sheaves with a tighter economy passed it (step C, below). The user chose three mechanics from a shortlist: **Virgo, the harvest**; **Sagittarius, the black hole**; **Pisces, the cord**. Chapter 6 is a chapter like the others (its own mechanic; the campaign can keep growing after it), not a finale. Nothing here is committed: every rule below is a proposal that has to pass its gates, as Aquarius's current and Leo's heat did ([chapter_2_3_plan.md](chapter_2_3_plan.md)). [design.md](design.md) remains the rules reference.

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

Needed, as its own chore before chapter 5: Virgo and Libra as passing figures; the ring (world x wraps every 12 signs; each chapter's place is its sign plus its lap); and the **chapters' own constellations drawn as passing figures**. Today a voyage from Scorpio to Leo crosses Aquarius's place empty, because chapter figures aren't drawn as passing ones. The background stars wrap with the ring.

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

Links pay a percent of their dust under the harvest (`harvest.link_dust_percent`, rounded down: 90% is one dust less a link). Whole Leo (12 to light, branching), reaping for nothing, 200 paired seeds, won %:

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
