"""Genera el arte vectorial del juego (PNG a 3x) en assets/vec/.
Escenarios con perspectiva, luz calida y contornos de color. Requiere rsvg-convert.
Uso: python3 tools/gen_vector.py
"""
import os, subprocess, random, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "vec")
TMP = "/tmp/vecsvg"
os.makedirs(OUT, exist_ok=True); os.makedirs(TMP, exist_ok=True)
SCALE = 3
INK = "#3a2618"

def render(name, w, h, body, defs="", scale=SCALE):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*scale}" height="{h*scale}" viewBox="0 0 {w} {h}"><defs>{COMMON_DEFS}{defs}</defs>{body}</svg>'
    sp = os.path.join(TMP, name + ".svg")
    open(sp, "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(w * scale), "-h", str(h * scale), sp, "-o", os.path.join(OUT, name + ".png")], check=True)

COMMON_DEFS = '''
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9fd4f2"/><stop offset="1" stop-color="#e8f4f0"/></linearGradient>
<linearGradient id="ao" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a2010" stop-opacity="0.35"/><stop offset="1" stop-color="#3a2010" stop-opacity="0"/></linearGradient>
<linearGradient id="cone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff2c0" stop-opacity="0.40"/><stop offset="1" stop-color="#fff2c0" stop-opacity="0"/></linearGradient>
<radialGradient id="glow"><stop offset="0" stop-color="#fff6c8" stop-opacity="0.75"/><stop offset="1" stop-color="#fff6c8" stop-opacity="0"/></radialGradient>
<radialGradient id="vignette" cx="0.45" cy="0.42" r="0.78"><stop offset="0.55" stop-color="#3a1a08" stop-opacity="0"/><stop offset="1" stop-color="#3a1a08" stop-opacity="0.36"/></radialGradient>
<linearGradient id="woodv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6b4c38"/><stop offset="1" stop-color="#4a3427"/></linearGradient>
'''

W, H = 360, 272   # area del escenario en el juego
FL = 212          # union pared-piso

# ====================================================================== piezas comunes
def sack(x, y, label, c, band, line):
    return f'''<g><ellipse cx="{x+21}" cy="{y+21}" rx="22" ry="3.5" fill="#5a2e1a" opacity="0.25"/>
      <path d="M{x},{y+19} q-2,-17 5,-19 l32,0 q7,2 5,19 q-21,4 -42,0z" fill="{c}" stroke="{line}" stroke-width="1.3"/>
      <path d="M{x+4},{y+2} q17,-3 34,0" stroke="#ffffff" stroke-width="1.6" opacity="0.5" fill="none"/>
      <rect x="{x+3}" y="{y+6}" width="36" height="7" fill="{band}" opacity="0.92"/>
      <text x="{x+21}" y="{y+11.8}" font-family="Oswald" font-weight="600" font-size="5.2" fill="#fff" text-anchor="middle">{label}</text></g>'''

def pile(cx, base, w, h, c1, c2, hi):
    return f'''<g><ellipse cx="{cx}" cy="{base+1}" rx="{w/2+4}" ry="4" fill="#5a2e1a" opacity="0.22"/>
      <path d="M{cx-w/2},{base} q{w*0.18},{-h*0.9} {w/2},{-h} q{w*0.32},{h*0.1} {w/2},{h}z" fill="{c1}" stroke="{c2}" stroke-width="1.3"/>
      <path d="M{cx-w*0.18},{base-h*0.62} q{w*0.12},{-h*0.3} {w*0.24},{-h*0.32}" stroke="{hi}" stroke-width="2.2" fill="none" stroke-linecap="round" opacity="0.9"/></g>'''

def rock(x, y, s, c, line):
    return f'<path d="M{x},{y} q{s*0.1},{-s*0.8} {s*0.5},{-s*0.85} q{s*0.45},{-s*0.05} {s*0.5},{s*0.85}z" fill="{c}" stroke="{line}" stroke-width="1.2"/><path d="M{x+s*0.25},{y-s*0.5} q{s*0.15},{-s*0.2} {s*0.3},{-s*0.2}" stroke="#ffffff" stroke-width="1.2" opacity="0.4" fill="none"/>'

def shelf_frame(x, y, w, h, levels, wood="#a87a4e", wood_dk="#7a5232", wood_lt="#c99a68"):
    S = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#6e4a30"/>',
         f'<rect x="{x}" y="{y}" width="{w}" height="{h*0.6}" fill="#5a3a22" opacity="0.4"/>',
         f'<rect x="{x-4}" y="{y-4}" width="6" height="{h+8}" fill="{wood}" stroke="{wood_dk}" stroke-width="1.2"/>',
         f'<rect x="{x+w-2}" y="{y-4}" width="6" height="{h+8}" fill="{wood_dk}" stroke="#5a3a22" stroke-width="1.2"/>']
    boards = []
    for lv in levels:
        boards.append(f'<path d="M{x-2},{lv} l{w+4},0 l-4,4 l{-w+4},0z" fill="{wood_lt}" stroke="{wood_dk}" stroke-width="1.1"/>')
        boards.append(f'<rect x="{x-2}" y="{lv+4}" width="{w}" height="4" fill="{wood}" stroke="{wood_dk}" stroke-width="1.1"/>')
        boards.append(f'<rect x="{x}" y="{lv+8}" width="{w}" height="6" fill="#3a2010" opacity="0.18"/>')
    return "\n".join(S), "\n".join(boards)

def rusty_items(x, levels, cobweb=True, w=124, y0=0):
    rust, rust_dk = "#a8582e", "#7a3a1e"
    it = []
    l = levels[0]
    it.append(f'<rect x="{x+10}" y="{l-18}" width="16" height="18" rx="2" fill="#8c8a7a" stroke="#5a584c" stroke-width="1.2"/><path d="M{x+10},{l-14} l16,0" stroke="#b5463a" stroke-width="3"/><path d="M{x+14},{l-14} l0,6 q1,3 2,0 l0,-3" fill="#b5463a"/>')
    it.append(f'<rect x="{x+32}" y="{l-15}" width="12" height="15" rx="3" fill="#cfe6e0" fill-opacity="0.55" stroke="#7a8f8a" stroke-width="1.1"/><path d="M{x+34},{l-6} l8,0 M{x+34},{l-4} l8,0 M{x+34},{l-2} l8,0" stroke="{rust}" stroke-width="1.2"/><rect x="{x+31}" y="{l-17}" width="14" height="3" fill="{rust}"/>')
    it.append(f'<path d="M{x+52},{l-14} l26,0 l0,14 l-26,0z" fill="#c49a62" stroke="#8a6a3e" stroke-width="1.2"/><path d="M{x+52},{l-14} l-4,-5 l12,0 l4,5 M{x+78},{l-14} l4,-6 l-10,0 l-4,6" fill="#d8b07a" stroke="#8a6a3e" stroke-width="1"/><text x="{x+65}" y="{l-4}" font-family="Oswald" font-size="5.5" fill="#6a4a2a" text-anchor="middle">CLAVOS</text>')
    if cobweb:
        it.append(f'<g opacity="0.75" stroke="#f4ecdf" stroke-width="0.6" fill="none"><path d="M{x+w-2},{y0} l-18,18 M{x+w-2},{y0} l-26,6 M{x+w-2},{y0} l-8,24"/><path d="M{x+w-10},{y0+3} q-4,5 -1,9 M{x+w-16},{y0+4} q-6,8 -3,14 M{x+w-22},{y0+5} q-8,10 -4,18"/></g>')
    l = levels[1]
    it.append(f'<path d="M{x+8},{l-4} l30,-6" stroke="#8a5c34" stroke-width="3.4" stroke-linecap="round"/><path d="M{x+34},{l-16} l7,-1 l2,12 l-7,1z" fill="{rust}" stroke="{rust_dk}" stroke-width="1"/>')
    it.append(f'<path d="M{x+48},{l-2} l36,-12 l3,6 l-36,8z" fill="#b8b0a4" stroke="#7a746a" stroke-width="1"/><circle cx="{x+70}" cy="{l-7}" r="1.4" fill="{rust}"/><circle cx="{x+60}" cy="{l-4}" r="1.6" fill="{rust}"/><rect x="{x+82}" y="{l-17}" width="10" height="9" rx="2" fill="#6e4126" stroke="#4a2c18" stroke-width="1"/>')
    it.append(f'<circle cx="{x+105}" cy="{l-10}" r="9" fill="#c9a86a" stroke="#8a6a3e" stroke-width="1.1"/><circle cx="{x+105}" cy="{l-10}" r="5" fill="none" stroke="#8a6a3e" stroke-width="1"/><circle cx="{x+105}" cy="{l-10}" r="2" fill="#6e4a30"/>')
    l = levels[2]
    it.append(f'<path d="M{x+10},{l-34} l4,30" stroke="#8a5c34" stroke-width="3" stroke-linecap="round"/><path d="M{x+6},{l-10} q8,-4 16,0 l-2,10 q-6,3 -12,0z" fill="#9a8a7a" stroke="#6a5a4a" stroke-width="1.1"/><path d="M{x+9},{l-6} q3,2 6,0" stroke="{rust}" stroke-width="2.2" fill="none"/>')
    it.append(f'<path d="M{x+32},{l-18} l22,0 l-3,18 l-16,0z" fill="#9aa4a8" stroke="#66707a" stroke-width="1.1"/><path d="M{x+33},{l-18} q10,-9 20,0" stroke="#66707a" stroke-width="1.1" fill="none"/>')
    it.append(f'<path d="M{x+64},{l-3} l14,-8 l6,4 l-14,6z" fill="#a9a4b0" stroke="#6a6670" stroke-width="1"/><path d="M{x+82},{l-5} l10,-6" stroke="#8a5c34" stroke-width="2.6" stroke-linecap="round"/>')
    it.append(f'<path d="M{x+98},{l-14} l18,0 l0,14 l-18,0z" fill="#d8c8a8" stroke="#a89878" stroke-width="1"/><text x="{x+107}" y="{l-5}" font-family="Patrick Hand" font-size="6" fill="#7a6a4a" text-anchor="middle">1987</text>')
    return "\n".join(it)

