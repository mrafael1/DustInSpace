#!/usr/bin/env python3
"""Monte Carlo balance check for Dust In Space.

Reads game/config/balance.json and simulates many runs with simple player policies.
Usage:
    python tools/balance/sim.py                 # 20k runs per policy
    python tools/balance/sim.py --runs 50000 --seed 1
    python tools/balance/sim.py --set packs.red.cost=6 --set combos.sequence.dust=4
The bots always take a sequence when one exists, else the most valuable triple,
so real players will do slightly worse than these numbers.

Scorpio (#40): when balance.json has scorpio.enabled, the objective is the constellation:
finishing its gaps wins, and light no longer does. The sting and the gaps are modelled without
geometry, so two assumptions stand in for aiming and scatter:
    --sting-hit P   chance a combo's last star has another star within sting reach (default 0.3)
    --gap-hit P     chance each star of an aimed pack lands in an open gap (default 0.25)
The bots combine the other stars first and build with the gap stars left over once no
combination remains. Real rates depend on the player's aim: treat the Scorpio rows as rough.
"""
import argparse, json, random, pathlib, statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]
SIZES = ("small", "medium", "big")
TRIPLE = {"small": "small_triple", "medium": "medium_triple", "big": "big_triple"}
# Scorpio's gaps to build: Scorpio.GAPS in game/core/scorpio.gd.
SEGMENTS = 4


def load(overrides):
    cfg = json.loads((ROOT / "game/config/balance.json").read_text())
    for o in overrides:
        path, val = o.split("=", 1)
        node, keys = cfg, path.split(".")
        for k in keys[:-1]:
            node = node[k]
        old = node[keys[-1]]
        if isinstance(old, bool):
            node[keys[-1]] = val.lower() == "true"
        elif isinstance(old, (int, float)):
            node[keys[-1]] = type(old)(float(val))
        else:
            node[keys[-1]] = val
    return cfg


def draw(pack):
    w = pack["weights"]
    return random.choices(SIZES, [w[s] for s in SIZES])[0]


def run(cfg, policy, build=False, sting_hit=0.3, gap_hit=0.25, segments=None):
    scorpio = cfg.get("scorpio", {})
    on = scorpio.get("enabled", False)
    segments_left = (segments or SEGMENTS) if on and build else 0
    dust, light = cfg["start_dust"], 0
    packs = ["blue"] * cfg["start_packs"]["blue"] + ["red"] * cfg["start_packs"]["red"]
    # Each star is [size, in_gap]. in_gap only matters to builders, who combine the other stars
    # first and build with the gap stars left over once no combination remains.
    sky, opened, big_bangs = [], 0, 0

    def take(size):
        for want_gap in (False, True):
            for star in sky:
                if star[0] == size and star[1] == want_gap:
                    sky.remove(star)
                    return

    while True:
        # resolve every available combination (best first)
        while True:
            sizes = [star[0] for star in sky]
            c = {s: sizes.count(s) for s in SIZES}
            if all(c.values()):
                key, used = "sequence", list(SIZES)
            else:
                best = max((s for s in SIZES if c[s] >= 3), key=lambda s: cfg["combos"][TRIPLE[s]]["dust"], default=None)
                if not best:
                    break
                key, used = TRIPLE[best], [best] * 3
            for s in used:
                take(s)
            dust += cfg["combos"][key]["dust"]
            light += cfg["combos"][key]["light"]
            if on and sky and random.random() < sting_hit:
                sky.remove(random.choice(sky))
                dust += scorpio["sting_dust"]
            if not on and light >= cfg["sun_target"]:
                return True, opened, big_bangs
        # builders keep what the combinations didn't need
        for star in [star for star in sky if star[1]]:
            if segments_left:
                sky.remove(star)
                segments_left -= 1
                dust += scorpio.get("segment_dust", 0)
                if segments_left == 0:
                    return True, opened, big_bangs
        if not packs:
            choice = policy(cfg, sky, dust)
            if choice is None:
                return False, opened, big_bangs
            dust -= cfg["packs"][choice]["cost"]
            packs.append(choice)
        kind = packs.pop(0)
        pack = cfg["packs"][kind]
        opened += 1
        if random.random() < pack["big_bang_chance"]:
            big_bangs += 1
            dust += cfg["big_bang"]["base_dust"] + cfg["big_bang"]["dust_per_cleared_star"] * len(sky)
            sky = []
        else:
            sky += [[draw(pack), bool(segments_left) and random.random() < gap_hit] for _ in range(int(pack["stars"]))]


def blue_only(cfg, sky, dust):
    return "blue" if dust >= cfg["packs"]["blue"]["cost"] else None


def red_when_affordable(cfg, sky, dust):
    if dust >= cfg["packs"]["red"]["cost"]:
        return "red"
    return "blue" if dust >= cfg["packs"]["blue"]["cost"] else None


POLICIES = {"blue only": blue_only, "red when affordable": red_when_affordable}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--set", action="append", default=[], help="override, e.g. packs.red.cost=6")
    ap.add_argument("--sting-hit", type=float, default=0.3)
    ap.add_argument("--gap-hit", type=float, default=0.25)
    ap.add_argument("--segments", type=int, default=None, help="explore a shorter or longer constellation")
    a = ap.parse_args()
    if a.seed is not None:
        random.seed(a.seed)
    cfg = load(a.set)
    print(f"{a.runs} runs per policy{' with ' + ', '.join(a.set) if a.set else ''}")
    print(f"{'policy':<30}{'win %':>7}{'packs to win':>14}{'runs w/ Big Bang':>18}")
    rows = [(name, pol, False) for name, pol in POLICIES.items()]
    if cfg.get("scorpio", {}).get("enabled"):
        print(f"scorpio on (the constellation wins): sting hit {a.sting_hit:.0%}, gap hit {a.gap_hit:.0%} (assumed)")
        rows = [(name + " + build", pol, True) for name, pol in POLICIES.items()]
    for name, pol, build in rows:
        res = [run(cfg, pol, build, a.sting_hit, a.gap_hit, a.segments) for _ in range(a.runs)]
        wins = [r for r in res if r[0]]
        packs = statistics.mean(r[1] for r in wins) if wins else float("nan")
        bb = 100 * sum(1 for r in res if r[2]) / a.runs
        print(f"{name:<30}{100 * len(wins) / a.runs:>6.1f}%{packs:>14.1f}{bb:>17.1f}%")


if __name__ == "__main__":
    main()
