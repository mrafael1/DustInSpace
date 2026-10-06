"""Summarise playtest logs (#89): time per tutorial step, refusals per step, and per stage the
runs' outcomes, durations, packs and stars.

The game writes one JSON object a line to user://playtest/<timestamp>.jsonl in debug builds
(game/scenes/playtest_log.gd). On Windows, user:// is
%APPDATA%/Godot/app_userdata/<project name>/.
Web playtest: with an endpoint set, every build also sends each record to a Google Sheet
(tools/playtest/apps_script.gs). Download the sheet as CSV (File > Download > .csv) and pass it
here: its "json" column holds the records.

Usage:
    python tools/playtest/summary.py LOG_OR_DIR_OR_CSV [...]

A directory reads every *.jsonl and *.csv in it. Python 3, no dependencies.
"""
import csv
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
        files.extend(sorted(path.glob("*.jsonl")) + sorted(path.glob("*.csv")) if path.is_dir() else [path])
    records = []
    for file in files:
        if file.suffix.lower() == ".csv":
            records.extend(read_csv(file))
            continue
        for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"skipped {file}:{number}: not JSON", file=sys.stderr)
    return files, records


def read_csv(file):
    """The records in a sheet exported as CSV: one JSON record a row, in its "json" column."""
    records = []
    with file.open(encoding="utf-8", newline="") as handle:
        for number, row in enumerate(csv.DictReader(handle), 2):
            try:
                records.append(json.loads(row.get("json") or ""))
            except json.JSONDecodeError:
                print(f"skipped {file}:{number}: no JSON record", file=sys.stderr)
    return records


def stages(records):
    """Per stage, from each run_ended: outcomes, seconds, packs used and stars linked."""
    ended = defaultdict(list)
    for record in records:
        if record.get("type") == "run_ended":
            ended[record.get("stage", "?")].append(record)
    head = ["stage", "runs", "players", "won", "lost", "left", "win %", "median s", "median packs", "median stars"]
    rows = [head]
    for stage, runs in ended.items():
        outcomes = [r.get("outcome") for r in runs]
        finished = outcomes.count("won") + outcomes.count("lost")

        def median(key):
            values = [float(r[key]) for r in runs if key in r]
            return f"{statistics.median(values):.0f}" if values else "-"

        rows.append([
            stage,
            str(len(runs)),
            str(len({r.get("session") for r in runs if r.get("session")})),
            str(outcomes.count("won")),
            str(outcomes.count("lost")),
            str(outcomes.count("left")),
            f"{100 * outcomes.count('won') / finished:.0f}" if finished else "-",
            median("seconds"),
            median("packs_used"),
            median("stars_linked"),
        ])
    return format_rows(rows)


def format_rows(rows):
    """Rows of cells as aligned columns: the first left-aligned, the rest right; a rule under the head."""
    widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
    lines = []
    for index, row in enumerate(rows):
        lines.append("  ".join(cell.ljust(widths[i]) if i == 0 else cell.rjust(widths[i]) for i, cell in enumerate(row)))
        if index == 0:
            lines.append("  ".join("-" * w for w in widths))
    return "\n".join(lines)


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
    return format_rows(rows)


def main(argv):
    if not argv:
        print(__doc__.strip())
        return 2
    files, records = read_records(argv)
    order, seconds, refusals, idles, runs = summarise(records)
    print(f"{len(files)} log(s), {len(records)} records, runs won {runs['won']} / lost {runs['lost']} / left {runs['left']}")
    print()
    print(table(order, seconds, refusals, idles))
    print()
    print(stages(records))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
