#!/usr/bin/env python3
"""Generates Last Mile's original soundtrack and sound effects.

Everything is synthesized from scratch with numpy (FM electric piano, plucks,
bells, bass, pads and drum machines), then encoded to OGG Vorbis with ffmpeg.
Music loops are rendered "circularly" (notes, delay and reverb tails wrap from
the end back to the start), so every track loops seamlessly in game.

Usage:  python3 tools/make_audio.py            (writes audio/music/*.ogg, audio/sfx/*.ogg)
Needs:  numpy, ffmpeg with libvorbis
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
TAU = 2.0 * np.pi


# ----------------------------------------------------------------- basics

def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def m(name, octave):
    return 12 * (octave + 1) + NOTE[name]


def tvec(dur):
    return np.arange(int(dur * SR)) / SR


def adsr(n, a=0.005, d=0.1, s=0.7, r=0.1):
    """Envelope for n samples; release happens inside the note's length."""
    env = np.full(n, s, dtype=np.float64)
    ia, idd, ir = int(a * SR), int(d * SR), int(r * SR)
    ia = max(1, min(ia, n))
    env[:ia] = np.linspace(0, 1, ia)
    end_d = min(n, ia + idd)
    if end_d > ia:
        env[ia:end_d] = np.linspace(1, s, end_d - ia)
    ir = min(ir, n)
    if ir > 0:
        env[n - ir:] *= np.linspace(1, 0, ir)
    return env


def expdec(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def fft_filter(x, lo=None, hi=None, circular=True):
    """Gentle band filter in the frequency domain (circular = loop-safe)."""
    n = len(x)
    pad = 0 if circular else 4096
    X = np.fft.rfft(np.concatenate([x, np.zeros(pad)]))
    f = np.fft.rfftfreq(n + pad, 1.0 / SR)
    g = np.ones_like(f)
    if hi is not None:
        g *= 1.0 / np.sqrt(1.0 + (f / hi) ** 4)
    if lo is not None:
        g *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** 4)
    y = np.fft.irfft(X * g, n + pad)
    return y[:n] if circular else y[:n]


def circ_convolve(x, ir):
    n = len(x)
    h = np.zeros(n)
    k = min(len(ir), n)
    h[:k] = ir[:k]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)


def reverb_ir(seconds, seed, damp=6000.0):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    noise = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    noise = fft_filter(noise, lo=180, hi=damp, circular=False)
    noise[:int(0.012 * SR)] = 0.0   # pre-delay
    return noise / np.sqrt(np.sum(noise ** 2))


def circ_delay(x, seconds, feedback, taps=4):
    out = x.copy()
    d = int(seconds * SR)
    g = 1.0
    for k in range(1, taps + 1):
        g *= feedback
        out += np.roll(x, d * k) * g
    return out


# ----------------------------------------------------------------- instruments

def epiano(f, dur, vel=0.6):
    """FM electric piano (Rhodes-ish): bright bark that mellows out."""
    t = tvec(dur)
    n = len(t)
    idx = 1.6 * np.exp(-t * 3.5) + 0.25
    car = np.sin(TAU * f * t + idx * np.sin(TAU * f * t))
    tine = 0.18 * np.sin(TAU * f * 7.0 * t) * np.exp(-t * 18)
    trem = 1.0 + 0.08 * np.sin(TAU * 4.5 * t)
    env = adsr(n, 0.003, 0.6, 0.45, 0.08) * expdec(n, 1.2)
    return (car + tine) * env * trem * vel


def pluck(f, dur, vel=0.5, bright=1.0):
    """Additive plucked string: upper harmonics die first."""
    t = tvec(dur)
    out = np.zeros(len(t))
    for k in range(1, 9):
        if f * k > SR * 0.45:
            break
        out += (1.0 / k) * np.sin(TAU * f * k * t) * np.exp(-t * (2.5 + k * 3.0 / bright))
    return out * adsr(len(t), 0.002, 0.05, 1.0, 0.03) * vel * 0.7


def bell(f, dur, vel=0.5):
    t = tvec(dur)
    mod = np.sin(TAU * f * 1.4 * t) * (1.1 * np.exp(-t * 6))
    out = np.sin(TAU * f * t + mod) * np.exp(-t * 2.2)
    out += 0.3 * np.sin(TAU * f * 2.01 * t) * np.exp(-t * 4)
    return out * adsr(len(t), 0.001, 0.0, 1.0, 0.05) * vel


def bass(f, dur, vel=0.7, growl=0.0):
    t = tvec(dur)
    out = np.sin(TAU * f * t) + 0.35 * np.sin(TAU * 2 * f * t) * np.exp(-t * 6)
    if growl:
        out += growl * np.sign(np.sin(TAU * f * t)) * 0.25
    return out * adsr(len(t), 0.004, 0.15, 0.75, 0.04) * vel


def saw(f, t, partials=12):
    out = np.zeros(len(t))
    for k in range(1, partials + 1):
        if f * k > SR * 0.45:
            break
        out += ((-1) ** (k + 1)) / k * np.sin(TAU * f * k * t)
    return out * 0.6


def pad(freqs, dur, vel=0.25):
    t = tvec(dur)
    out = np.zeros(len(t))
    for f in freqs:
        for det in (-0.06, 0.0, 0.07):
            out += saw(f * 2 ** (det / 12), t, 8)
    out = fft_filter(out, hi=1800, circular=False)
    return out * adsr(len(t), 0.6, 0.3, 0.8, 0.7) * vel / max(1, len(freqs))


