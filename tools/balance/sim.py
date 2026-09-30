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
rekindles: back to 0 light, lights one landmark and bursts the sky's stars for sun_dust_per_star
each; the bots link every combo they can before that happens, best first. The Sun fills at
scorpio.sun_target there (sun_target without it).
Not modelled: where stars are. The bots link any stars in the sky, so scorpio.max_link_distance
(each step of a link must be at most that long) is ignored: real Scorpio runs can only do worse.
Orion (#64, the Tail map): from launch orion.first_mark_launch he keeps one random sky star marked
(a burst marks one when none is). A combo that uses it saves it; a combo that leaves it behind has it
destroyed for nothing, unless a Sun clear takes the sky first. After every combo he marks a new one.
Launches never shoot. The bots don't play around the mark: when a combo takes stars of the marked
star's size they use the others first (pessimistic), unless --orion-rescue (they use it first).
Orion's volley (#70, the Body map): every volley.interval-th combo, once it and any Sun clear
resolve, destroys a random volley.fraction of the sky's stars (rounded up) for nothing; the winning
combo skips it. The bots don't play around it (they never hold a combo back or launch first).
    --lighting-pays what-if for what a lighting combo pays: all (the game), dust, light, half,
                    minus1 (dust - 1, no light) or none
"""
import argparse, json, math, random, pathlib, statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]
SIZES = ("small", "medium", "big")
TRIPLE = {"small": "small_triple", "medium": "medium_triple", "big": "big_triple"}
# Scorpio's landmark sizes, head to stinger, and the ones lit from the start (game/core/scorpio.gd).
LANDMARK_SIZES = ("medium", "medium", "small", "small", "big", "small", "medium", "small",
                  "small", "small", "big", "small", "medium", "big")
STARTING_LIT = (0, 1, 2)
ORION = False
# The chapter's part stages play their own maps (#62, game/core/star_map.gd): --map picks one.
MAPS = {
    "scorpio": (LANDMARK_SIZES, STARTING_LIT, False),
    "stinger": (("small", "small", "medium", "small", "big", "medium"), (0,), False),
    "tail": (("medium", "small", "medium", "small", "big", "small"), (0,), True),
    "body": (("big", "medium", "big", "medium", "small", "small", "small", "medium", "small"), (0,), False),
}
# The maps where Orion looses his volley (#70).
VOLLEY_MAPS = {"body"}
VOLLEY = False
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


def run(cfg, policy, lighting_pays="all", orion_rescue=False):
    scorpio = cfg.get("scorpio", {})
    on = scorpio.get("enabled", False)
    unlit = [size for i, size in enumerate(LANDMARK_SIZES) if i not in STARTING_LIT] if on else []
    sun_full = scorpio.get("sun_target", cfg["sun_target"]) if on else cfg["sun_target"]
    dust, light = cfg["start_dust"], 0
    packs = ["blue"] * cfg["start_packs"]["blue"] + ["red"] * cfg["start_packs"]["red"]
    sky, opened, big_bangs = [], 0, 0
    # Orion: the size of the marked star, or None; and the launch he marks first (0: never).
    marked = None
    first_mark = cfg.get("orion", {}).get("first_mark_launch", 0) if on and ORION else 0
    # The volley: combos between volleys (0: none), the share it takes, and combos counted so far.
    volley_every = cfg.get("volley", {}).get("interval", 0) if on and VOLLEY else 0
    volley_share = cfg.get("volley", {}).get("fraction", 0.0)
    counted = 0
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
            # Saved when the combo has to take it (or the bots take it first, --orion-rescue).
            saved = marked is not None and marked in used and (orion_rescue or sky.count(marked) == used.count(marked))
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
                if light >= sun_full:
                    light = 0
                    dust += scorpio["sun_dust_per_star"] * len(sky)
                    sky = []
                    marked = None
                    if unlit:
                        unlit.pop(0)
                if not unlit:
                    return True, opened, big_bangs
            elif light >= cfg["sun_target"]:
                return True, opened, big_bangs
            # Orion: a combo that left the mark behind has it shot (a Sun clear took it already);
            # then he marks a new one.
            if marked is not None and not saved:
                sky.remove(marked)
            marked = None
            # Orion's volley: every volley_every-th combo destroys a share of the sky, rounded up.
            if volley_every:
                counted += 1
                if counted == volley_every:
                    counted = 0
                    for _ in range(min(math.ceil(len(sky) * volley_share - 1e-9), len(sky))):
                        sky.pop(random.randrange(len(sky)))
            if first_mark and opened >= first_mark and sky:
                marked = random.choice(sky)
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
            marked = None
        else:
            sky += [draw(pack) for _ in range(int(pack["stars"]))]
        if first_mark and opened >= first_mark and sky and marked is None:
            marked = random.choice(sky)


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
    ap.add_argument("--map", default="scorpio", choices=sorted(MAPS), help="the constellation map (scorpio.enabled)")
    ap.add_argument("--lighting-pays", default="all", choices=["all", "dust", "light", "half", "minus1", "none"],
                    help="what-if: what a combo that lights a landmark pays (the game: all)")
    ap.add_argument("--orion-rescue", action="store_true",
                    help="Orion's maps: the bots use the marked star first when a combo takes its size")
    a = ap.parse_args()
    global LANDMARK_SIZES, STARTING_LIT, ORION, VOLLEY
    LANDMARK_SIZES, STARTING_LIT, ORION = MAPS[a.map]
    VOLLEY = a.map in VOLLEY_MAPS
    if a.seed is not None:
        random.seed(a.seed)
    cfg = load(a.set)
    print(f"{a.runs} runs per policy{' with ' + ', '.join(a.set) if a.set else ''}")
    print(f"{'policy':<30}{'win %':>7}{'packs to win':>14}{'runs w/ Big Bang':>18}")
    scorpio = cfg.get("scorpio", {})
    if scorpio.get("enabled"):
        print(f"scorpio on, map {a.map} (the constellation wins), lighting pays {a.lighting_pays}, "
              f"Sun full at {scorpio.get('sun_target', cfg['sun_target'])}")
        if ORION and cfg.get("orion", {}).get("first_mark_launch"):
            print(f"  Orion marks from launch {cfg['orion']['first_mark_launch']}; the bots "
                  f"{'rescue the mark when they can' if a.orion_rescue else 'use the marked star last'}")
        if VOLLEY and cfg.get("volley", {}).get("interval"):
            print(f"  Orion's volley every {cfg['volley']['interval']} combos takes "
                  f"{cfg['volley']['fraction']:.0%} of the sky (rounded up); the bots don't play around it")
        if scorpio.get("max_link_distance"):
            print(f"  not modelled: max_link_distance {scorpio['max_link_distance']} (the bots ignore where stars are)")
    for name, pol in POLICIES.items():
        res = [run(cfg, pol, a.lighting_pays, a.orion_rescue) for _ in range(a.runs)]
        wins = [r for r in res if r[0]]
        packs = statistics.mean(r[1] for r in wins) if wins else float("nan")
        bb = 100 * sum(1 for r in res if r[2]) / a.runs
        print(f"{name:<30}{100 * len(wins) / a.runs:>6.1f}%{packs:>14.1f}{bb:>17.1f}%")


if __name__ == "__main__":
    main()
