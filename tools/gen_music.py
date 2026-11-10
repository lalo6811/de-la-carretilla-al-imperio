"""Compone la musica del juego (chiptune). Genera assets/sfx/music_game.ogg y music_menu.ogg.
- music_game: estilo cumbia, ~2 min, secciones Intro / A / B / Puente / C / D / A' / Final.
- music_menu: tranquila, tipo guitarra, ~1 min.
Uso: python3 tools/gen_music.py
"""
import os, subprocess, random
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 32000

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}

def midi(name, octave):
    return 12 * (octave + 1) + NOTE[name]

def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12)

CHORDS = {  # tipo -> intervalos
    '': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10],
}

def chord_notes(sym, octave=3):
    root = sym.rstrip('m7') if sym not in ('',) else sym
    q = sym[len(root):]
    return [midi(root, octave) + i for i in CHORDS[q]]

# ------------------------------------------------------------- osciladores
def osc(kind, f, n, duty=0.5, vib=0.0):
    t = np.arange(n) / SR
    if vib:
        ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1)) / SR)
    else:
        ph = f * t
    x = ph % 1.0
    if kind == 'square':
        return np.where(x < duty, 1.0, -1.0)
    if kind == 'tri':
        return 4 * np.abs(x - 0.5) - 1
    if kind == 'saw':
        return 2 * x - 1
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    raise ValueError(kind)

def env(n, a=0.005, d=0.08, s=0.6, r=0.05):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n); e[:na] = np.linspace(0, 1, na) if na else e[:na]
    if na + nd < n: e[na:na + nd] = np.linspace(1, s, nd)
    if nr and nr < n: e[-nr:] *= np.linspace(1, 0, nr)
    return e

def lowpass(x, k=6):
    if k <= 1: return x
    return np.convolve(x, np.ones(k) / k, mode='same')

class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR)
    def add(self, t, sig):
        i = int(t * SR)
        if i >= len(self.buf): return
        sig = sig[:len(self.buf) - i]
        self.buf[i:i + len(sig)] += sig

# ------------------------------------------------------------- instrumentos
def lead(f, dur, vol=0.12, duty=0.25):
    n = int(dur * SR)
    return lowpass(osc('square', f, n, duty, vib=0.006), 3) * env(n, 0.004, 0.06, 0.7, 0.04) * vol

def accordion(fs, dur, vol=0.05):
    n = int(dur * SR)
    s = np.zeros(n)
    for f in fs:
        s += osc('square', f * 1.003, n, 0.5) + osc('square', f * 0.997, n, 0.5)
    return lowpass(s, 8) * env(n, 0.01, 0.05, 0.5, 0.03) * vol

def bass(f, dur, vol=0.22):
    n = int(dur * SR)
    return osc('tri', f, n) * env(n, 0.003, 0.1, 0.65, 0.03) * vol

def pluck(f, dur, vol=0.12):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = osc('square', f, n, 0.3) * 0.6 + osc('tri', f * 2, n) * 0.4
    return lowpass(s, 10) * np.exp(-t * 5.5) * vol

def noise(dur, vol=0.05, k=1, decay=40):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.random.uniform(-1, 1, n)
    if k > 1: s = s - lowpass(s, k)
    return s * np.exp(-t * decay) * vol

def kick(vol=0.35):
    n = int(0.16 * SR); t = np.arange(n) / SR
    f = 120 * np.exp(-t * 25) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18) * vol

def clap(vol=0.09):
    return noise(0.12, vol, k=4, decay=28)

def guiro(dur, vol=0.035):
    # raspado: varios golpecitos rapidos
    n = int(dur * SR); s = np.zeros(n)
    for i in range(int(dur / 0.012)):
        g = noise(0.01, vol * (0.6 + 0.4 * (i / max(1, dur / 0.012))), k=2, decay=200)
        j = int(i * 0.012 * SR)
        s[j:j + len(g)] += g[:n - j]
    return s