def lead(f, dur, vel=0.4, wave_kind="square"):
    t = tvec(dur)
    vib = 1.0 + 0.004 * np.sin(TAU * 5.5 * t) * np.clip(t * 3, 0, 1)
    ph = TAU * f * np.cumsum(vib) / SR
    if wave_kind == "square":
        out = sum((1.0 / k) * np.sin(k * ph) for k in (1, 3, 5, 7, 9))
    else:
        out = sum(((-1) ** (k + 1)) / k * np.sin(k * ph) for k in range(1, 10))
    return out * adsr(len(t), 0.01, 0.1, 0.7, 0.06) * vel * 0.6


def kick(vel=1.0, punch=1.0):
    t = tvec(0.35)
    f = 45 + 95 * np.exp(-t * 28 * punch)
    ph = TAU * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vel


def snare(vel=0.6, seed=1, tone=190):
    rng = np.random.default_rng(seed)
    t = tvec(0.22)
    noise = fft_filter(rng.standard_normal(len(t)), lo=1200, hi=8000, circular=False)
    body = np.sin(TAU * tone * t) * np.exp(-t * 30)
    return (noise * 0.5 * np.exp(-t * 16) + body * 0.6) * vel


def clap(vel=0.6, seed=3):
    rng = np.random.default_rng(seed)
    t = tvec(0.25)
    noise = fft_filter(rng.standard_normal(len(t)), lo=900, hi=6000, circular=False)
    env = np.exp(-t * 14)
    for off in (0.0, 0.011, 0.022):
        env += 0.6 * (t >= off) * np.exp(-np.clip(t - off, 0, None) * 70)
    return noise * env * vel * 0.35


def hat(vel=0.3, seed=2, open_=False):
    rng = np.random.default_rng(seed)
    t = tvec(0.3 if open_ else 0.06)
    noise = fft_filter(rng.standard_normal(len(t)), lo=7000, hi=14000, circular=False)
    return noise * np.exp(-t * (9 if open_ else 60)) * vel


def shaker(vel=0.15, seed=4):
    rng = np.random.default_rng(seed)
    t = tvec(0.09)
    noise = fft_filter(rng.standard_normal(len(t)), lo=4000, hi=11000, circular=False)
    env = np.sin(np.pi * np.clip(t / 0.09, 0, 1)) ** 2
    return noise * env * vel


def crackle(n, seed=9, amount=0.02):
    rng = np.random.default_rng(seed)
    x = np.zeros(n)
    pops = rng.integers(0, n, size=int(n / SR * 9))
    x[pops] = rng.uniform(-1, 1, size=len(pops))
    hiss = fft_filter(rng.standard_normal(n), lo=2000, hi=9000) * 0.06
    return (fft_filter(x, lo=800, hi=6000) * 3.0 + hiss) * amount


# ----------------------------------------------------------------- arranging

