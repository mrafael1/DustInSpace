"""Builds the game's sound effects into assets/audio/*.wav.

Soft chiptune: square and triangle voices with gentle envelopes, bell-like chimes for payouts,
filtered noise for air and impacts. Everything is synthesized here, so the sounds are ours
(see assets/audio/LICENSE.md) and a tweak is one rebuild away. Python 3, no dependencies.
Seeded, so a rebuild gives the same samples.

Mix: each cue has a peak level in dBFS. Frequent cues (particle landings, star taps) sit low;
rare ones (Big Bang, ignition, win) get the headroom. Nothing peaks above -1 dBFS, so several
voices at once stay clear of clipping once the game's voice limits apply.

    python tools/audio/build_sfx.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
rng = random.Random(0xD057)


# --- voices -------------------------------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def tone(freq, seconds, shape="triangle", freq_end=None, duty=0.5, vibrato=0.0, vib_rate=6.0):
    """One voice, its pitch gliding exponentially from freq to freq_end."""
    n = int(seconds * RATE)
    freq_end = freq if freq_end is None else freq_end
    out = []
    phase = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        f = freq * (freq_end / freq) ** k
        f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * i / RATE)
        phase = (phase + f / RATE) % 1.0
        if shape == "square":
            s = 1.0 if phase < duty else -1.0
        elif shape == "sine":
            s = math.sin(2 * math.pi * phase)
        else:
            s = 4.0 * abs(phase - 0.5) - 1.0
        out.append(s)
    return out


def noise(seconds, cutoff=4000.0, cutoff_end=None):
    """White noise through a one-pole low-pass whose cutoff glides from cutoff to cutoff_end."""
    n = int(seconds * RATE)
    cutoff_end = cutoff if cutoff_end is None else cutoff_end
    out = []
    y = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        c = cutoff * (cutoff_end / cutoff) ** k
        a = 1.0 - math.exp(-2 * math.pi * c / RATE)
        y += a * (rng.uniform(-1.0, 1.0) - y)
        out.append(y * 1.8)
    return out


def envelope(samples, attack=0.005, release=None, curve=2.0, hold=0.0):
    """Linear attack, optional flat hold, then a curved decay to silence at the end."""
    n = len(samples)
    a = max(int(attack * RATE), 1)
    h = int(hold * RATE)
    out = []
    for i, s in enumerate(samples):
        if i < a:
            g = i / a
        elif i < a + h:
            g = 1.0
        else:
            k = (i - a - h) / max(n - a - h, 1)
            g = (1.0 - k) ** curve
        out.append(s * g)
    if release:
        r = min(int(release * RATE), n)
        for i in range(r):
            out[n - r + i] *= 1.0 - i / r
    return out


def tremolo(samples, rate, depth):
    return [s * (1.0 - depth * 0.5 * (1.0 + math.sin(2 * math.pi * rate * i / RATE))) for i, s in enumerate(samples)]


def mix(*layers):
    """Sums (offset_seconds, samples, gain) layers."""
    n = max(int(o * RATE) + len(s) for o, s, _ in layers)
    out = [0.0] * n
    for offset, samples, gain in layers:
        start = int(offset * RATE)
        for i, s in enumerate(samples):
            out[start + i] += s * gain
    return out


def bell(freq, seconds, gain=1.0):
    """A soft chime: triangle fundamental, a quiet sine octave and a hint of a fifth above."""
    return envelope(mix(
        (0, tone(freq, seconds), 1.0),
        (0, tone(freq * 2, seconds, "sine"), 0.35),
        (0, tone(freq * 3, seconds * 0.5, "sine"), 0.12),
    ), attack=0.003, curve=2.5)


def note(name):
    """Equal-tempered pitch, e.g. note('C5')."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = steps[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semis / 12)


def arpeggio(names, step, length, gain=1.0):
    return mix(*[(i * step, bell(note(n), length), gain) for i, n in enumerate(names)])


# --- cues ---------------------------------------------------------------------------------
# Each returns raw samples; CUES gives its peak level.

def pack_load():
    return envelope(tone(note("A5"), 0.05, "square", note("E6"), duty=0.25), attack=0.002)


