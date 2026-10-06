# Chapter 2: first playable current experiment

2026-10-06. This implements the first cheap experiment from [the chapter plan](chapter_2_3_plan.md), on a debug copy of Tail geometry. **Orion is absent.** Trial wins have no campaign, tutorial or encounter save callbacks. Aquarius art, stages, campaign access, rare payout, Gemini, wells and resonance remain outside this experiment.

## Play and compare

- In the Godot editor/debug build, press **C** on the chart for this Tail trial (Shift+C: flow off). **FLOW** on the chart, or **A** (Shift+A: off), opens the later Aquarius flow layout (below).
- In the trial, tap **FLOW ON/OFF**, or press **C**, to restart with the same seed and the other setting. The control is blocked during animations and while the combination table is open.
- **MAP** returns to Scorpio's chart. Ordinary Scorpio stages still use their original threats.
- CLI: `godot --path . -- --currents` (or `--currents-off`; `--aquarius` / `--aquarius-off` for the Aquarius layout). Debug exports also expose the FLOW button. Release builds do not expose the experiment.

One leftward field covers `(64,124)` through `(171,223)` in the home layout, shifting with the map on taller screens. A successful normal launch resolves its entire pack, then shifts affected loose stars once. Strength is `currents.step` in balance.json (currently 24 native pixels). Stars are processed downstream first (leftmost first here), so upstream stars can follow their neighbours regardless of creation order. A blocked destination leaves the star in place. New stars participate; landmarks stay fixed. Buying, linking, cancelled gestures and invalid actions do not advance the flow. Forced debug Big Bangs keep the existing clearing behavior and bypass the movement step; the trial's normal Big Bang chance remains disabled.

While aiming, affected existing stars show cool brackets at their reserved destinations. The random burst remains unknown. Flow arrows remain faint; constellation strings recede during aiming; tracing keeps its existing link hints and reach feedback. Movement plays after scatter in a 300 ms integer-pixel drift. Tail's completion painting is still a placeholder, not Aquarius art.

Debug trial runs use the existing playtest logger, tagged `current_trial` or `current_baseline`. With a configured analytics endpoint, desktop/editor trial events can be uploaded to the playtest sheet. `tools/playtest/summary.py` reports those stages separately; exclude them when evaluating campaign play. Headless checks never upload events.

## Verification and result

The core fixture demonstrates one launch removing a valid saved small-star link while opening a previously unreachable big-star link. Tests also cover downstream cluster movement with swapped creation IDs, preview purity and execution across seeds, blocked positions, bounds, one movement after red's two bursts, new-star movement, unchanged RNG, invalid actions, remaining-combo loss checks, view sequencing, mobile controls, tall-screen placement, processing only on current stages and save isolation.

Native-size crowded aiming and tracing states were rendered and inspected at **180×320** and **180×390**. A tall-screen control overlap was corrected. This is desktop screenshot review; phone interaction/readability still needs human playtesting.

The ordinary Python economy check, seed 1, 20,000 runs per policy, is unchanged:

| Policy | Before win | After win | Before / after packs to win |
|---|---:|---:|---:|
| Blue only | 100.0% | 100.0% | 7.2 / 7.2 |
| Red when affordable | 100.0% | 100.0% | 5.5 / 5.5 |

That simulator uses the full unthreatened constellation, ignores positions and cannot measure currents. It is an economy regression check, not chapter difficulty evidence.

The new [spatial runner](../tools/currents/playtest.gd) uses the actual GDScript core and paired seeds 1–1,000 on the same threat-free Tail layout, with the shipped pack odds, costs, rewards, reach and Sun. Both policies consume starting packs and buy red when affordable, otherwise blue. Both aim 12 pixels left and 18 above the first unlit landmark. Links prioritize landmarks, then dust plus light. Neither policy anticipates or aims upstream for the current. Orion-on comparisons are intentionally excluded: the confirmed chapter plan prohibits Orion in later chapters, including prototypes. This is the required Orion-off comparison, not a skipped chapter-2 threat test.

| Spatial policy | Flow | Wins / losses / capped | Mean packs to win |
|---|---|---:|---:|
| Link every available combo first | Off | 1,000 / 0 / 0 | 3.443 |
| Link every available combo first | On | 1,000 / 0 / 0 | 3.526 |
| Launch all owned packs before linking | Off | 1,000 / 0 / 0 | 4.274 |
| Launch all owned packs before linking | On | 1,000 / 0 / 0 | 4.392 |

For flow-on runs, the runner probes visible boards immediately before launching: it applies only the exact existing-star preview temporarily, compares reachable landmark-link sets, then restores positions before opening the random pack. New arrivals are excluded from this probe.