class Song:
    def __init__(self, bpm, bars, beats_per_bar=4, swing=0.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.swing = swing
        self.n = int(round(bars * beats_per_bar * self.beat * SR))
        self.tracks = {}

    def at(self, bar, beat):
        """Seconds for a bar/beat position, with 8th-note swing."""
        b = bar * self.bpb + beat
        frac = b - np.floor(b)
        if self.swing and abs(frac - 0.5) < 1e-6:
            b += self.swing * 0.5
        return b * self.beat

    def add(self, track, when, sig, gain=1.0):
        buf = self.tracks.setdefault(track, np.zeros(self.n))
        i = int(round(when * SR)) % self.n
        k = len(sig)
        end = i + k
        if end <= self.n:
            buf[i:end] += sig * gain
        else:
            first = self.n - i
            buf[i:] += sig[:first] * gain
            rest = sig[first:]
            while len(rest) > 0:          # wrap around: the loop is seamless
                take = min(len(rest), self.n)
                buf[:take] += rest[:take] * gain
                rest = rest[take:]

    def get(self, track):
        return self.tracks.get(track, np.zeros(self.n))


def chord_notes(root, quality, octave=4):
    shapes = {
        "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "m9": [0, 3, 7, 10, 14],
        "maj9": [0, 4, 7, 11, 14], "13": [0, 4, 10, 14, 21], "7b9": [0, 4, 7, 10, 13],
        "maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7, 10], "add9": [0, 4, 7, 14],
    }
    base = m(root, octave)
    return [base + s for s in shapes[quality]]


def melody(rng, chords, scale, bars, notes_per_bar_options, low, high):
    """Motif-based melody: A A' B A'' over 8 bars, chord tones on strong beats."""
    def make_bar(ch, prev):
        rhythm = notes_per_bar_options[rng.integers(0, len(notes_per_bar_options))]
        out = []
        for j, (beat, length) in enumerate(rhythm):
            if j == 0 or beat in (0, 2):
                cands = [n for n in range(low, high + 1) if n % 12 in [c % 12 for c in ch]]
            else:
                cands = [n for n in range(low, high + 1) if n % 12 in scale]
            cands.sort(key=lambda n: abs(n - prev) + rng.uniform(0, 2.5))
            note = cands[0] if rng.uniform() < 0.7 else cands[min(1, len(cands) - 1)]
            out.append((beat, length, note))
            prev = note
        return out, prev

    prev = (low + high) // 2
    motif = []
    for b in range(2):
        bar, prev = make_bar(chords[b % len(chords)], prev)
        motif.append(bar)
    result = []
    for section in range(bars // 2):
        if section % 4 == 2:          # B part: new material
            for b in range(2):
                bar, prev = make_bar(chords[(section * 2 + b) % len(chords)], prev)
                result.append(bar)
        else:
            for b in range(2):
                bar = [(bt, ln, nt) for (bt, ln, nt) in motif[b]]
                if section % 4 == 3 and b == 1:   # resolve to the tonic at the end
                    bt, ln, nt = bar[-1]
                    tonic = min([n for n in range(low, high + 1) if n % 12 == scale[0]], key=lambda n: abs(n - nt))
                    bar[-1] = (bt, ln, tonic)
                elif section % 4 == 1 and b == 1 and len(bar) > 1:
                    bt, ln, nt = bar[-1]
                    bar[-1] = (bt, ln, nt + (2 if nt + 2 <= high else -2))
                result.append(bar)
    return result


def master(song, mixes, rev_seconds=1.6, rev_mix=0.22, seed=0, width=True):
    """Mix tracks [(name, gain, reverb_send)], add stereo reverb, normalize."""
    dry = np.zeros(song.n)
    send = np.zeros(song.n)
    for name, gain, rsend in mixes:
        x = song.get(name) * gain
        dry += x
        send += x * rsend
    left = dry + circ_convolve(send, reverb_ir(rev_seconds, seed + 1)) * rev_mix * 6
    right = dry + circ_convolve(send, reverb_ir(rev_seconds, seed + 2 if width else seed + 1)) * rev_mix * 6
    left = fft_filter(left, lo=30, hi=9000)      # warm top end, no rumble
    right = fft_filter(right, lo=30, hi=9000)
    st = np.stack([left, right], axis=1)
    st = np.tanh(st / (np.max(np.abs(st)) + 1e-9) * 1.3) / np.tanh(1.3)   # gentle glue
    return st * 0.84


# ----------------------------------------------------------------- the tracks

def track_title():
    """'Maple St. at Dawn': calm F major, FM piano, pad, soft shaker. Title screen."""
    s = Song(84, 16, swing=0.12)
    prog = [("F", "maj7"), ("A", "m7"), ("Bb", "maj7"), ("C", "sus"),
            ("D", "m7"), ("A", "m7"), ("Bb", "maj9"), ("C", "7")]
    rng = np.random.default_rng(11)
    for bar in range(16):
        root, q = prog[bar % 8]
        notes = chord_notes(root, q, 4)
        s.add("pad", s.at(bar, 0), pad([hz(n - 12) for n in notes[:3]], s.beat * 4.2), 1.0)
        for beat, ln in [(0, 1.4), (1.5, 0.9), (2.5, 1.4)]:
            for k, n in enumerate(notes):
                s.add("keys", s.at(bar, beat) + k * 0.012, epiano(hz(n), s.beat * ln, 0.22))
        s.add("bass", s.at(bar, 0), bass(hz(m(root, 2)), s.beat * 1.6, 0.6))
        s.add("bass", s.at(bar, 2.5), bass(hz(m(root, 2) + 7), s.beat * 1.2, 0.45))
        for e in range(8):
            s.add("perc", s.at(bar, e * 0.5), shaker(0.12 if e % 2 else 0.18, seed=e))
        if bar >= 4:
            s.add("perc", s.at(bar, 0), kick(0.45, 0.7))
            s.add("perc", s.at(bar, 2), kick(0.35, 0.7))
            s.add("perc", s.at(bar, 1), snare(0.18, seed=bar, tone=210))
            s.add("perc", s.at(bar, 3), snare(0.2, seed=bar + 50, tone=210))
    scale = [5, 7, 9, 10, 0, 2, 4]
    chords = [chord_notes(r, q, 5) for r, q in prog]
    rhythms = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 1), (1, 1), (2, 1.5), (3.5, 0.5)], [(0.5, 1.5), (2, 2)]]
    mel = melody(rng, chords, scale, 8, rhythms, m("C", 5), m("A", 6))
    for i, bar in enumerate(mel):
        for beat, ln, note in bar:
            s.add("bell", s.at(8 + i, beat), bell(hz(note), s.beat * ln * 2.2, 0.28))
    return master(s, [("pad", 0.55, 0.6), ("keys", 0.8, 0.35), ("bass", 0.75, 0.05), ("perc", 0.55, 0.15), ("bell", 0.5, 0.7)],
                  rev_seconds=2.4, rev_mix=0.3, seed=10)