def pack_buy():
    return mix(
        (0, envelope(tone(note("B5"), 0.07, "square", duty=0.25), attack=0.002), 1.0),
        (0.06, bell(note("E6"), 0.25), 1.0),
    )


def pack_ready():
    # With the slot's flash and sparkle: two quick rising chimes, a tiny "ding-ding".
    return mix((0, bell(note("E6"), 0.18), 0.8), (0.07, bell(note("B6"), 0.28), 1.0))


def tap_refused():
    return envelope(tone(170, 0.12, "square", 140, duty=0.3), attack=0.004, curve=1.5)


def pull_start():
    return envelope(tone(note("E4"), 0.04, "triangle", note("A4")), attack=0.002)


def pull_step():
    # A tight creak, pitched up per step by the game.
    return envelope(mix((0, tone(note("A4"), 0.05, "square", duty=0.2), 0.6), (0, noise(0.05, 3000), 0.3)), attack=0.002)


def pull_cancel():
    return envelope(tone(note("A4"), 0.14, "triangle", note("A3")), attack=0.004, curve=1.5)


def launch():
    return mix(
        (0, envelope(noise(0.38, 400, 3000), attack=0.03, curve=1.2), 0.7),
        (0, envelope(tone(180, 0.36, "triangle", 620), attack=0.01, curve=1.0), 0.5),
    )


def tremble():
    # Anticipation: a rattle that tightens and rises for the tremble's 0.28 s.
    rattle = tremolo(tone(note("E4"), 0.28, "square", note("B4"), duty=0.25), 28, 0.8)
    return envelope(mix((0, rattle, 0.6), (0, noise(0.28, 1500, 5000), 0.3)), attack=0.2, curve=0.6, release=0.02)


def burst():
    return mix(
        (0, envelope(noise(0.08, 6000, 800), attack=0.001, curve=2), 1.0),
        (0, envelope(tone(note("C4"), 0.09, "square", note("C3"), duty=0.3), attack=0.001), 0.5),
        (0.04, arpeggio(["C6", "E6", "G6"], 0.05, 0.35), 0.5),
    )


def star_select():
    # The game raises its pitch for each star in the link.
    return bell(note("C6"), 0.2)


def link_collect():
    return mix(
        (0, arpeggio(["G5", "C6", "E6", "G6"], 0.04, 0.45), 0.6),
        (0, envelope(noise(0.25, 8000, 2000), attack=0.002, curve=3), 0.15),
    )


def link_reject():
    return envelope(mix(
        (0, tone(note("E3"), 0.36, "square", note("C3"), duty=0.4, vibrato=0.03, vib_rate=12), 0.6),
        (0, tone(note("F3"), 0.36, "triangle", note("C#3")), 0.5),
    ), attack=0.006, curve=1.6)


def drain():
    # A star sucked out of the sky by Aquarius's drain (0.4 s): a hard thump, a gulp of filtered
    # water noise sinking fast, and a short whistle falling away down the plughole.
    return mix(
        (0, envelope(tone(140, 0.16, "sine", 45), attack=0.001, curve=2.2), 1.0),
        (0, envelope(tone(note("C3"), 0.08, "square", note("C2"), duty=0.35), attack=0.001, curve=2), 0.45),
        (0.01, envelope(noise(0.22, 3200, 220), attack=0.002, curve=1.8), 0.7),
        (0.03, envelope(tone(note("A5"), 0.3, "triangle", note("A3"), vibrato=0.015, vib_rate=18), attack=0.004, curve=1.5), 0.35),
    )


def dust_land():
    # A tiny coin tick; the game climbs its pitch across a payout.
    return mix(
        (0, envelope(tone(note("E6"), 0.035, "square", duty=0.25), attack=0.001), 0.6),
        (0.025, envelope(tone(note("B6"), 0.06, "triangle"), attack=0.001), 0.8),
    )


def light_land():
    return mix((0, bell(note("G5"), 0.3), 0.8), (0, bell(note("D6"), 0.3), 0.4))


def big_bang_collapse():
    # Freeze to implosion (0.9 s): everything drawn in, pitch sinking, then cut dead.
    n = 0.9
    return envelope(mix(
        (0, noise(n, 6000, 150), 0.6),
        (0, tone(900, n, "triangle", 45, vibrato=0.02, vib_rate=20), 0.6),
        (0, tone(450, n, "sine", 30), 0.4),
    ), attack=0.35, curve=0.4, release=0.015)