| Spatial policy | Probed boards | Lose a landmark link | Gain a landmark link | Both in the same board | Runs with both |
|---|---:|---:|---:|---:|---:|
| Link first | 3,526 | 0 | 24 | 0 | 0 / 1,000 |
| Launch owned first | 4,392 | 1,452 | 44 | 34 | 34 / 1,000 |

These spatial measurements were rerun after correcting the movement order to downstream first. Flow-off results are unchanged; flow-on results replace the original ID-ordered measurements.

**The concept has not passed the pressure gate.** The effect can help and hurt in ordinary random play, but simultaneous opportunities occur in only 3.4% of launch-first runs, and every run still wins. The flow costs just 0.083 additional packs per run for link-first and 0.118 for launch-first: it supplies almost no run pressure under these policies. Link-first's zero lost links is largely guaranteed by the policy draining every available combo before launching, not evidence of a meaningful launch-or-link decision. This experiment establishes no incentive to launch before collecting a valid link; the plan calls for revision when linking everything first is the trivial answer.

This build supports human comparison; it does not justify expanding into campaign stages. The next experiment should improve the frequency and importance of the launch-or-link choice through flow/layout design before selecting chapter difficulty or adding infrastructure. No Orion fallback or economy inflation is approved.

Godot 4.7 import and startup checks passed; the full GUT suite passed **847/847 tests**. The new cluster regression failed on the original implementation and passed after correcting the flow order. GUT still reports two float/int comparison warnings and ObjectDB/resource cleanup diagnostics at exit (385 instances, 9 resources); these are recorded separately from failed assertions.

## Second experiment: the Aquarius flow layout and a drain

2026-10-06. A layout alone did not create the choice: with reach 56, a 24-48 px drift rarely carries a waiting star out of reach, and on a first Aquarius layout the flow even helped slightly (link-first 3.64 packs off, 3.60 on; still every run won). A shorter reach made aiming a skill but still lost almost no runs, since dust always buys more packs. The user chose a **drain** to give the flow stakes.

**The layout** (`StarMap.aquarius_flow`, debug only, no Orion): six landmarks, the jar at the upper right starting lit, so five to light. The leftward field runs the sky's full height (on any screen) from x 48 to the right edge; four landmarks sit inside it and the last, at x 32, lies past its left edge, in the strip the flow leaves still. Placeholder painting (Tail's).

**The drain** (the field's left edge, so it too runs the full height; a map setting, `StarMap.current_drains`; the Tail trial doesn't drain): a star the flow would carry out of the field is lost and pays nothing. It still moves downstream first, and a drained star never blocks the star behind it. Stars outside the field are never touched. The loss check runs after the drain, so a combo it carries off doesn't keep the run alive. No new tuning: the step is still `currents.step` (24).

**What the player sees:** the field's left edge is an ember dotted line (S3). While aiming, a star the launch would drain trails ember dots (S4) out to where it leaves; other moving stars keep their cool destination brackets. Ember brackets were tried first and read as the landmarks' warm corner hints. On the launch, a drained star drifts out, then bursts like a star Orion's arrow breaks. The trial control's caption reads DRAIN TAKES STARS.

**Measurements** (`tools/currents/playtest.gd --map=aquarius`, paired seeds 1-1,000, reach 56, same bots as above plus one aiming a step upstream when its target is in the field):

| Policy | Flow off: win / packs | Drain, step 24: win / packs / drained per run | What-if step 32 (`--step=32`): win / packs / drained |
|---|---:|---:|---:|
| Link first | 100.0% / 3.67 | 98.8% / 3.96 / 2.8 | 94.7% / 4.19 / 4.5 |
| Link first, aim upstream | 100.0% / 3.67 | 100.0% / 3.89 / 1.6 | 99.8% / 3.95 / 2.0 |
| Launch owned first | 100.0% / 4.25 | 96.4% / 4.58 / 4.8 | 64.9% / 5.00 / 7.8 |

The Tail trial is unchanged (no drain): 100% for every policy.

(Measured with the full-height field and the drain at x 48. A first version, with a 120-row field and the drain at x 56, was a little harsher: link-first 98.9% at step 24 and 90.3% at 32, launch-first 95.0% and 50.0%.)

**Reading:** the drain is the first version with stakes. Hoarding is punished (launch-first loses 3.6% at step 24, a third of its runs at 32), and aiming against the flow is a skill (it drains about 40% fewer stars and loses almost nothing: at step 32, 99.8% against 94.7%). At the shipped step 24 the stakes are still mild; step 32 is the more interesting what-if, but `currents.step` also drives the Tail trial, so it is left at 24 until the user decides. These bots never wait for a pair's third star or aim to rescue, so humans should sit between the policies. Human touch play is the next check: whether players see the drain coming, aim upstream on purpose and feel a drained star as their mistake.