def track_desk():
    """'Dispatch Desk': lo-fi ii-V-I in C, vinyl crackle. Briefing and evening sheets."""
    s = Song(72, 8, swing=0.22)
    prog = [("D", "m9"), ("G", "13"), ("C", "maj9"), ("A", "7b9")]
    for bar in range(8):
        root, q = prog[bar % 4]
        notes = chord_notes(root, q, 4 if root in "CD" else 3)
        for beat, ln in [(0, 1.8), (2.5, 1.3)]:
            for k, n in enumerate(notes):
                s.add("keys", s.at(bar, beat) + k * 0.018, epiano(hz(n), s.beat * ln, 0.2))
        s.add("bass", s.at(bar, 0), bass(hz(m(root, 2)), s.beat * 1.4, 0.65))
        s.add("bass", s.at(bar, 1.5), bass(hz(m(root, 2) + 7), s.beat * 0.4, 0.4))
        s.add("bass", s.at(bar, 3), bass(hz(m(root, 2) + 12), s.beat * 0.8, 0.45))
        s.add("drums", s.at(bar, 0), kick(0.7, 0.6))
        s.add("drums", s.at(bar, 2.5), kick(0.5, 0.6))
        s.add("drums", s.at(bar, 1), snare(0.35, seed=bar, tone=170))
        s.add("drums", s.at(bar, 3), snare(0.38, seed=bar + 9, tone=170))
        for e in range(8):
            s.add("drums", s.at(bar, e * 0.5), hat(0.12 if e % 2 else 0.2, seed=e + bar))
    rng = np.random.default_rng(23)
    scale = [0, 2, 4, 7, 9]
    chords = [chord_notes(r, q, 5) for r, q in prog]
    mel = melody(rng, chords, scale, 8, [[(0.5, 1), (1.5, 0.5), (2, 1.5)], [(1, 0.5), (1.5, 0.5), (2.5, 1.5)]], m("E", 5), m("D", 6))
    for i, bar in enumerate(mel):
        if i % 4 in (1, 3):
            for beat, ln, note in bar:
                s.add("lead", s.at(i, beat), pluck(hz(note), s.beat * ln * 1.6, 0.35, bright=0.7))
    mix = master(s, [("keys", 0.85, 0.3), ("bass", 0.8, 0.0), ("drums", 0.6, 0.08), ("lead", 0.45, 0.5)], rev_seconds=1.4, rev_mix=0.2, seed=20)
    lofi = np.stack([fft_filter(mix[:, 0], lo=60, hi=5200), fft_filter(mix[:, 1], lo=60, hi=5200)], axis=1)
    lofi += crackle(s.n, amount=0.05)[:, None]
    return lofi / np.max(np.abs(lofi)) * 0.82


def track_day():
    """'Out for Delivery': upbeat C major, plucky arps and a whistly lead. Daytime."""
    s = Song(112, 16)
    a = [("C", "add9"), ("A", "m7"), ("F", "maj7"), ("G", "7")]
    b = [("E", "m7"), ("F", "maj7"), ("D", "m7"), ("G", "sus")]
    prog = a + a + b + a
    for bar in range(16):
        root, q = prog[bar]
        notes = chord_notes(root, q, 4)
        arp = notes + [notes[1] + 12, notes[2] + 12]
        order = [0, 2, 1, 3, 2, 4, 3, 5] * 2
        for k in range(16):
            n = arp[order[k] % len(arp)]
            s.add("arp", s.at(bar, k * 0.25), pluck(hz(n), s.beat * 0.6, 0.3 if k % 4 else 0.42, bright=1.4))
        for e in range(8):
            o = 0 if e % 2 == 0 else 12
            s.add("bass", s.at(bar, e * 0.5), bass(hz(m(root, 2) + o), s.beat * 0.45, 0.55 if e % 2 == 0 else 0.4))
        for k in (0, 2):
            s.add("drums", s.at(bar, k), kick(0.9))
        s.add("drums", s.at(bar, 2.75), kick(0.5))
        for k in (1, 3):
            s.add("drums", s.at(bar, k), snare(0.5, seed=bar * 4 + k))
        for k in range(16):
            s.add("drums", s.at(bar, k * 0.25), hat(0.09 if k % 2 else 0.15, seed=k))
        if bar % 4 == 3:
            s.add("drums", s.at(bar, 3.5), hat(0.25, seed=99, open_=True))
        s.add("pad", s.at(bar, 0), pad([hz(n) for n in notes[:3]], s.beat * 4.1, 0.18))
    rng = np.random.default_rng(5)
    scale = [0, 2, 4, 7, 9]
    chords = [chord_notes(r, q, 5) for r, q in prog]
    rhythms = [[(0, 0.5), (0.5, 0.5), (1, 1), (2.5, 0.5), (3, 1)], [(0, 1.5), (1.5, 0.5), (2, 0.5), (2.5, 1.5)],
               [(0, 0.75), (0.75, 0.75), (1.5, 0.5), (2, 2)]]
    mel = melody(rng, chords[:8], scale, 8, rhythms, m("E", 5), m("E", 6))
    for i, bar in enumerate(mel):
        for beat, ln, note in bar:
            s.add("lead", s.at(i + 8 if i < 8 else i, beat), lead(hz(note), s.beat * ln * 0.95, 0.32, "square"))
    lead_tr = circ_delay(s.get("lead"), s.beat * 0.75, 0.32, 3)
    s.tracks["lead"] = lead_tr
    return master(s, [("arp", 0.6, 0.25), ("bass", 0.85, 0.0), ("drums", 0.7, 0.06), ("pad", 0.5, 0.5), ("lead", 0.5, 0.3)],
                  rev_seconds=1.3, rev_mix=0.18, seed=30)


