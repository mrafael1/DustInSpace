"""Summarise playtest logs (#89): time per tutorial step and refusals per step.

The game writes one JSON object a line to user://playtest/<timestamp>.jsonl in debug builds
(game/scenes/playtest_log.gd). On Windows, user:// is
%APPDATA%/Godot/app_userdata/<project name>/.

Usage:
    python tools/playtest/summary.py LOG_OR_DIR [LOG_OR_DIR ...]

A directory reads every *.jsonl in it. Python 3, no dependencies.
"""
import json
import pathlib
import statistics
import sys
from collections import defaultdict

REFUSAL_KINDS = ("launch", "link", "buy", "load")


def read_records(paths):
    """Every record in the given files and directories, file by file, in order."""
    files = []
    for arg in paths:
        path = pathlib.Path(arg)
        files.extend(sorted(path.glob("*.jsonl")) if path.is_dir() else [path])
    records = []
    for file in files:
        for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"skipped {file}:{number}: not JSON", file=sys.stderr)
    return files, records


def summarise(records):
    """Per step: the seconds spent each time it was left, refusals by kind, and idle gaps."""
    seconds = defaultdict(list)
    refusals = defaultdict(lambda: defaultdict(int))
    idles = defaultdict(list)
    order = []
    runs = {"won": 0, "lost": 0, "left": 0}
    for record in records:
        kind = record.get("type")
        step = record.get("step") or "(free play)"
        if kind == "step_entered" and step not in order:
            order.append(step)
        elif kind == "step_left":
            seconds[step].append(float(record.get("seconds", 0.0)))
        elif kind == "refusal":
            refusals[step][record.get("kind", "?")] += 1
        elif kind == "idle":
            idles[step].append(float(record.get("seconds", 0.0)))
        elif kind == "run_ended":
            outcome = record.get("outcome")
            if outcome in runs:
                runs[outcome] += 1
    for step in list(refusals) + list(idles):
        if step not in order:
            order.append(step)
    return order, seconds, refusals, idles, runs


def table(order, seconds, refusals, idles):
    kinds = list(REFUSAL_KINDS) + sorted({k for r in refusals.values() for k in r} - set(REFUSAL_KINDS))
    head = ["step", "n", "mean s", "median s", "max s"] + kinds + ["idle gaps", "idle s"]
    rows = [head]
    for step in order:
        times = seconds.get(step, [])
        rows.append([
            step,
            str(len(times)),
            f"{statistics.mean(times):.1f}" if times else "-",
            f"{statistics.median(times):.1f}" if times else "-",
            f"{max(times):.1f}" if times else "-",
            *[str(refusals.get(step, {}).get(kind, 0)) for kind in kinds],
            str(len(idles.get(step, []))),
            f"{sum(idles.get(step, [])):.1f}",
        ])
    widths = [max(len(row[i]) for row in rows) for i in range(len(head))]
    lines = []
    for index, row in enumerate(rows):
        lines.append("  ".join(cell.ljust(widths[i]) if i == 0 else cell.rjust(widths[i]) for i, cell in enumerate(row)))
        if index == 0:
            lines.append("  ".join("-" * w for w in widths))
    return "\n".join(lines)


def main(argv):
    if not argv:
        print(__doc__.strip())
        return 2
    files, records = read_records(argv)
    order, seconds, refusals, idles, runs = summarise(records)
    print(f"{len(files)} log(s), {len(records)} records, runs won {runs['won']} / lost {runs['lost']} / left {runs['left']}")
    print()
    print(table(order, seconds, refusals, idles))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