def big_bang_bang():
    boom = envelope(tone(70, 1.6, "sine", 32), attack=0.002, curve=2.2)
    crack = envelope(noise(0.5, 9000, 500), attack=0.001, curve=2.5)
    crunch = envelope(tone(110, 0.3, "square", 50, duty=0.35), attack=0.001, curve=2)
    shimmer = arpeggio(["C6", "G6", "C7", "E7", "G7", "C7", "E7", "G7"], 0.09, 0.5)
    return mix((0, boom, 1.0), (0, crack, 0.8), (0, crunch, 0.35), (0.12, shimmer, 0.25))


def sun_ignite():
    swell = envelope(mix(
        (0, tone(note("C4"), 1.8, "triangle", note("C5")), 0.5),
        (0, tone(note("G4"), 1.8, "triangle", note("G5")), 0.35),
        (0, noise(1.8, 500, 7000), 0.15),
    ), attack=1.2, curve=1.2)
    return mix((0, swell, 1.0), (1.2, arpeggio(["C6", "E6", "G6", "C7"], 0.06, 0.6), 0.4))


def win():
    return mix(
        (0, arpeggio(["C5", "E5", "G5", "C6"], 0.11, 0.5), 0.6),
        (0.44, envelope(mix((0, tone(note("C5"), 0.9), 0.4), (0, tone(note("E5"), 0.9), 0.3),
                            (0, tone(note("G5"), 0.9), 0.3), (0, tone(note("C6"), 0.9, "sine"), 0.3)),
                        attack=0.01, curve=1.8), 1.0),
    )


def loss():
    return mix(
        (0, envelope(tone(note("A4"), 0.38, "triangle", vibrato=0.01), attack=0.01, curve=1.3), 0.6),
        (0.34, envelope(tone(note("F4"), 0.38, "triangle", vibrato=0.01), attack=0.01, curve=1.3), 0.6),
        (0.68, envelope(tone(note("D4"), 0.9, "triangle", note("C#4"), vibrato=0.012), attack=0.01, curve=1.5), 0.6),
    )


def restart():
    return mix(
        (0, envelope(tone(note("C5"), 0.12, "square", note("C6"), duty=0.25), attack=0.003), 0.5),
        (0.08, bell(note("G6"), 0.25), 0.4),
    )


# name -> (builder, peak dBFS)
CUES = {
    "pack_load": (pack_load, -14),
    "pack_buy": (pack_buy, -10),
    "pack_ready": (pack_ready, -13),
    "tap_refused": (tap_refused, -16),
    "pull_start": (pull_start, -18),
    "pull_step": (pull_step, -18),
    "pull_cancel": (pull_cancel, -16),
    "launch": (launch, -12),
    "tremble": (tremble, -14),
    "burst": (burst, -8),
    "star_select": (star_select, -14),
    "link_collect": (link_collect, -8),
    "link_reject": (link_reject, -12),
    "drain": (drain, -7),
    "dust_land": (dust_land, -18),
    "light_land": (light_land, -18),
    "big_bang_collapse": (big_bang_collapse, -6),
    "big_bang_bang": (big_bang_bang, -1),
    "sun_ignite": (sun_ignite, -4),
    "win": (win, -5),
    "loss": (loss, -8),
    "restart": (restart, -12),
}


def normalised(samples, peak_db):
    peak = max(abs(s) for s in samples) or 1.0
    gain = 10 ** (peak_db / 20) / peak
    # A 3 ms fade in and out: no clicks at either end.
    fade = int(0.003 * RATE)
    out = [s * gain for s in samples]
    for i in range(min(fade, len(out))):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def write(path, samples):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, round(s * 32767)))) for s in samples))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (build, peak_db) in CUES.items():
        rng.seed(sum(map(ord, name)))  # per cue, so editing one never shifts another
        samples = normalised(build(), peak_db)
        write(OUT / f"{name}.wav", samples)
        print(f"wrote assets/audio/{name}.wav  {len(samples) / RATE:.2f} s  peak {peak_db} dBFS")


if __name__ == "__main__":
    main()