def track_peak():
    """'Holiday Peak': a busier A minor at 120 bpm for boss and peak days (kept warm, not harsh)."""
    s = Song(120, 16)
    prog = [("A", "min"), ("F", "maj"), ("C", "maj"), ("G", "maj")] * 2 + [("D", "min"), ("F", "maj"), ("E", "min"), ("E", "7")] + [("A", "min"), ("F", "maj"), ("G", "maj"), ("E", "7")]
    for bar in range(16):
        root, q = prog[bar]
        notes = chord_notes(root, q, 4)
        arp = notes + [notes[0] + 12, notes[1] + 12]
        for k in range(16):
            n = arp[[0, 1, 2, 3, 2, 1, 4, 2][k % 8] % len(arp)]
            t = tvec(s.beat * 0.24)
            sig = saw(hz(n), t, 10) * adsr(len(t), 0.002, 0.08, 0.3, 0.02) * (0.35 if k % 4 == 0 else 0.25)
            s.add("arp", s.at(bar, k * 0.25), fft_filter(sig, hi=1500 + 700 * (bar % 4) / 3, circular=False))
        for e in range(8):
            s.add("bass", s.at(bar, e * 0.5 + 0.0), bass(hz(m(root, 1) + 12), s.beat * 0.42, 0.7, growl=0.6))
        for k in range(4):
            s.add("drums", s.at(bar, k), kick(1.0, 1.2))
            s.add("drums", s.at(bar, k + 0.5), hat(0.09, seed=k + bar, open_=True))
        for k in (1, 3):
            s.add("drums", s.at(bar, k), clap(0.4, seed=bar + k))
        for k in range(16):
            if k % 2:
                s.add("drums", s.at(bar, k * 0.25), hat(0.12, seed=k * 3))
        if bar % 2 == 0:
            for n in notes:
                t = tvec(s.beat * 0.4)
                s.add("stab", s.at(bar, 0), saw(hz(n + 12), t, 8) * adsr(len(t), 0.002, 0.2, 0.0, 0.05) * 0.3)
    # Sidechain-style pump on everything but the drums.
    pump = np.ones(s.n)
    beat_n = int(s.beat * SR)
    shape = 1.0 - 0.55 * np.exp(-np.arange(beat_n) / SR * 14)
    for b in range(s.bars * 4):
        i = b * beat_n
        pump[i:i + beat_n] = shape[:min(beat_n, s.n - i)]
    for name in ("arp", "bass", "stab"):
        s.tracks[name] = s.get(name) * pump
    rng = np.random.default_rng(77)
    scale = [9, 11, 0, 2, 4, 5, 7]
    chords = [chord_notes(r, q, 5) for r, q in prog]
    mel = melody(rng, chords[8:] + chords[8:], scale, 8, [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 1.5), (3, 1)], [(0, 1), (1, 1), (2, 2)]], m("A", 4), m("A", 5))
    for i, bar in enumerate(mel):
        for beat, ln, note in bar:
            s.add("lead", s.at(8 + i, beat), lead(hz(note), s.beat * ln * 0.9, 0.34, "saw"))
    s.tracks["lead"] = circ_delay(s.get("lead"), s.beat * 0.5, 0.3, 3)
    return master(s, [("arp", 0.5, 0.2), ("bass", 0.75, 0.0), ("drums", 0.8, 0.04), ("stab", 0.5, 0.3), ("lead", 0.45, 0.25)],
                  rev_seconds=1.1, rev_mix=0.14, seed=40)


# ----------------------------------------------------------------- sound effects

def seq(parts, total=None):
    """parts: [(start_seconds, signal)]"""
    end = max(int(st * SR) + len(sig) for st, sig in parts)
    n = max(end, int((total or 0) * SR))
    out = np.zeros(n)
    for st, sig in parts:
        i = int(st * SR)
        out[i:i + len(sig)] += sig
    return out


def noise(dur, seed=0):
    return np.random.default_rng(seed).standard_normal(int(dur * SR))


def sweep_noise(dur, f0, f1, seed=0, q=0.3):
    """Noise through a moving band, built from short filtered slices."""
    x = noise(dur, seed)
    n = len(x)
    out = np.zeros(n)
    seg = 512
    for i in range(0, n, seg):
        fc = f0 + (f1 - f0) * (i / max(1, n))
        piece = x[max(0, i - seg):i + seg * 2]
        piece = fft_filter(piece, lo=fc * (1 - q), hi=fc * (1 + q), circular=False)
        out[i:i + seg] = piece[min(seg, i):min(seg, i) + len(out[i:i + seg])]
    return out


def fade(x, ms=8):
    k = min(len(x), int(ms / 1000 * SR))
    x = x.copy()
    x[-k:] *= np.linspace(1, 0, k)
    return x


