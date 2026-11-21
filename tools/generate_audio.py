#!/usr/bin/env python3
"""Reproducible original arcade pinball SFX; no external audio, libraries or licenses.

Run: python3 tools/generate_audio.py
Writes mono 24 kHz/16-bit WAVs to assets/audio/, including styled bumper hits,
plunger, physical mechanisms, and bonus fanfares.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 24000
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


class Sfx:
    def __init__(self, duration: float, seed: int):
        self.samples = [0.0] * int(duration * RATE)
        self.random = random.Random(seed)

    def tone(self, start: float, duration: float, f0: float, f1: float,
             gain: float = 0.35, harmonics: tuple[float, ...] = (1.0,),
             decay: float = 4.0, attack: float = 0.003, vibrato: float = 0.0):
        first = int(start * RATE)
        count = int(duration * RATE)
        for j in range(count):
            i = first + j
            if i >= len(self.samples):
                break
            t = j / RATE
            q = t / duration
            # Integrated linear frequency sweep ensures no discontinuous phase.
            phase = 2 * math.pi * (f0 * t + (f1 - f0) * t * q / 2)
            phase += vibrato * math.sin(t * 27.0)
            env = min(1.0, t / attack) if attack else 1.0
            env *= math.exp(-decay * t / duration)
            env *= min(1.0, (duration - t) / 0.016)
            value = 0.0
            for h, mix in enumerate(harmonics, start=1):
                value += math.sin(phase * h) * mix
            self.samples[i] += gain * env * value
        return self

    def grit(self, start: float, duration: float, gain: float = 0.15,
             decay: float = 12.0):
        first = int(start * RATE)
        count = int(duration * RATE)
        previous = 0.0
        for j in range(count):
            i = first + j
            if i >= len(self.samples):
                break
            t = j / RATE
            noise = self.random.uniform(-1.0, 1.0)
            # High-pass: metallic contact without a loud bass rumble.
            bright = noise - previous * 0.72
            previous = noise
            env = math.exp(-decay * t / duration)
            self.samples[i] += gain * bright * env
        return self

    def echo(self, delay: float = 0.036, amount: float = 0.14):
        offset = int(delay * RATE)
        for i in range(offset, len(self.samples)):
            self.samples[i] += self.samples[i - offset] * amount
        return self

    def save(self, name: str):
        peak = max(0.001, max(abs(x) for x in self.samples))
        # Normalize while retaining ~3 dB headroom for simultaneous hits.
        factor = 0.66 / peak
        raw = bytearray()
        for sample in self.samples:
            raw.extend(struct.pack("<h", int(max(-1, min(1, sample * factor)) * 32767)))
        with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
            file.setnchannels(1)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(raw)


def compose():
    OUT.mkdir(parents=True, exist_ok=True)
    (Sfx(0.48, 1).grit(0, 0.09, 0.65)
     .tone(0, 0.29, 95, 60, 0.52, (1, 0.23), decay=7)
     .tone(0.045, 0.40, 185, 760, 0.58, (1, 0.25), decay=2.4)
     .grit(0.19, 0.06, 0.18).echo().save("launch"))

    (Sfx(0.15, 2).grit(0, 0.07, 0.58)
     .tone(0, 0.12, 210, 100, 0.46, (1, .4, .15), decay=9)
     .tone(.025, .09, 930, 510, .32, (1, .3), decay=10).save("flipper"))

    (Sfx(.15, 3).grit(0, .052, .24)
     .tone(.002, .14, 1050, 650, .24, (1, .4, .12), decay=8)
     .tone(.01, .12, 1650, 970, .14, (1, .2), decay=9).save("rail"))

    (Sfx(.49, 4).tone(0, .48, 830, 560, .49, (1, .24, .12), decay=3)
     .tone(.018, .42, 1250, 1000, .29, (1, .22), decay=3.6)
     .tone(.045, .30, 1660, 1280, .14, (1,), decay=3)
     .grit(0, .025, .17).echo(.060, .19).save("bumper_celestial"))

    (Sfx(.32, 5).tone(0, .31, 330, 1850, .65, (1, .5, .21), decay=4)
     .tone(.02, .24, 1800, 290, .31, (1, .34), decay=5)
     .grit(0, .10, .35).echo(.023, .1).save("bumper_neon"))

    (Sfx(.47, 6).grit(0, .14, .5)
     .tone(0, .46, 515, 493, .44, (1, .36, .11), decay=4)
     .tone(.01, .40, 780, 760, .31, (1, .3), decay=4.5)
     .tone(.02, .3, 1290, 1200, .19, (1, .15), decay=5)
     .echo(.045, .16).save("bumper_clockwork"))

    (Sfx(.88, 7).tone(0, .83, 180, 980, .56, (1, .35), decay=2.2, vibrato=.35)
     .tone(.10, .68, 330, 1450, .34, (1, .32), decay=2.8, vibrato=.4)
     .tone(.25, .52, 1240, 350, .23, (1, .26), decay=3)
     .echo(.060, .20).save("portal"))

    (Sfx(.52, 8).tone(0, .50, 105, 54, .57, (1, .32, .19), decay=2.6, vibrato=.5)
     .tone(.06, .40, 290, 174, .25, (1, .35), decay=3.0)
     .echo(.08, .12).save("gravity"))

    (Sfx(.38, 9).grit(0, .12, .6)
     .tone(0, .35, 230, 115, .51, (1, .5, .2), decay=5)
     .tone(.025, .28, 1100, 780, .29, (1, .35), decay=5)
     .echo(.05, .13).save("gate"))

    (Sfx(.38, 10).grit(0, .12, .43)
     .tone(0, .34, 380, 300, .47, (1, .38), decay=4)
     .tone(.04, .29, 745, 590, .3, (1, .35), decay=4.3)
     .echo(.038, .11).save("gear"))

    (Sfx(.65, 11).tone(0, .56, 270, 920, .48, (1, .32), decay=2)
     .tone(.08, .46, 550, 1460, .31, (1, .24), decay=2.6)
     .grit(.0, .04, .21).echo(.06, .12).save("boost"))

    award = Sfx(.90, 12)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        award.tone(i * .13, .39, f, f * .998, .48, (1, .26, .09), decay=2.5)
    award.echo(.085, .19).save("award")

    jackpot = Sfx(1.28, 13)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98)):
        jackpot.tone(i * .105, .50, f, f * 1.008, .39,
                     (1, .26, .12), decay=2)
    jackpot.tone(.64, .59, 261.6, 261.6, .3,
                 (1, .35, .22), decay=1.7).echo(.09, .20).save("jackpot")

    multiball = Sfx(1.07, 14).grit(0, .11, .25)
    for i, f in enumerate((220, 330, 440, 660, 880)):
        multiball.tone(i * .115, .46, f, f * 1.16, .43,
                       (1, .34), decay=2.5)
    multiball.echo(.075, .17).save("multiball")

    (Sfx(.60, 15).tone(0, .57, 390, 80, .53, (1, .34, .14), decay=2.4)
     .grit(0, .09, .22).echo(.05, .10).save("drain"))

    (Sfx(.75, 16).tone(0, .29, 720, 1120, .45, (1, .3), decay=2)
     .tone(.16, .34, 1020, 1520, .5, (1, .22), decay=2)
     .tone(.36, .35, 1310, 1760, .39, (1, .24), decay=2)
     .echo(.07, .2).save("extra_ball"))

    print(f"Generated {len(list(OUT.glob('*.wav')))} original audio effects in {OUT}")


if __name__ == "__main__":
    compose()
