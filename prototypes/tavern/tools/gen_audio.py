"""
Original audio: SFX and music, synthesised from scratch.

No samples, no libraries, no downloads - every waveform here is built out of
oscillators, envelopes and filtered noise in numpy and written as 16-bit PCM
WAV. That keeps the audio as original as the art and makes the whole soundtrack
reproducible from source.

Music is written as note lists over a shared scale so the four day-parts are
recognisably the same tune, re-voiced. Morning is bright and busy, night is
sparse and low - the player should be able to tell the time with their eyes
shut.
"""
import math
import os
import struct
import sys
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "audio")
# 22.05 kHz mono for SFX / stereo for music: this is a pixel game with
# synthesised audio - nothing here has content above 11 kHz, so the higher
# rate was costing repo size for no audible gain.
SR = 22050


def rel(p):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    return "res://" + os.path.relpath(os.path.abspath(p), root).replace("\\", "/")


def write_wav(path, data, sr=SR, stereo=True):
    data = np.clip(data, -1.0, 1.0)
    pcm = (data * 32000).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(sr)
        if stereo:
            if pcm.ndim == 1:
                pcm = np.stack([pcm, pcm], 1)
            w.writeframes(pcm.astype("<i2").tobytes())
        else:
            w.writeframes(pcm.astype("<i2").tobytes())
    return path


# --------------------------------------------------------------- synthesis --
def t_arr(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.01, d=0.1, s=0.6, r=0.2, sustain_len=None):
    """ADSR envelope over n samples."""
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    r_n = max(1, int(r * SR))
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, a_n),
        np.linspace(1, s, d_n),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def sine(f, dur, phase=0.0):
    return np.sin(2 * np.pi * f * t_arr(dur) + phase)


def tri(f, dur):
    x = (t_arr(dur) * f) % 1.0
    return 2 * np.abs(2 * x - 1) - 1


def square(f, dur, duty=0.5):
    return np.where((t_arr(dur) * f) % 1.0 < duty, 1.0, -1.0)


def saw(f, dur):
    return 2 * ((t_arr(dur) * f) % 1.0) - 1


