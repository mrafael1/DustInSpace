# Current experiment tools

Run from the repository root with Godot 4.7, after importing the project:

```powershell
godot --headless --path . --import
godot --headless --path . -s tools/currents/playtest.gd -- --runs=1000
```

The runner prints four rows and writes `tools/currents/out/results.json`. It uses paired seeds 1..N, fixed aim and greedy links, with flow off/on for each policy. It probes visible boards for gain/loss of reachable landmark links without consuming RNG or including future random stars. All tuning is loaded from balance.json. A 200-action cap is reported separately from losses. These simple bots do not predict human difficulty.

Render the crowded aim and tracing fixtures with an actual graphics driver:

```powershell
godot --path . -s tools/currents/capture.gd --resolution 180x320 --audio-driver Dummy
godot --path . -s tools/currents/capture.gd --resolution 180x390 --audio-driver Dummy
```

Images are saved as `tools/currents/out/aim-180x320.png`, `trace-180x320.png`, and equivalents for the taller screen. Output is ignored by Git. Capture launches only Main and never touches campaign progress. Results and remaining evaluation are in [the trial notes](../../docs/chapter_2_current_trial.md).