def stocked_items(x, levels, w=124, seed=1):
    rnd = random.Random(seed)
    cols = ["#d0533f", "#3f8f8a", "#e8b23a", "#2f4f8f", "#6fc2a8", "#e07a2e", "#a8475a", "#5aa847"]
    out = []
    for lv in levels:
        xx = x + 6
        while xx < x + w - 14:
            kind = rnd.randrange(5); c = rnd.choice(cols)
            if kind == 0:  # bote de pintura
                out.append(f'<rect x="{xx}" y="{lv-17}" width="13" height="17" rx="2" fill="{c}" stroke="{darker(c)}" stroke-width="1.2"/><rect x="{xx+2}" y="{lv-12}" width="9" height="6" fill="#f7eedb"/><path d="M{xx+1},{lv-17} q5.5,-5 11,0" stroke="{darker(c)}" stroke-width="1.1" fill="none"/>')
                xx += 15
            elif kind == 1:  # caja
                out.append(f'<rect x="{xx}" y="{lv-14}" width="17" height="14" rx="1.5" fill="#d8a870" stroke="#9a7040" stroke-width="1.2"/><path d="M{xx+8.5},{lv-14} l0,14" stroke="#b5874f" stroke-width="2"/><rect x="{xx+3}" y="{lv-9}" width="4" height="3" fill="{c}"/>')
                xx += 19
            elif kind == 2:  # rollo de alambre
                out.append(f'<circle cx="{xx+8}" cy="{lv-8}" r="7.5" fill="#a9a4b0" stroke="#6a6670" stroke-width="1.2"/><circle cx="{xx+8}" cy="{lv-8}" r="3" fill="#6e4a30" stroke="#6a6670" stroke-width="1"/>')
                xx += 17
            elif kind == 3:  # sellador
                out.append(f'<rect x="{xx}" y="{lv-20}" width="8" height="20" rx="3" fill="{c}" stroke="{darker(c)}" stroke-width="1.2"/><rect x="{xx+2.5}" y="{lv-24}" width="3" height="5" fill="#f7eedb"/>')
                xx += 10
            else:  # herramienta colgada
                out.append(f'<path d="M{xx+2},{lv-22} l0,20" stroke="#8a5c34" stroke-width="2.6" stroke-linecap="round"/><rect x="{xx-2}" y="{lv-24}" width="9" height="5" rx="1" fill="#a9a4b0" stroke="#6a6670" stroke-width="1"/>')
                xx += 11
    return "\n".join(out)

def darker(hexc, f=0.4):
    hexc = hexc.lstrip('#')
    r, g, b = (int(hexc[i:i+2], 16) for i in (0, 2, 4))
    return '#%02x%02x%02x' % (int(r * (1 - f) + 58 * f), int(g * (1 - f) + 30 * f), int(b * (1 - f) + 24 * f))

def window(x, y, w, h, dirty=False):
    s = f'''<g>
      <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="url(#sky)"/>
      <path d="M{x},{y+h*0.7} q{w*0.16},{-h*0.16} {w*0.34},{-h*0.1} q{w*0.12},{-h*0.18} {w*0.3},{-h*0.08} q{w*0.18},{-h*0.1} {w*0.36},{h*0.06} l0,{h*0.4} l{-w},0z" fill="#8fbf6a"/>
      <rect x="{x+w*0.56}" y="{y+h*0.42}" width="{w*0.18}" height="{h*0.3}" fill="#e9d2b8" stroke="#b89a7a" stroke-width="0.8"/><path d="M{x+w*0.54},{y+h*0.42} l{w*0.11},{-h*0.1} l{w*0.11},{h*0.1}z" fill="#c0614a"/>
      <circle cx="{x+w*0.82}" cy="{y+h*0.2}" r="{h*0.1}" fill="#fff8d6" opacity="0.9"/>'''
    if dirty:
        s += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#8a7a62" opacity="0.45"/><path d="M{x+6},{y+8} l{w*0.3},{h*0.4}" stroke="#ffffff" stroke-width="1" opacity="0.3"/>'
    s += f'''<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="none" stroke="#7a5232" stroke-width="4"/>
      <path d="M{x+w/2},{y} l0,{h} M{x},{y+h/2} l{w},0" stroke="#7a5232" stroke-width="3"/>
      <path d="M{x+4},{y+4} l14,0 l-10,14z" fill="#ffffff" opacity="0.35"/>
      <path d="M{x-6},{y+h+2} l{w+12},0 l4,6 l{-w-20},0z" fill="#c99a68" stroke="#7a5232" stroke-width="1.2"/></g>'''
    return s

def lamp_light(cx, top=0, bottom=H):
    dust = "".join(f'<circle cx="{random.Random(i+cx).uniform(cx-50, cx+70):.1f}" cy="{random.Random(i*7+cx).uniform(top+40, bottom-20):.1f}" r="{random.Random(i*3).uniform(0.5,1.2):.1f}" fill="#fff6d0" opacity="0.7"/>' for i in range(22))
    return f'''<path d="M{cx},{top} l0,22" stroke="{INK}" stroke-width="1.4"/>
      <path d="M{cx-14},{top+30} q14,-14 28,0z" fill="#3a5a52" stroke="#24382f" stroke-width="1.2"/>
      <ellipse cx="{cx}" cy="{top+30}" rx="5" ry="2.5" fill="#fff6c8"/>
      <path d="M{cx-14},{top+30} l-60,{bottom-top-30} l148,0 l-60,{-(bottom-top-30)}z" fill="url(#cone)"/>
      <ellipse cx="{cx}" cy="{top+40}" rx="40" ry="26" fill="url(#glow)"/>{dust}'''

