"""Genera el arte pixel del juego (estilo Jessy's Rush) en assets/art/.
Cada PNG se puede reemplazar despues por arte propio con el mismo nombre y tamano.
Uso: python3 tools/gen_art.py
"""
import os, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art")
FONT = os.path.join(ROOT, "assets", "fonts", "PressStart2P.ttf")
os.makedirs(OUT, exist_ok=True)

def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i+2], 16) for i in (0, 2, 4)) + (255,)

INK = '#1b1424'
C = dict(
    ink=INK, night='#1b1830', panel='#241f3d', line='#3a3363', sand='#f2c14e', mint='#7fe0c4',
    coral='#ef6f6c', bone='#f4ecd8', dim='#9a93c4', gold='#f2c14e',
    sky1='#a6dcf8', sky2='#cdeefc', grass='#6cc24a', grassDk='#4d9a38', grassHi='#9ade6a',
    dirt='#9c6b3e', dirtDk='#7a5230', dirtHi='#b88450', wood='#b88450', woodDk='#7a5230', woodHi='#d8a870',
    concrete='#a9a4b0', concreteDk='#8a8494', concreteHi='#c9c4cf', white='#fffaf0',
)

class Cv:
    def __init__(self, w, h, bg=None):
        self.img = Image.new('RGBA', (w, h), hx(bg) if bg else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.w, self.h = w, h
    def r(self, x, y, w, h, c):
        if w <= 0 or h <= 0: return
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=hx(c))
    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), hx(c))
    def box(self, x, y, w, h, fill, outline=INK):
        self.r(x, y, w, h, outline); self.r(x + 1, y + 1, w - 2, h - 2, fill)
    def text(self, x, y, s, c, size=8):
        f = ImageFont.truetype(FONT, size)
        self.d.text((x, y), s, font=f, fill=hx(c))
    def text_w(self, s, size=8):
        f = ImageFont.truetype(FONT, size)
        return int(self.d.textlength(s, font=f))
    def save(self, name, scale=1):
        im = self.img
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(os.path.join(OUT, name))