def noise(dur, seed=0):
    return np.random.RandomState(seed).uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff, sr=SR):
    """One-pole lowpass. Cheap, and exactly the softening these sounds want."""
    a = math.exp(-2 * math.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = a * acc + (1 - a) * x[i]
        y[i] = acc
    return y


def lowpass_fast(x, cutoff, sr=SR):
    """Vectorised approximation via cumulative smoothing - used where an exact
    pole is not needed and the buffer is long (music beds)."""
    k = max(1, int(sr / max(cutoff, 1.0)))
    ker = np.ones(k) / k
    return np.convolve(x, ker, mode="same")


def pitch_sweep(f0, f1, dur, wave_fn=sine):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_fn is sine:
        return np.sin(ph)
    if wave_fn is square:
        return np.where((ph / (2 * np.pi)) % 1.0 < .5, 1.0, -1.0)
    return 2 * ((ph / (2 * np.pi)) % 1.0) - 1


def stereo(x, pan=0.0, width=0.0):
    l = x * (1 - max(0, pan))
    r = x * (1 + min(0, pan))
    if width:
        d = int(SR * width)
        r = np.roll(r, d)
    return np.stack([l, r], 1)


def reverb(x, amount=0.25, delays=(0.031, 0.057, 0.089, 0.123)):
    out = x.copy()
    for i, d in enumerate(delays):
        n = int(SR * d)
        tail = np.zeros_like(x)
        tail[n:] = x[:-n] * (amount * (0.7 ** i))
        out = out + tail
    return out / (1 + amount)


# ================================================================== SFX ======
def sfx_chop():
    n = 0.16
    body = noise(n, 1) * env(int(SR * n), .001, .02, .1, .08)
    body = lowpass(body, 2600)
    knock = sine(180, n) * env(int(SR * n), .001, .04, .0, .05) * .6
    return (body * .8 + knock) * .9


def sfx_sizzle():
    n = 1.2
    x = noise(n, 2)
    x = lowpass(x, 5200) - lowpass(x, 900)
    mod = 1 + .35 * np.sin(2 * np.pi * 7 * t_arr(n))
    return x * mod * env(int(SR * n), .08, .2, .7, .35) * .34


def sfx_fire_whoosh():
    n = 0.7
    x = lowpass(noise(n, 3), 1800)
    sweep = pitch_sweep(90, 240, n, sine) * .3
    return (x + sweep) * env(int(SR * n), .04, .18, .5, .35) * .55


def sfx_plate():
    n = 0.5
    out = np.zeros(int(SR * n))
    for f, a, d in ((2100, .5, .35), (3160, .34, .28), (4700, .2, .2)):
        out += sine(f, n) * env(int(SR * n), .001, d, .05, .12) * a
    return reverb(out * .5, .3)


def sfx_plate_break():
    n = 0.6
    out = noise(n, 4) * env(int(SR * n), .001, .06, .1, .3)
    out = lowpass(out, 7000)
    for i, f in enumerate((2400, 3300, 4100, 5200)):
        out += sine(f, n) * env(int(SR * n), .001, .05 + i * .02, .0, .1) * .22
    return reverb(out * .7, .35)


def sfx_bell():
    """Door bell - announces every customer, so it must be pleasant."""
    n = 1.4
    out = np.zeros(int(SR * n))
    for f, a in ((1318, .5), (1975, .3), (2637, .18), (3951, .08)):
        out += sine(f, n) * env(int(SR * n), .002, .5, .18, .7) * a
    return reverb(out * .5, .4)


def sfx_footstep(i=0):
    n = 0.12
    x = lowpass(noise(n, 10 + i), 1100)
    thud = sine(90 + i * 8, n) * .5
    return (x * .7 + thud) * env(int(SR * n), .002, .03, .1, .06) * .5


def sfx_ui_click():
    n = 0.09
    return (square(880, n, .25) * .4 + sine(1760, n) * .2) * \
        env(int(SR * n), .001, .02, .2, .05)


def sfx_ui_confirm():
    n = 0.34
    out = np.zeros(int(SR * n))
    for i, f in enumerate((523, 659, 784)):
        seg = sine(f, n) * env(int(SR * n), .004, .1, .35, .18) * .32
        out += np.roll(seg, int(SR * .055 * i))
    return out


def sfx_ui_cancel():
    n = 0.22
    return pitch_sweep(520, 240, n, square) * \
        env(int(SR * n), .003, .06, .3, .12) * .28


def sfx_perfect():
    """Perfect-dish stinger. The best sound in the game - it has to land."""
    n = 1.1
    out = np.zeros(int(SR * n))
    for i, f in enumerate((784, 988, 1175, 1568)):
        seg = (sine(f, n) * .5 + sine(f * 2, n) * .18) * \
            env(int(SR * n), .004, .22, .28, .5)
        out += np.roll(seg, int(SR * .06 * i)) * .3
    shimmer = sine(3136, n) * env(int(SR * n), .05, .4, .1, .5) * .08
    return reverb(out + shimmer, .35)


def sfx_fail():
    n = 0.8
    out = pitch_sweep(320, 110, n, saw) * env(int(SR * n), .01, .2, .4, .4)
    out = lowpass(out, 1400)
    return out * .42


def sfx_coin():
    n = 0.45
    out = np.zeros(int(SR * n))
    for i, f in enumerate((1318, 1760)):
        seg = sine(f, n) * env(int(SR * n), .002, .12, .2, .2) * .34
        out += np.roll(seg, int(SR * .05 * i))
    return out


def sfx_slime():
    n = 0.45
    base = pitch_sweep(420, 160, n, sine)
    wob = 1 + .5 * np.sin(2 * np.pi * 18 * t_arr(n))
    wet = lowpass(noise(n, 6), 2200) * .3
    return (base * wob * .5 + wet) * env(int(SR * n), .01, .12, .4, .25) * .55


def sfx_slime_pop():
    n = 0.22
    return (pitch_sweep(700, 220, n, sine) *
            env(int(SR * n), .002, .05, .2, .12)) * .5


def sfx_dragon_roar():
    n = 1.5
    growl = pitch_sweep(72, 54, n, saw)
    growl = lowpass(growl, 700)
    rasp = lowpass(noise(n, 7), 1600) * .45
    mod = 1 + .3 * np.sin(2 * np.pi * 24 * t_arr(n))
    return (growl * .8 + rasp) * mod * env(int(SR * n), .06, .3, .6, .55) * .6


def sfx_dragon_happy():
    n = 0.9
    rumble = pitch_sweep(80, 130, n, saw)
    rumble = lowpass(rumble, 900)
    return rumble * env(int(SR * n), .05, .25, .5, .4) * .5


def sfx_vampire():
    n = 1.0
    breath = lowpass(noise(n, 8), 900) * .35
    tone = sine(196, n) * .25 + sine(294, n) * .12
    return (breath + tone) * env(int(SR * n), .12, .3, .5, .5) * .5


def sfx_ghost():
    n = 1.6
    x = np.zeros(int(SR * n))
    for f in (330, 495, 660):
        vib = 1 + .02 * np.sin(2 * np.pi * 5.5 * t_arr(n))
        x += sine(f, n) * vib * .2
    return reverb(x * env(int(SR * n), .3, .4, .5, .6), .5) * .5


def sfx_golem():
    n = 0.8
    grind = lowpass(noise(n, 9), 620) * .8
    thud = pitch_sweep(64, 44, n, sine) * .5
    return (grind + thud) * env(int(SR * n), .02, .2, .5, .35) * .6


def sfx_eat():
    n = 0.5
    out = np.zeros(int(SR * n))
    for i in range(3):
        seg = lowpass(noise(0.12, 20 + i), 1500) * env(int(SR * .12), .005, .03, .3, .06)
        out[int(SR * .14 * i):int(SR * .14 * i) + len(seg)] += seg * .7
    return out * .7


def sfx_pour():
    n = 0.9
    x = lowpass(noise(n, 11), 3000) - lowpass(noise(n, 11), 700)
    warble = 1 + .2 * np.sin(2 * np.pi * 11 * t_arr(n))
    return x * warble * env(int(SR * n), .06, .2, .6, .3) * .3


def sfx_magic():
    n = 1.2
    out = np.zeros(int(SR * n))
    for i, f in enumerate((880, 1174, 1568, 2093)):
        seg = sine(f, n) * env(int(SR * n), .02, .3, .2, .5) * .22
        out += np.roll(seg, int(SR * .07 * i))
    shimmer = sine(60, n) * .0
    return reverb(out + shimmer, .45)


def sfx_event():
    n = 0.9
    out = np.zeros(int(SR * n))
    for i, f in enumerate((392, 523, 659)):
        seg = tri(f, n) * env(int(SR * n), .006, .18, .3, .35) * .3
        out += np.roll(seg, int(SR * .08 * i))
    return reverb(out, .3)


def sfx_levelup():
    n = 1.3
    out = np.zeros(int(SR * n))
    for i, f in enumerate((523, 659, 784, 1046, 1318)):
        seg = (tri(f, n) * .5 + sine(f * 2, n) * .12) * \
            env(int(SR * n), .005, .2, .3, .45) * .26
        out += np.roll(seg, int(SR * .07 * i))
    return reverb(out, .35)


SFX = {
    "chop": sfx_chop, "footstep": sfx_footstep, "sizzle": sfx_sizzle, "fire_whoosh": sfx_fire_whoosh,
    "plate": sfx_plate, "plate_break": sfx_plate_break, "bell": sfx_bell,
    "ui_click": sfx_ui_click, "ui_confirm": sfx_ui_confirm,
    "ui_cancel": sfx_ui_cancel, "perfect": sfx_perfect, "fail": sfx_fail,
    "coin": sfx_coin, "slime": sfx_slime, "slime_pop": sfx_slime_pop,
    "dragon_roar": sfx_dragon_roar, "dragon_happy": sfx_dragon_happy,
    "vampire": sfx_vampire, "ghost": sfx_ghost, "golem": sfx_golem,
    "eat": sfx_eat, "pour": sfx_pour, "magic": sfx_magic,
    "event": sfx_event, "levelup": sfx_levelup,
}


# ================================================================ MUSIC =====
# One theme, four voicings. Scale: D natural minor - warm, a little wistful,
# works for both cosy service and the strange night hours.
SCALE = [146.83, 164.81, 174.61, 196.00, 220.00, 233.08, 261.63,
         293.66, 329.63, 349.23, 392.00, 440.00, 466.16, 523.25]

THEME = [0, 2, 4, 3, 2, 0, 2, 4, 7, 6, 4, 3, 2, 0, -1, 0]
COUNTER = [7, 6, 4, 3, 4, 6, 7, 9, 7, 6, 4, 2, 0, 2, 3, 4]


def note(freq, dur, kind="tri", amp=.3, a=.01, d=.1, s=.55, r=.2):
    n = int(SR * dur)
    if kind == "tri":
        w = tri(freq, dur)
    elif kind == "sine":
        w = sine(freq, dur) + sine(freq * 2, dur) * .12
    elif kind == "square":
        w = square(freq, dur, .30)
    elif kind == "pluck":
        w = saw(freq, dur)
        w = lowpass_fast(w, 2200)
    else:
        w = sine(freq, dur)
    return w[:n] * env(n, a, d, s, r) * amp


def bass(freq, dur, amp=.28):
    n = int(SR * dur)
    w = sine(freq, dur) * .7 + tri(freq, dur) * .3
    return w[:n] * env(n, .01, .12, .6, .2) * amp


def build_track(name, bpm, voices, bars=8, seed=0):
    """Assemble a loopable bed. `voices` is a list of layer descriptors."""
    beat = 60.0 / bpm
    step = beat / 2
    total = int(SR * step * 16 * bars)
    buf = np.zeros(total + SR)
    for v in voices:
        pat = v["pattern"]
        for b in range(bars):
            for i, deg in enumerate(pat):
                if deg is None:
                    continue
                if v.get("every") and (b % v["every"]) != v.get("phase", 0):
                    continue
                idx = deg + v.get("transpose", 0)
                if idx < 0 or idx >= len(SCALE):
                    continue
                f = SCALE[idx] * v.get("octave", 1.0)
                pos = int(SR * step * (b * 16 + i))
                dur = step * v.get("length", 1.9)
                if v.get("kind") == "bass":
                    seg = bass(f, dur, v.get("amp", .26))
                else:
                    seg = note(f, dur, v.get("kind", "tri"), v.get("amp", .22),
                               a=v.get("a", .01), d=v.get("d", .12),
                               s=v.get("s", .5), r=v.get("r", .25))
                end = min(len(buf), pos + len(seg))
                buf[pos:end] += seg[:end - pos]
    buf = buf[:total]
    buf = reverb(buf, .22)
    peak = np.max(np.abs(buf)) or 1.0
    buf = buf / peak * .72
    # gentle fade at the seam so the loop does not click
    fade = int(SR * .02)
    buf[:fade] *= np.linspace(0, 1, fade)
    buf[-fade:] *= np.linspace(1, 0, fade)
    return buf


def music_morning():
    return build_track("morning", 104, [
        {"pattern": THEME, "kind": "tri", "amp": .24, "octave": 2.0},
        {"pattern": COUNTER, "kind": "pluck", "amp": .13, "octave": 1.0,
         "every": 2, "phase": 1},
        {"pattern": [0, None, None, None, 3, None, None, None,
                     4, None, None, None, 2, None, None, None],
         "kind": "bass", "amp": .26, "octave": .5, "length": 3.4},
    ], bars=4)


def music_day():
    return build_track("day", 118, [
        {"pattern": THEME, "kind": "tri", "amp": .22, "octave": 2.0},
        {"pattern": COUNTER, "kind": "square", "amp": .10, "octave": 2.0},
        {"pattern": [0, None, 3, None, 4, None, 2, None,
                     0, None, 3, None, 6, None, 4, None],
         "kind": "bass", "amp": .27, "octave": .5, "length": 1.6},
        {"pattern": [None, 7, None, 9, None, 7, None, 6] * 2,
         "kind": "pluck", "amp": .09, "octave": 2.0, "length": .8},
    ], bars=4)


def music_evening():
    return build_track("evening", 92, [
        {"pattern": THEME, "kind": "sine", "amp": .24, "octave": 1.0},
        {"pattern": COUNTER, "kind": "tri", "amp": .12, "octave": 2.0,
         "every": 2},
        {"pattern": [0, None, None, None, 2, None, None, None,
                     3, None, None, None, 0, None, None, None],
         "kind": "bass", "amp": .25, "octave": .5, "length": 3.6},
    ], bars=4)


def music_night():
    return build_track("night", 74, [
        {"pattern": [d if i % 2 == 0 else None for i, d in enumerate(THEME)],
         "kind": "sine", "amp": .22, "octave": 1.0, "a": .08, "r": .5,
         "length": 3.0},
        {"pattern": [None] * 8 + [7, None, 6, None, 4, None, 2, None],
         "kind": "pluck", "amp": .10, "octave": 2.0},
        {"pattern": [0, None, None, None, None, None, None, None,
                     3, None, None, None, None, None, None, None],
         "kind": "bass", "amp": .24, "octave": .5, "length": 7.0},
    ], bars=4)


def music_title():
    return build_track("title", 96, [
        {"pattern": THEME, "kind": "tri", "amp": .26, "octave": 2.0},
        {"pattern": THEME, "kind": "sine", "amp": .14, "octave": 1.0},
        {"pattern": COUNTER, "kind": "pluck", "amp": .12, "octave": 2.0,
         "every": 2, "phase": 1},
        {"pattern": [0, None, None, None, 3, None, None, None,
                     4, None, None, None, 2, None, None, None],
         "kind": "bass", "amp": .28, "octave": .5, "length": 3.4},
    ], bars=4)


def normalise(x, peak=0.55):
    """Bring a bed up to a usable level.

    Noise pushed through lowpass_fast loses most of its amplitude (averaging N
    samples of white noise scales it by ~1/sqrt(N)), so ambience beds come out
    of synthesis almost silent. Normalise rather than hand-tuning every gain.
    """
    m = float(np.max(np.abs(x))) or 1.0
    return x / m * peak


def ambience_restaurant():
    """Room tone: low hum, a hearth crackle, occasional distant clink."""
    n = 12.0
    total = int(SR * n)
    hum = lowpass_fast(np.random.RandomState(30).uniform(-1, 1, total), 220) * .10
    crackle = np.zeros(total)
    rng = np.random.RandomState(31)
    for _ in range(160):
        p = rng.randint(0, total - 2000)
        d = rng.randint(200, 1400)
        seg = rng.uniform(-1, 1, d) * np.linspace(1, 0, d) ** 2
        crackle[p:p + d] += seg * rng.uniform(.05, .22)
    crackle = lowpass_fast(crackle, 3000)
    out = hum + crackle * .5
    fade = int(SR * .5)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return normalise(out, .40)


def ambience_forest():
    n = 12.0
    total = int(SR * n)
    wind = lowpass_fast(np.random.RandomState(40).uniform(-1, 1, total), 380)
    wind *= (.10 + .05 * np.sin(2 * np.pi * .08 * np.arange(total) / SR))
    birds = np.zeros(total)
    rng = np.random.RandomState(41)
    for _ in range(14):
        p = rng.randint(0, total - SR)
        f0 = rng.uniform(1800, 3200)
        d = rng.uniform(.08, .18)
        seg = pitch_sweep(f0, f0 * rng.uniform(.7, 1.4), d, sine)
        seg = seg * env(len(seg), .01, .04, .3, .06) * .10
        birds[p:p + len(seg)] += seg
    out = wind + birds
    fade = int(SR * .5)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return normalise(out, .45)


MUSIC = {"title": music_title, "morning": music_morning, "day": music_day,
         "evening": music_evening, "night": music_night}
AMBIENCE = {"restaurant": ambience_restaurant, "forest": ambience_forest}


def build(manifest):
    for name, fn in SFX.items():
        x = fn()
        p = write_wav(os.path.join(OUT, "sfx", name + ".wav"), x, stereo=False)
        manifest.append({"kind": "audio", "group": "sfx", "id": name,
                         "path": rel(p), "seconds": round(len(x) / SR, 2)})
    for name, fn in MUSIC.items():
        x = fn()
        p = write_wav(os.path.join(OUT, "music", name + ".wav"), x)
        manifest.append({"kind": "audio", "group": "music", "id": name,
                         "path": rel(p), "loop": True,
                         "seconds": round(len(x) / SR, 2)})
    for name, fn in AMBIENCE.items():
        x = fn()
        p = write_wav(os.path.join(OUT, "ambience", name + ".wav"), x)
        manifest.append({"kind": "audio", "group": "ambience", "id": name,
                         "path": rel(p), "loop": True,
                         "seconds": round(len(x) / SR, 2)})
    print("  audio: %d sfx, %d music, %d ambience"
          % (len(SFX), len(MUSIC), len(AMBIENCE)))
    return manifest


if __name__ == "__main__":
    build([])