# ====================================================================== LOCAL
def shop_bg(stage):
    S = []
    grime = stage == 0
    wall_top = "#e9cf9c" if stage < 3 else "#f4dfb6"
    wall_bot = "#cfa872" if stage < 3 else "#e6c690"
    if stage >= 8: wall_top, wall_bot = "#f6ead2", "#e8d6b4"
    defs = f'''<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{wall_top}"/><stop offset="1" stop-color="{wall_bot}"/></linearGradient>
      <linearGradient id="lwall" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{darker(wall_bot,0.25)}"/><stop offset="1" stop-color="{wall_top}"/></linearGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{'#b8673f' if stage < 8 else '#cfc8bc'}"/><stop offset="1" stop-color="{'#d27e52' if stage < 8 else '#e8e2d8'}"/></linearGradient>'''
    S.append(f'<rect x="0" y="0" width="{W}" height="{FL}" fill="url(#wall)"/>')
    S.append(f'<path d="M0,0 l46,26 l0,186 l-46,26z" fill="url(#lwall)"/><path d="M46,26 l0,186" stroke="{darker(wall_bot,0.2)}" stroke-width="1.2"/>')
    # techo
    S.append(f'<path d="M0,0 l{W},0 l0,26 l{-W+46},0z" fill="#8a6244"/><path d="M46,26 l{W-46},0" stroke="#6e4a30" stroke-width="2"/>')
    for i in range(3):
        S.append(f'<path d="M{70+i*110},0 l-8,26 l20,0 l4,-26z" fill="#a87a54" stroke="#7a5232" stroke-width="1"/>')
    # zoclo
    zc = "#4f8f86" if stage < 3 else ("#3f8f8a" if stage < 8 else "#2f4f8f")
    S.append(f'<path d="M46,182 l{W-46},0 l0,30 l{-W+46},0z" fill="{zc}"/><path d="M0,198 l46,-16 l0,30 l-46,16z" fill="{darker(zc,0.2)}"/><path d="M46,182 l{W-46},0" stroke="{darker(zc,0.3)}" stroke-width="2"/>')
    if stage < 3:
        for (x, w) in [(150, 18), (230, 10), (300, 24)]:
            S.append(f'<path d="M{x},190 q{w/2},-5 {w},0 q-{w/2},8 -{w},2z" fill="#e9d2a4" opacity="0.8"/>')
    if grime:
        S.append('<path d="M268,62 l6,10 l-3,8 l7,12" stroke="#b8935f" stroke-width="1" fill="none"/><ellipse cx="300" cy="157" rx="26" ry="14" fill="#b8935f" opacity="0.35"/><ellipse cx="90" cy="30" rx="30" ry="8" fill="#8a6a4a" opacity="0.2"/>')
    # ventana (o portón al patio de carga)
    if stage >= 7:
        S.append('''<g><rect x="232" y="44" width="96" height="132" fill="url(#sky)"/>
          <rect x="232" y="140" width="96" height="36" fill="#c9a06a"/>
          <path d="M240,170 q10,-16 22,0z" fill="#e9c27a" stroke="#c99a52" stroke-width="1"/><path d="M262,170 q10,-14 20,0z" fill="#a9a4b0" stroke="#7a7682" stroke-width="1"/>
          <rect x="286" y="132" width="34" height="22" rx="2" fill="#e8b23a" stroke="#9a7020" stroke-width="1.2"/><rect x="306" y="124" width="16" height="16" fill="#e07a2e" stroke="#9a4a1a" stroke-width="1.2"/><circle cx="294" cy="156" r="5" fill="#3a3540"/><circle cx="314" cy="156" r="5" fill="#3a3540"/>
          <rect x="232" y="44" width="96" height="10" fill="#8a8494"/><path d="M232,48 l96,0 M232,52 l96,0" stroke="#6b6578" stroke-width="1"/>
          <rect x="232" y="44" width="96" height="132" fill="none" stroke="#5a3a22" stroke-width="4"/>
          <rect x="250" y="30" width="60" height="12" rx="2" fill="#2f4f8f" stroke="#1f3060" stroke-width="1.2"/><text x="280" y="39.5" font-family="Oswald" font-weight="700" font-size="8" fill="#f2b533" text-anchor="middle">PATIO DE CARGA</text></g>''')
    else:
        S.append(window(238, 40, 64, 52, dirty=grime))
        S.append('<g transform="translate(96,-62)"><path d="M216,174 l14,0 l-2,-10 l-10,0z" fill="#b5563a" stroke="#7a3a22" stroke-width="1"/><path d="M223,164 q-4,-10 -8,-12 M223,164 q3,-9 8,-10" stroke="' + ("#8a7a4a" if stage < 2 else "#5aa847") + '" stroke-width="1.6" fill="none"/></g>')
    # bodega (abertura en la pared izquierda)
    if stage >= 6:
        S.append('''<g><path d="M6,68 l34,10 l0,120 l-34,10z" fill="#5a3a22"/>
          <path d="M8,150 l30,4 l0,40 l-30,6z" fill="#6e4a30"/>
          <rect x="10" y="132" width="24" height="10" rx="2" fill="#ddd6c6" stroke="#9a9282" stroke-width="0.8"/><rect x="12" y="122" width="22" height="10" rx="2" fill="#ddd6c6" stroke="#9a9282" stroke-width="0.8"/><rect x="10" y="142" width="26" height="10" rx="2" fill="#f1ead8" stroke="#a8a08a" stroke-width="0.8"/>
          <path d="M6,68 l34,10 l0,120 l-34,10z" fill="none" stroke="#3a2618" stroke-width="2.4"/>
          <path d="M2,58 l42,12 l0,10 l-42,-12z" fill="#e8b23a" stroke="#9a7020" stroke-width="1.2"/><text x="23" y="72" font-family="Oswald" font-weight="700" font-size="7" fill="#3a2618" text-anchor="middle" transform="rotate(16 23 70)">BODEGA</text></g>''')
    # anaquel principal
    sx, sy, sw, sh = 60, 46, 124, 136
    levels = [sy + 36, sy + 76, sy + 116]
    frame, boards = shelf_frame(sx, sy, sw, sh, levels)
    S.append(frame)
    S.append(rusty_items(sx, levels, cobweb=grime, y0=sy) if stage < 2 else stocked_items(sx, levels, seed=stage))
    S.append(boards)
    if stage >= 4:  # exhibidor junto a la ventana
        f2, b2 = shelf_frame(196, 112, 30, 70, [140, 176])
        S.append(f2 + stocked_items(196, [140, 176], w=30, seed=9) + b2)
    if stage >= 5:  # tapanco con cajas
        S.append('<path d="M46,26 l314,0 l0,8 l-314,0z" fill="#8a5c34" stroke="#5a3a22" stroke-width="1.4"/>')
        for i in range(9):
            x = 58 + i * 32
            if 226 < x < 330 and stage >= 7: continue
            S.append(f'<rect x="{x}" y="14" width="24" height="12" rx="1" fill="#d8a870" stroke="#9a7040" stroke-width="1"/><path d="M{x+12},14 l0,12" stroke="#b5874f" stroke-width="2"/>')
    # letrero
    if stage < 3:
        S.append('''<g transform="rotate(-3 110 30) translate(-178,-70)">
          <path d="M270,86 l-4,14 M312,86 l4,14" stroke="#5a3a22" stroke-width="1.2"/>
          <rect x="252" y="100" width="78" height="22" rx="3" fill="#6a7a96" stroke="#4a566e" stroke-width="1.6"/>
          <text x="291" y="116" font-family="Oswald" font-weight="700" font-size="12" fill="#e8d8a8" text-anchor="middle" letter-spacing="1" opacity="0.8">MATERIA ES</text></g>''')
    else:
        txt = "MATERIALES"
        S.append(f'''<g transform="rotate(-1.5 122 34)">
          <path d="M96,26 l-4,4 M150,26 l4,4" stroke="#3a2618" stroke-width="1.4"/>
          <rect x="74" y="28" width="96" height="24" rx="4" fill="{'#2f4f8f' if stage < 8 else '#c0432e'}" stroke="#1f3060" stroke-width="1.8"/>
          <text x="122" y="45" font-family="Oswald" font-weight="700" font-size="14" fill="#f2b533" text-anchor="middle" letter-spacing="1">{txt}</text></g>''')
    # cuadro del abuelo (desde etapa 1, se cuelga al limpiar)
    if stage >= 1:
        S.append('<g transform="rotate(3 214 66)"><rect x="200" y="50" width="26" height="32" rx="1.5" fill="#b5874f" stroke="#5a3a22" stroke-width="1.6"/><rect x="204" y="54" width="18" height="24" fill="#f3e6c8"/>'
                 '<ellipse cx="213" cy="68" rx="5" ry="6" fill="#c98f62" stroke="#3a2618" stroke-width="0.8"/><path d="M204,63 q9,-4 18,0 l-2,2 q-7,-2 -14,0z" fill="#e3c47e" stroke="#3a2618" stroke-width="0.6"/><path d="M209,71 q4,-2 8,0" stroke="#f2ede2" stroke-width="1.6"/></g>')
    # piso
    S.append(f'<path d="M0,224 l46,-12 l{W-46},0 l0,{H-FL} l-{W},0z" fill="url(#floor)"/>')
    tile = "#a65a3a" if stage < 8 else "#b8b0a4"
    for i in range(-6, 14):
        x0 = 46 + i * 30
        S.append(f'<path d="M{x0},{FL} l{(x0-200)*0.55:.1f},{H-FL}" stroke="{tile}" stroke-width="1" opacity="0.7"/>')
    for y in (222, 236, 254):
        S.append(f'<path d="M0,{y} l{W},0" stroke="{tile}" stroke-width="1" opacity="0.7"/>')
    if stage >= 8:
        S.append('<path d="M120,230 l60,0 l-10,30 l-70,0z" fill="#ffffff" opacity="0.18"/>')
    S.append(f'<rect x="0" y="{FL-2}" width="{W}" height="8" fill="url(#ao)"/>')
    if stage < 7:
        S.append('<path d="M240,214 l70,0 l20,40 l-90,0z" fill="#fff4c8" opacity="0.16"/>')
    # puerta (entrada)
    S.append('<path d="M330,92 l30,-6 l0,140 l-30,-4z" fill="#ffe2a0" stroke="#7a5232" stroke-width="2"/><path d="M330,92 l8,4 l0,124 l-8,2z" fill="#8a5c34"/>')
    S.append('<path d="M330,222 l30,4 l-50,30 l-40,0z" fill="#fff0c0" opacity="0.2"/>')
    if stage >= 8:
        for (x, y) in [(56, 196), (316, 196)]:
            S.append(f'<path d="M{x},{y+16} l12,0 l-2,-12 l-8,0z" fill="#c0614a" stroke="#7a3a22" stroke-width="1"/><path d="M{x+6},{y+4} q-8,-14 -10,-18 M{x+6},{y+4} q2,-16 0,-22 M{x+6},{y+4} q8,-12 12,-16" stroke="#4d9a38" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    render(f"shop_{stage}", W, H, "\n".join(S), defs)

def counter(variant):
    """Mostrador como capa al frente del personaje. Coordenadas del escenario."""
    body, top, lip, plank = [("#8a5c34", "#c99a68", "#e6c08c", "#6e4126"), ("#9a6a40", "#d8a870", "#ecc896", "#7a5232"),
                              ("#3f8f8a", "#d8a870", "#ecc896", "#2f6f6b"), ("#2f4f8f", "#e8e2d8", "#ffffff", "#1f3a70")][variant]
    x0, x1 = (134, 280) if variant < 2 else (126, 296)
    reg = ""
    if variant == 0:
        reg = f'<path d="M150,166 l2,-14 l22,0 l2,14z" fill="#8a8494" stroke="#5a5468" stroke-width="1.2"/><rect x="155" y="154" width="16" height="5" fill="#4a4458"/>'
    else:
        reg = '''<path d="M146,166 l4,-22 l30,0 l4,22z" fill="#4a6fb5" stroke="#2f4a80" stroke-width="1.4" stroke-linejoin="round"/>
          <rect x="153" y="147" width="24" height="8" rx="1.5" fill="#1f3a2e"/>
          <circle cx="154" cy="160" r="1.4" fill="#f2ede2"/><circle cx="160" cy="160" r="1.4" fill="#f2ede2"/><circle cx="166" cy="160" r="1.4" fill="#f2ede2"/><circle cx="172" cy="160" r="1.4" fill="#f2ede2"/>'''
    planks = "".join(f'<path d="M{x},182 l0,44" stroke="{plank}" stroke-width="1.4"/>' for x in range(x0 + 18, x1 - 4, 28))
    deco = ""
    if variant == 0:
        deco = f'<path d="M{x0+20},196 l18,4 M{x0+80},204 l10,-3" stroke="#5a3a22" stroke-width="1.2"/>'
    if variant >= 2:
        deco = f'<rect x="{(x0+x1)/2-30}" y="190" width="60" height="16" rx="3" fill="#f2b533" stroke="#9a7020" stroke-width="1.2"/><text x="{(x0+x1)/2}" y="201.5" font-family="Oswald" font-weight="700" font-size="8" fill="#3a2618" text-anchor="middle">CAJA</text>'
    body_svg = f'''<ellipse cx="{(x0+x1)/2}" cy="230" rx="{(x1-x0)/2+6}" ry="5" fill="#3a1a08" opacity="0.25"/>
      <path d="M{x0},174 l{x1-x0},0 l0,54 l{x0-x1},0z" fill="{body}" stroke="{darker(body,0.4)}" stroke-width="1.6"/>
      {planks}{deco}
      <path d="M{x0-6},166 l{x1-x0+12},0 l-4,10 l{-(x1-x0)-4},0z" fill="{top}" stroke="{darker(body,0.4)}" stroke-width="1.6"/>
      <path d="M{x0-3},167 l{x1-x0+6},0" stroke="{lip}" stroke-width="2"/>{reg}'''
    render(f"counter_{variant}", W, H, body_svg)

def shop_light(two=False):
    random.seed(4)
    body = lamp_light(150) + (lamp_light(276) if two else "") + f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#vignette)"/><rect x="0" y="0" width="{W}" height="{H}" fill="#ff9a40" opacity="0.05"/>'
    render("shop_light_2" if two else "shop_light", W, H, body)

def stock_sprites():
    render("stock_cemento", 46, 26, sack(2, 4, "CEMENTO", "#ddd6c6", "#4a6fb5", "#9a9282"))
    render("stock_cal", 46, 26, sack(2, 4, "CAL", "#f1ead8", "#4fa37a", "#a8a08a"))
    render("stock_yeso", 46, 26, sack(2, 4, "YESO", "#ffffff", "#c0432e", "#a8a08a"))
    render("stock_arena", 80, 34, pile(40, 30, 72, 26, "#e9c27a", "#c99a52", "#fbe6b0"))
    render("stock_grava", 80, 34, pile(40, 30, 72, 26, "#a9a4b0", "#7a7682", "#d8d4dc"))
    render("stock_tepetate", 80, 34, pile(40, 30, 72, 26, "#d8b07a", "#b58f62", "#ecd4a8"))
    b = "".join(f'<rect x="{2+i*14+(j%2)*7}" y="{22-j*7}" width="13" height="7" rx="1" fill="#c0613f" stroke="#8a3a22" stroke-width="1"/>' for j in range(3) for i in range(3))
    render("stock_tabique", 50, 32, b)
    render("stock_piedra", 50, 32, rock(4, 30, 22, "#8a8494", "#5a5468") + rock(20, 30, 26, "#a9a4b0", "#6a6670") + rock(14, 30, 14, "#c9c4cf", "#7a7682"))
    render("stock_varilla", 60, 20, "".join(f'<path d="M2,{6+i*3} l56,0" stroke="#7a7682" stroke-width="2.2" stroke-linecap="round"/>' for i in range(4)) + '<path d="M18,4 l0,14 M42,4 l0,14" stroke="#c0432e" stroke-width="2"/>')

def dirt_sprites():
    render("dirt_web", 40, 40, '<g stroke="#f4ecdf" stroke-width="1" fill="none" opacity="0.9"><path d="M38,2 L2,38 M38,2 L4,14 M38,2 L26,38 M38,2 L14,30"/><path d="M28,5 q-4,6 1,10 M20,8 q-6,8 1,14 M12,11 q-8,10 2,18"/></g>')
    render("dirt_bag", 40, 40, '<ellipse cx="20" cy="37" rx="16" ry="3" fill="#3a1a08" opacity="0.25"/><path d="M8,36 q-4,-20 8,-24 l8,0 q12,4 8,24z" fill="#3d3548" stroke="#24202c" stroke-width="1.6"/><path d="M15,12 l2,-6 l3,4 l3,-4 l2,6z" fill="#3d3548" stroke="#24202c" stroke-width="1.4"/><path d="M12,20 q4,-3 8,0" stroke="#6a6278" stroke-width="2" fill="none"/>')
    render("dirt_box", 40, 40, '<ellipse cx="20" cy="37" rx="17" ry="3" fill="#3a1a08" opacity="0.25"/><path d="M5,36 l2,-20 l26,0 l2,20z" fill="#b58f62" stroke="#7a5a3a" stroke-width="1.6"/><path d="M7,16 l-4,-7 l12,2 M33,16 l4,-6 l-12,1" fill="#d8b07a" stroke="#7a5a3a" stroke-width="1.4"/><path d="M12,26 l14,4" stroke="#7a5a3a" stroke-width="1"/>')
    render("dirt_rubble", 40, 40, rock(3, 36, 14, "#a9a4b0", "#6a6670") + rock(13, 36, 18, "#8a8494", "#5a5468") + rock(26, 36, 11, "#c9c4cf", "#7a7682"))
    render("dirt_stain", 44, 20, '<path d="M4,12 q6,-8 16,-6 q12,-4 18,4 q4,6 -6,8 q-10,4 -20,0 q-10,0 -8,-6z" fill="#5a4a3a" opacity="0.55"/><circle cx="38" cy="16" r="2" fill="#5a4a3a" opacity="0.5"/>')

# ====================================================================== CASA
def house_bg(stage):
    S = []
    wall = ["#cbb48e", "#dcc49a", "#efd3a6", "#f2d9c0", "#e2ead4", "#e8e0f2"][stage]
    defs = f'''<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{wall}"/><stop offset="1" stop-color="{darker(wall,0.12)}"/></linearGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{['#7a6a58','#9c6b3e','#b88450','#b88450','#c9a26e','#d8b07a'][stage]}"/><stop offset="1" stop-color="{['#8a7a66','#b07a48','#c99a68','#c99a68','#d8b884','#e6c490'][stage]}"/></linearGradient>'''
    S.append(f'<rect x="0" y="0" width="{W}" height="{FL}" fill="url(#wall)"/>')
    S.append(f'<path d="M0,0 l46,26 l0,186 l-46,26z" fill="{darker(wall,0.18)}"/>')
    S.append(f'<path d="M0,0 l{W},0 l0,22 l{-W+46},4z" fill="#8a6244"/>')
    if stage == 0:
        S.append('<path d="M120,60 l8,14 l-4,10 l9,16" stroke="#9a8a6a" stroke-width="1.2" fill="none"/><ellipse cx="300" cy="150" rx="30" ry="16" fill="#9a8a6a" opacity="0.3"/>')
    if stage >= 3:
        for x in range(60, W, 22): S.append(f'<path d="M{x},26 l0,{FL-26}" stroke="{darker(wall,0.08)}" stroke-width="5" opacity="0.5"/>')
    # ventana
    if stage == 0:
        S.append('<rect x="150" y="50" width="70" height="56" fill="#2a1c14" stroke="#5a3a22" stroke-width="3"/><path d="M144,62 l82,0 M144,92 l82,0" stroke="#c9a26e" stroke-width="7"/>')
    else:
        S.append(window(150, 44, 74 if stage < 5 else 100, 60))
        if stage >= 2:
            S.append(f'<path d="M144,40 l{(86 if stage < 5 else 112)},0" stroke="#9a6a44" stroke-width="3"/><path d="M146,40 q-4,40 2,74 l10,0 q-4,-40 -2,-74z M{228 if stage < 5 else 254},40 q4,40 -2,74 l-10,0 q4,-40 2,-74z" fill="#e8a0b0" stroke="#b5707e" stroke-width="1.2"/>')
    # piso
    S.append(f'<path d="M0,224 l46,-12 l{W-46},0 l0,{H-FL} l-{W},0z" fill="url(#floor)"/>')
    for i in range(-6, 14):
        x0 = 46 + i * 34
        S.append(f'<path d="M{x0},{FL} l{(x0-200)*0.5:.1f},{H-FL}" stroke="#6e4a30" stroke-width="1" opacity="0.4"/>')
    S.append(f'<rect x="0" y="{FL-2}" width="{W}" height="8" fill="url(#ao)"/>')
    # puerta
    S.append('<path d="M326,90 l30,-6 l0,140 l-30,-4z" fill="#8a5c34" stroke="#5a3a22" stroke-width="2"/><circle cx="332" cy="160" r="2" fill="#e8c45a"/>')
    # cama
    if stage == 0:
        S.append('<ellipse cx="96" cy="234" rx="58" ry="6" fill="#3a1a08" opacity="0.2"/><path d="M40,232 l108,0 l0,-14 l-108,0z" fill="#d9d4c8" stroke="#8a8494" stroke-width="1.4"/><path d="M44,220 q12,-8 26,0 l0,10 l-26,0z" fill="#f4ecd8" stroke="#a8a08a" stroke-width="1.2"/><path d="M76,222 l70,0 l0,8 l-70,0z" fill="#8a8494" opacity="0.7"/>')
        S.append('<path d="M160,232 l24,0 l0,-18 l-24,0z" fill="#b58f62" stroke="#7a5a3a" stroke-width="1.4"/><path d="M168,214 l2,-14 M172,214 l4,-12" stroke="#f2ede2" stroke-width="2"/>')
    else:
        bc = ["", "#c0432e", "#3f8f8a", "#2f4f8f", "#5aa847", "#a8475a"][stage]
        S.append(f'''<ellipse cx="100" cy="238" rx="66" ry="6" fill="#3a1a08" opacity="0.2"/>
          <path d="M34,236 l0,-56 q0,-6 6,-6 l8,0 q6,0 6,6 l0,56z" fill="#8a5c34" stroke="#5a3a22" stroke-width="1.6"/>
          <path d="M50,236 l112,0 l0,-22 l-112,0z" fill="#9a6a40" stroke="#5a3a22" stroke-width="1.6"/>
          <path d="M52,214 l108,0 l0,-12 l-108,0z" fill="#f6efe2" stroke="#a89878" stroke-width="1.2"/>
          <path d="M56,204 q14,-10 30,0 l0,8 l-30,0z" fill="#ffffff" stroke="#a89878" stroke-width="1.2"/>
          <path d="M92,202 l70,0 l2,16 l-72,0z" fill="{bc}" stroke="{darker(bc)}" stroke-width="1.2"/>''')
        S.append('<path d="M172,236 l26,0 l0,-26 l-26,0z" fill="#a87a4e" stroke="#5a3a22" stroke-width="1.4"/><circle cx="185" cy="222" r="1.6" fill="#e8c45a"/><path d="M178,210 l14,0 l-3,-10 l-8,0z" fill="#f2b533" stroke="#9a7020" stroke-width="1"/>')
    # cocina
    if stage >= 2:
        S.append('''<path d="M228,236 l40,0 l0,-40 l-40,0z" fill="#e8e2d8" stroke="#8a8494" stroke-width="1.4"/><path d="M228,196 l40,0 l0,5 l-40,0z" fill="#3a3540"/>
          <circle cx="238" cy="198" r="3" fill="#c0432e"/><circle cx="256" cy="198" r="3" fill="#c0432e"/><rect x="234" y="208" width="28" height="18" rx="2" fill="#8a8494"/>
          <path d="M274,236 l30,0 l0,-80 l-30,0z" fill="#f4ecdf" stroke="#8a8494" stroke-width="1.4"/><path d="M274,190 l30,0" stroke="#8a8494" stroke-width="1.2"/><path d="M298,172 l0,10 M298,200 l0,12" stroke="#8a8494" stroke-width="2"/>''')
    # sala
    if stage >= 3:
        S.append('''<path d="M60,140 l50,0 l0,34 l-50,0z" fill="#3a3540" stroke="#24202c" stroke-width="1.4"/><rect x="64" y="144" width="42" height="26" fill="#4fbf9a"/><path d="M66,146 l10,0 l-6,8z" fill="#ffffff" opacity="0.4"/>''')
        S.append('<path d="M196,256 l90,0 l0,-22 l-90,0z" fill="#a8475a" stroke="#6e2a38" stroke-width="1.4"/><path d="M190,256 l0,-36 l12,0 l0,36z M280,256 l0,-36 l12,0 l0,36z" fill="#8a3a4a" stroke="#6e2a38" stroke-width="1.4"/>')
        S.append('<path d="M308,236 l14,0 l-2,-14 l-10,0z" fill="#c0614a" stroke="#7a3a22" stroke-width="1"/><path d="M315,222 q-10,-16 -12,-22 M315,222 q2,-18 0,-26 M315,222 q10,-14 14,-18" stroke="#4d9a38" stroke-width="2.6" fill="none" stroke-linecap="round"/>')
    if stage >= 4:
        S.append('<path d="M140,262 l140,0 l-14,-14 l-112,0z" fill="#7fc8b4" stroke="#4f8f86" stroke-width="1.2"/>')
        S.append('<rect x="250" y="56" width="22" height="28" rx="1" fill="#b5874f" stroke="#5a3a22" stroke-width="1.4"/><rect x="254" y="60" width="14" height="20" fill="#a6dcf8"/><path d="M254,74 l14,0 l0,6 l-14,0z" fill="#8fbf6a"/>')
    if stage >= 5:
        S.append('<rect x="70" y="60" width="30" height="40" rx="1" fill="#e8c45a" stroke="#9a7020" stroke-width="1.6"/><rect x="74" y="64" width="22" height="32" fill="#f3e6c8"/><ellipse cx="85" cy="80" rx="6" ry="7" fill="#c98f62" stroke="#3a2618" stroke-width="0.8"/><path d="M76,74 q9,-5 18,0" stroke="#e3c47e" stroke-width="3"/>')
    S.append(lamp_light(110, 0, H) if stage >= 1 else f'<path d="M110,0 l0,40" stroke="{INK}" stroke-width="1.2"/><circle cx="110" cy="44" r="5" fill="#fff6c8" stroke="#9a8a6a" stroke-width="1"/>')
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#vignette)"/>')
    render(f"house_{stage}", W, H, "\n".join(S), defs)

# ====================================================================== MINA
def mine_bg(own):
    S = []
    defs = '''<linearGradient id="msky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fc8ec"/><stop offset="1" stop-color="#f6e8c8"/></linearGradient>
      <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c99a62"/><stop offset="1" stop-color="#b8844e"/></linearGradient>'''
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#msky)"/>')
    for (x, y, s) in [(40, 30, 1), (180, 18, 1.3), (300, 40, 0.9)]:
        S.append(f'<g transform="translate({x},{y}) scale({s})"><ellipse cx="0" cy="0" rx="22" ry="9" fill="#ffffff"/><ellipse cx="14" cy="-5" rx="14" ry="9" fill="#ffffff"/><ellipse cx="-12" cy="2" rx="12" ry="7" fill="#ffffff"/></g>')
    S.append('<path d="M180,140 q40,-40 90,-30 q40,-30 90,0 l0,60 l-180,0z" fill="#a6c98a"/><path d="M220,150 q50,-30 140,-10 l0,40 l-140,0z" fill="#8fb878"/>')
    # cantera escalonada
    for (y, w, c) in [(70, 200, "#d8b07a"), (104, 236, "#c99a62"), (140, 270, "#b8844e")]:
        S.append(f'<path d="M0,{y} l{w},0 l12,{40 if y<140 else 60} l{-w-12},0z" fill="{c}" stroke="{darker(c,0.3)}" stroke-width="1.6"/>')
        for i in range(8):
            x = random.Random(y + i).uniform(4, w - 10)
            S.append(f'<path d="M{x:.0f},{y+8} l6,10" stroke="{darker(c,0.25)}" stroke-width="1.2" opacity="0.6"/>')
    S.append(f'<path d="M0,190 l{W},0 l0,{H-190} l-{W},0z" fill="url(#ground)"/><path d="M0,190 l{W},0" stroke="#9a6a3a" stroke-width="1.4"/>')
    for i in range(40):
        r = random.Random(i * 13)
        S.append(f'<circle cx="{r.uniform(0,W):.0f}" cy="{r.uniform(196,H):.0f}" r="{r.uniform(0.6,1.6):.1f}" fill="#9a6a3a" opacity="0.6"/>')
    # montones de material
    S.append(pile(36, 214, 60, 30, "#e9c27a", "#c99a52", "#fbe6b0"))
    S.append(pile(98, 214, 56, 26, "#a9a4b0", "#7a7682", "#d8d4dc"))
    S.append(pile(156, 214, 50, 22, "#d8b07a", "#b58f62", "#ecd4a8"))
    S.append(rock(196, 214, 22, "#8a8494", "#5a5468") + rock(212, 214, 16, "#a9a4b0", "#6a6670") + rock(204, 202, 14, "#c9c4cf", "#7a7682"))
    S.append(rock(234, 214, 18, "#a04a3a", "#6a2a1e") + rock(248, 214, 14, "#c0613f", "#7a3a22") + rock(240, 202, 12, "#8a3a2a", "#5a1a10"))
    # caseta
    hc = "#f4ecdf" if own else "#d9cdb4"
    roof = "#2f4f8f" if own else "#c0613f"
    S.append(f'''<path d="M282,214 l64,0 l0,-50 l-64,0z" fill="{hc}" stroke="#7a6a52" stroke-width="1.6"/>
      <path d="M274,166 l80,0 l-8,-16 l-64,0z" fill="{roof}" stroke="{darker(roof)}" stroke-width="1.6"/>
      <rect x="320" y="184" width="16" height="30" fill="#8a5c34" stroke="#5a3a22" stroke-width="1.4"/>
      <rect x="292" y="178" width="20" height="16" fill="#a6dcf8" stroke="#7a5232" stroke-width="2"/>''')
    sign = "TU MINA" if own else "LA MINA"
    S.append(f'''<path d="M290,130 l0,20 M338,130 l0,20" stroke="#5a3a22" stroke-width="2.4"/>
      <rect x="280" y="112" width="68" height="22" rx="3" fill="{'#2f4f8f' if own else '#7a4a2a'}" stroke="#3a2618" stroke-width="1.8"/>
      <text x="314" y="128" font-family="Oswald" font-weight="700" font-size="13" fill="{'#f2b533' if own else '#f4ecd8'}" text-anchor="middle" letter-spacing="1">{sign}</text>''')
    if own:
        S.append('<path d="M350,112 l0,-34" stroke="#3a2618" stroke-width="1.6"/><path d="M350,78 l-18,4 l18,6z" fill="#c0432e"/>')
        S.append('<path d="M60,176 l160,-40" stroke="#3a3540" stroke-width="4"/><path d="M64,176 l0,14 M216,138 l0,52" stroke="#3a3540" stroke-width="3"/>')
    render("mine_own" if own else "mine", W, H, "\n".join(S), defs)

# ====================================================================== FACHADAS / INTRO
def facade(kind):
    old = kind in ("old", "rain")
    night = kind in ("night", "rain")
    S = []
    defs = f'''<linearGradient id="fsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{'#1f2a4a' if night else '#8fc8ec'}"/><stop offset="1" stop-color="{'#3a4a6a' if night else '#f2e6c8'}"/></linearGradient>'''
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#fsky)"/>')
    if night:
        for i in range(30):
            r = random.Random(i)
            S.append(f'<circle cx="{r.uniform(0,W):.0f}" cy="{r.uniform(0,80):.0f}" r="{r.uniform(0.5,1.4):.1f}" fill="#fff6d0"/>')
        S.append('<circle cx="300" cy="34" r="14" fill="#f6ecd0"/><circle cx="294" cy="30" r="3" fill="#e6dcc0"/>')
    # edificios vecinos
    for (x, w, h, c) in [(-10, 80, 170, "#c09060"), (282, 90, 190, "#7fa0c0")]:
        cc = darker(c, 0.45) if night else c
        S.append(f'<rect x="{x}" y="{H-50-h}" width="{w}" height="{h}" fill="{cc}" stroke="{darker(c,0.5)}" stroke-width="1.6"/>')
        for j in range(4):
            for i in range(2):
                lit = night and (i + j) % 2 == 0
                S.append(f'<rect x="{x+14+i*30}" y="{H-40-h+j*36}" width="18" height="22" fill="{"#ffd98a" if lit else ("#2a3550" if night else "#cfe6f2")}" stroke="{darker(c,0.5)}" stroke-width="1.2"/>')
    # local
    body = "#b8ad98" if old else "#f0d9a8"
    if night: body = darker(body, 0.35)
    S.append(f'<rect x="64" y="70" width="226" height="152" fill="{body}" stroke="#5a3a22" stroke-width="2"/>')
    S.append(f'<path d="M58,66 l238,0 l0,10 l-238,0z" fill="#7a5232" stroke="#5a3a22" stroke-width="1.6"/>')
    if old:
        S.append('<path d="M120,100 l8,14 l-4,10 l9,16 M240,150 l-6,12 l4,8" stroke="#8a7a62" stroke-width="1.2" fill="none"/>')
    signc = "#6a7a96" if old else "#2f4f8f"
    S.append(f'<rect x="84" y="80" width="186" height="34" rx="4" fill="{signc}" stroke="#3a2618" stroke-width="2"/>')
    S.append(f'<text x="177" y="105" font-family="Oswald" font-weight="700" font-size="24" fill="{"#d8c8a0" if old else "#f2b533"}" text-anchor="middle" letter-spacing="2" opacity="{0.75 if old else 1}">{"MATERIA ES" if old else "MATERIALES"}</text>')
    # cortina / entrada
    if old:
        S.append('<rect x="92" y="124" width="112" height="98" fill="#8a8494" stroke="#5a5468" stroke-width="1.6"/>' + "".join(f'<path d="M92,{y} l112,0" stroke="#6b6578" stroke-width="1.2"/>' for y in range(130, 222, 6)) + '<rect x="130" y="160" width="30" height="14" fill="#c0614a" opacity="0.8"/>')
    else:
        S.append('<rect x="92" y="124" width="112" height="98" fill="#ffe2a0" stroke="#7a5232" stroke-width="2"/><path d="M92,124 l112,0 l0,8 l-112,0z" fill="#c0432e"/><path d="M92,124 l14,8 l14,-8 l14,8 l14,-8 l14,8 l14,-8 l14,8 l14,-8" stroke="#f4ecd8" stroke-width="3" fill="none"/>')
    S.append(f'<rect x="218" y="128" width="58" height="50" fill="{"#7f9cab" if old else "#a6dcf8"}" stroke="#7a5232" stroke-width="3"/>')
    if old: S.append('<path d="M222,132 l30,30" stroke="#3a2618" stroke-width="1"/>')
    # banqueta y calle
    S.append(f'<rect x="0" y="222" width="{W}" height="10" fill="#c9c4cf" stroke="#8a8494" stroke-width="1.2"/><rect x="0" y="232" width="{W}" height="40" fill="#5d6270"/>')
    for x in range(10, W, 50): S.append(f'<rect x="{x}" y="250" width="26" height="4" fill="#f2c14e"/>')
    if night: S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#1a2040" opacity="0.25"/>')
    if kind == "rain":
        for i in range(120):
            r = random.Random(i * 7)
            x = r.uniform(0, W); y = r.uniform(0, H)
            S.append(f'<path d="M{x:.0f},{y:.0f} l-3,9" stroke="#b8cce8" stroke-width="1.2" opacity="0.6"/>')
    render({"old": "facade_old", "new": "facade_new", "night": "facade_night", "rain": "intro_rain"}[kind], W, H, "\n".join(S), defs)

def intro_office():
    S = [f'<rect x="0" y="0" width="{W}" height="{FL}" fill="#dcd6cc"/>']
    for x in range(0, W, 60): S.append(f'<path d="M{x},0 l0,{FL}" stroke="#cfc8bc" stroke-width="2"/>')
    S.append(window(30, 40, 90, 70))
    S.append(f'<path d="M0,{FL} l{W},0 l0,{H-FL} l-{W},0z" fill="#6a8fd8"/>')
    S.append('<path d="M190,196 l130,0 l0,-10 l-130,0z" fill="#8a8494" stroke="#5a5468" stroke-width="1.4"/><path d="M200,196 l0,40 M310,196 l0,40" stroke="#5a5468" stroke-width="4"/>')
    S.append('<rect x="232" y="150" width="48" height="34" rx="2" fill="#3d3548" stroke="#24202c" stroke-width="1.4"/><rect x="236" y="154" width="40" height="26" fill="#7fe0c4"/><path d="M252,184 l8,0 l2,4 l-12,0z" fill="#3d3548"/>')
    S.append('<rect x="150" y="56" width="70" height="44" rx="2" fill="#ffffff" stroke="#8a8494" stroke-width="1.4"/><path d="M158,70 l14,10 l12,-6 l12,14 l14,6" stroke="#c0432e" stroke-width="2.4" fill="none"/><text x="185" y="66" font-family="Oswald" font-size="8" fill="#c0432e" text-anchor="middle">VENTAS</text>')
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#vignette)"/>')
    render("intro_office", W, H, "\n".join(S))

def intro_letter():
    S = [f'<rect x="0" y="0" width="{W}" height="{H}" fill="#9a6a40"/>']
    for y in range(0, H, 22): S.append(f'<path d="M0,{y} l{W},0" stroke="#7a5232" stroke-width="2"/>')
    S.append('<g transform="rotate(-2 180 136)"><rect x="70" y="24" width="220" height="226" rx="3" fill="#f6ecd8" stroke="#c9b48c" stroke-width="1.6"/>' + "".join(f'<path d="M84,{y} l192,0" stroke="#d9cfb8" stroke-width="1"/>' for y in range(60, 240, 18)) + '<circle cx="262" cy="222" r="14" fill="#b5463a" stroke="#7e2e20" stroke-width="1.6"/><circle cx="262" cy="222" r="8" fill="none" stroke="#e8a090" stroke-width="1.2"/></g>')
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#vignette)"/>')
    render("intro_letter", W, H, "\n".join(S))

# ====================================================================== VEHICULOS (lateral, hacia la derecha)
def wheel(x, y, r):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="#2e2a32" stroke="#1a161c" stroke-width="1.4"/><circle cx="{x}" cy="{y}" r="{r*0.45}" fill="#a9a4b0" stroke="#6a6670" stroke-width="1"/>'

def vehicles():
    for tier, (c, hi, rusty) in enumerate([("#8a5c34", "#b07a48", True), ("#4fa37a", "#7fe0c4", False), ("#e07a2e", "#f2b533", False)]):
        b = f'''<path d="M4,22 l20,-6" stroke="#7a5232" stroke-width="3" stroke-linecap="round"/>
          <path d="M20,8 l40,0 l-6,18 l-28,0z" fill="{c}" stroke="{darker(c)}" stroke-width="1.6" stroke-linejoin="round"/>
          <path d="M22,10 l36,0" stroke="{hi}" stroke-width="2"/>
          <path d="M34,26 l0,8 M46,26 l6,6" stroke="#5a5468" stroke-width="2"/>'''
        if rusty: b += '<circle cx="34" cy="16" r="2" fill="#a8582e"/><circle cx="48" cy="19" r="2.4" fill="#7a3a1e"/><path d="M28,12 l4,6" stroke="#5a3a22" stroke-width="1"/>'
        b += wheel(52, 32, 6)
        render(f"veh_wheelbarrow_{tier}", 64, 40, b)
    render("veh_pickup", 120, 56, f'''<path d="M6,38 l0,-14 l50,0 l0,-14 q2,-4 6,-4 l26,0 q6,0 10,6 l10,12 q8,2 8,8 l0,6z" fill="#f4ecdf" stroke="#8a8494" stroke-width="1.6" stroke-linejoin="round"/>
      <path d="M64,10 l22,0 l10,12 l-32,0z" fill="#a6dcf8" stroke="#7a8a9a" stroke-width="1.2"/><path d="M6,30 l108,0" stroke="#2f4f8f" stroke-width="3"/>
      <rect x="108" y="30" width="6" height="4" fill="#f2b533"/>{wheel(26, 40, 9)}{wheel(92, 40, 9)}''')
    render("veh_truck", 150, 70, f'''<path d="M6,48 l0,-36 l86,0 l0,36z" fill="#e8b23a" stroke="#9a7020" stroke-width="1.6"/>
      <path d="M10,16 l78,0" stroke="#f6d47a" stroke-width="3"/>{"".join(f'<path d="M{x},16 l0,28" stroke="#c99a2a" stroke-width="1.6"/>' for x in range(22, 90, 16))}
      <path d="M96,48 l0,-30 q0,-4 4,-4 l20,0 q6,0 10,6 l10,14 l0,14z" fill="#e07a2e" stroke="#9a4a1a" stroke-width="1.6" stroke-linejoin="round"/>
      <path d="M104,18 l16,0 l10,14 l-26,0z" fill="#a6dcf8" stroke="#7a8a9a" stroke-width="1.2"/>
      <rect x="2" y="48" width="140" height="6" fill="#3a3540"/>{wheel(26, 56, 11)}{wheel(54, 56, 11)}{wheel(120, 56, 11)}''')
    render("veh_bigtruck", 190, 76, f'''<path d="M4,54 l0,-46 l124,0 l0,46z" fill="#ece6dc" stroke="#8a8494" stroke-width="1.6"/>
      <rect x="14" y="18" width="104" height="22" rx="2" fill="#c0432e"/><text x="66" y="34" font-family="Oswald" font-weight="700" font-size="13" fill="#fff6e8" text-anchor="middle">MATERIALES</text>
      <path d="M132,54 l0,-38 q0,-4 4,-4 l26,0 q8,0 12,8 l10,16 l0,18z" fill="#c0432e" stroke="#7e2e20" stroke-width="1.6" stroke-linejoin="round"/>
      <path d="M140,16 l22,0 l12,18 l-34,0z" fill="#a6dcf8" stroke="#7a8a9a" stroke-width="1.2"/>
      <rect x="2" y="54" width="184" height="6" fill="#3a3540"/>{wheel(24, 62, 12)}{wheel(52, 62, 12)}{wheel(100, 62, 12)}{wheel(160, 62, 12)}''')
    render("tr_bike", 60, 40, f'''{wheel(13, 28, 10)}{wheel(47, 28, 10)}
      <path d="M13,28 l14,-14 l16,0 l4,14 M27,14 l8,14 l12,0 M41,8 l2,6 M24,10 l8,0 M39,8 l6,0" stroke="#c0432e" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>''')
    render("tr_moto", 70, 46, f'''{wheel(14, 34, 10)}{wheel(56, 34, 10)}
      <path d="M14,34 l14,-12 l20,0 l8,12z" fill="#c0432e" stroke="#7e2e20" stroke-width="1.6" stroke-linejoin="round"/>
      <path d="M22,20 l18,0 q4,0 4,4 l-22,0z" fill="#3a3540"/><path d="M48,22 l6,-14 l6,0" stroke="#3a3540" stroke-width="2.6" fill="none" stroke-linecap="round"/><circle cx="60" cy="18" r="2.6" fill="#f2b533"/>''')
    render("tr_vocho", 100, 54, f'''<path d="M8,40 q0,-14 16,-16 q8,-16 26,-18 q20,0 30,18 q14,2 14,16z" fill="#3f8f8a" stroke="#235854" stroke-width="1.8" stroke-linejoin="round"/>
      <path d="M30,22 q6,-10 16,-11 l0,11z M50,11 q12,0 18,11 l-18,0z" fill="#a6dcf8" stroke="#235854" stroke-width="1.2"/>
      <path d="M10,32 l82,0" stroke="#6fc2a8" stroke-width="2"/><circle cx="90" cy="34" r="2.6" fill="#f2b533"/>{wheel(26, 42, 9)}{wheel(74, 42, 9)}''')

# ====================================================================== ICONOS (48x48 unidades)
def icons():
    I = {}
    I["arena"] = pile(24, 40, 40, 24, "#e9c27a", "#c99a52", "#fbe6b0")
    I["grava"] = pile(24, 40, 40, 24, "#a9a4b0", "#7a7682", "#d8d4dc")
    I["tepetate"] = pile(24, 40, 40, 24, "#d8b07a", "#b58f62", "#ecd4a8")
    I["piedra"] = rock(4, 42, 22, "#8a8494", "#5a5468") + rock(20, 42, 26, "#a9a4b0", "#6a6670") + rock(14, 42, 14, "#c9c4cf", "#7a7682")
    I["tezontle"] = rock(4, 42, 22, "#a04a3a", "#6a2a1e") + rock(20, 42, 26, "#c0613f", "#7a3a22") + rock(14, 42, 14, "#8a3a2a", "#5a1a10")
    I["cemento"] = sack(3, 16, "CEMENTO", "#ddd6c6", "#4a6fb5", "#9a9282")
    I["cal"] = sack(3, 16, "CAL", "#f1ead8", "#4fa37a", "#a8a08a")
    I["yeso"] = sack(3, 16, "YESO", "#ffffff", "#c0432e", "#a8a08a")
    I["tabique"] = "".join(f'<rect x="{4+i*14+(j%2)*7}" y="{34-j*9}" width="13" height="8" rx="1" fill="#c0613f" stroke="#8a3a22" stroke-width="1.2"/>' for j in range(3) for i in range(2))
    I["block"] = '<rect x="6" y="14" width="36" height="26" rx="2" fill="#a9a4b0" stroke="#6a6670" stroke-width="1.6"/><rect x="11" y="19" width="11" height="16" rx="1" fill="#6b6578"/><rect x="26" y="19" width="11" height="16" rx="1" fill="#6b6578"/>'
    I["varilla"] = "".join(f'<path d="M4,{14+i*6} l40,6" stroke="#7a7682" stroke-width="3" stroke-linecap="round"/>' for i in range(4)) + '<path d="M18,10 l-2,30 M32,12 l-2,30" stroke="#c0432e" stroke-width="2.4"/>'
    I["alambre"] = '<circle cx="24" cy="24" r="17" fill="none" stroke="#7a7682" stroke-width="5"/><circle cx="24" cy="24" r="17" fill="none" stroke="#c9c4cf" stroke-width="1.4"/><circle cx="24" cy="24" r="10" fill="none" stroke="#7a7682" stroke-width="4"/>'
    I["clavos"] = '<path d="M8,42 l2,-24 l28,0 l2,24z" fill="#d8b07a" stroke="#8a6a3e" stroke-width="1.6"/><rect x="14" y="28" width="20" height="7" fill="#c0432e"/>' + "".join(f'<path d="M{x},20 l0,-12 M{x-3},8 l6,0" stroke="#6a6670" stroke-width="2.2" stroke-linecap="round"/>' for x in (16, 24, 32))
    I["pintura"] = '<path d="M10,14 l28,0 l-2,28 l-24,0z" fill="#d0533f" stroke="#8a2a1e" stroke-width="1.6"/><rect x="13" y="22" width="22" height="10" fill="#f7eedb"/><circle cx="20" cy="27" r="3" fill="#3f8f8a"/><circle cx="28" cy="27" r="3" fill="#e8b23a"/><path d="M10,14 q14,-14 28,0" stroke="#6a6670" stroke-width="1.8" fill="none"/>'
    I["tubo"] = '<rect x="4" y="12" width="40" height="9" rx="4" fill="#f2ede2" stroke="#8a8494" stroke-width="1.4"/><rect x="4" y="26" width="40" height="9" rx="4" fill="#f2ede2" stroke="#8a8494" stroke-width="1.4"/><rect x="38" y="10" width="8" height="13" rx="2" fill="#c9c4cf" stroke="#8a8494" stroke-width="1.2"/>'
    I["impermeabilizante"] = '<path d="M8,12 l32,0 l-2,30 l-28,0z" fill="#e07a2e" stroke="#9a4a1a" stroke-width="1.6"/><rect x="11" y="20" width="26" height="12" fill="#f7eedb"/><path d="M14,26 q10,-6 20,0" stroke="#c0432e" stroke-width="2" fill="none"/><rect x="18" y="6" width="12" height="6" fill="#6a6670"/>'
    I["azulejo"] = "".join(f'<rect x="{5+i*19}" y="{5+j*19}" width="18" height="18" rx="2" fill="{"#6a8fd8" if (i+j)%2 else "#a6dcf8"}" stroke="#3f63a8" stroke-width="1.2"/>' for i in range(2) for j in range(2))
    I["castillo"] = '<path d="M4,14 l40,0 M4,34 l40,0 M4,24 l40,0" stroke="#7a7682" stroke-width="3"/>' + "".join(f'<path d="M{x},12 l0,24" stroke="#c0432e" stroke-width="2.2"/>' for x in range(8, 44, 7))
    I["martillo"] = '<path d="M12,42 l18,-24" stroke="#8a5c34" stroke-width="5" stroke-linecap="round"/><path d="M20,8 l18,0 l4,8 l-8,6 l-14,-6z" fill="#a9a4b0" stroke="#5a5468" stroke-width="1.6" stroke-linejoin="round"/>'
    I["pala"] = '<path d="M10,8 l18,22" stroke="#8a5c34" stroke-width="4" stroke-linecap="round"/><path d="M24,28 l14,-4 l6,14 q-6,8 -16,2z" fill="#9aa4a8" stroke="#5a5468" stroke-width="1.6" stroke-linejoin="round"/><path d="M6,6 l8,0" stroke="#5a3a22" stroke-width="4" stroke-linecap="round"/>'
    I["cuchara"] = '<path d="M6,36 l20,-14 l12,8 l-20,14z" fill="#c9c4cf" stroke="#5a5468" stroke-width="1.6" stroke-linejoin="round"/><path d="M30,24 l4,-8 l8,-6" stroke="#8a5c34" stroke-width="4" stroke-linecap="round"/>'
    I["cinta"] = '<rect x="8" y="10" width="28" height="28" rx="6" fill="#f2b533" stroke="#9a7020" stroke-width="1.6"/><circle cx="22" cy="24" r="7" fill="#3a3540"/><path d="M36,32 l8,0 l0,4 l-8,0z" fill="#f6e070" stroke="#9a7020" stroke-width="1"/>'
    I["taladro"] = '<path d="M6,14 l26,0 l0,12 l-26,0z" fill="#3f9a68" stroke="#235a3a" stroke-width="1.6"/><path d="M14,26 l10,0 l2,16 l-12,0z" fill="#3a3540" stroke="#1a161c" stroke-width="1.4"/><path d="M32,20 l12,0" stroke="#a9a4b0" stroke-width="3" stroke-linecap="round"/>'
    I["carretilla"] = '<path d="M4,30 l12,-4" stroke="#7a5232" stroke-width="3" stroke-linecap="round"/><path d="M12,16 l28,0 l-4,14 l-20,0z" fill="#4fa37a" stroke="#2f6a50" stroke-width="1.6"/>' + wheel(34, 36, 6)
    # UI
    I["coin"] = '<circle cx="24" cy="24" r="18" fill="#f2b533" stroke="#9a7020" stroke-width="2"/><circle cx="24" cy="24" r="12" fill="none" stroke="#fff1b8" stroke-width="2"/><text x="24" y="31" font-family="Oswald" font-weight="700" font-size="18" fill="#9a6a10" text-anchor="middle">$</text>'
    I["bolt"] = '<path d="M12,10 l24,0 l-4,10 l-16,0z" fill="#f2c14e" stroke="#9a7020" stroke-width="1.8" stroke-linejoin="round"/><rect x="20" y="20" width="8" height="22" fill="#e0a830" stroke="#9a7020" stroke-width="1.6"/>' + "".join(f'<path d="M20,{y} l8,-3" stroke="#9a7020" stroke-width="1.2"/>' for y in (26, 31, 36, 41))
    I["energy"] = '<path d="M14,14 l18,0 l-2,28 l-14,0z" fill="#c0432e" stroke="#7e2e20" stroke-width="1.8"/><path d="M32,20 q8,2 0,12" stroke="#7e2e20" stroke-width="2.4" fill="none"/><rect x="13" y="10" width="20" height="5" rx="1.5" fill="#f2ede2" stroke="#8a8494" stroke-width="1.2"/><path d="M18,7 q2,-4 0,-6 M24,7 q2,-4 0,-6 M30,7 q2,-4 0,-6" stroke="#c9c4cf" stroke-width="1.6" fill="none"/>'
    I["clock"] = '<circle cx="24" cy="24" r="18" fill="#f7eedb" stroke="#3a2618" stroke-width="2.6"/><path d="M24,24 l0,-11 M24,24 l8,4" stroke="#3a2618" stroke-width="2.6" stroke-linecap="round"/><circle cx="24" cy="24" r="2" fill="#c0432e"/>'
    I["star"] = '<path d="M24,5 l5.5,12 l13,1.5 l-10,9 l3,13 l-11.5,-7 l-11.5,7 l3,-13 l-10,-9 l13,-1.5z" fill="#f2b533" stroke="#9a7020" stroke-width="1.8" stroke-linejoin="round"/>'
    I["lock"] = '<path d="M14,22 l0,-6 q0,-10 10,-10 q10,0 10,10 l0,6" stroke="#6a6670" stroke-width="4" fill="none"/><rect x="10" y="22" width="28" height="20" rx="3" fill="#f2b533" stroke="#9a7020" stroke-width="1.8"/><circle cx="24" cy="31" r="3" fill="#3a2618"/>'
    I["box"] = '<path d="M6,16 l36,0 l0,26 l-36,0z" fill="#d8a870" stroke="#9a7040" stroke-width="1.6"/><path d="M6,16 l6,-8 l24,0 l6,8" fill="#e8c08a" stroke="#9a7040" stroke-width="1.4"/><path d="M20,16 l8,0 l0,10 l-8,0z" fill="#f5d58f"/>'
    I["ad"] = '<rect x="4" y="10" width="40" height="28" rx="6" fill="#2f8790" stroke="#1d5559" stroke-width="1.8"/><path d="M19,17 l0,14 l12,-7z" fill="#f7eedb"/>'
    I["person"] = '<circle cx="24" cy="16" r="9" fill="#e8b48a" stroke="#3a2618" stroke-width="1.8"/><path d="M8,42 q0,-16 16,-16 q16,0 16,16z" fill="#3f8f8a" stroke="#3a2618" stroke-width="1.8"/>'
    I["menu"] = "".join(f'<rect x="8" y="{y}" width="32" height="5" rx="2.5" fill="#3a2618"/>' for y in (12, 22, 32))
    I["newspaper"] = '<path d="M6,10 l32,0 l0,30 q0,4 -4,4 l-24,0 q-4,0 -4,-4z" fill="#f2ede2" stroke="#6a6670" stroke-width="1.6"/><rect x="10" y="14" width="16" height="5" fill="#3a2618"/><path d="M10,24 l24,0 M10,29 l24,0 M10,34 l16,0" stroke="#a9a4b0" stroke-width="2"/><rect x="28" y="14" width="6" height="6" fill="#c0432e"/><path d="M38,16 l4,0 l0,24 q0,4 -4,4" fill="#e8e2d8" stroke="#6a6670" stroke-width="1.4"/>'
    I["nav_local"] = '<path d="M10,22 l0,20 l28,0 l0,-20" fill="#f3dcae" stroke="#3a2618" stroke-width="2"/><path d="M6,22 l4,-12 l28,0 l4,12z" fill="#c0432e" stroke="#3a2618" stroke-width="2" stroke-linejoin="round"/><path d="M6,22 l6,4 l6,-4 l6,4 l6,-4 l6,4 l6,-4" stroke="#f4ecd8" stroke-width="2" fill="none"/><rect x="19" y="29" width="10" height="13" fill="#8a5c34" stroke="#3a2618" stroke-width="1.6"/>'
    I["nav_mine"] = '<path d="M12,42 l18,-22" stroke="#8a5c34" stroke-width="4.5" stroke-linecap="round"/><path d="M14,12 q14,-6 24,12" stroke="#5a5468" stroke-width="6.5" fill="none" stroke-linecap="round"/><path d="M14,12 q14,-6 24,12" stroke="#a9a4b0" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
    I["nav_house"] = '<path d="M6,24 l18,-16 l18,16" fill="#c0432e" stroke="#3a2618" stroke-width="2" stroke-linejoin="round"/><rect x="11" y="24" width="26" height="18" fill="#f7eedb" stroke="#3a2618" stroke-width="2"/><rect x="20" y="30" width="8" height="12" fill="#8a5c34"/><rect x="31" y="10" width="5" height="9" fill="#8a5c34" stroke="#3a2618" stroke-width="1.4"/>'
    I["nav_up"] = '<rect x="6" y="10" width="36" height="28" fill="#3f6fb0" stroke="#1f3a70" stroke-width="2"/><path d="M12,30 l0,-14 l12,0 l0,8 l12,0" stroke="#dce8ff" stroke-width="1.8" fill="none"/><circle cx="6" cy="24" r="5" fill="#2f5590" stroke="#1f3a70" stroke-width="1.6"/><path d="M28,14 l8,0 l0,8" stroke="#dce8ff" stroke-width="1.2" fill="none" stroke-dasharray="2 2"/>'
    I["nav_shop"] = '<path d="M10,18 l28,0 l3,24 l-34,0z" fill="#f2b533" stroke="#3a2618" stroke-width="2" stroke-linejoin="round"/><path d="M17,18 q0,-12 7,-12 q7,0 7,12" stroke="#3a2618" stroke-width="2" fill="none"/><path d="M24,26 l2,4 l4,0 l-3,3 l1,4 l-4,-2 l-4,2 l1,-4 l-3,-3 l4,0z" fill="#c0432e"/>'
    for k, v in I.items():
        render("ic_" + k, 48, 48, v)

def ui_pieces():
    # borde rasgado de la nota de remision
    teeth = "".join(f"l6,-4 l6,4 " for _ in range(30))
    render("note_tear", 360, 8, f'<path d="M0,8 l0,-4 {teeth} l0,4z" fill="#fffbef"/>')
    # textura de madera para barras
    b = '<rect width="120" height="60" fill="url(#woodv)"/>' + "".join(f'<path d="M0,{y} q30,{random.Random(y).uniform(-2,2):.1f} 60,0 t60,0" stroke="#3b2a20" stroke-width="1" fill="none" opacity="0.35"/>' for y in range(6, 60, 7))
    render("wood_tile", 120, 60, b)
    k = '<rect width="32" height="32" fill="#c9a57a"/>' + "".join(f'<path d="M{x},0 l0,32" stroke="#c19e72" stroke-width="1"/>' for x in range(0, 32, 4)) + "".join(f'<circle cx="{random.Random(i).uniform(0,32):.1f}" cy="{random.Random(i*5).uniform(0,32):.1f}" r="0.5" fill="#b8935f"/>' for i in range(14))
    render("bg_kraft", 32, 32, k)
    # icono de la app
    ic = f'''<rect width="64" height="64" rx="0" fill="#4a3427"/><rect x="0" y="44" width="64" height="20" fill="#c99a62"/>
      {pile(18, 50, 26, 16, "#e9c27a", "#c99a52", "#fbe6b0")}
      <g transform="translate(22,24) scale(0.62)"><path d="M4,22 l20,-6" stroke="#7a5232" stroke-width="3" stroke-linecap="round"/><path d="M20,8 l40,0 l-6,18 l-28,0z" fill="#4fa37a" stroke="#2f6a50" stroke-width="1.6"/>{wheel(52, 32, 6)}</g>
      <text x="32" y="22" font-family="Oswald" font-weight="700" font-size="16" fill="#f2b533" text-anchor="middle">$</text>'''
    render("icon", 64, 64, ic)

if __name__ == "__main__":
    for s in range(9): shop_bg(s)
    for v in range(4): counter(v)
    shop_light(False); shop_light(True)
    stock_sprites(); dirt_sprites()
    for s in range(6): house_bg(s)
    mine_bg(False); mine_bg(True)
    for k in ("old", "new", "night", "rain"): facade(k)
    intro_letter()  # intro_office y la calle viven en gen_street.py
    vehicles(); icons(); ui_pieces()
    print("ok", len(os.listdir(OUT)))