# ------------------------------------------------------------- composicion
def make_motif(rng, chord, scale, bars=2, beats=4, density=0.6):
    """Motivo de 'bars' compases: lista de (beat_inicio, duracion, grado relativo al acorde)"""
    events = []
    rhythms = [
        [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
        [(0, 1.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1)],
        [(0, 0.5), (0.5, 0.5), (1, 1), (2.5, 0.5), (3, 1)],
        [(0, 2), (2, 0.5), (2.5, 0.5), (3, 0.5), (3.5, 0.5)],
        [(0.5, 0.5), (1, 0.5), (1.5, 1), (3, 1)],
    ]
    pos = rng.randrange(0, 3)
    for b in range(bars):
        rh = rng.choice(rhythms)
        for (st, du) in rh:
            step = rng.choice([-2, -1, -1, 1, 1, 2, 0, 3])
            pos = max(-3, min(9, pos + step))
            events.append((b * beats + st, du, pos))
    return events

def scale_note(scale, root_midi, deg):
    o, i = divmod(deg, len(scale))
    return root_midi + scale[i] + 12 * o

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]

def section(track, t0, bpm, prog, key, mode, seed, lead_on=True, lead_oct=5, style='cumbia', lead_vol=0.11, variation=0):
    rng = random.Random(seed)
    beat = 60.0 / bpm
    scale = MAJOR if mode == 'maj' else MINOR
    key_m = midi(key, lead_oct)
    motif = make_motif(rng, prog[0], scale)
    motif2 = make_motif(rng, prog[0], scale)
    nbars = len(prog)
    for bar, ch in enumerate(prog):
        tb = t0 + bar * 4 * beat
        cn = chord_notes(ch, 3)
        root = cn[0]
        # ---- percusion
        if style == 'cumbia':
            for b in range(4):
                if b in (0, 2): track.add(tb + b * beat, kick())
                if b in (1, 3): track.add(tb + b * beat, clap())
            for b in range(4):  # guiro: largo-corto-corto
                track.add(tb + b * beat, guiro(beat * 0.45))
                track.add(tb + b * beat + beat * 0.5, noise(0.03, 0.03, k=2, decay=90))
                track.add(tb + b * beat + beat * 0.75, noise(0.03, 0.03, k=2, decay=90))
            # bajo tumbao: 1, 2&, 3, 4& (raiz-quinta)
            for (bt, iv, du) in [(0, 0, 0.9), (1.5, 7, 0.4), (2, 0, 0.9), (3.5, 7, 0.4)]:
                track.add(tb + bt * beat, bass(freq(root - 12 + iv), du * beat))
            # acordeon a contratiempo
            for b in range(4):
                track.add(tb + (b + 0.5) * beat, accordion([freq(m + 12) for m in cn], beat * 0.35))
        elif style == 'break':
            track.add(tb, kick()); track.add(tb + 2 * beat, kick())
            for b in range(8):
                track.add(tb + b * beat * 0.5, noise(0.02, 0.025, k=2, decay=120))
            for (bt, iv, du) in [(0, 0, 1.4), (1.5, 12, 0.4), (2, 7, 1.4), (3.5, 5, 0.4)]:
                track.add(tb + bt * beat, bass(freq(root - 12 + iv), du * beat))
            for k in range(8):  # arpegio
                m = cn[k % len(cn)] + 24
                track.add(tb + k * beat * 0.5, pluck(freq(m), beat * 0.5, 0.06))
        elif style == 'menu':
            for (bt, iv, du) in [(0, 0, 1.8), (2, 7, 1.8)]:
                track.add(tb + bt * beat, bass(freq(root - 12 + iv), du * beat, 0.16))
            arp = [0, 1, 2, 1, 2, 1, 0, 1] if len(cn) >= 3 else [0, 1, 0, 1]
            for k, a in enumerate(arp):
                m = cn[a % len(cn)] + 12 + (12 if k in (2, 4) else 0)
                track.add(tb + k * beat * 0.5, pluck(freq(m), beat * 1.2, 0.07))
        # ---- melodia
        if lead_on:
            phrase_bar = bar % 4
            mot = motif if phrase_bar < 2 or (variation == 1 and phrase_bar == 2) else motif2
            off = (bar % 2) * 4
            for (st, du, deg) in mot:
                if off <= st < off + 4:
                    shift = {'': 0, 'm': 0, '7': 0}.get('', 0)
                    # acerca la nota a una del acorde en tiempos fuertes
                    m = scale_note(scale, key_m, deg + (2 if (bar % 4 == 1 and variation) else 0))
                    if st % 1 == 0:
                        chord_pcs = [(x - root) % 12 for x in cn]
                        best = min(range(-2, 3), key=lambda d: 0 if ((m + d - root) % 12) in [0, 4, 7, 3] else 1 + abs(d))
                        m += best
                    if bar == nbars - 1 and st >= off + 2:
                        m = root + 12 * (lead_oct - 3)
                    if style == 'menu':
                        track.add(tb + (st - off) * beat, pluck(freq(m), du * beat * 1.4, lead_vol))
                    else:
                        track.add(tb + (st - off) * beat, lead(freq(m), du * beat * 0.92, lead_vol, 0.25 if variation == 0 else 0.125))
    return t0 + nbars * 4 * beat

