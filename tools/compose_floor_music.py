"""Render the seven original looping scores. Offline tool: Python + FFmpeg only."""
from __future__ import annotations

from array import array
import math
from pathlib import Path
import random
import shutil
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
TAU = math.tau

# Eight-bar melodies, eighth-note steps; the second phrase changes orchestration.
# Chords are explicit MIDI voicings so each location has its own harmonic identity.
SCORES = {
    "office": dict(bpm=112, voice="keys", backing="keys", meter=8,
        chords=[(48,52,55,59),(45,48,52,55),(50,53,57,60),(43,47,50,53),
                (48,52,55,59),(52,55,59,62),(53,57,60,64),(43,47,50,53)],
        melody=[(76,0,79,81,0,79,76,74),(72,0,76,79,0,76,72,0),
                (74,77,0,81,79,0,77,74),(71,0,74,77,0,74,71,0),
                (76,79,84,0,83,81,79,76),(79,0,83,86,0,83,79,0),
                (81,79,77,0,76,77,81,0),(79,77,74,71,0,74,0,0)]),
    "workshop": dict(bpm=128, voice="metal", backing="pluck", meter=8,
        chords=[(38,45,50),(38,45,53),(34,41,46),(36,43,48),
                (38,45,50),(41,48,53),(43,50,55),(33,40,49)],
        melody=[(62,0,69,62,65,0,69,0),(62,65,0,69,72,69,65,0),
                (70,0,65,62,0,65,70,0),(67,0,63,60,67,63,60,0),
                (74,0,69,74,77,74,69,0),(72,69,65,0,72,0,77,0),
                (74,70,67,0,70,67,62,0),(73,0,69,64,61,0,64,0)]),
    "server": dict(bpm=132, voice="synth", backing="pad", meter=8,
        chords=[(40,47,55),(36,43,52),(43,50,59),(38,45,54),
                (40,47,55),(36,43,52),(45,52,60),(35,42,51)],
        melody=[(76,83,79,83,74,83,79,83),(76,79,84,79,74,79,84,79),
                (79,86,83,86,78,86,83,86),(78,81,86,81,76,81,86,81),
                (88,83,79,83,86,83,79,83),(84,79,76,79,83,79,76,79),
                (81,88,84,88,79,88,84,88),(83,78,75,78,81,78,75,0)]),
    "garden": dict(bpm=92, voice="bell", backing="pad", meter=6,
        chords=[(45,52,60),(41,48,57),(48,55,64),(43,50,59),
                (45,52,60),(50,57,65),(41,48,57),(40,47,56)],
        melody=[(81,0,84,83,0,76),(77,0,81,79,0,72),(79,0,84,88,0,86),
                (83,0,79,74,0,0),(84,83,81,0,76,79),(81,0,86,89,0,88),
                (84,0,81,77,0,79),(80,0,83,76,0,0)]),
    "wilds": dict(bpm=106, voice="flute", backing="pluck", meter=6,
        chords=[(50,57,62),(43,50,59),(48,55,60),(50,57,62),
                (46,53,62),(48,55,64),(43,50,59),(45,52,61)],
        melody=[(74,76,77,81,0,77),(79,0,74,71,74,0),(76,79,84,83,79,76),
                (77,76,74,0,69,0),(77,81,82,86,0,82),(84,79,76,79,0,76),
                (79,81,79,74,71,74),(73,76,81,79,76,0)]),
    "sumo": dict(bpm=104, voice="koto", backing="koto", meter=8,
        chords=[(38,45,50),(38,45,53),(36,43,48),(38,45,50),
                (34,41,46),(36,43,48),(38,45,50),(33,40,45)],
        melody=[(62,0,65,67,0,69,0,0),(74,0,69,67,65,0,62,0),
                (72,0,67,65,0,60,0,0),(62,65,67,0,69,0,74,0),
                (77,0,74,70,0,65,0,0),(72,0,67,72,0,74,72,0),
                (74,69,67,65,0,62,65,0),(64,0,69,67,64,0,61,0)]),
    "castle": dict(bpm=118, voice="organ", backing="strings", meter=8,
        chords=[(45,52,57),(41,48,57),(50,57,62),(40,47,56),
                (45,52,60),(48,55,64),(41,48,57),(40,47,56)],
        melody=[(69,0,72,76,81,0,79,76),(77,0,76,72,69,0,72,0),
                (74,0,77,81,86,84,81,77),(80,0,76,71,68,0,71,0),
                (81,0,84,88,86,84,83,81),(79,0,84,88,91,88,84,0),
                (89,88,84,81,77,0,81,84),(83,0,80,76,71,0,68,0)]),
}