def rows_sprite(rows, pal):
    h = len(rows); w = len(rows[0])
    cv = Cv(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal: cv.p(x, y, pal[ch])
    return cv

# ------------------------------------------------------------------ piezas
def sack(cv, x, y, body='#d9d4c8', band='#4a6fb5', w=10, h=8):
    cv.r(x, y + 1, w, h - 1, INK); cv.r(x + 1, y, w - 2, 1, INK)
    cv.r(x + 1, y + 1, w - 2, h - 2, body)
    cv.r(x + 1, y + 3, w - 2, 2, band)
    cv.r(x + 2, y + 1, w - 4, 1, C['white'])

def sand_pile(cv, x, base, w, h, c1='#e8c47a', c2='#c9a25a', c3='#f5dc9e'):
    for i in range(h):
        ww = int(w * (i + 1) / h)
        cv.r(x + (w - ww) // 2, base - h + i, ww, 1, c1)
    cv.r(x, base - 1, w, 1, c2)
    for i in range(max(1, w // 6)):
        cv.p(x + w // 2 - w // 6 + i * 2, base - h + 2 + i % 2, c3)
    cv.p(x + (w // 2), base - h, INK)

def gravel_pile(cv, x, base, w, h):
    sand_pile(cv, x, base, w, h, '#9a96a0', '#6f6b78', '#c4c0cb')
    rnd = random.Random(x * 7 + base)
    for _ in range(w * h // 6):
        px = x + rnd.randrange(w); py = base - rnd.randrange(h)
        if cv.img.getpixel((px, py))[3] > 0: cv.p(px, py, rnd.choice(['#6f6b78', '#c4c0cb', '#55515e']))

def rock(cv, x, y, s=6, c='#8a8494'):
    cv.r(x + 1, y, s - 2, s, INK); cv.r(x, y + 1, s, s - 2, INK)
    cv.r(x + 1, y + 1, s - 2, s - 2, c)
    cv.r(x + 1, y + 1, s - 3, 1, '#c9c4cf')

def bricks(cv, x, y, cols=3, rows=3, c='#c0613f'):
    for j in range(rows):
        for i in range(cols):
            off = 2 if j % 2 else 0
            cv.box(x + i * 6 + off, y + j * 3, 6, 4, c)

def shelf(cv, x, y, w, h, levels=3, broken=False, full=0):
    """Anaquel de madera. full: 0 vacio, 1 poco, 2 lleno"""
    cv.r(x, y, 2, h, INK); cv.r(x + w - 2, y, 2, h, INK)
    cv.r(x + 1, y + 1, 1, h - 1, C['wood']); cv.r(x + w - 1, y, 0, 0, INK)
    step = h // levels
    rnd = random.Random(x * 13 + y)
    cols = ['#ef6f6c', '#4fa3a0', '#f2c14e', '#7fe0c4', '#c0613f', '#6a8fd8', '#f4ecd8', '#9c6b3e']
    for i in range(levels):
        yy = y + step * (i + 1) - 1
        if broken and i == 1:
            cv.r(x + 2, yy, w // 2 - 2, 2, C['woodDk'])
            for k in range(w // 2 - 2, w - 4): cv.p(x + 2 + k, yy + (k - w // 2) // 3 + 2, C['woodDk'])
        else:
            cv.r(x, yy, w, 2, INK); cv.r(x + 1, yy, w - 2, 1, C['woodHi'])
        if full:
            px = x + 3
            while px < x + w - 5:
                if full == 1 and rnd.random() < 0.6:
                    px += 5; continue
                kind = rnd.randrange(3)
                col = rnd.choice(cols)
                if kind == 0:  # bote de pintura
                    cv.box(px, yy - 6, 5, 6, col); cv.r(px + 1, yy - 5, 3, 1, C['white'])
                    px += 6
                elif kind == 1:  # caja
                    cv.box(px, yy - 5, 6, 5, '#d8a870'); cv.r(px + 2, yy - 4, 2, 1, col)
                    px += 7
                else:  # rollo / botella
                    cv.box(px, yy - 7, 3, 7, col)
                    px += 4

def door(cv, x, y, w, h, open_=True):
    cv.r(x - 1, y - 1, w + 2, h + 1, INK)
    cv.r(x, y, w, h, '#ffd98a' if open_ else '#7a4a2a')
    if open_:
        cv.r(x, y + h - 4, w, 4, '#e8b060')
        cv.r(x, y, 3, h, '#7a4a2a'); cv.r(x + 1, y + 3, 1, h - 6, '#5c361e')

def window_(cv, x, y, w, h, view='sky'):
    cv.r(x - 1, y - 1, w + 2, h + 2, INK)
    if view == 'sky':
        cv.r(x, y, w, h, C['sky1']); cv.r(x + 1, y + 1, w // 3, 2, '#ffffff')
        cv.r(x, y + h - 3, w, 3, C['grass'])
    elif view == 'night':
        cv.r(x, y, w, h, '#2b3f6a'); cv.p(x + 2, y + 2, '#fff27a'); cv.p(x + w - 4, y + 4, '#ffffff')
    elif view == 'yard':
        cv.r(x, y, w, h, C['sky1']); cv.r(x, y + h - 4, w, 4, C['dirtHi'])
        sand_pile(cv, x + 2, y + h - 3, 10, 5); gravel_pile(cv, x + w - 13, y + h - 3, 11, 5)
    cv.r(x + w // 2, y, 1, h, INK); cv.r(x, y + h // 2, w, 1, INK)

def bulb(cv, x, y):
    cv.r(x, 0, 1, y, INK); cv.box(x - 2, y, 5, 5, '#fff27a'); cv.p(x - 1, y + 1, '#ffffff')

# ------------------------------------------------------------------ LOCAL (180x136)
W, H = 180, 136
FLOOR = 104

def shop_stage(stage):
    cv = Cv(W, H)
    # pared
    wall = {0: '#b8ad98', 1: '#d9cdb4', 2: '#d9cdb4', 3: '#f0d9a8', 4: '#f0d9a8', 5: '#e9e1c8', 6: '#e9e1c8', 7: '#dfe8d4', 8: '#f4ecd8'}[stage]
    wallDk = {0: '#958a76', 1: '#bfb398', 2: '#bfb398', 3: '#d9bd86', 4: '#d9bd86', 5: '#cfc6aa', 6: '#cfc6aa', 7: '#c3cfb5', 8: '#e0d4b8'}[stage]
    cv.r(0, 0, W, FLOOR, wall)
    for yy in range(6, FLOOR, 8): cv.r(0, yy, W, 1, wallDk)
    if stage >= 3:  # franja pintada
        band = '#4fa3a0' if stage < 8 else '#2b3f8f'
        cv.r(0, FLOOR - 26, W, 26, band); cv.r(0, FLOOR - 27, W, 1, INK)
        cv.r(0, FLOOR - 25, W, 1, '#7fe0c4' if stage < 8 else '#6a8fd8')
    # piso
    fl = '#8a8494' if stage == 0 else ('#a9a4b0' if stage < 5 else ('#c0613f' if stage < 8 else '#d9d4c8'))
    flDk = '#6b6578' if stage == 0 else ('#8a8494' if stage < 5 else ('#9a4a30' if stage < 8 else '#b0aab8'))
    cv.r(0, FLOOR, W, H - FLOOR, fl)
    cv.r(0, FLOOR, W, 1, INK)
    for xx in range(0, W, 12): cv.r(xx, FLOOR + 1, 1, H - FLOOR, flDk)
    for yy in range(FLOOR + 10, H, 10): cv.r(0, yy, W, 1, flDk)
    # techo / vigas
    cv.r(0, 0, W, 4, C['woodDk']); cv.r(0, 4, W, 1, INK)
    # puerta derecha
    door(cv, 160, 52, 18, FLOOR - 52)
    # ventana
    if stage >= 6:
        window_(cv, 112, 14, 30, 18, 'yard')
    else:
        window_(cv, 118, 16, 22, 16, 'sky')
        if stage == 0:
            cv.r(118, 16, 22, 16, '#7f9cab'); cv.r(120, 18, 6, 1, '#b8c8d0')
            for i in range(8): cv.p(126 + i, 18 + i, INK)
    # anaqueles
    if stage == 0:
        shelf(cv, 6, 30, 44, 48, 3, broken=True, full=1)
    elif stage == 1:
        shelf(cv, 6, 30, 44, 48, 3, full=1)
    else:
        shelf(cv, 4, 26, 46, 52, 3, full=2)
        shelf(cv, 54, 26, 40, 52, 3, full=2 if stage >= 3 else 1)
    if stage >= 5:  # tapanco / ampliacion: anaquel alto y escalera
        cv.r(0, 18, 100, 3, INK); cv.r(0, 18, 100, 2, C['wood'])
        for i in range(0, 96, 8): cv.box(2 + i, 10, 7, 8, '#d8a870')
    if stage >= 6:  # puerta a bodega
        cv.r(0, 30, 3, FLOOR - 30, INK)
    # letrero
    if stage >= 3:
        sign = 'MATERIALES'
        tw = cv.text_w(sign)
        cv.box(110 - tw // 2 + 18, 37, tw + 6, 12, '#2b3f8f' if stage < 8 else '#c0613f')
        cv.text(110 - tw // 2 + 21, 39, sign, C['sand'] if stage < 8 else C['bone'])
    # foco
    bulb(cv, 90, 8 if stage == 0 else 10)
    if stage >= 4:
        bulb(cv, 40, 10)
    # suciedad base
    if stage == 0:
        for (x, y, l) in [(70, 8, 14), (150, 12, 10), (20, 6, 9)]:
            for i in range(l): cv.p(x + i, y + (i % 3), '#5a5246')
        cv.r(100, 60, 1, 14, '#6b604e'); cv.r(101, 74, 1, 6, '#6b604e')
    # mostrador
    cx, cy = 96, 84
    cnt = '#7a4a2a' if stage < 4 else ('#2b3f8f' if stage >= 8 else '#4fa3a0')
    cntw = 30 if stage < 4 else 38
    cv.box(cx, cy, cntw, FLOOR - cy + 1, cnt)
    cv.r(cx - 2, cy - 2, cntw + 4, 4, INK); cv.r(cx - 1, cy - 1, cntw + 2, 2, C['woodHi'] if stage < 8 else '#d9d4c8')
    cv.r(cx + 3, cy + 6, cntw - 6, 1, INK)
    if stage >= 2:  # caja registradora
        cv.box(cx + 4, cy - 9, 10, 8, '#d9d4c8'); cv.r(cx + 6, cy - 7, 6, 2, '#4fbf9a')
    if stage == 0:
        cv.r(cx + 6, cy + 10, 8, 1, '#5a3c24'); cv.r(cx + 14, cy + 11, 4, 1, '#5a3c24')
    return cv

def shop_overlay_bodega():
    """Seccion de bodega anexa que se ve a la izquierda (etapa 6+)."""
    cv = Cv(W, H)
    return cv

def make_shop():
    for s in range(9):
        shop_stage(s).save(f'shop_{s}.png')
    # manchas / basura para limpiar (16x16)
    trash = [
        ['................', '................', '........oo......', '......oo..oo....', '....oo......o...', '...o..o..o...o..', '..o.o..o..o..o..', '..o..o..o..o.o..', '...o..o..o..o...', '....o..o..oo....', '.....oooooo.....', '................', '................', '................', '................', '................'],
    ]
    # telarana
    cv = Cv(16, 16)
    for i in range(16): cv.p(i, i, '#e8e4ee'); cv.p(15 - i, i, '#c9c4cf')
    for i in range(16): cv.p(8, i, '#e8e4ee'); cv.p(i, 8, '#c9c4cf')
    for k in (3, 6):
        for a in range(-k, k + 1):
            cv.p(8 + a, 8 - k, '#e8e4ee'); cv.p(8 + a, 8 + k, '#e8e4ee'); cv.p(8 - k, 8 + a, '#e8e4ee'); cv.p(8 + k, 8 + a, '#e8e4ee')
    cv.save('dirt_web.png')
    # bolsa de basura
    cv = Cv(16, 16)
    cv.r(3, 6, 10, 9, INK); cv.r(4, 5, 8, 10, INK); cv.r(4, 6, 8, 8, '#3d3548'); cv.r(5, 7, 3, 2, '#5a5168')
    cv.r(6, 2, 4, 4, INK); cv.r(7, 3, 2, 2, '#3d3548'); cv.p(5, 2, INK); cv.p(10, 2, INK)
    cv.save('dirt_bag.png')
    # mancha
    cv = Cv(16, 16)
    for (x, y, w, h) in [(2, 9, 12, 4), (4, 8, 8, 6), (1, 11, 3, 2), (12, 12, 3, 1)]:
        cv.r(x, y, w, h, '#5a4a3a')
    cv.r(5, 9, 4, 1, '#6e5c48')
    cv.save('dirt_stain.png')
    # escombro
    cv = Cv(16, 16)
    rock(cv, 1, 9, 6, '#a9a4b0'); rock(cv, 6, 7, 7, '#8a8494'); rock(cv, 11, 11, 4, '#c9c4cf')
    cv.r(2, 15, 13, 1, '#6b6578')
    cv.save('dirt_rubble.png')
    # caja de carton vieja
    cv = Cv(16, 16)
    cv.box(2, 6, 12, 9, '#b58f62'); cv.r(3, 7, 10, 1, '#d8a870'); cv.r(7, 6, 1, 9, '#7a5a3a')
    cv.r(1, 4, 6, 3, INK); cv.r(2, 5, 4, 1, '#b58f62')
    cv.save('dirt_box.png')

# ------------------------------------------------------------------ CASA
def house_stage(s):
    cv = Cv(W, H)
    wall = ['#a89a86', '#c9b894', '#e8c89a', '#f2d9c0', '#dfe8d4', '#e6e0f4'][s]
    wallDk = ['#8f8170', '#b0a07c', '#cfae80', '#dcc0a6', '#c3cfb5', '#cbc4de'][s]
    cv.r(0, 0, W, FLOOR, wall)
    if s == 0:
        for yy in range(5, FLOOR, 6): cv.r(0, yy, W, 1, wallDk)
        for i in range(10): cv.p(40 + i, 20 + i * 2, '#6b604e')
    elif s >= 3:  # tapiz
        for xx in range(4, W, 10): cv.r(xx, 0, 2, FLOOR, wallDk)
    else:
        for yy in range(10, FLOOR, 12): cv.r(0, yy, W, 1, wallDk)
    floor = ['#7a6a58', '#9c6b3e', '#b88450', '#b88450', '#c9a26e', '#d8b07a'][s]
    cv.r(0, FLOOR, W, H - FLOOR, floor); cv.r(0, FLOOR, W, 1, INK)
    for xx in range(0, W, 16): cv.r(xx, FLOOR + 1, 1, H - FLOOR, C['woodDk'] if s else '#5a4a3a')
    cv.r(0, 0, W, 3, C['woodDk']); cv.r(0, 3, W, 1, INK)
    # ventana
    if s >= 5:
        window_(cv, 70, 14, 44, 30, 'sky')
        cv.r(66, 12, 4, 40, '#e8a0b0'); cv.r(114, 12, 4, 40, '#e8a0b0'); cv.r(64, 11, 56, 2, '#9a6a44')
    elif s >= 1:
        window_(cv, 76, 18, 28, 22, 'sky')
        if s >= 2:
            cv.r(72, 15, 4, 30, '#e8a0b0'); cv.r(104, 15, 4, 30, '#e8a0b0'); cv.r(70, 14, 40, 2, '#9a6a44')
    else:
        cv.r(76, 18, 28, 22, INK); cv.r(77, 19, 26, 20, '#2a1c14'); cv.r(73, 22, 34, 3, '#c9a26e'); cv.r(73, 32, 34, 3, '#c9a26e')
    # puerta
    door(cv, 160, 54, 18, FLOOR - 54, open_=False)
    cv.p(163, 80, C['gold'])
    # cama
    if s == 0:
        cv.box(8, FLOOR - 8, 40, 8, '#d9d4c8'); cv.r(9, FLOOR - 7, 10, 3, '#f4ecd8')  # colchon en el piso
        cv.r(20, FLOOR - 7, 27, 2, '#8a8494')
    else:
        bx, bw = 6, 46 if s < 4 else 54
        cv.box(bx, FLOOR - 20, 6, 20, C['woodDk'])  # cabecera
        cv.box(bx + 4, FLOOR - 12, bw, 8, '#f4ecd8')
        cv.r(bx + 6, FLOOR - 11, 10, 3, '#ffffff')
        cv.r(bx + 18, FLOOR - 11, bw - 15, 6, ['#ef6f6c', '#ef6f6c', '#4fa3a0', '#6a8fd8', '#7fe0c4', '#c0616b'][s])
        cv.r(bx + 4, FLOOR - 4, 3, 4, INK); cv.r(bx + bw, FLOOR - 4, 3, 4, INK)
    # foco / lampara
    if s <= 1:
        bulb(cv, 60, 8)
    else:
        cv.r(60, 0, 1, 6, INK); cv.box(55, 6, 11, 6, '#f2c14e'); cv.r(57, 12, 7, 1, '#fff27a')
    # caja / buro
    if s == 0:
        cv.box(52, FLOOR - 9, 12, 9, '#b58f62'); cv.r(53, FLOOR - 8, 10, 1, '#d8a870')
    else:
        cv.box(54, FLOOR - 12, 12, 12, C['wood']); cv.r(55, FLOOR - 11, 10, 1, C['woodHi']); cv.p(60, FLOOR - 7, C['gold'])
        cv.box(57, FLOOR - 18, 5, 6, '#f2c14e')  # lamparita
    # cocina
    if s >= 2:
        cv.box(118, FLOOR - 16, 16, 16, '#d9d4c8'); cv.r(118, FLOOR - 16, 16, 2, INK)
        cv.r(120, FLOOR - 16, 4, 1, C['coral']); cv.r(127, FLOOR - 16, 4, 1, C['coral'])
        cv.box(120, FLOOR - 11, 12, 8, '#8a8494')
        cv.box(136, FLOOR - 30, 14, 30, '#f4ecd8'); cv.r(137, FLOOR - 18, 12, 1, INK); cv.r(147, FLOOR - 26, 1, 4, '#8a8494')
    # sala
    if s >= 3:
        cv.box(84, FLOOR - 14, 30, 10, '#c0616b'); cv.box(82, FLOOR - 20, 6, 16, '#a04a55'); cv.box(110, FLOOR - 20, 6, 16, '#a04a55')
        cv.r(86, FLOOR - 4, 2, 4, INK); cv.r(108, FLOOR - 4, 2, 4, INK)
        # tele
        cv.box(88, 50, 22, 14, '#3d3548'); cv.r(90, 52, 18, 10, '#4fbf9a'); cv.r(91, 53, 5, 2, '#a8f0d8')
        # planta
        cv.box(150, FLOOR - 8, 8, 8, '#c46a3a'); cv.r(151, FLOOR - 16, 2, 8, C['grassDk']); cv.r(154, FLOOR - 18, 2, 10, C['grass']); cv.r(156, FLOOR - 14, 2, 6, C['grassHi'])
    if s >= 4:  # escalera al segundo piso + tapete
        for i in range(6):
            cv.r(150 - i * 0, 18 + i * 0, 0, 0, INK)
        cv.r(30, FLOOR + 6, 60, 10, '#7fe0c4'); cv.r(32, FLOOR + 8, 56, 6, '#4fa3a0')
        for i in range(5):
            cv.box(140 - 30 + i * 6, 30 + i * 0, 0, 0, INK)
        # cuadros
        cv.box(20, 30, 14, 12, '#d8a870'); cv.r(22, 32, 10, 8, '#a6dcf8'); cv.r(22, 37, 10, 3, C['grass'])
    if s >= 5:
        cv.box(36, 26, 12, 16, '#d8a870'); cv.r(38, 28, 8, 12, '#ff9ec4')
        cv.box(124, 26, 16, 12, C['gold']); cv.r(126, 28, 12, 8, '#f4ecd8'); cv.text(127, 29, '1', C['coral'])
    return cv

def make_house():
    for s in range(6):
        house_stage(s).save(f'house_{s}.png')

# ------------------------------------------------------------------ MINA
def mine_scene(own=False):
    cv = Cv(W, H)
    for y in range(70):
        cv.r(0, y, W, 1, C['sky1'] if y > 30 else C['sky2'] if y < 12 else C['sky1'])
    cv.r(0, 0, W, 20, '#bfe6fb')
    # nubes
    for (x, y) in [(20, 10), (110, 6), (150, 18)]:
        cv.r(x + 2, y, 14, 4, '#ffffff'); cv.r(x, y + 3, 20, 4, '#ffffff'); cv.r(x + 1, y + 7, 18, 1, '#dbe9f2')
    # paredes de cantera escalonadas
    tiers = [(0, 40, '#c9a26e'), (0, 56, '#b58f62'), (0, 72, '#9c6b3e')]
    cv.r(0, 34, 72, 4, '#d8b07a'); cv.r(0, 38, 72, 70, '#c9a26e')
    cv.r(0, 52, 96, 3, '#b58f62'); cv.r(0, 55, 96, 60, '#b58f62')
    cv.r(0, 70, 120, 3, '#9c6b3e'); cv.r(0, 73, 120, 60, '#9c6b3e')
    for (x0, y0, l) in [(0, 38, 72), (0, 55, 96), (0, 73, 120)]:
        cv.r(x0, y0 - 1, l, 1, INK); cv.r(x0 + l - 1, y0 - 1, 1, 20, INK)
    rnd = random.Random(4)
    for _ in range(60):
        x = rnd.randrange(0, 118); y = rnd.randrange(40, 100)
        cv.p(x, y, rnd.choice(['#7a5230', '#d8b07a', '#8a5c34']))
    # colinas al fondo derecha
    for i in range(60):
        h = int(12 + 8 * abs(((i % 30) - 15) / 15))
        cv.r(120 + i, 70 - h, 1, h, '#93c07f')
    cv.r(120, 70, 60, 34, '#7fb46e')
    # suelo
    cv.r(0, FLOOR, W, H - FLOOR, C['dirtHi']); cv.r(0, FLOOR, W, 1, C['dirtDk'])
    for _ in range(40):
        cv.p(rnd.randrange(W), rnd.randrange(FLOOR + 2, H), rnd.choice([C['dirt'], C['dirtDk'], '#d8b07a']))
    # montones de material (posiciones fijas, el juego dibuja etiquetas encima)
    sand_pile(cv, 8, FLOOR + 1, 30, 14)
    gravel_pile(cv, 42, FLOOR + 1, 28, 13)
    sand_pile(cv, 74, FLOOR + 1, 26, 11, '#d8b07a', '#b58f62', '#ead2a4')  # tepetate
    for (x, y, s) in [(104, FLOOR - 9, 9), (112, FLOOR - 7, 7), (108, FLOOR - 14, 7), (118, FLOOR - 5, 6)]:
        rock(cv, x, y, s, '#8a8494')  # piedra
    for (x, y, s) in [(130, FLOOR - 8, 8), (137, FLOOR - 6, 6), (133, FLOOR - 13, 6)]:
        rock(cv, x, y, s, '#a04a3a')  # tezontle
    # caseta
    hx0 = 146
    cv.box(hx0, FLOOR - 26, 30, 26, '#d9cdb4' if not own else '#f4ecd8')
    cv.r(hx0 - 3, FLOOR - 30, 36, 5, INK); cv.r(hx0 - 2, FLOOR - 29, 34, 3, '#c0613f' if not own else '#2b3f8f')
    door(cv, hx0 + 18, FLOOR - 16, 8, 16, open_=True)
    cv.box(hx0 + 4, FLOOR - 20, 9, 7, C['sky1'])
    # letrero
    if own:
        cv.box(114, 38, 64, 14, '#2b3f8f'); cv.text(118, 41, 'TU MINA', C['sand'])
        cv.r(176, 20, 1, 18, INK); cv.r(166, 20, 10, 7, C['coral']); cv.r(166, 22, 10, 1, C['white'])
        # banda transportadora
        cv.r(60, FLOOR - 22, 50, 2, INK);
        for i in range(60, 110, 4): cv.r(i, FLOOR - 21, 2, 1, '#8a8494')
        cv.r(62, FLOOR - 20, 2, 20, INK); cv.r(106, FLOOR - 20, 2, 20, INK)
    else:
        cv.box(114, 40, 64, 14, '#7a4a2a'); cv.text(118, 43, 'LA MINA', C['bone'])
    cv.r(150, 54, 2, 8, INK); cv.r(170, 54, 2, 8, INK)
    return cv

def make_mine():
    mine_scene(False).save('mine.png')
    mine_scene(True).save('mine_own.png')

# ------------------------------------------------------------------ CALLE / FACHADA (menu e intro)
def facade(old=True, night=False):
    cv = Cv(W, H)
    sky = '#2b3f6a' if night else C['sky1']
    cv.r(0, 0, W, H, sky)
    if night:
        rnd = random.Random(9)
        for _ in range(30): cv.p(rnd.randrange(W), rnd.randrange(60), rnd.choice(['#ffffff', '#fff27a', '#9a93c4']))
        cv.box(150, 10, 10, 10, '#f4ecd8'); cv.r(151, 11, 3, 3, '#ffffff')
    else:
        cv.r(0, 0, W, 16, C['sky2'])
        for (x, y) in [(12, 12), (120, 8)]:
            cv.r(x + 2, y, 16, 4, '#ffffff'); cv.r(x, y + 3, 22, 4, '#ffffff')
    # edificios vecinos
    cv.box(-1, 40, 34, 80, '#c09060' if not night else '#4a3c52')
    for yy in (48, 64, 80): cv.box(6, yy, 8, 8, '#a6dcf8' if not night else '#ffd98a'); cv.box(20, yy, 8, 8, '#a6dcf8' if not night else '#2b3f6a')
    cv.box(146, 30, 36, 90, '#7fa0c0' if not night else '#3a3363')
    for yy in (38, 54, 70, 86): cv.box(152, yy, 8, 8, '#f4ecd8' if not night else '#ffd98a'); cv.box(166, yy, 8, 8, '#f4ecd8' if not night else '#2b3f6a')
    # local
    body = '#b8ad98' if old else '#f0d9a8'
    cv.box(32, 34, 116, 86, body)
    if old:
        for i in range(14): cv.p(60 + i, 50 + (i * 3) % 7, '#958a76')
        for i in range(10): cv.p(120 + i // 2, 70 + i, '#958a76')
    cv.r(30, 32, 120, 4, INK); cv.r(31, 33, 118, 2, C['woodDk'])
    # letrero
    signc = '#7a6a58' if old else '#2b3f8f'
    cv.box(40, 38, 100, 16, signc)
    t = 'MATERIALES' if not old else 'MATER ALES'
    tw = cv.text_w(t)
    cv.text(90 - tw // 2, 42, t, '#c9b894' if old else C['sand'])
    if old: cv.r(120, 40, 1, 10, INK)
    # cortina metalica
    cv.box(46, 62, 56, 58, '#8a8494' if old else '#ffd98a')
    if old:
        for yy in range(64, 118, 3): cv.r(47, yy, 54, 1, '#6b6578')
        cv.r(60, 80, 12, 6, '#c0613f'); cv.text(61, 79, 'SE', '#fff6d0', 8) if False else None
    else:
        cv.r(47, 112, 54, 7, '#e8b060')
    # ventana
    cv.box(110, 64, 28, 24, '#7f9cab' if old else C['sky1'])
    if old:
        for i in range(10): cv.p(114 + i, 68 + i, INK)
    # banqueta
    cv.r(0, 120, W, 4, '#c9c4cf'); cv.r(0, 120, W, 1, INK)
    cv.r(0, 124, W, 12, '#5d6270')
    for xx in range(4, W, 24): cv.r(xx, 129, 12, 2, '#f2c14e')
    return cv

def make_facades():
    facade(True).save('facade_old.png')
    facade(False).save('facade_new.png')
    facade(False, True).save('facade_night.png')
    # oficina (intro: pierdes tu trabajo)
    cv = Cv(W, H, '#d9d4c8')
    for xx in range(0, W, 30): cv.r(xx, 0, 1, FLOOR, '#c9c4cf')
    cv.r(0, FLOOR, W, H - FLOOR, '#6a8fd8'); cv.r(0, FLOOR, W, 1, INK)
    window_(cv, 20, 16, 40, 30, 'sky')
    cv.box(100, FLOOR - 26, 60, 6, '#8a8494'); cv.r(104, FLOOR - 20, 3, 20, INK); cv.r(154, FLOOR - 20, 3, 20, INK)
    cv.box(118, FLOOR - 40, 22, 14, '#3d3548'); cv.r(120, FLOOR - 38, 18, 10, '#7fe0c4'); cv.r(127, FLOOR - 26, 4, 0, INK)
    cv.box(70, 20, 22, 12, '#ffffff'); cv.text(72, 22, '-$', C['coral'])
    for i in range(18): cv.p(72 + i, 30 - (i % 9) // 2, C['coral'])
    cv.save('intro_office.png')
    # lluvia en la calle
    cv = facade(True, True)
    rnd = random.Random(2)
    for _ in range(90):
        x = rnd.randrange(W); y = rnd.randrange(H)
        cv.p(x, y, '#9fb6d8'); cv.p(x, y + 1, '#9fb6d8')
    cv.save('intro_rain.png')
    # carta del abuelo (fondo madera)
    cv = Cv(W, H, C['wood'])
    for yy in range(0, H, 9): cv.r(0, yy, W, 1, C['woodDk'])
    cv.box(40, 14, 100, 108, '#f4ecd8'); cv.r(41, 15, 98, 1, '#ffffff')
    for yy in range(28, 110, 8): cv.r(48, yy, 84, 1, '#c9b894')
    cv.box(118, 98, 16, 16, '#c0616b'); cv.r(122, 102, 8, 8, '#ef6f6c')
    cv.save('intro_letter.png')

# ------------------------------------------------------------------ VEHICULOS (mirando a la derecha)
def wheel(cv, x, y, r=3):
    cv.r(x - r, y - r + 1, 2 * r + 1, 2 * r - 1, INK); cv.r(x - r + 1, y - r, 2 * r - 1, 2 * r + 1, INK)
    cv.r(x - r + 2, y - r + 2, 2 * r - 3, 2 * r - 3, '#5d6270'); cv.p(x, y, '#c9c4cf')

def wheelbarrow(kind):
    cv = Cv(24, 14)
    col = {'rota': '#8a5c34', 'buena': '#4fbf9a', 'pro': '#ef8a3a'}[kind]
    hi = {'rota': '#b07a48', 'buena': '#7fe0c4', 'pro': '#f2c14e'}[kind]
    # charola
    cv.r(6, 2, 16, 1, INK); cv.r(7, 3, 14, 5, INK); cv.r(9, 8, 10, 1, INK)
    cv.r(8, 3, 12, 4, col); cv.r(9, 3, 10, 1, hi); cv.r(10, 7, 8, 1, col)
    if kind == 'rota':
        cv.p(12, 5, '#5a3c24'); cv.p(16, 4, '#5a3c24'); cv.p(19, 6, '#c0613f'); cv.p(9, 5, '#c0613f')
    # mangos
    cv.r(0, 4, 8, 1, INK); cv.r(0, 3, 3, 1, INK)
    cv.r(14, 9, 1, 3, INK); cv.r(9, 9, 1, 4, INK)
    wheel(cv, 18, 10, 3)
    if kind == 'rota':
        cv.p(20, 12, '#8a8494')
    return cv

def pickup():
    cv = Cv(44, 22)
    body, hi = '#f4ecd8', '#ffffff'
    cv.r(2, 8, 40, 9, INK); cv.r(3, 9, 38, 7, body)
    cv.r(26, 2, 14, 7, INK); cv.r(27, 3, 12, 6, body); cv.r(29, 4, 8, 4, '#a6dcf8'); cv.r(30, 4, 2, 2, '#ffffff')
    cv.r(3, 12, 38, 1, '#4a6fb5'); cv.r(40, 12, 3, 3, '#f2c14e'); cv.r(3, 9, 22, 1, hi)
    cv.r(2, 7, 23, 2, INK)
    wheel(cv, 10, 17, 4); wheel(cv, 33, 17, 4)
    return cv

def dump_truck():
    cv = Cv(60, 28)
    cv.r(2, 4, 38, 15, INK); cv.r(3, 5, 36, 13, '#f2c14e'); cv.r(3, 5, 36, 2, '#fff27a')
    for xx in range(8, 38, 8): cv.r(xx, 7, 1, 10, '#d9a030')
    cv.r(40, 6, 18, 14, INK); cv.r(41, 7, 16, 12, '#ef8a3a'); cv.r(44, 8, 10, 5, '#a6dcf8'); cv.r(45, 8, 3, 2, '#ffffff')
    cv.r(2, 18, 56, 3, INK); cv.r(56, 15, 3, 3, '#f2c14e')
    wheel(cv, 11, 22, 5); wheel(cv, 24, 22, 5); wheel(cv, 49, 22, 5)
    return cv

def big_truck():
    cv = Cv(78, 30)
    cv.r(2, 4, 54, 17, INK); cv.r(3, 5, 52, 15, '#d9d4c8'); cv.r(3, 5, 52, 2, '#ffffff')
    cv.r(6, 9, 46, 7, '#c0613f'); cv.text(8, 9, 'MAT', '#fff6d0', 8)
    cv.r(56, 6, 20, 16, INK); cv.r(57, 7, 18, 14, '#ef6f6c'); cv.r(61, 8, 11, 6, '#a6dcf8'); cv.r(62, 8, 3, 2, '#ffffff')
    cv.r(2, 20, 74, 3, INK); cv.r(74, 16, 3, 3, '#f2c14e')
    for x in (10, 22, 34, 64): wheel(cv, x, 24, 5)
    return cv

def bicycle():
    cv = Cv(22, 14)
    wheel(cv, 5, 9, 4); wheel(cv, 16, 9, 4)
    for (x, y) in [(5, 9), (7, 7), (9, 5), (11, 7), (13, 9), (15, 8), (10, 9), (8, 9)]:
        cv.p(x, y, '#ef6f6c')
    for i in range(6): cv.p(6 + i, 9 - i // 2, '#ef6f6c'); cv.p(11 + i // 2, 5 + i, '#ef6f6c')
    cv.r(8, 3, 4, 1, INK); cv.r(14, 3, 1, 3, INK); cv.r(13, 2, 3, 1, INK)
    return cv

def moto():
    cv = Cv(26, 16)
    wheel(cv, 5, 11, 4); wheel(cv, 20, 11, 4)
    cv.r(6, 6, 14, 5, INK); cv.r(7, 7, 12, 3, '#ef6f6c'); cv.r(8, 7, 5, 1, '#ffb0a8')
    cv.r(4, 5, 7, 2, INK); cv.r(18, 2, 2, 6, INK); cv.r(17, 1, 4, 1, INK); cv.r(21, 6, 2, 2, '#f2c14e')
    return cv

def vocho():
    cv = Cv(36, 20)
    cv.r(4, 6, 28, 9, INK); cv.r(9, 2, 18, 5, INK)
    cv.r(5, 7, 26, 7, '#4fa3a0'); cv.r(10, 3, 16, 4, '#4fa3a0')
    cv.r(12, 4, 5, 3, '#a6dcf8'); cv.r(19, 4, 5, 3, '#a6dcf8'); cv.r(12, 4, 2, 1, '#ffffff')
    cv.r(5, 8, 26, 1, '#7fe0c4'); cv.r(30, 9, 2, 2, '#f2c14e')
    wheel(cv, 10, 15, 4); wheel(cv, 26, 15, 4)
    return cv

def make_vehicles():
    wheelbarrow('rota').save('veh_wheelbarrow_0.png')
    wheelbarrow('buena').save('veh_wheelbarrow_1.png')
    wheelbarrow('pro').save('veh_wheelbarrow_2.png')
    pickup().save('veh_pickup.png')
    dump_truck().save('veh_truck.png')
    big_truck().save('veh_bigtruck.png')
    bicycle().save('tr_bike.png')
    moto().save('tr_moto.png')
    vocho().save('tr_vocho.png')

# ------------------------------------------------------------------ ICONOS 16x16
def icon(name, fn):
    cv = Cv(16, 16)
    fn(cv)
    cv.save(f'ic_{name}.png')

def ic_sack(color, band, letter=None):
    def f(cv):
        sack(cv, 2, 3, color, band, 12, 12)
        if letter: cv.text(5, 6, letter, INK, 8) if False else None
    return f

def make_icons():
    icon('arena', lambda cv: sand_pile(cv, 1, 14, 14, 9))
    icon('grava', lambda cv: gravel_pile(cv, 1, 14, 14, 9))
    icon('tepetate', lambda cv: sand_pile(cv, 1, 14, 14, 9, '#d8b07a', '#b58f62', '#ead2a4'))
    def piedra(cv):
        rock(cv, 1, 7, 8); rock(cv, 7, 5, 8, '#a9a4b0'); rock(cv, 5, 10, 5, '#c9c4cf')
    icon('piedra', piedra)
    def tezontle(cv):
        rock(cv, 1, 7, 8, '#a04a3a'); rock(cv, 7, 5, 8, '#c0613f'); rock(cv, 5, 10, 5, '#8a3a2a')
    icon('tezontle', tezontle)
    icon('cemento', ic_sack('#d9d4c8', '#4a6fb5'))
    icon('cal', ic_sack('#f4ecd8', '#4fbf9a'))
    icon('yeso', ic_sack('#ffffff', '#ef6f6c'))
    icon('tabique', lambda cv: bricks(cv, 1, 4, 2, 3, '#c0613f'))
    def block(cv):
        cv.box(1, 4, 14, 10, '#a9a4b0'); cv.box(3, 6, 4, 6, '#6b6578'); cv.box(9, 6, 4, 6, '#6b6578')
    icon('block', block)
    def varilla(cv):
        for i in range(4):
            for k in range(14): cv.p(1 + k, 12 - k // 2 + i * 1 - 3 + i, INK if k % 3 else '#8a8494')
        cv.r(5, 3, 2, 10, INK) if False else None
    def varilla2(cv):
        for i in range(4):
            y0 = 4 + i * 3
            cv.r(1, y0, 14, 2, INK); cv.r(2, y0, 12, 1, '#8a8494')
            for k in range(2, 14, 3): cv.p(k, y0, '#c9c4cf')
        cv.r(6, 2, 2, 14, '#c0613f')
    icon('varilla', varilla2)
    def alambre(cv):
        for r in (6, 4):
            for a in range(-r, r + 1):
                for b in range(-r, r + 1):
                    if r * r - 2 * r <= a * a + b * b <= r * r: cv.p(8 + a, 8 + b, '#8a8494' if r == 6 else '#c9c4cf')
        cv.p(8, 1, INK)
    icon('alambre', alambre)
    def clavos(cv):
        cv.box(2, 6, 12, 9, '#d8a870'); cv.r(3, 7, 10, 1, '#f5d58f'); cv.r(5, 10, 6, 2, '#c0613f')
        for x in (4, 7, 10): cv.r(x, 2, 2, 1, INK); cv.r(x, 3, 1, 4, '#8a8494')
    icon('clavos', clavos)
    def pintura(cv):
        cv.box(3, 4, 10, 11, '#ef6f6c'); cv.r(4, 7, 8, 4, '#f4ecd8'); cv.r(5, 8, 2, 2, '#4fa3a0'); cv.r(8, 8, 3, 2, '#f2c14e')
        cv.r(3, 2, 10, 2, INK); cv.r(5, 1, 6, 1, INK)
    icon('pintura', pintura)
    def tubo(cv):
        for i in range(2):
            y0 = 4 + i * 6
            cv.r(1, y0, 14, 4, INK); cv.r(2, y0 + 1, 12, 2, '#f4ecd8'); cv.r(2, y0 + 1, 12, 1, '#ffffff')
            cv.r(13, y0, 2, 4, '#c9c4cf')
    icon('tubo', tubo)
    def impermeabilizante(cv):
        cv.box(2, 3, 12, 12, '#ef8a3a'); cv.r(3, 7, 10, 4, '#f4ecd8'); cv.r(5, 8, 6, 2, '#ef6f6c'); cv.r(4, 1, 8, 2, INK)
    icon('impermeabilizante', impermeabilizante)
    def azulejo(cv):
        for i in range(2):
            for j in range(2):
                cv.box(1 + i * 7, 1 + j * 7, 7, 7, '#6a8fd8' if (i + j) % 2 else '#a6dcf8')
                cv.p(3 + i * 7, 3 + j * 7, '#ffffff')
    icon('azulejo', azulejo)
    def castillo(cv):
        cv.r(1, 4, 14, 1, INK); cv.r(1, 11, 14, 1, INK); cv.r(1, 7, 14, 2, '#8a8494')
        for x in range(2, 15, 3): cv.r(x, 4, 1, 8, '#c0613f')
    icon('castillo', castillo)
    def martillo(cv):
        for i in range(10): cv.p(3 + i, 13 - i, INK); cv.p(4 + i, 13 - i, C['wood'])
        cv.r(9, 1, 7, 4, INK); cv.r(10, 2, 5, 2, '#a9a4b0')
    icon('martillo', martillo)
    def pala(cv):
        for i in range(9): cv.p(2 + i, 2 + i, INK); cv.p(3 + i, 2 + i, C['wood'])
        cv.r(9, 9, 6, 6, INK); cv.r(10, 10, 4, 4, '#a9a4b0'); cv.r(1, 1, 3, 2, INK)
    icon('pala', pala)
    def cuchara(cv):
        cv.r(2, 9, 9, 5, INK); cv.r(3, 10, 7, 3, '#c9c4cf'); for_ = None
        cv.r(10, 6, 2, 4, INK); cv.r(11, 3, 4, 3, INK); cv.r(12, 4, 2, 1, C['wood'])
    icon('cuchara', cuchara)
    def cinta(cv):
        cv.box(2, 3, 11, 11, '#f2c14e'); cv.box(5, 6, 5, 5, '#3d3548'); cv.r(12, 11, 4, 2, INK); cv.r(12, 11, 3, 1, '#fff27a')
    icon('cinta', cinta)
    def taladro(cv):
        cv.box(2, 3, 11, 6, '#4fbf9a'); cv.box(5, 8, 5, 7, '#3d3548'); cv.r(13, 5, 3, 2, '#c9c4cf')
    icon('taladro', taladro)
    def carretilla_ic(cv):
        wb = wheelbarrow('buena').img.resize((16, 9), Image.NEAREST)
        cv.img.alpha_composite(wb, (0, 4))
    icon('carretilla', carretilla_ic)
    # iconos de UI
    def coin(cv):
        cv.r(4, 1, 8, 14, INK); cv.r(2, 3, 12, 10, INK); cv.r(3, 2, 10, 12, INK)
        cv.r(4, 2, 8, 12, '#f2c14e'); cv.r(3, 4, 10, 8, '#f2c14e'); cv.r(5, 3, 2, 3, '#fff27a')
        cv.r(7, 4, 2, 8, '#c08a20'); cv.r(6, 5, 4, 1, '#c08a20'); cv.r(6, 10, 4, 1, '#c08a20')
    icon('coin', coin)
    def bolt(cv):
        cv.r(3, 1, 10, 5, INK); cv.r(4, 2, 8, 3, '#f2c14e'); cv.r(5, 2, 2, 1, '#fff27a')
        cv.r(6, 6, 4, 9, INK); cv.r(7, 6, 2, 8, '#d9a030')
        for y in range(7, 14, 2): cv.p(7, y, '#fff27a')
    icon('bolt', bolt)
    def energy(cv):
        pts = ['......oooo......', '.....oyyyo......', '....oyyyo.......', '...oyyyo........', '..oyyyyyyyyo....', '..ooooyyyyo.....', '.....oyyyo......', '....oyyyo.......', '...oyyyo........', '..oyyo..........', '..oyo...........', '..oo............', '................', '................', '................', '................']
        sp = rows_sprite(pts, {'o': INK, 'y': '#fff27a'})
        cv.img.alpha_composite(sp.img, (2, 2))
    icon('energy', energy)
    def star(cv):
        pts = ['.......o........', '......oyo.......', '......oyo.......', '.ooooooyyooooo..', '..oyyyyyyyyyo...', '...oyyyyyyyo....', '....oyyyyyo.....', '....oyyoyyo.....', '...oyyo.oyyo....', '...ooo...ooo....']
        sp = rows_sprite(pts, {'o': INK, 'y': '#f2c14e'})
        cv.img.alpha_composite(sp.img, (0, 3))
    icon('star', star)
    def nav_local(cv):
        cv.box(1, 5, 14, 10, '#f0d9a8'); cv.r(0, 3, 16, 3, INK); cv.r(1, 4, 14, 1, '#ef6f6c')
        cv.box(5, 9, 6, 6, '#7a4a2a'); cv.r(2, 7, 12, 1, '#2b3f8f')
    icon('nav_local', nav_local)
    def nav_mine(cv):
        for i in range(10): cv.p(2 + i, 13 - i, INK); cv.p(3 + i, 13 - i, C['wood'])
        cv.r(6, 1, 9, 2, INK); cv.r(6, 2, 2, 3, INK); cv.r(13, 2, 2, 3, INK); cv.r(7, 1, 7, 1, '#a9a4b0')
    icon('nav_mine', nav_mine)
    def nav_house(cv):
        for i in range(8): cv.r(8 - i, 1 + i, 2 * i, 1, INK)
        cv.box(3, 8, 10, 7, '#f4ecd8'); cv.box(7, 10, 3, 5, '#7a4a2a'); cv.r(2, 6, 12, 2, '#ef6f6c')
    icon('nav_house', nav_house)
    def nav_up(cv):
        pts = ['.......oo.......', '......oyyo......', '.....oyyyyo.....', '....oyyyyyyo....', '...oyyyyyyyyo...', '..oooooyyooooo..', '......oyyo......', '......oyyo......', '......oyyo......', '......oyyo......', '......oyyo......', '......oooo......']
        sp = rows_sprite(pts, {'o': INK, 'y': '#7fe0c4'})
        cv.img.alpha_composite(sp.img, (0, 2))
    icon('nav_up', nav_up)
    def nav_shop(cv):
        cv.box(2, 5, 12, 10, '#ef6f6c'); cv.r(5, 2, 6, 1, INK); cv.r(4, 3, 1, 3, INK); cv.r(11, 3, 1, 3, INK)
        cv.r(6, 8, 4, 4, '#f2c14e')
    icon('nav_shop', nav_shop)
    def ad(cv):
        cv.box(1, 3, 14, 10, '#4fbf9a'); cv.r(6, 5, 1, 6, INK); cv.r(7, 6, 1, 4, INK); cv.r(8, 7, 1, 2, INK)
    icon('ad', ad)
    def clock(cv):
        cv.r(4, 1, 8, 14, INK); cv.r(1, 4, 14, 8, INK); cv.r(2, 2, 12, 12, INK)
        cv.r(3, 3, 10, 10, '#f4ecd8'); cv.r(4, 2, 8, 12, '#f4ecd8'); cv.r(2, 4, 12, 8, '#f4ecd8')
        cv.r(7, 4, 2, 5, INK); cv.r(8, 8, 3, 1, INK)
    icon('clock', clock)
    def box_ic(cv):
        cv.box(1, 4, 14, 11, '#d8a870'); cv.r(1, 4, 14, 3, INK); cv.r(2, 5, 12, 1, '#b58f62'); cv.r(6, 4, 4, 11, '#f5d58f'); cv.r(6, 4, 4, 1, INK)
    icon('box', box_ic)
    def menu_ic(cv):
        for y in (3, 7, 11): cv.r(2, y, 12, 3, INK); cv.r(3, y + 1, 10, 1, '#f4ecd8')
    icon('menu', menu_ic)
    def person(cv):
        cv.box(5, 1, 6, 6, '#f3c7a0'); cv.box(3, 7, 10, 8, '#4fa3a0')
    icon('person', person)
    def lock(cv):
        cv.r(4, 1, 8, 7, INK); cv.r(5, 2, 6, 6, '#00000000'.replace('#00000000', '#241f3d')); cv.r(6, 3, 4, 5, '#241f3d')
        cv.box(2, 7, 12, 8, '#f2c14e'); cv.r(7, 9, 2, 3, INK)
    icon('lock', lock)

# ------------------------------------------------------------------ icono de app y logo
def make_logo():
    cv = Cv(160, 48)
    t1, t2 = 'DE LA CARRETILLA', 'AL IMPERIO'
    for dx, dy in ((1, 1), (2, 2)):
        cv.text(80 - cv.text_w(t1) // 2 + dx, 6 + dy, t1, INK)
        cv.text(80 - cv.text_w(t2, 16) // 2 + dx, 22 + dy, t2, INK, 16)
    cv.text(80 - cv.text_w(t1) // 2, 6, t1, C['bone'])
    cv.text(80 - cv.text_w(t2, 16) // 2, 22, t2, C['sand'], 16)
    cv.save('logo.png')
    ic = Cv(48, 48, '#4a3427')
    ic.r(0, 34, 48, 14, C['dirtHi']); ic.r(0, 34, 48, 1, C['dirtDk'])
    sand_pile(ic, 6, 35, 18, 9)
    wb = wheelbarrow('buena').img
    ic.img.alpha_composite(wb, (20, 22))
    ic.r(0, 0, 48, 2, C['sand']); ic.r(0, 46, 48, 2, C['sand'])
    ic.text(6, 6, '$', C['sand'], 16)
    ic.save('icon.png', 4)  # 192x192

if __name__ == '__main__':
    make_shop(); make_house(); make_mine(); make_facades(); make_vehicles(); make_icons(); make_logo()
    print('ok', len(os.listdir(OUT)), 'archivos')

def make_bg():
    rnd = random.Random(11)
    cv = Cv(64, 64, '#c9a57a')
    for x in range(0, 64, 4):
        cv.r(x, 0, 1, 64, '#c39f72')
    for _ in range(90):
        cv.p(rnd.randrange(64), rnd.randrange(64), rnd.choice(['#bf9a6c', '#d2b088', '#c4a073', '#b8935f']))
    for _ in range(6):
        x = rnd.randrange(64); y = rnd.randrange(60)
        cv.r(x, y, 1, rnd.randrange(2, 5), '#b8935f')
    cv.save('bg_kraft.png')

make_bg()
