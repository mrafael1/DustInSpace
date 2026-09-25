#!/usr/bin/env python3
"""Monte Carlo balance check for Dust In Space.

Reads game/config/balance.json and simulates many runs with simple player policies.
Usage:
    python tools/balance/sim.py                 # 20k runs per policy
    python tools/balance/sim.py --runs 50000 --seed 1
    python tools/balance/sim.py --set packs.red.cost=6 --set combos.sequence.dust=4
The bots always take a sequence when one exists, else the most valuable triple,
so real players will do slightly worse than these numbers.
"""
import argparse, json, random, pathlib, statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]
SIZES = ("small", "medium", "big")
TRIPLE = {"small": "small_triple", "medium": "medium_triple", "big": "big_triple"}


def load(overrides):
    cfg = json.loads((ROOT / "game/config/balance.json").read_text())
    for o in overrides:
        path, val = o.split("=", 1)
        node, keys = cfg, path.split(".")
        for k in keys[:-1]:
            node = node[k]
        node[keys[-1]] = type(node[keys[-1]])(float(val)) if isinstance(node[keys[-1]], (int, float)) else val
    return cfg


def draw(pack):
    w = pack["weights"]
    return random.choices(SIZES, [w[s] for s in SIZES])[0]


def run(cfg, policy):
    dust, light = cfg["start_dust"], 0
    packs = ["blue"] * cfg["start_packs"]["blue"] + ["red"] * cfg["start_packs"]["red"]
    sky, opened, big_bangs = [], 0, 0
    while True:
        # resolve every available combination (best first)
        while True:
            c = {s: sky.count(s) for s in SIZES}
            if all(c.values()):
                key, used = "sequence", list(SIZES)
            else:
                best = max((s for s in SIZES if c[s] >= 3), key=lambda s: cfg["combos"][TRIPLE[s]]["dust"], default=None)
                if not best:
                    break
                key, used = TRIPLE[best], [best] * 3
            for s in used:
                sky.remove(s)
            dust += cfg["combos"][key]["dust"]
            light += cfg["combos"][key]["light"]
            if light >= cfg["sun_target"]:
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
            sky += [draw(pack) for _ in range(int(pack["stars"]))]


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
    a = ap.parse_args()
    if a.seed is not None:
        random.seed(a.seed)
    cfg = load(a.set)
    print(f"{a.runs} runs per policy{' with ' + ', '.join(a.set) if a.set else ''}")
    print(f"{'policy':<22}{'win %':>7}{'packs to win':>14}{'runs w/ Big Bang':>18}")
    for name, pol in POLICIES.items():
        res = [run(cfg, pol) for _ in range(a.runs)]
        wins = [r for r in res if r[0]]
        packs = statistics.mean(r[1] for r in wins) if wins else float("nan")
        bb = 100 * sum(1 for r in res if r[2]) / a.runs
        print(f"{name:<22}{100 * len(wins) / a.runs:>6.1f}%{packs:>14.1f}{bb:>17.1f}%")


if __name__ == "__main__":
    main()
