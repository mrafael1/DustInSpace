# Chapter 2: first playable current experiment

2026-10-06. This implements the first cheap experiment from [the chapter plan](chapter_2_3_plan.md), on a debug copy of Tail geometry. **Orion is absent.** Trial wins have no campaign, tutorial or encounter save callbacks. Aquarius art, stages, campaign access, rare payout, Gemini, wells and resonance remain outside this experiment.

## Play and compare

- In the Godot editor/debug build, tap **FLOW** on the chart, or press **C**. Shift+C opens the control with flow off.
- In the trial, tap **FLOW ON/OFF**, or press **C**, to restart with the same seed and the other setting. The control is blocked during animations and while the combination table is open.
- **MAP** returns to Scorpio's chart. Ordinary Scorpio stages still use their original threats.
- CLI: `godot --path . -- --currents` (or `--currents-off`). Debug exports also expose the FLOW button. Release builds do not expose the experiment.

One leftward field covers `(64,124)` through `(171,223)` in the home layout, shifting with the map on taller screens. A successful normal launch resolves its entire pack, then shifts affected loose stars once. Strength is `currents.step` in balance.json (currently 24 native pixels). A blocked destination leaves the star in place. New stars participate; landmarks stay fixed. Buying, linking, cancelled gestures and invalid actions do not advance the flow. Forced debug Big Bangs keep the existing clearing behavior and bypass the movement step; the trial's normal Big Bang chance remains disabled.

While aiming, affected existing stars show cool brackets at their reserved destinations. The random burst remains unknown. Flow arrows remain faint; constellation strings recede during aiming; tracing keeps its existing link hints and reach feedback. Movement plays after scatter in a 300 ms integer-pixel drift. Tail's completion painting is still a placeholder, not Aquarius art.

## Verification and result

The core fixture demonstrates one launch removing a valid saved small-star link while opening a previously unreachable big-star link. Tests also cover preview purity and execution across seeds, blocked positions, bounds, one movement after red's two bursts, new-star movement, unchanged RNG, invalid actions, remaining-combo loss checks, view sequencing, mobile controls, tall-screen placement and save isolation.

Native-size crowded aiming and tracing states were rendered and inspected at **180×320** and **180×390**. A tall-screen control overlap was corrected. This is desktop screenshot review; phone interaction/readability still needs human playtesting.

The ordinary Python economy check, seed 1, 20,000 runs per policy, is unchanged:

| Policy | Before win | After win | Before / after packs to win |
|---|---:|---:|---:|
| Blue only | 100.0% | 100.0% | 7.2 / 7.2 |
| Red when affordable | 100.0% | 100.0% | 5.5 / 5.5 |

That simulator uses the full unthreatened constellation, ignores positions and cannot measure currents. It is an economy regression check, not chapter difficulty evidence.

The new [spatial runner](../tools/currents/playtest.gd) uses the actual GDScript core and paired seeds 1–1,000 on the same threat-free Tail layout, with the shipped pack odds, costs, rewards, reach and Sun. Both policies consume starting packs and buy red when affordable, otherwise blue. Both aim 12 pixels left and 18 above the first unlit landmark. Links prioritize landmarks, then dust plus light. Neither policy anticipates or aims upstream for the current.

| Spatial policy | Flow | Wins / losses / capped | Mean packs to win |
|---|---|---:|---:|
| Link every available combo first | Off | 1,000 / 0 / 0 | 3.443 |
| Link every available combo first | On | 1,000 / 0 / 0 | 3.526 |
| Launch all owned packs before linking | Off | 1,000 / 0 / 0 | 4.274 |
| Launch all owned packs before linking | On | 1,000 / 0 / 0 | 4.376 |

For flow-on runs, the runner probes visible boards immediately before launching: it applies only the exact existing-star preview temporarily, compares reachable landmark-link sets, then restores positions before opening the random pack. New arrivals are excluded from this probe.

| Spatial policy | Probed boards | Lose a landmark link | Gain a landmark link | Both in the same board | Runs with both |
|---|---:|---:|---:|---:|---:|
| Link first | 3,526 | 0 | 26 | 0 | 0 / 1,000 |
| Launch owned first | 4,376 | 1,435 | 49 | 38 | 38 / 1,000 |

**The concept has not passed the pressure gate.** The effect can help and hurt in ordinary random play, but simultaneous opportunities occur in only 3.8% of launch-first runs, and every run still wins. Linking first eliminates all measured loss of existing landmark links. This build supports human comparison; it does not justify expanding into campaign stages. The next experiment should improve the frequency and importance of the launch-or-link choice through flow/layout design before selecting chapter difficulty or adding infrastructure. No Orion fallback or economy inflation is approved.

Godot 4.7 import and startup checks passed; the full GUT suite passed **846/846 tests**. GUT still reports two float/int comparison warnings and ObjectDB/resource cleanup diagnostics at exit (385 instances, 9 resources); these are recorded separately from failed assertions.
