"""Genera efectos de sonido y una musica chiptune sencilla en assets/sfx/ (wav).
Reemplazables por audio propio con el mismo nombre."""
import os, math, struct, random, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
SR = 22050

def write(name, samples):
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 30000)) for s in samples))

def tone(freq, dur, wave_='square', vol=0.3, slide=0.0, decay=True):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = freq + slide * (i / n)
        ph += f / SR
        x = ph % 1.0
        if wave_ == 'square': v = 1 if x < 0.5 else -1
        elif wave_ == 'tri': v = 4 * abs(x - 0.5) - 1
        elif wave_ == 'noise': v = random.uniform(-1, 1)
        else: v = math.sin(2 * math.pi * x)
        env = (1 - i / n) if decay else min(1, (n - i) / (SR * 0.01))
        out.append(v * vol * env)
    return out

def seq(*parts):
    o = []
    for p in parts: o += p
    return o

write('click.wav', tone(880, 0.04, 'square', 0.18))
write('coin.wav', seq(tone(988, 0.05, 'square', 0.2), tone(1319, 0.12, 'square', 0.2)))
write('cash.wav', seq(tone(1319, 0.05, 'square', 0.2), tone(1568, 0.05, 'square', 0.2), tone(2093, 0.16, 'square', 0.2)))
write('buy.wav', seq(tone(660, 0.05, 'tri', 0.35), tone(990, 0.08, 'tri', 0.35)))
write('error.wav', seq(tone(220, 0.08, 'square', 0.2), tone(165, 0.14, 'square', 0.2)))
write('levelup.wav', seq(*[tone(f, 0.08, 'square', 0.2) for f in (523, 659, 784, 1047)], tone(1319, 0.25, 'square', 0.2)))
write('clean.wav', tone(0, 0.12, 'noise', 0.25))
write('truck.wav', seq(tone(90, 0.25, 'square', 0.18, slide=40), tone(130, 0.2, 'square', 0.15, slide=-30)))
write('unload.wav', seq(tone(0, 0.08, 'noise', 0.2), tone(0, 0.08, 'noise', 0.15), tone(523, 0.1, 'tri', 0.3)))
write('bell.wav', seq(tone(1760, 0.06, 'sine', 0.35), tone(1760, 0.3, 'sine', 0.25)))
write('page.wav', tone(0, 0.06, 'noise', 0.12))

# musica: loop de 16 compases tipo ranchera-chiptune muy suave
notes = {'C4': 262, 'D4': 294, 'E4': 330, 'F4': 349, 'G4': 392, 'A4': 440, 'B4': 494, 'C5': 523, 'D5': 587, 'E5': 659, 'G3': 196, 'C3': 131, 'F3': 175, 'G2': 98, 'A3': 220}
mel = ['E4', 'G4', 'C5', 'G4', 'A4', 'G4', 'E4', '-', 'F4', 'A4', 'C5', 'A4', 'G4', 'E4', 'D4', '-',
       'E4', 'G4', 'C5', 'D5', 'E5', 'D5', 'C5', 'A4', 'G4', 'A4', 'G4', 'E4', 'D4', 'E4', 'C4', '-']
bass = ['C3', 'G3', 'C3', 'G3', 'F3', 'C4', 'F3', 'C4', 'G2', 'D4', 'G2', 'D4', 'C3', 'G3', 'C3', 'G3']
beat = 0.24
music = []
for rep in range(2):
    for i, m in enumerate(mel):
        b = bass[(i // 2) % len(bass)]
        n = int(SR * beat)
        mf = notes.get(m, 0); bf = notes[b]
        for k in range(n):
            t = k / SR
            env = max(0, 1 - k / n * 0.9)
            v = 0
            if mf: v += (1 if (t * mf) % 1 < 0.25 else -1) * 0.09 * env
            v += (4 * abs((t * bf) % 1 - 0.5) - 1) * 0.12
            if k < SR * 0.02 and i % 2 == 0: v += random.uniform(-1, 1) * 0.05
            music.append(v)
write('music.wav', music)
print('ok')