class Renderer:
    def __init__(self, duration: float, seed: int):
        self.frames = round(duration * RATE)
        self.left = array("f", [0.0]) * self.frames
        self.right = array("f", [0.0]) * self.frames
        self.rng = random.Random(seed)
        self.cache = {}

    def note(self, at, midi, duration, voice, gain, pan=0.0):
        if not midi:
            return
        frequency = 440.0 * 2 ** ((midi - 69) / 12)
        # Cache samples across phrases, with independently placed stereo voices.
        key = (midi, round(duration, 4), voice)
        if key not in self.cache:
            sound = array("f")
            length = duration + (0.65 if voice in ("bell", "keys", "koto", "pluck", "metal") else 0.12)
            for i in range(round(length * RATE)):
                t = i / RATE
                phase = TAU * frequency * t
                attack = min(1.0, t / (0.06 if voice in ("pad", "strings", "flute") else 0.006))
                release = min(1.0, max(0.0, (length - t) / 0.1))
                if voice == "keys":
                    value = math.sin(phase + 1.2 * math.sin(phase * 2) * math.exp(-t * 7))
                    envelope = math.exp(-t * 4)
                elif voice in ("pluck", "koto"):
                    value = sum(math.sin(phase * h) * math.exp(-t * h * 2.5) / h for h in range(1, 7)) / 1.5
                    envelope = math.exp(-t * (4 if voice == "koto" else 2.5))
                elif voice in ("bell", "metal"):
                    ratio = 2.76 if voice == "bell" else 3.49
                    value = math.sin(phase + 1.6 * math.sin(phase * ratio) * math.exp(-t * 5))
                    envelope = math.exp(-t * (3 if voice == "bell" else 7))
                elif voice == "flute":
                    vibrato = 0.015 * math.sin(TAU * 5 * t) * min(1.0, t * 3)
                    value = (math.sin(phase + vibrato) + 0.15 * math.sin(phase * 2) + 0.06 * self.rng.uniform(-1, 1)) / 1.2
                    envelope = min(1.0, max(0.0, (duration - t) / 0.12))
                elif voice == "bass":
                    value = (math.sin(phase) + 0.23 * math.sin(phase * 2)) / 1.2
                    envelope = math.exp(-t * 2.2)
                elif voice == "organ":
                    value = (math.sin(phase) + 0.5 * math.sin(phase * 2) + 0.22 * math.sin(phase * 3) + 0.13 * math.sin(phase * 4)) / 1.6
                    envelope = min(1.0, max(0.0, (duration - t) / 0.08))
                elif voice == "synth":
                    value = math.sin(phase + 0.8 * math.sin(phase * 2) * math.exp(-t * 14))
                    envelope = math.exp(-t * 8)
                else:
                    detune = 1.004 if voice == "strings" else 1.002
                    value = (math.sin(phase) + math.sin(phase * detune) + 0.25 * math.sin(phase * 2)) / 2.2
                    envelope = min(1.0, max(0.0, (duration - t) / 0.2))
                sound.append(value * envelope * attack * release)
            self.cache[key] = sound
        self.place(at, self.cache[key], gain, pan)

    def place(self, at, sound, gain, pan):
        start = round(at * RATE)
        left_gain = gain * math.sqrt((1 - pan) / 2)
        right_gain = gain * math.sqrt((1 + pan) / 2)
        for i, value in enumerate(sound):
            index = (start + i) % self.frames
            self.left[index] += value * left_gain
            self.right[index] += value * right_gain

    def drum(self, at, kind, gain, pan=0.0):
        if kind not in self.cache:
            length = {"kick":0.35, "snare":0.22, "hat":0.09, "wood":0.12, "taiko":0.8, "shaker":0.12}[kind]
            sound = array("f")
            low = 0.0
            for i in range(round(length * RATE)):
                t = i / RATE
                noise = self.rng.uniform(-1, 1)
                low += (noise - low) * 0.15
                if kind in ("kick", "taiko"):
                    base, sweep, decay = (48, 95, 12) if kind == "kick" else (67, 58, 5)
                    phase = TAU * (base * t + sweep * (1 - math.exp(-t * 25)) / 25)
                    value = math.sin(phase) * math.exp(-t * decay)
                    if kind == "taiko":
                        value += 0.28 * math.sin(phase * 1.48) * math.exp(-t * 9)
                    value += noise * math.exp(-t * 90) * 0.2
                elif kind == "snare":
                    value = (noise - low) * math.exp(-t * 23) * 0.65 + math.sin(TAU * 175 * t) * math.exp(-t * 35) * 0.3
                elif kind == "wood":
                    value = (math.sin(TAU * 840 * t) + 0.5 * math.sin(TAU * 1350 * t)) * math.exp(-t * 55)
                else:
                    value = (noise - low) * math.exp(-t * (55 if kind == "hat" else 32))
                sound.append(value * min(1.0, t * 1500) * min(1.0, (length - t) * 100))
            self.cache[kind] = sound
        self.place(at, self.cache[kind], gain, pan)

    def save(self, target, echo):
        # Circular delay carries the tail into the start, preserving the loop seam.
        dry_left, dry_right = self.left[:], self.right[:]
        for seconds, amount in [(echo, 0.17), (echo * 1.5, 0.1), (echo * 2.5, 0.055)]:
            delay = round(seconds * RATE)
            for i in range(self.frames):
                self.left[i] += dry_right[(i - delay) % self.frames] * amount
                self.right[i] += dry_left[(i - delay) % self.frames] * amount
        mean_left = sum(self.left) / self.frames
        mean_right = sum(self.right) / self.frames
        rms = math.sqrt(sum((l - mean_left) ** 2 + (r - mean_right) ** 2 for l, r in zip(self.left, self.right)) / (self.frames * 2))
        peak = max(max(abs(v - mean_left) for v in self.left), max(abs(v - mean_right) for v in self.right))
        scale = min(0.16 / rms, 0.86 / peak)
        pcm = array("h")
        for l, r in zip(self.left, self.right):
            pcm.extend((round((l - mean_left) * scale * 32767), round((r - mean_right) * scale * 32767)))
        with wave.open(str(target), "wb") as out:
            out.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
            out.writeframes(pcm.tobytes())
        assert peak * scale <= 0.861 and rms * scale > 0.08, "Unexpected mix level"


