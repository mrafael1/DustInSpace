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
lighting every landmark wins. A combo may use unlit landmarks as stars (at least one sky star in
it) and lights them; the bots always prefer a combo that lights the most landmarks. A full Sun
rekindles: back to 0 light, lights one landmark and pays dust per sky star.
    --lighting-pays what-if for what a lighting combo pays: all (the game), dust, light, half,
                    minus1 (dust - 1, no light) or none
"""
import argparse, json, random, pathlib, statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]
SIZES = ("small", "medium", "big")
TRIPLE = {"small": "small_triple", "medium": "medium_triple", "big": "big_triple"}
# Scorpio's landmark sizes, head to stinger, and the ones lit from the start (game/core/scorpio.gd).
LANDMARK_SIZES = ("medium", "big", "small", "medium", "small", "medium", "small", "big")
STARTING_LIT = (0, 1)
MAX_LANDMARKS_PER_COMBO = 1



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


def best_combo(cfg, sky, unlit):
    """The combo to take: (key, sky sizes used, landmark sizes used), or None.
    Prefers lighting the most landmarks, then a sequence, then the most dust."""
    best, best_rank = None, None
    pool = [(size, False) for size in sky] + [(size, True) for size in unlit]
    seen = set()
    for i in range(len(pool)):
        for j in range(i + 1, len(pool)):
            for k in range(j + 1, len(pool)):
                trio = sorted([pool[i], pool[j], pool[k]])
                key_t = tuple(trio)
                if key_t in seen:
                    continue
                seen.add(key_t)
                marks = sum(1 for _, landmark in trio if landmark)
                if marks > MAX_LANDMARKS_PER_COMBO:
                    continue
                sizes = [size for size, _ in trio]
                if len(set(sizes)) == 3:
                    key = "sequence"
                elif len(set(sizes)) == 1:
                    key = TRIPLE[sizes[0]]
                else:
                    continue
                rank = (marks, key == "sequence", cfg["combos"][key]["dust"])
                if best_rank is None or rank > best_rank:
                    best_rank = rank
                    best = (key, [s for s, landmark in trio if not landmark], [s for s, landmark in trio if landmark])
    return best


def run(cfg, policy, lighting_pays="all"):
    scorpio = cfg.get("scorpio", {})
    on = scorpio.get("enabled", False)
    unlit = [size for i, size in enumerate(LANDMARK_SIZES) if i not in STARTING_LIT] if on else []
    dust, light = cfg["start_dust"], 0
    packs = ["blue"] * cfg["start_packs"]["blue"] + ["red"] * cfg["start_packs"]["red"]
    sky, opened, big_bangs = [], 0, 0
    while True:
        # resolve every available combination (best first)
        while True:
            if on:
                found = best_combo(cfg, sky, unlit)
                if not found:
                    break
                key, used, lit = found
                for size in lit:
                    unlit.remove(size)
            else:
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
            # What a combo that lights a landmark pays: as usual in the game ("all"); the other
            # settings are what-ifs for the playtest (--lighting-pays).
            lights = on and bool(lit)
            reward = cfg["combos"][key]
            if not lights or lighting_pays in ("all", "dust"):
                dust += reward["dust"]
            elif lighting_pays == "half":
                dust += reward["dust"] // 2
            elif lighting_pays == "minus1":
                dust += reward["dust"] - 1
            if not lights or lighting_pays in ("all", "light"):
                light += reward["light"]
            if on:
                if light >= cfg["sun_target"]:
                    light = 0
                    dust += scorpio["sun_dust_per_star"] * len(sky)
                    if unlit:
                        unlit.pop(0)
                if not unlit:
                    return True, opened, big_bangs
            elif light >= cfg["sun_target"]:
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
    ap.add_argument("--lighting-pays", default="all", choices=["all", "dust", "light", "half", "minus1", "none"],
                    help="what-if: what a combo that lights a landmark pays (the game: all)")
    a = ap.parse_args()
    if a.seed is not None:
        random.seed(a.seed)
    cfg = load(a.set)
    print(f"{a.runs} runs per policy{' with ' + ', '.join(a.set) if a.set else ''}")
    print(f"{'policy':<30}{'win %':>7}{'packs to win':>14}{'runs w/ Big Bang':>18}")
    if cfg.get("scorpio", {}).get("enabled"):
        print(f"scorpio on (the constellation wins), lighting pays {a.lighting_pays}")
    for name, pol in POLICIES.items():
        res = [run(cfg, pol, a.lighting_pays) for _ in range(a.runs)]
        wins = [r for r in res if r[0]]
        packs = statistics.mean(r[1] for r in wins) if wins else float("nan")
        bb = 100 * sum(1 for r in res if r[2]) / a.runs
        print(f"{name:<30}{100 * len(wins) / a.runs:>6.1f}%{packs:>14.1f}{bb:>17.1f}%")


if __name__ == "__main__":
    main()
