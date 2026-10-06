# Chapters 2 and 3: ideas to test

**Status: revised proposal, 2026-10-06.** This is a short experiment plan, not a chapter specification or gameplay implementation request. [design.md](design.md) remains the current rules reference. Aquarius and Gemini are working themes; stage lists, detailed effect rules, and tuning wait until the ideas survive evaluation.

## Direction and stakes

Chapter 1 asks the player to protect stars. Chapter 2 should ask when to rearrange them at a cost. Chapter 3 needs a genuine competing use for its echoes before it earns a place in the campaign.

| Concept | Status | Proposed pressure | Decision that must exist |
|---|---|---|---|
| 2: Aquarius / currents | First experiment | Launching can move a saved cluster out of reach while helping another; keep the existing map's single mark during the experiment. | Link a useful cluster first, or risk moving it to obtain a new opportunity? |
| 3: Gemini / echoes | Weaker concept; paper work only for now | A scarce echo can serve its partner or a competing landmark; use the existing single-mark threat as the baseline for any later prototype. | Spend the echo here, or save/use it elsewhere at a real cost? |

Finite packs and dust alone are not proof of pressure. A later chapter must retain meaningful losses and understandable consequences. Early stages can teach gently; mastery stages should aim for stakes comparable to late Scorpio, measured with the same spatial core bots and human playtests. No numerical win target is chosen yet, and no new win rates are claimed.

The Python simulator ignores positions and link reach. Historical all-win estimates for unthreatened configurations do not establish current chapter difficulty; threatened stages also have lower recorded rates. Neither a higher simulator win rate nor more free resources proves an interesting mechanic.

Keep the three sizes, three-star combos, one landmark per link, existing pack roles, dust, light, and constellation objective. No new currency, persistent upgrade, or inventory. Do not increase targets simply to disguise a mechanic that only helps.

## First experiment: double-edged currents

Use a debug-only switch on the existing **Tail** map. Keep its normal packs and landmarks. No chapter selection, save migration, new chart, or general effects framework is needed.

Orion's mark already asks "link first or launch first": a link that leaves the mark behind loses it, and launching to find a rescue is his cost. Currents ask the same question, so a plain off/on comparison with Orion present can't say which one changed the player's choices. Compare all four cases on the same seed range: current off/on × Orion off/on (a map without an `orion` block never marks). Orion off with current on is the main reading of the current alone; the Orion-on pair shows whether the two pressures add up or merely repeat each other.

One current shifts loose stars on a successful launch; landmarks stay fixed and the sky stays still between actions. Both red bursts resolve before the single movement step. Buying, cancelled gestures, and invalid actions do not advance it. Orion's mark stays on its star when the current moves it, so a current can carry the marked star out of every rescue's reach (or into one); the bow warning and the arrow follow the star. Treat this as a deliberate part of the Orion-on cases and record when it happens. These are the minimum assumptions for the experiment, not the final movement specification.

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

The original equal-size, partner-matching echo is mostly a free star. Do not prototype that version as a chapter, and do not write its Sun/clear/event-order specification yet.

Sketch two alternatives separately:

- **Combo-dependent echo:** the combo used to light the first twin changes the echo's size. Triples could echo their repeated size; a mixed sequence needs a simple, visibly understandable outcome. First ask whether choosing a different valid combo is actually possible often enough to matter.
- **Competing destination:** the echo lands near the partner but also within useful reach of another unfinished landmark. Using it for one prevents using that same star for the other. Completing the same map in either order without a meaningful cost is not sufficient.

Prefer the competing-destination sketch first because it can use ordinary stars without another size rule. Test combo dependence only if the spatial competition is weak. Do not stack both ideas immediately.

For any later prototype, keep the Tail's single-mark threat as the baseline for pressure; use a small debug-only paired layout or overlay, not a new campaign chapter. Compare against that same threat/layout without echoes. Demonstrate a case where taking a link sacrifices another useful opportunity or a threatened star. Extra stars that merely make every run easier fail the concept gate.

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
| A | Sketch one Tail current conflict and its busiest aim state. Outline the payout moment. | A visible gain and cost; phone-scale readability; a quick choice that preserves anticipation. |
| B | Add one debug-only current to Tail, with minimum core checks and view cues. | The existing map runs unchanged with the switch off; movement matches cues and keeps stars selectable; a moved mark stays on its star. |
| C | Play current off/on × Orion off/on across matched seeds; observe human touch play early. | Players notice both helping and harming, sometimes link first and sometimes launch first, and aiming upstream is a skill that never removes the cost. |
| D | Run the existing simple bot across the four cases; current-aware bots only if human play leaves the keep/drop call unclear. Try the forced payout presentation separately. | Useful decisions survive unscripted runs; losses are explainable; rich openings are legible and satisfying. |
| E | Record keep, revise, or drop. | No dominant trivial answer, no clutter-heavy preview, and meaningful stakes. |
| After E | Specify only a surviving mechanic; revisit Gemini sketches, then consider chapter maps and progression. | An echo trade-off must pass its own gate before any Gemini chapter commitment. |

Wells and resonance are outside this sequence. Full stage progressions, boss names, paintings, chapter unlocks, and save generalisation wait. If currents fail, leave Scorpio intact and return to the reserve ideas rather than grow systems around them.

## Evidence and boundaries

For the current prototype, check fixed landmarks, one step per successful launch including red twins, invalid/cancelled actions changing nothing, safe selectable positions, shown destinations matching execution, and remaining reachable combos being checked before loss. Movement rules stay in pure typed GDScript; scenes observe events. Use integer pixels, the existing palette, and injectable randomness. Previews must not alter pack draws.

Record the map, the case (current and Orion on or off), seeds, bot policy, wins/losses, packs, links, gains and losses of reachable opportunities after movement, chosen launch/link order, and marks the current moved into or out of a rescue. Human observation should include first-use understanding, preview confusion, refused touches, decision time, and explanations of a surprising outcome. Compare blue-only and deliberate mixed-pack play; classify deliberate star sacrifices separately from mistakes.

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