def sfx_all():
    out = {}
    t = tvec
    # UI
    out["click"] = seq([(0, np.sin(TAU * 1500 * t(0.04)) * expdec(int(0.04 * SR), 90) * 0.5),
                        (0, fft_filter(noise(0.01, 1), lo=2000, hi=9000, circular=False) * 0.4)])
    out["card"] = sweep_noise(0.22, 1500, 6000, seed=2) * adsr(int(0.22 * SR), 0.03, 0.1, 0.4, 0.08) * 1.2
    out["coin"] = seq([(0, bell(hz(m("B", 6)), 0.25, 0.5)), (0.07, bell(hz(m("E", 7)), 0.4, 0.5))])
    out["stamp"] = seq([(0, kick(0.8, 2.0)[:int(0.15 * SR)]), (0, fft_filter(noise(0.08, 3), lo=400, hi=3000, circular=False) * expdec(int(0.08 * SR), 40) * 0.6)])
    out["event"] = seq([(0, sweep_noise(0.15, 2000, 5000, seed=4) * expdec(int(0.15 * SR), 18) * 0.7),
                        (0.08, bell(hz(m("G", 5)), 0.8, 0.35)), (0.16, bell(hz(m("D", 6)), 0.9, 0.3))])
    # Deliveries
    out["ding"] = bell(hz(m("E", 6)), 0.7, 0.55)
    out["late"] = seq([(0, bass(110, 0.25, 0.8) * np.linspace(1, 0.3, int(0.25 * SR))),
                       (0, fft_filter(noise(0.12, 5), lo=100, hi=900, circular=False) * expdec(int(0.12 * SR), 30) * 0.5)])
    out["cash"] = seq([(0, fft_filter(noise(0.05, 6), lo=200, hi=2000, circular=False) * expdec(int(0.05 * SR), 50)),
                       (0.03, bell(hz(m("A", 6)), 0.5, 0.5)), (0.1, bell(hz(m("E", 7)), 0.6, 0.45)),
                       (0.1, fft_filter(noise(0.35, 7), lo=6000, hi=12000, circular=False) * expdec(int(0.35 * SR), 12) * 0.35)])
    arp = [m("C", 6), m("E", 6), m("G", 6), m("C", 7), m("E", 7), m("G", 7)]
    out["jackpot"] = seq([(i * 0.06, bell(hz(n), 0.9, 0.42)) for i, n in enumerate(arp)] +
                         [(0.36, sum(epiano(hz(n), 1.2, 0.18) for n in [m("C", 5), m("E", 5), m("G", 5), m("B", 5)])),
                          (0.3, fft_filter(noise(0.9, 8), lo=7000, hi=13000, circular=False) * expdec(int(0.9 * SR), 5) * 0.25)])
    out["bust"] = seq([(i * 0.22, fft_filter(saw(hz(n), t(0.3), 10) * adsr(int(0.3 * SR), 0.01, 0.1, 0.7, 0.08), hi=1200, circular=False) * 0.5)
                       for i, n in enumerate([m("G", 4), m("F#", 4), m("F", 4)])] +
                      [(0.66, fft_filter(saw(hz(m("E", 4)), t(0.7), 10) * np.linspace(1, 0, int(0.7 * SR)) * (1 + 0.15 * np.sin(TAU * 6 * t(0.7))), hi=900, circular=False) * 0.5)])
    out["streak"] = seq([(i * 0.05, pluck(hz(n), 0.35, 0.5, bright=1.5)) for i, n in enumerate([m("G", 5), m("C", 6), m("E", 6), m("G", 6)])])
    out["streak_break"] = seq([(0, bell(hz(m("E", 6)), 0.3, 0.3)), (0.08, bell(hz(m("C", 6)), 0.3, 0.28)),
                               (0.16, bell(hz(m("A", 5)), 0.5, 0.26)), (0.16, bass(70, 0.3, 0.6))])
    # Trouble
    out["breakdown"] = seq([(0, fft_filter(noise(0.25, 9), lo=80, hi=1500, circular=False) * expdec(int(0.25 * SR), 14)),
                            (0, np.sin(TAU * 320 * t(0.4) + 3 * np.sin(TAU * 87 * t(0.4))) * expdec(int(0.4 * SR), 9) * 0.4),
                            (0.25, fft_filter(noise(0.9, 10), lo=3000, hi=9000, circular=False) * adsr(int(0.9 * SR), 0.05, 0.2, 0.4, 0.4) * 0.25)])
    tone = lambda f, d: lead(f, d, 0.4, "square")
    out["rush"] = seq([(0, tone(hz(m("A", 5)), 0.12)), (0.14, tone(hz(m("E", 5)), 0.12)),
                       (0.28, tone(hz(m("A", 5)), 0.12)), (0.42, tone(hz(m("E", 5)), 0.16))])
    out["notice"] = seq([(0, sum(pad([hz(n)], 1.4, 0.6) for n in [m("A", 2), m("C", 3), m("Eb", 3)])),
                         (0, kick(0.7, 0.5))])
    # Powers, departures
    out["power"] = seq([(0, sweep_noise(0.45, 600, 7000, seed=11) * adsr(int(0.45 * SR), 0.15, 0.1, 0.8, 0.15) * 1.1),
                        (0.25, bell(hz(m("B", 6)), 0.6, 0.25))])
    eng_t = t(0.6)
    eng_f = 55 + 60 * np.clip(eng_t / 0.4, 0, 1) ** 0.6
    ph = TAU * np.cumsum(eng_f) / SR
    eng = sum((1.0 / k) * np.sin(k * ph) for k in range(1, 8))
    out["depart"] = fft_filter(eng * adsr(len(eng_t), 0.03, 0.2, 0.7, 0.2) * 0.5, hi=900, circular=False) + \
        fft_filter(noise(0.6, 12), lo=200, hi=1500, circular=False) * 0.08 * adsr(len(eng_t), 0.05, 0.2, 0.5, 0.2)
    # Big moments
    out["rent_paid"] = seq([(0, out["stamp"]), (0.18, out["cash"])])
    fan = [m("C", 5), m("E", 5), m("G", 5), m("C", 6)]
    out["win"] = seq([(i * 0.13, lead(hz(n), 0.22, 0.4, "square")) for i, n in enumerate(fan)] +
                     [(0.55, sum(lead(hz(n), 1.4, 0.22, "square") for n in [m("C", 5), m("E", 5), m("G", 5), m("C", 6)]))] +
                     [(0.55, kick(0.8)), (0.55, out["jackpot"] * 0.6)])
    trom = []
    for i, n in enumerate([m("D", 4), m("C#", 4), m("C", 4), m("B", 3)]):
        d = 0.32 if i < 3 else 1.1
        tt = t(d)
        vib = 1 + (0.012 * np.sin(TAU * 6 * tt) if i == 3 else 0)
        ph = TAU * hz(n) * np.cumsum(vib * np.ones(len(tt))) / SR
        sig = sum(((-1) ** (k + 1)) / k * np.sin(k * ph) for k in range(1, 12)) * adsr(len(tt), 0.03, 0.1, 0.8, 0.1)
        trom.append((i * 0.34, fft_filter(sig, hi=1400, circular=False) * 0.4))
    out["evicted"] = seq(trom)
    out["level_up"] = seq([(i * 0.07, pluck(hz(n), 0.5, 0.45, bright=1.6)) for i, n in enumerate([m("C", 6), m("G", 6), m("C", 7), m("E", 7)])])
    out["relic"] = seq([(i * 0.09, bell(hz(n), 1.8, 0.3)) for i, n in enumerate([m("E", 5), m("B", 5), m("D#", 6), m("F#", 6), m("B", 6)])] +
                       [(0, sweep_noise(1.2, 3000, 9000, seed=13) * adsr(int(1.2 * SR), 0.3, 0.3, 0.5, 0.5) * 0.4)])
    # small room reverb on everything for glue
    ir = reverb_ir(0.5, 99)
    for k in list(out.keys()):
        x = out[k]
        wet = np.convolve(x, ir)[:len(x) + int(0.25 * SR)]
        x = np.concatenate([x, np.zeros(len(wet) - len(x))]) + wet * 0.18
        x = fft_filter(x, lo=40, hi=9500, circular=False)
        x = fade(x / (np.max(np.abs(x)) + 1e-9) * 0.85)
        out[k] = x
    return out


