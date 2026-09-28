# Gameplay showcase

`gameplay.gif` is an unchanged copy of the existing project recording `Claude outputs/scorpio-run.gif`, supplied in the development workspace. It is actual gameplay footage from an earlier Scorpio prototype, not the concept mockup.

- Dimensions: 360 × 640 (2× the 180 × 320 game canvas).
- Duration: approximately 22 seconds; 335 frames; loops indefinitely.
- File size: 312,041 bytes (305 KiB).
- Content: pack launches, three-star links, dust/light payouts, another pack purchase, and Scorpio completion.
- Audio: none (GIF).

The recording predates the current constellation presentation, link reach and Sun tuning. In particular, its Sun counter and completion string count must not be treated as current balance values. The README's play instructions describe the current build; `docs/design.md` and `game/config/balance.json` are the references for rules and tuning.

To refresh the showcase, record an actual run from the current main branch, include a launch → valid link → payout → purchase cycle, and export a looping GIF at an integer multiple of the native canvas using nearest-neighbour scaling. Keep it short and preferably below 1 MiB. Check the beginning, each mechanic, and the loop transition before replacing the file. Update these notes and the README caption when newer footage replaces this recording.
