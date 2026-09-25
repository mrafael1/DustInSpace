---
name: balance-check
description: Change or evaluate Dust In Space tuning (pack costs, star odds, combo rewards, Big Bang, Sun target) and report its effect with the Monte Carlo simulator. Use whenever balance.json changes or the user asks whether the game is too easy or too hard.
---

# Balance check

The only source of truth is `game/config/balance.json`. The game and `tools/balance/sim.py` both read it.

## Workflow
1. **Baseline:** run `python tools/balance/sim.py --seed 1` and keep the table.
2. **Try changes without editing the file:** `python tools/balance/sim.py --seed 1 --set packs.red.cost=6 --set combos.sequence.dust=4`
3. Compare against the targets below, and only then edit `balance.json`.
4. Rerun and put a before/after table in your reply or PR.

## Targets (first playable)
| Metric | Target |
|---|---|
| Win rate, "blue only" bot | 75–90% |
| Win rate, "red when affordable" bot | within ±5 points of blue only, so both strategies stay viable |
| Packs opened in a winning run | 6–9 |
| Runs that see a Big Bang | ~15% (raise it temporarily for playtests if needed) |

The bots play perfectly, so real players will do a little worse. Aim a little easier than the feel you want.

## Design intent to protect
- **Triples** mainly pay **dust**, which buys packs. The **sequence** mainly pays **light**, which restores the Sun. Matching should never beat the sequence on light, and the sequence should never beat triples on dust.
- A triple paying at least the cost of a blue pack makes the run almost impossible to lose (the 5/8/10/8 dust experiment gave a 100% win rate).
- Red should cost more per star than blue, but be worth it for big stars. At a cost of 6 red simply dominates; at 7 it's a real choice.

## Reporting
State what changed, show the before/after table, and describe the effect in one sentence of player terms (e.g. "Red is now the obvious buy").