# ----------------------------------------------------------------- ambience (seamless loops)

def _loop_noise(n, seed, lo, hi):
    return fft_filter(np.random.default_rng(seed).standard_normal(n), lo=lo, hi=hi)


def _slow_lfo(n, cycles, depth, phase=0.0):
    t = np.arange(n) / n
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(TAU * cycles * t + phase))


def amb_day():
    """Distant traffic, a soft breeze and birds. 40 s loop."""
    s = Song(60, 10)
    n = s.n
    rng = np.random.default_rng(31)
    traffic = _loop_noise(n, 1, 40, 320) * _slow_lfo(n, 3, 0.35) * 0.9
    wind = _loop_noise(n, 2, 300, 1800) * _slow_lfo(n, 2, 0.7, 1.0) * 0.25
    s.tracks["bed"] = traffic + wind
    for _ in range(26):
        when = rng.uniform(0, n / SR)
        f0 = rng.uniform(2600, 4200)
        for k in range(rng.integers(2, 6)):
            d = rng.uniform(0.05, 0.11)
            tt = tvec(d)
            sweep = f0 * (1 + rng.uniform(-0.18, 0.25) * tt / d)
            chirp = np.sin(TAU * np.cumsum(sweep) / SR) * np.sin(np.pi * tt / d) ** 2
            s.add("birds", when + k * rng.uniform(0.09, 0.16), chirp * rng.uniform(0.05, 0.12))
    for _ in range(4):   # a car passing in the distance
        when = rng.uniform(0, n / SR)
        d = 3.5
        swell = _loop_noise(int(d * SR), rng.integers(100), 80, 900) * np.sin(np.pi * tvec(d) / d) ** 2
        s.add("bed", when, swell * 0.6)
    mix = s.get("bed") + s.get("birds")
    return mix / np.max(np.abs(mix)) * 0.55


def amb_night():
    """Crickets, a light breeze, the odd owl. 40 s loop."""
    s = Song(60, 10)
    n = s.n
    rng = np.random.default_rng(41)
    wind = _loop_noise(n, 3, 120, 900) * _slow_lfo(n, 2, 0.6) * 0.3
    s.tracks["bed"] = wind
    for voice in range(3):
        f = rng.uniform(4300, 5200)
        rate = rng.uniform(2.2, 3.4)          # chirps per second
        t = 0.0
        while t < n / SR:
            if rng.uniform() < 0.82:
                d = 0.16
                tt = tvec(d)
                pulse = np.sin(TAU * f * tt) * (0.5 + 0.5 * np.sign(np.sin(TAU * 38 * tt))) * np.sin(np.pi * tt / d) ** 2
                s.add("crickets", t, pulse * (0.035 + 0.02 * voice))
            t += 1.0 / rate
    for _ in range(2):
        when = rng.uniform(0, n / SR)
        for k, d in enumerate([0.32, 0.5]):
            tt = tvec(d)
            hoot = np.sin(TAU * 390 * tt * (1 + 0.01 * np.sin(TAU * 5 * tt))) * np.sin(np.pi * tt / d)
            s.add("owl", when + k * 0.45, hoot * 0.07)
    mix = s.get("bed") + fft_filter(s.get("crickets"), lo=3000, hi=7000) + s.get("owl")
    return mix / np.max(np.abs(mix)) * 0.5


