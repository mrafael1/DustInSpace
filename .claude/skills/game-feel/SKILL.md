---
name: game-feel
description: Design and implement feedback, juice and reveal sequences in Dust In Space (pack launch and burst, link, collect, Sun brightening, Big Bang). Use when adding effects, animation timing, screen shake, particles or sound cues.
---

# Game feel

The game's emotional core is the slot machine's: **anticipation, then reveal, then payout**. Every player action gets an immediate, readable, satisfying reaction that still fits the pixel grid.

## Principles
1. **Every action answers within 100 ms**, even if only a 1-frame flash or a pixel nudge.
2. **Anticipation before a reveal:** a pack trembles and brightens for about 250 ms before it bursts.
3. **Payouts travel.** Dust particles fly to the dust counter and light particles fly into the Sun. The counters only increase **when the particles arrive**, and they pulse when they do.
4. **Rare means different.** The Big Bang breaks the normal rhythm through a freeze, silence and scale. Common events must never use its signature effects.
5. **Pixel-honest effects.** Particles are 1–2 px palette pixels, glows are dithered steps, and there's no blur or smooth scaling. Screen shake is in whole pixels (1–3 px) and never on UI text.
6. **Repetition-proof.** Common effects are short (under 700 ms) and never block input for more than about 400 ms. Treat anything the player sees 50 times per run as a candidate for speeding up.
7. Respect a **reduced-motion** setting: no shake, and half-length sequences.

## Reference timings (first playable)
| Event | Sequence | Duration |
|---|---|---|
| Launch | Pack flies along an arc to its target | ~430 ms |
| Tremble | Shake, grow and brighten | ~280 ms |
| Burst | Ring, spark pixels, stars scatter with an ease-out-back | ~650 ms |
| Valid link | Line and stars flare white, hold, then dissolve | ~380 ms + particles |
| Invalid link | Ember (S4) line shakes and fades; nothing is used up | ~450 ms |
| Particles to counter or Sun | Bézier path, staggered by ~28 ms each | 750–1100 ms |
| Sun gains light | Pulse, fill level rises, next ray lights | on arrival |

## Big Bang script
1. Starts **exactly like a normal burst** to keep the surprise.
2. **+260 ms:** freeze. The sky darkens to about 80% and a black hole opens at the burst point (N0 disc, C2 photon ring, the far side of its accretion disc lensed into an arc over the top, the near side crossing in front; never a ringed planet, which is the red pack). Every star (including this pack's decoy stars) spirals into it (~750 ms), with cool specks of sky dust: fast at first, then slowing and dimming (redshift) as they near the hole, where they hang, orbiting, until it swallows them in the last ~15%.
3. The hole implodes (~150 ms) into a 1–2 px white point that pulses. **Silence:** all audio ducks to zero for ~500 ms.
4. **Bang:** a hard full-screen flash for ~2 frames, then a solid white core (C1 rim) shrinking away over ~250 ms, with no dithered fade, 3 staggered shockwave rings, about 200 multi-colour pixels from the palette that streak and twinkle, a 1–3 px decaying world shake (~350 ms; the only screen shake in the game), and about 28 newborn sparkles twinkling up across the sky over ~1.2 s.
5. Dust streams to the counter, with a "BIG BANG +N" banner (large pixel type) for ~2.5 s: it pops in at 3× for a frame, settles at 2×, shimmers C0/C1, and rolls its +N up from 0 like a slot payout.
6. Input returns about 1.1 s after the bang.
The debug key **B** forces the next pack to be a Big Bang.

## Sun ignition (win)
The fill completes and all rays light. The halo switches from the S ramp to the C ramp, the sky warms over ~1.8 s, then the win screen appears. Until then the unlit Sun smoulders on a 2-frame tick (0.5 s): embers swap S3/S4 and the dim halo thins by one dither step. Once ignited it idles on the same tick: every other ray loses its tip in turn and the core's C0 glint moves a pixel; the sky glow holds still. It never rotates or scales.