def render(track, name, seconds):
    x = track.buf[:int(seconds * SR)]
    # compresion suave y normalizacion
    x = np.tanh(x * 1.6) / np.tanh(1.6)
    x = x / max(1e-6, np.max(np.abs(x))) * 0.85
    # fundido corto para que el loop no truene
    f = int(0.03 * SR)
    x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
    wav = os.path.join(OUT, name + '.wav')
    pcm = (x * 32767).astype(np.int16)
    import wave
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    ogg = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', ogg], check=True)
    os.remove(wav)
    print(name, round(seconds, 1), 's')

def game_music():
    np.random.seed(3)
    bpm = 98
    tr = Track(200)
    t = 0.0
    t = section(tr, t, bpm, ['C', 'G', 'G', 'C'], 'C', 'maj', 1, lead_on=False)                                   # intro
    t = section(tr, t, bpm, ['C', 'G', 'G', 'C', 'F', 'C', 'G', 'C'], 'C', 'maj', 11)                               # A
    t = section(tr, t, bpm, ['Am', 'F', 'C', 'G', 'Am', 'F', 'G', 'Am'], 'A', 'min', 22, lead_oct=5, variation=1)   # B
    t = section(tr, t, bpm, ['F', 'C', 'G', 'C'], 'C', 'maj', 33, lead_on=False, style='break')                     # puente
    t = section(tr, t, bpm, ['F', 'Bb', 'C', 'F', 'Dm', 'Bb', 'C', 'F'], 'F', 'maj', 44, lead_oct=5)               # C
    t = section(tr, t, bpm, ['G', 'D', 'D', 'G', 'C', 'G', 'D', 'G'], 'G', 'maj', 55, lead_oct=5, variation=1)     # D
    t = section(tr, t, bpm, ['C', 'G', 'G', 'C', 'F', 'C', 'G', 'C'], 'C', 'maj', 11, lead_oct=6, variation=1, lead_vol=0.09)  # A'
    t = section(tr, t, bpm, ['F', 'G', 'C', 'C'], 'C', 'maj', 66, lead_on=False, style='break')                     # final
    render(tr, 'music_game', t)

def menu_music():
    np.random.seed(5)
    bpm = 76
    tr = Track(120)
    t = 0.0
    t = section(tr, t, bpm, ['C', 'Am', 'F', 'G'], 'C', 'maj', 101, lead_on=False, style='menu')
    t = section(tr, t, bpm, ['C', 'Am', 'F', 'G', 'C', 'Am', 'Dm', 'G'], 'C', 'maj', 102, style='menu', lead_vol=0.1)
    t = section(tr, t, bpm, ['F', 'G', 'Em', 'Am', 'F', 'G', 'C', 'C'], 'C', 'maj', 103, style='menu', lead_vol=0.1, variation=1)
    render(tr, 'music_menu', t)

if __name__ == '__main__':
    game_music()
    menu_music()