def amb_rain():
    """Steady rain with soft drips on rooftops. 30 s loop."""
    s = Song(60, 8)
    n = s.n
    rng = np.random.default_rng(51)
    hiss = _loop_noise(n, 5, 400, 3800) * _slow_lfo(n, 3, 0.2) * 0.55
    body = _loop_noise(n, 6, 90, 600) * 0.5
    s.tracks["bed"] = hiss + body
    for _ in range(int(n / SR * 9)):
        when = rng.uniform(0, n / SR)
        d = 0.03
        drop = np.sin(TAU * rng.uniform(900, 2200) * tvec(d)) * np.exp(-tvec(d) * 120)
        s.add("drops", when, drop * rng.uniform(0.04, 0.12))
    mix = s.get("bed") + s.get("drops")
    return mix / np.max(np.abs(mix)) * 0.55


def engine_loop():
    """A soft diesel idle hum, exactly periodic over 2 s so it loops cleanly."""
    n = 2 * SR
    t = np.arange(n) / SR
    f = 45.0                                   # 90 whole cycles in 2 s
    ph = TAU * f * t
    tone = sum((1.0 / k) * np.sin(k * ph) for k in range(1, 9))
    chug = 0.75 + 0.25 * np.sin(TAU * 8.0 * t)   # 16 whole cycles
    rumble = _loop_noise(n, 7, 40, 400) * 0.35
    x = fft_filter(tone * chug + rumble, lo=30, hi=700)
    return x / np.max(np.abs(x)) * 0.7


def sfx_extra():
    out = {}
    t = tvec
    # Tow truck: reverse beeper, chain rattle, low engine.
    beeps = [(i * 0.36, np.sin(TAU * 1046 * t(0.18)) * adsr(int(0.18 * SR), 0.005, 0.02, 0.9, 0.03) * 0.35) for i in range(3)]
    chain = [(0.15 + i * 0.07, fft_filter(noise(0.05, 60 + i), lo=2500, hi=7000, circular=False) * np.exp(-t(0.05) * 60) * 0.5) for i in range(8)]
    out["tow"] = seq(beeps + chain + [(0, engine_loop()[:int(1.2 * SR)] * np.linspace(0.6, 0, int(1.2 * SR)))])
    # Card reveal: a paper flick and a soft pluck.
    out["reveal"] = seq([(0, sweep_noise(0.18, 1200, 4500, seed=61) * adsr(int(0.18 * SR), 0.02, 0.08, 0.5, 0.06) * 0.9),
                         (0.08, pluck(hz(m("A", 5)), 0.5, 0.35, bright=0.8))])
    # Ultra rare sting: warm chord swell under a rising bell run.
    run = [m("D", 5), m("A", 5), m("D", 6), m("F#", 6), m("A", 6)]
    out["ultra"] = seq([(i * 0.07, bell(hz(n), 1.6, 0.28)) for i, n in enumerate(run)] +
                       [(0.1, sum(pad([hz(n)], 1.8, 0.7) for n in [m("D", 4), m("F#", 4), m("A", 4)]))])
    # Confirm: two soft rising notes.
    out["confirm"] = seq([(0, pluck(hz(m("E", 5)), 0.3, 0.4, bright=0.9)), (0.07, pluck(hz(m("B", 5)), 0.45, 0.4, bright=0.9))])
    # Nobody home: a doorbell that goes unanswered.
    out["doorbell"] = seq([(0, bell(hz(m("E", 5)), 0.6, 0.35)), (0.28, bell(hz(m("C", 5)), 0.9, 0.3))])
    ir = reverb_ir(0.5, 98)
    for k in list(out.keys()):
        x = out[k]
        wet = np.convolve(x, ir)[:len(x) + int(0.25 * SR)]
        x = np.concatenate([x, np.zeros(len(wet) - len(x))]) + wet * 0.15
        x = fft_filter(x, lo=40, hi=9000, circular=False)
        out[k] = fade(x / (np.max(np.abs(x)) + 1e-9) * 0.8)
    return out


# ----------------------------------------------------------------- output

def write_ogg(path, data, quality=4):
    data = np.asarray(data)
    if data.ndim == 1:
        data = data[:, None]
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        name = tmp.name
    with wave.open(name, "wb") as w:
        w.setnchannels(pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(name)


def main():
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    for name, fn in [("title", track_title), ("desk", track_desk), ("day", track_day), ("peak", track_peak)]:
        data = fn()
        write_ogg(os.path.join(ROOT, "music", name + ".ogg"), data, 4)
        print("music/%s.ogg  %.1fs" % (name, len(data) / SR))
    os.makedirs(os.path.join(ROOT, "ambience"), exist_ok=True)
    for name, fn in [("day", amb_day), ("night", amb_night), ("rain", amb_rain), ("engine", engine_loop)]:
        write_ogg(os.path.join(ROOT, "ambience", name + ".ogg"), fn(), 3)
        print("ambience/%s.ogg" % name)
    effects = sfx_all()
    effects.update(sfx_extra())
    for name, data in effects.items():
        write_ogg(os.path.join(ROOT, "sfx", name + ".ogg"), data, 5)
    print("sfx: %d files" % len(effects))


if __name__ == "__main__":
    main()
