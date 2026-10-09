"""Synthesises the app's UI sound effects as small 16-bit mono WAV files.
All sounds are generated from sine/square tones here, so they are original
and licence-free. Run: python tools/make_sfx.py  (writes frontend/codewar/assets/sfx/)."""
import math, os, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'frontend', 'codewar', 'assets', 'sfx')


def tone(freq, dur, vol=0.5, shape='sine', slide=0.0, attack=0.004, release=0.06):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq + slide * (t / dur)
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        if shape == 'square':
            s = 1.0 if s >= 0 else -1.0
            s *= 0.6
        env = min(1.0, t / attack) if attack else 1.0
        tail = dur - t
        if tail < release:
            env *= tail / release
        out.append(s * vol * env)
    return out


def silence(dur):
    return [0.0] * int(RATE * dur)


def mix(*parts):
    return [x for p in parts for x in p]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))
    print(name, os.path.getsize(path), 'bytes')


save('tap', tone(1400, 0.035, 0.35, release=0.02))
save('select', mix(tone(880, 0.04, 0.3), tone(1320, 0.05, 0.3)))
save('success', mix(tone(660, 0.09, 0.4), tone(880, 0.09, 0.4), tone(1320, 0.18, 0.4)))
save('error', mix(tone(220, 0.12, 0.45, 'square'), silence(0.02), tone(165, 0.2, 0.45, 'square')))
save('countdown', tone(880, 0.12, 0.45))
save('go', mix(tone(1320, 0.28, 0.5, slide=400)))
save('levelup', mix(*[tone(f, 0.1, 0.4) for f in (523, 659, 784, 1047)], tone(1319, 0.3, 0.4)))
save('win', mix(tone(523, 0.12, 0.45), tone(659, 0.12, 0.45), tone(784, 0.12, 0.45), tone(1047, 0.35, 0.5)))
save('lose', mix(tone(392, 0.16, 0.4), tone(330, 0.16, 0.4), tone(262, 0.4, 0.4, release=0.2)))
