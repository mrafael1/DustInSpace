# Chapters 2 and 3: ideas to test

**Status: chapter 3 is Leo, the heat, 2026-10-07.** Chapter 2 (Aquarius, the draining current) is built and in the campaign ([design.md](design.md)). For chapter 3 the user chose **Leo: stars that ripen** over Gemini's echoes (below); it is at step A, on paper. The earlier current experiments are recorded in [chapter_2_current_trial.md](chapter_2_current_trial.md). [design.md](design.md) remains the current rules reference.

## Direction and stakes

Chapter 1 asks the player to protect stars (an enemy takes them). Chapter 2 asks when to rearrange them at a cost (the space takes them). Chapter 3 asks when to let a star change: the pressure is on **what a star is**, its size, not where it is.

**Confirmed chapter identity:** Orion is exclusive to chapter 1 and its Scorpio mythology. His mark, volley, and hunting area do not carry into chapters 2 or 3, including their prototypes. Do not reskin those threats to supply later chapters with pressure; each chapter must establish its own mechanic and stakes.

| Concept | Status | Proposed pressure | Decision that must exist |
|---|---|---|---|
| 2: Aquarius / currents | Built, with a drain | Launching can move a saved cluster out of reach while helping another; movement itself must create the cost. | Link a useful cluster first, or risk moving it to obtain a new opportunity? |
| 3: Leo / heat | Chosen; step A (paper) | Stars in the heat grow a size each launch; a big one that grows again burns out. | Link it now, or let it ripen into a better combo and risk losing it? |
| Gemini / echoes | Parked | A scarce echo can serve its partner or a competing landmark; it still has no loss. | Spend the echo here, or save/use it elsewhere at a real cost? |

Finite packs and dust alone are not proof of pressure. A later chapter must retain meaningful losses and understandable consequences. Early stages can teach gently; mastery stages should aim for stakes comparable to late Scorpio, measured with the same spatial core bots and human playtests. No numerical win target is chosen yet, and no new win rates are claimed.

The Python simulator ignores positions and link reach. Historical all-win estimates for unthreatened configurations do not establish current chapter difficulty; threatened stages also have lower recorded rates. Neither a higher simulator win rate nor more free resources proves an interesting mechanic.

Keep the three sizes, three-star combos, one landmark per link, existing pack roles, dust, light, and constellation objective. No new currency, persistent upgrade, or inventory. Do not increase targets simply to disguise a mechanic that only helps.

## First experiment: double-edged currents

Use a debug-only copy of the existing **Tail layout**, with Orion and all his threats disabled. Keep its normal packs and landmarks. This borrows geometry only; normal chapter 1 play keeps Orion and its existing rules. No chapter selection, save migration, new chart, or general effects framework is needed.

Compare current off/on on this same threat-free layout and seed range. The experiment must demonstrate that currents produce meaningful pressure independently. If movement is only a convenience, revise or drop it rather than borrow Orion's threats.

One current shifts loose stars on a successful launch; landmarks stay fixed and the sky stays still between actions. Both red bursts resolve before the single movement step. Buying, cancelled gestures, and invalid actions do not advance it. These are the minimum assumptions for the experiment, not the final movement specification.

The layout must demonstrate both outcomes:

- A launch brings previously stranded stars into useful reach.
- That same launch carries another usable cluster away from its landmark or breaks its useful reach.
- Aiming upstream so the current carries the burst where it's wanted is the intended skill. What must not happen is aim removing the cost: new burst stars move too, and no aim point reliably helps one cluster without moving another.
- Linking the saved cluster first prevents that loss of opportunity, but uses stars the player might otherwise save.

Show this conflict in ordinary random play after the initial example. If it exists only in a scripted board, or the best answer is always "link everything before launching," revise or drop the current.

**Readability is an early pass/fail condition.** Before implementing movement, mock up the busiest aim state at 180x320 and on a phone: existing strings, scatter preview, flow cue, and affected stars. Do not add a persistent layer of exact trajectories for every star.

Try a short flow arrow plus destination dots only for affected stars while aiming. Keep link hints and reach feedback for tracing; let nonessential strings recede during aiming. Existing-star destinations must match execution if shown. Unopened contents and scatter remain uncertain. If the player needs a dense board-analysis overlay to understand the cost, simplify the effect or reject it.

The player should make a quick launch-or-link choice, then enjoy a random burst and its consequences. Do not turn each shot into a long calculation. Spacing, integer movement, safe bounds, and hint/loss updates are implementation necessities to settle when building the small prototype.

## Gemini must first prove a trade-off

*Parked on 2026-10-07: chapter 3 is Leo (below). Kept for a later chapter if it finds a loss.*

The original equal-size, partner-matching echo is mostly a free star. Do not prototype that version as a chapter, and do not write its Sun/clear/event-order specification yet.