def render(style, score, target):
    step = 30 / score["bpm"]
    meter = score["meter"]
    song = Renderer(16 * meter * step, 20261114 + list(SCORES).index(style))
    for bar in range(16):
        chord = score["chords"][bar % 8]
        base = bar * meter * step
        # Open the second phrase into a higher register; return to the tonic naturally.
        for tick, midi in enumerate(score["melody"][bar % 8]):
            if style == "server" and bar < 8 and tick % 2:
                continue
            swing = step * 0.12 if style == "office" and tick % 2 else 0.0
            length = step * (1.65 if style in ("garden", "wilds", "castle") else 0.82)
            song.note(base + tick * step + swing, midi, length, score["voice"], 0.21, -0.12)
            if bar >= 8 and style == "castle":
                song.note(base + tick * step, midi - 12 if midi else 0, length, "strings", 0.075, 0.25)
        if score["backing"] in ("pad", "strings"):
            for j, midi in enumerate(chord[1:]):
                song.note(base, midi + 12, meter * step * 0.95, score["backing"], 0.065, (j - 0.5) * 0.65)
        else:
            for tick in range(0 if style in ("wilds", "sumo") else 1, meter, 2):
                for j, midi in enumerate(chord[1:]):
                    song.note(base + tick * step, midi + 12, step * 0.8, score["backing"], 0.07, 0.38 + j * 0.12)
        for tick in range(0, meter, 2):
            midi = chord[0] + (7 if tick == meter - 2 else 0)
            song.note(base + tick * step, midi - (12 if style == "server" else 0), step * 1.65, "bass", 0.21)
        for tick in range(meter):
            at = base + tick * step
            if style in ("office", "workshop", "server", "castle"):
                if tick in (0, 4) or style == "server" and tick % 2 == 0:
                    song.drum(at, "kick", 0.27)
                if tick in (2, 6):
                    song.drum(at, "snare", 0.14 if style == "office" else 0.22, 0.1)
                song.drum(at, "wood" if style == "workshop" and tick % 2 else "hat", 0.055 if style == "office" else 0.07, (-1) ** tick * 0.4)
                if style == "castle" and tick in (0, 4):
                    song.drum(at, "taiko", 0.16)
            elif style == "sumo":
                if tick in (0, 3, 4) or bar % 4 == 3 and tick in (6, 7):
                    song.drum(at, "taiko", 0.36 if tick == 0 else 0.23, -0.12)
                if tick in (2, 6):
                    song.drum(at, "wood", 0.12, 0.45)
            elif style == "wilds":
                song.drum(at, "shaker", 0.075, 0.4)
                if tick in (0, 3):
                    song.drum(at, "taiko", 0.15)
                if tick in (2, 5):
                    song.drum(at, "wood", 0.075, -0.45)
            elif tick in (0, 3):
                song.drum(at, "shaker", 0.045, 0.5)
        if style == "server" and bar >= 8:
            for tick in range(meter):
                song.note(base + tick * step, chord[tick % len(chord)] + 24, step * 0.6, "synth", 0.065, 0.5)
    song.save(target, step * (1.5 if style in ("garden", "wilds", "sumo") else 0.75))


def main():
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("FFmpeg is required to regenerate the Ogg assets.")
    output = ROOT / "assets/audio/music"
    temp = ROOT / ".tools/music"
    output.mkdir(parents=True, exist_ok=True)
    temp.mkdir(parents=True, exist_ok=True)
    for style, score in SCORES.items():
        wav = temp / f"{style}.wav"
        render(style, score, wav)
        subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5",
                        "-metadata", f"title=Yichuan - {style}", "-metadata", "artist=Yichuan original synthesized score",
                        str(output / f"{style}.ogg")], check=True)
        print(f"Rendered {style}: {16 * score['meter'] * 30 / score['bpm']:.2f}s", flush=True)


if __name__ == "__main__":
    main()