Sketch two alternatives separately:

- **Combo-dependent echo:** the combo used to light the first twin changes the echo's size. Triples could echo their repeated size; a mixed sequence needs a simple, visibly understandable outcome. First ask whether choosing a different valid combo is actually possible often enough to matter.
- **Competing destination:** the echo lands near the partner but also within useful reach of another unfinished landmark. Using it for one prevents using that same star for the other. Completing the same map in either order without a meaningful cost is not sufficient.

Prefer the competing-destination sketch first because it can use ordinary stars without another size rule. Test combo dependence only if the spatial competition is weak. Do not stack both ideas immediately.

Before any later prototype, identify Gemini's own source of pressure in the paper sketches. Use a small debug-only paired layout or overlay with no Orion threats, not a new campaign chapter. Compare that same layout with echoes off/on. Demonstrate a case where taking a link sacrifices another useful opportunity, and establish why that sacrifice matters to the run. Extra stars that merely make every run easier fail the concept gate; Gemini stays unresolved until it has independent stakes.

An echo should remain an ordinary star, with a finite source such as one emission per pair. Reject unlimited generation or a guaranteed completion chain. The unresolved size mapping, pair layout, Sun interaction, and exact timing remain questions for a surviving concept, not committed rules.

## A chapter also needs a payout spike

Movement and a free star are not replacements for the Big Bang's anticipation and payoff. Each chapter needs a noticeable payout spike that fits its objective; completion paintings alone are not enough.

First payoff hypothesis: a **Big Bang that doesn't clear the sky**. It keeps the Big Bang's rare roll and its build-up, then delivers an unusually rich ordinary burst and a visible dust spike, and keeps saved stars and lit landmarks. That avoids the reason the Big Bang is off on constellation stages (it wiped the stars saved for a landmark). Amount, chance, and burst tuning remain undecided.

This would change Scorpio's constellation stages as much as any new chapter, so it is its own topic: it needs the user's approval, its own branch and its own balance report, and it does not ride along with the currents experiment.

For Aquarius, the exciting result would be a rich burst followed by a readable rearrangement that exposes several opportunities. For Gemini, it would supply a contested area and let the player choose which completion to pursue. Neither should silently auto-complete landmarks or introduce a new currency.

Evaluate the idea early with a forced debug presentation or paper sequence, separately from ordinary current/echo trials. A forced example tests readability and the feeling of the payout, not its natural frequency or balance. If it is only a bigger number and does not feel like a memorable opening, revise it before planning a full chapter. Natural non-clearing Big Bangs and their economics need separate tuning evidence before release.

## Cheap sequence and decision gates

Only the currents experiment is next. Gemini, the non-clearing Big Bang, and chapter infrastructure do not become parallel implementation tasks.

| Step | Work | Gate |
|---|---|---|
| A | Sketch one current conflict on the threat-free Tail layout and its busiest aim state. Outline the payout moment. | A visible gain and cost without Orion; phone-scale readability; a quick choice that preserves anticipation. |
| B | Add one debug-only current to that layout, with minimum core checks and view cues. | The switch-off case reproduces the threat-free baseline; normal Scorpio play stays unchanged; movement matches cues and keeps stars selectable. |
| C | Play current off/on across matched seeds with no Orion threats; observe human touch play early. | Players notice both helping and harming, sometimes link first and sometimes launch first, and aiming upstream is a skill that never removes the cost. |
| D | Run the existing simple bot across the two cases; current-aware bots only if human play leaves the keep/drop call unclear. Try the forced payout presentation separately. | Useful decisions survive unscripted runs; losses are explainable; rich openings are legible and satisfying. |
| E | Record keep, revise, or drop. | No dominant trivial answer, no clutter-heavy preview, and meaningful stakes. **Done: kept, with a drain** (below). |
| After E | Specify only a surviving mechanic; revisit Gemini sketches, then consider chapter maps and progression. | An echo trade-off must pass its own gate before any Gemini chapter commitment. |

Wells and resonance are outside this sequence. Full stage progressions, boss names, paintings, chapter unlocks, and save generalisation wait. If currents fail, leave Scorpio intact and return to the reserve ideas rather than grow systems around them.

### Decision E: keep currents, with a drain

Recorded 2026-10-06. A current that only moves stars did not create stakes: reach (56 px) dwarfs a 24-48 px drift, and linking everything first was always safe. The user chose a **drain**: a star the flow carries out of its field is lost for nothing. On the Aquarius flow layout (full-height field, drain at x 48) that meets the gate:

- **Stakes:** hoarding loses runs (launch-first 96.4% at step 24, 64.9% at step 32); link-first loses some (98.8% / 94.7%).
- **No dominant trivial answer:** linking first no longer avoids the cost, since a waiting pair drifts toward the drain while the player launches for its third star.
- **Skill:** aiming one step upstream drains about 40% fewer stars and almost never loses (100% / 99.8%).
- **Readable preview:** one ember trail per star that would drain, the cool brackets for the rest, an ember drain line.

Bots only; human touch play is still owed and can revise this. Still open: `currents.step` (24 shipped, 32 the stronger what-if; it also drives the Tail trial), whether draining is the chapter's rule on every stage or a feature of some, and then chapter 2's stages, chart and saves. Wells and the reserve ideas stay out.

## Chapter 3: Leo, the heat

Chosen by the user on 2026-10-07 from three candidates: Leo's ripening stars, Taurus's fusion (reserve: a burst landing on a star fuses them, so aim would shape sizes, which bends "the slingshot controls where, never contents") and Gemini's shared life (twins of opposite size that take turns in the sky; still no loss, so parked with the echoes). Leo is the lion of high summer, when the Sun is in its house: its heat ripens stars.

What Aquarius taught carries over: a mechanic that only helps has no stakes (drift alone failed the gate; the drain passed it), so the heat has a real loss from its first draining stage.

### Proposed rule (step A, not committed)

- **The heat** is a region of the sky, like the current's field. After each successful launch (both red bursts first, as with the current), every loose star inside it **grows one size**: small to medium, medium to big. A big star that grows again **burns out** and is lost for nothing, like a drained star.
- Landmarks never change size; stars outside the heat never change. Buying, linking, cancelled gestures and invalid actions don't advance it.
- **A new star doesn't ripen on the launch that brought it** (design guess: otherwise a big landing in the heat burns at once, before the player could see it). It ripens from the next launch on.
- Big Bang stays off, as on every constellation stage.

### Why it should make decisions

The shipped combos make ripening pay: a small triple is 3 dust / 5 light, a medium triple 5 / 10, a big triple 6 / 15. Three smalls left in the heat for two launches become a big triple worth three times the light, and burn out on the third.

- **Push your luck:** link a triple now, or let it ripen into a better one and risk losing it. This is the slot-machine pull, delivered by the player's own timing.
- **Heat favours dust, works against light:** stars that ripen together keep a triple a triple, but a one-of-each breaks (small, medium, big become medium, big, burnt). A set with one star in the heat and two out breaks too.
- **A waiting pair is a moving target:** two smalls waiting for a third need a medium after the next launch and a big after that, as Aquarius's waiting pair drifts toward the drain. So "link everything first" doesn't avoid the cost.
- **Aim is the skill, through the packs' own roles:** a blue planet (mostly small stars) aimed into the heat ripens cheap stars into value; a red one (mostly big) aimed into it gets stars that burn after one launch. Aiming outside the heat keeps sizes fixed, but layouts put landmarks in it.
- **Big landmarks are the tension point:** a big landmark in the heat needs two loose bigs, which in the heat last exactly one launch.

### One conflict to show (paper)

A medium landmark in the heat, and beside it, all loose and in reach: two smalls (A, B), a medium (C) and a big (D).

- **Link now:** A, C, D are a sequence (25 light), but the landmark stays unlit and B waits alone.
- **Launch first:** A and B become mediums and light the landmark with it (a medium triple); C becomes a big; D burns out. The sequence is gone and a star is lost, for a landmark and whatever the new burst brings.

Neither is always right: it depends on the Sun's fill, the packs left and how close the landmark is to finishing the figure. (A triple alone is never broken by the heat; it only grows, until it burns.) To check on the mockup: that this reads in one look while aiming.

### Readability (the step A gate)

Nothing moves, so the preview should be lighter than the current's. While aiming:

- each loose star in the heat shows the size it will become (proposed: a one-pixel outline of the next silhouette around it, cool, as the current's brackets);
- a star that would burn out gets the drain's ember mark;
- the heat itself: a warm-tinted field. Warm colours are reserved for interactive or valuable things, so the tint must stay subtle and below the stars (S/ember ramp at low steps, or a sparse pattern like Aquarius's water streaks, rising heat shimmer instead of flowing water).

Mock up the busiest aim state at 180x320 (about a dozen loose stars, half in the heat, two about to burn, strings, scatter ring) and check it on a phone before building anything.

### Possible stage ladder (to revise after the gate)

Mirroring Aquarius: teach the help first, bring the loss, then twist.

1. Heat that ripens but never burns (big stays big): it only helps.
2. Burning arrives.
3. The heat crosses the figure, so sets straddle its edge.
4. A cooling region: stars shrink (big to medium to small, then fade).
5. Heat and cold side by side.
6. Final, the whole Leo: the two swap after every launch.

### The reversed heat: stars lose a size

The user's addition (2026-10-07): a stage where the rule is reversed, so each launch makes a star in the region **lose one size**: big to medium, medium to small, and a small one fades out (lost). It is stage 4 above, and half of stages 5 and 6. It is not a mirror image in play:

- **Waiting only loses value:** a big triple (6 dust / 15 light) becomes a medium triple (5 / 10), then a small one (3 / 5), then fades. Ripening was a gamble with an upside; this is a fuse. The risk is that "link everything first" becomes the trivial answer, as it was for the current without a drain. Its decisions have to come from **needing a size**: a big that must become a medium for a medium landmark, a sequence rebuilt from a shrinking big.
- **The planets swap roles:** red (mostly big) aimed into the cold gives mediums and smalls a launch later; blue (mostly small) fades after one. In the heat it's the reverse. With both on one stage (5), aiming each planet at its region is the skill.
- **One-of-each breaks the other way:** small, medium, big become faded, small, medium. Triples hold, as in the heat.
- **Swapping each launch (the final):** a star alternates up and down a size, so most of them hover; only a big in the heat or a small in the cold is at risk on a given launch. Check on paper that this still has stakes before choosing it for the final.
- **Readability:** the cold needs a cool look distinct from the water's (Aquarius uses the M ramp): frost or still, sparse glints rather than streaks. The next-size outline works the same way; a star that would fade gets the ember mark like one that would burn.

Leo's figure: the Sickle (the mane and head: epsilon, mu, zeta, Algieba, eta, Regulus), the back (Zosma), the haunch (Chertan) and the tail (Denebola). Parts and chart wait for the gate.

### Payout spike

Leo's rare opening could be **the Leonids**, the meteor shower that radiates from Leo: a rich burst that doesn't clear the sky. This is the plan's non-clearing Big Bang (below) in Leo's colours, and like it needs its own approval, branch and balance report. A cheaper in-chapter idea: a **flare**, a rare launch that ripens the whole heat at once without burning anything.

### Steps

| Step | Work | Gate |
|---|---|---|
| A | This sketch; a mockup of the busiest aim state at 180x320; one conflict drawn on it. | Ripening and burning read in one look on a phone; the conflict is visible. |
| B | A debug-only heat trial on a threat-free layout (heat on/off, same seed), pure core rule with tests, minimal cues. | Heat off reproduces the baseline; previews match execution; RNG untouched. |
| C | Spatial bots: link-first, launch-first, heat-aware (ripen blue in the heat, link before burning); human play. | Stakes (hoarding loses runs), no trivial answer, a heat-aware skill that pays. |
| D | Keep, revise or drop. | As for currents: no dominant answer, no clutter, real stakes. |

## Evidence and boundaries

For the current prototype, check fixed landmarks, one step per successful launch including red twins, invalid/cancelled actions changing nothing, safe selectable positions, shown destinations matching execution, and remaining reachable combos being checked before loss. Movement rules stay in pure typed GDScript; scenes observe events. Use integer pixels, the existing palette, and injectable randomness. Previews must not alter pack draws.

Record the layout, the case (current on or off, with all Orion threats disabled), seeds, bot policy, wins/losses, packs, links, gains and losses of reachable opportunities after movement, and chosen launch/link order. Human observation should include first-use understanding, preview confusion, refused touches, decision time, and explanations of a surprising outcome. Compare blue-only and deliberate mixed-pack play; classify deliberate star sacrifices separately from mistakes.

All tuning belongs in game/config/balance.json. If it changes, run and report the required Python simulator as well as spatial core runs, explicitly describing what each models. No balancing or gameplay tests are claimed for this documentation revision.

## Reserve and research

| Reserve idea | Reason to defer |
|---|---|
| Gravity wells | Another movement system before currents prove useful. |
| Paired resonance | Expiry and Sun exceptions add complexity before echoes prove a choice. |
| Wormholes / conducting strings | More routing and preview rules; revisit only after simpler spatial ideas. |
| Triangle enclosure / size transformation | Touch geometry or changing silhouettes need independent readability experiments. |
| Eclipse / rhythm / longer combos / buffs | Broader timing or rules changes; outside the cheap current experiment. |

Research informs these hypotheses; it does not validate them. [Osmos](https://www.osmos-game.com/) supplies a spatial-field reference. [Into the Breach](https://store.steampowered.com/app/590380/Into_the_Breach/) supplies consequence telegraphing, not a target pace for this game. [Grindstone's developer AMA](https://www.reddit.com/r/Grindstone/comments/i1a9e4/) supports testing resource opportunities on paper grids. [Peglin](https://store.steampowered.com/app/1296610/Peglin/) is an aiming-and-randomness reference. [Luck be a Landlord's rules discussion](https://blog.trampolinetales.com/making-rules-and-breaking-rules/) is a reason to avoid premature exceptions.
