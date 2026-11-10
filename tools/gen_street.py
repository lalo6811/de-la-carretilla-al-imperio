"""Arte de la calle: tira de calle para el trayecto casa<->local, fachadas exteriores del local y
de la casa por etapa, y fondos mejorados del intro. Usa render() de gen_vector.
Uso: python3 tools/gen_street.py
"""
import random, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_vector import render, darker, W, H

INK = "#3a2618"
SIDE_Y = 214     # banqueta
ROAD_Y = 226     # calle

def sky(night=False, rain=False, w=W):
    top, bot = ("#1f2a4a", "#3a4a6a") if night else (("#6f7f94", "#a8b0b8") if rain else ("#8fc8ec", "#f2e6c8"))
    d = f'<linearGradient id="ssky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>'
    return d, f'<rect x="0" y="0" width="{w}" height="{H}" fill="url(#ssky)"/>'

def clouds(w, seed, n=4):
    r = random.Random(seed); S = []
    for i in range(n):
        x = r.uniform(0, w); y = r.uniform(18, 70); s = r.uniform(0.7, 1.3)
        S.append(f'<g opacity="0.9" transform="translate({x:.0f},{y:.0f}) scale({s:.2f})"><ellipse cx="0" cy="0" rx="22" ry="9" fill="#ffffff"/><ellipse cx="14" cy="-5" rx="14" ry="10" fill="#ffffff"/><ellipse cx="-12" cy="-3" rx="11" ry="8" fill="#ffffff"/></g>')
    return "".join(S)

def ground(w, night=False):
    side = "#c9c4cf" if not night else "#7a7688"
    road = "#5d6270" if not night else "#3a3e4c"
    S = [f'<rect x="0" y="{SIDE_Y}" width="{w}" height="{ROAD_Y-SIDE_Y}" fill="{side}" stroke="#8a8494" stroke-width="1.2"/>']
    for x in range(0, w, 24): S.append(f'<path d="M{x},{SIDE_Y} l0,{ROAD_Y-SIDE_Y}" stroke="#a9a4b0" stroke-width="1"/>')
    S.append(f'<rect x="0" y="{ROAD_Y}" width="{w}" height="{H-ROAD_Y}" fill="{road}"/>')
    S.append(f'<rect x="0" y="{ROAD_Y}" width="{w}" height="3" fill="#8a8494"/>')
    for x in range(10, w, 48): S.append(f'<rect x="{x}" y="{ROAD_Y+22}" width="24" height="4" fill="#f2c14e"/>')
    return "".join(S)

def little_house(x, w, h, c, r, night=False, kind="casa"):
    """Casita o changarro de colonia: muro de color, ventanas con herreria, puerta, tinaco."""
    cc = darker(c, 0.4) if night else c
    y = SIDE_Y - h
    S = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{cc}" stroke="{darker(c,0.55)}" stroke-width="1.6"/>']
    S.append(f'<rect x="{x-2}" y="{y-4}" width="{w+4}" height="5" fill="{darker(c,0.25)}" stroke="{darker(c,0.55)}" stroke-width="1.2"/>')
    if r.random() < 0.6:   # tinaco
        tx = x + r.uniform(8, w - 24)
        S.append(f'<rect x="{tx}" y="{y-20}" width="16" height="16" rx="3" fill="#2f2f36" stroke="#1a1a1e" stroke-width="1.2"/><rect x="{tx+2}" y="{y-24}" width="12" height="5" rx="2" fill="#3c3c44"/>')
    if r.random() < 0.5:   # varillas en la azotea
        for i in range(3): S.append(f'<path d="M{x+6+i*5},{y-4} l0,-12" stroke="#7a4a32" stroke-width="1.4"/>')
    win = "#ffd98a" if night else "#cfe6f2"
    if kind == "changarro":
        S.append(f'<rect x="{x+6}" y="{y+18}" width="{w-12}" height="{h-18}" fill="#8a8494" stroke="#5a5468" stroke-width="1.2"/>')
        for yy in range(int(y + 22), SIDE_Y, 5): S.append(f'<path d="M{x+6},{yy} l{w-12},0" stroke="#6b6578" stroke-width="1"/>')
        lab = r.choice(["ABARROTES", "TORTILLERÍA", "PAPELERÍA", "FARMACIA", "TACOS"])
        S.append(f'<rect x="{x+4}" y="{y+4}" width="{w-8}" height="12" fill="#fff6dc" stroke="{darker(c,0.55)}" stroke-width="1"/><text x="{x+w/2}" y="{y+13.5}" font-family="Oswald" font-weight="700" font-size="8.5" fill="#c0432e" text-anchor="middle">{lab}</text>')
    else:
        dx = x + r.uniform(6, w - 26)
        S.append(f'<rect x="{dx}" y="{SIDE_Y-34}" width="20" height="34" fill="{r.choice(["#7a4a32", "#3f6aa8", "#2f8a5b", "#8a3a2a"])}" stroke="{INK}" stroke-width="1.4"/><circle cx="{dx+15}" cy="{SIDE_Y-17}" r="1.4" fill="#f2c14e"/>')
        wx = x + 6
        while wx + 22 < x + w - 4:
            if not (wx < dx + 22 and wx + 22 > dx):
                S.append(f'<rect x="{wx}" y="{y+12}" width="22" height="18" fill="{win}" stroke="{darker(c,0.55)}" stroke-width="1.2"/>')
                for i in range(1, 4): S.append(f'<path d="M{wx+i*5.5},{y+12} l0,18" stroke="{INK}" stroke-width="0.9"/>')
            wx += 30
    return "".join(S)

def poste(x, night=False):
    S = f'<path d="M{x},{SIDE_Y+2} l0,-150" stroke="#6b5440" stroke-width="5"/><path d="M{x-14},{SIDE_Y-138} l28,0" stroke="#6b5440" stroke-width="3"/>'
    S += f'<path d="M{x},{SIDE_Y-150} q90,22 180,0" stroke="#2a2420" stroke-width="1" fill="none"/>'
    if night: S += f'<circle cx="{x+12}" cy="{SIDE_Y-132}" r="16" fill="url(#glow)"/>'
    S += f'<path d="M{x},{SIDE_Y-140} l12,4 l0,4" stroke="#4a4a52" stroke-width="2.5" fill="none"/><circle cx="{x+12}" cy="{SIDE_Y-131}" r="3" fill="{"#fff2b0" if night else "#e8e2d0"}"/>'
    return S

def tree(x, s=1.0):
    return f'<path d="M{x},{SIDE_Y} l0,-{40*s}" stroke="#6b4a2a" stroke-width="{5*s}"/><circle cx="{x}" cy="{SIDE_Y-48*s}" r="{18*s}" fill="#4f9a4a" stroke="#2f6a32" stroke-width="1.4"/><circle cx="{x-10*s}" cy="{SIDE_Y-40*s}" r="{12*s}" fill="#5cae55" stroke="#2f6a32" stroke-width="1.2"/>'

def street_tile(night=False):
    """Tira de 720 px que se repite: casitas de colonia, changarros, postes."""
    w = 720
    d, S0 = sky(night, w=w)
    S = [S0]
    if not night: S.append(clouds(w, 3, 6))
    else:
        r = random.Random(9)
        for i in range(40): S.append(f'<circle cx="{r.uniform(0,w):.0f}" cy="{r.uniform(0,90):.0f}" r="{r.uniform(0.5,1.4):.1f}" fill="#fff6d0"/>')
    r = random.Random(42)
    cols = ["#e8a0a0", "#f2d07a", "#9fd0b4", "#a8c4e8", "#f0b07a", "#d8b0e0", "#c8e08a", "#f4e0c0"]
    x = 0
    i = 0
    while x < w:
        bw = r.choice([70, 84, 96, 110])
        if x + bw > w: bw = w - x
        h = r.uniform(74, 120)
        kind = "changarro" if i % 3 == 1 and bw >= 70 else "casa"
        S.append(little_house(x, bw, h, cols[i % len(cols)], r, night, kind))
        x += bw; i += 1
    S.append(tree(150, 1.0)); S.append(tree(520, 0.9))
    S.append(poste(60, night)); S.append(poste(420, night))
    S.append(ground(w, night))
    if night: S.append(f'<rect x="0" y="0" width="{w}" height="{H}" fill="#1a2040" opacity="0.22"/>')
    d += '<radialGradient id="glow"><stop offset="0" stop-color="#fff6c8" stop-opacity="0.75"/><stop offset="1" stop-color="#fff6c8" stop-opacity="0"/></radialGradient>'
    render("street_night" if night else "street_day", w, H, "\n".join(S), d)

def shop_building(x, w, stage):
    """Fachada del local segun etapa."""
    old = stage <= 1
    S = []
    h = 140 if stage < 5 else 160
    top = SIDE_Y - h
    body = "#b8ad98" if stage == 0 else ("#e6d4b0" if stage < 3 else "#f0d9a8")
    if stage >= 3: body = "#f4dca0"
    S.append(f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{body}" stroke="#5a3a22" stroke-width="2"/>')
    if stage >= 5:   # tapanco: ventana arriba
        S.append(f'<rect x="{x+w/2-30}" y="{top+10}" width="60" height="22" fill="#a6dcf8" stroke="#7a5232" stroke-width="2"/><path d="M{x+w/2},{top+10} l0,22" stroke="#7a5232" stroke-width="2"/>')
    S.append(f'<path d="M{x-6},{top-4} l{w+12},0 l0,10 l-{w+12},0z" fill="#7a5232" stroke="#5a3a22" stroke-width="1.6"/>')
    if stage == 0:
        S.append(f'<path d="M{x+40},{top+40} l8,14 l-4,10 l9,16 M{x+w-40},{top+90} l-6,12 l4,8" stroke="#8a7a62" stroke-width="1.2" fill="none"/>')
    sy = top + (40 if stage >= 5 else 10)
    signc = "#6a7a96" if old else ("#2f4f8f" if stage < 8 else "#c0432e")
    sw = w - 30
    S.append(f'<rect x="{x+15}" y="{sy}" width="{sw}" height="30" rx="4" fill="{signc}" stroke="{INK}" stroke-width="2"/>')
    txt = "MATERIA ES" if stage == 0 else ("MATERIALES" if stage < 3 else ("MATERIALES DEL ABUELO" if stage < 8 else "EL IMPERIO"))
    fs = min(20, sw * 1.45 / len(txt))
    S.append(f'<text x="{x+w/2}" y="{sy+21}" font-family="Oswald" font-weight="700" font-size="{fs}" fill="{"#d8c8a0" if old else "#f2b533"}" text-anchor="middle" letter-spacing="1.5" opacity="{0.75 if stage == 0 else 1}">{txt}</text>')
    if stage >= 8:
        S.append(f'<text x="{x+w/2}" y="{sy-4}" font-family="Oswald" font-weight="700" font-size="8" fill="{INK}" text-anchor="middle" letter-spacing="2">CASA DE MATERIALES</text>')
    # entrada
    ex = x + 18; ew = w * 0.5; ey = sy + 40
    if stage == 0:
        S.append(f'<rect x="{ex}" y="{ey}" width="{ew}" height="{SIDE_Y-ey}" fill="#8a8494" stroke="#5a5468" stroke-width="1.6"/>' + "".join(f'<path d="M{ex},{yy} l{ew},0" stroke="#6b6578" stroke-width="1.2"/>' for yy in range(int(ey + 6), SIDE_Y, 6)))
    else:
        S.append(f'<rect x="{ex}" y="{ey}" width="{ew}" height="{SIDE_Y-ey}" fill="#ffe2a0" stroke="#7a5232" stroke-width="2"/>')
        # anaqueles adentro
        for j in range(3):
            S.append(f'<path d="M{ex+6},{ey+14+j*16} l{ew-12},0" stroke="#7a5232" stroke-width="2.4"/>')
            for k in range(int((ew - 16) / 12)):
                c = ["#c0432e", "#3f6aa8", "#e8e0d0", "#2f8a5b"][(j + k) % 4]
                S.append(f'<rect x="{ex+8+k*12}" y="{ey+5+j*16}" width="9" height="9" fill="{c}" stroke="{INK}" stroke-width="0.7"/>')
        if stage >= 2:   # toldo
            n = int(ew / 14)
            S.append(f'<path d="M{ex-4},{ey-2} l{ew+8},0 l0,9 l-{ew+8},0z" fill="#c0432e"/>')
            for k in range(n): S.append(f'<path d="M{ex-4+k*14+7},{ey-2} l0,9" stroke="#f4ecd8" stroke-width="5"/>')
    # ventana
    wx = ex + ew + 10
    S.append(f'<rect x="{wx}" y="{ey+4}" width="{x+w-wx-14}" height="44" fill="{"#7f9cab" if stage == 0 else "#a6dcf8"}" stroke="#7a5232" stroke-width="3"/>')
    if stage >= 4:
        S.append(f'<text x="{(wx+x+w-14)/2}" y="{ey+30}" font-family="Caveat" font-weight="700" font-size="12" fill="#c0432e" text-anchor="middle">¡Ofertas!</text>')
    if stage >= 1:   # costales afuera
        for k in range(3 if stage >= 3 else 1):
            S.append(f'<rect x="{wx+k*16}" y="{SIDE_Y-14}" width="15" height="14" rx="3" fill="#e8e0d0" stroke="{INK}" stroke-width="1"/>')
    return "".join(S)

def bodega(x, w):
    S = [f'<rect x="{x}" y="{SIDE_Y-120}" width="{w}" height="120" fill="#c8a878" stroke="#5a3a22" stroke-width="2"/>']
    S.append(f'<path d="M{x-4},{SIDE_Y-120} l{w/2+4},-22 l{w/2+4},22z" fill="#8a6a4a" stroke="#5a3a22" stroke-width="1.8"/>')
    S.append(f'<rect x="{x+12}" y="{SIDE_Y-84}" width="{w-24}" height="84" fill="#8a8494" stroke="#5a5468" stroke-width="1.6"/>')
    for yy in range(SIDE_Y - 80, SIDE_Y, 6): S.append(f'<path d="M{x+12},{yy} l{w-24},0" stroke="#6b6578" stroke-width="1.1"/>')
    S.append(f'<rect x="{x+10}" y="{SIDE_Y-108}" width="{w-20}" height="16" fill="#fff6dc" stroke="{INK}" stroke-width="1.2"/><text x="{x+w/2}" y="{SIDE_Y-96}" font-family="Oswald" font-weight="700" font-size="10" fill="#2f4f8f" text-anchor="middle">BODEGA</text>')
    return "".join(S)

def yard_fence(x, w):
    S = [f'<rect x="{x}" y="{SIDE_Y-70}" width="{w}" height="70" fill="#b0a890" opacity="0.5"/>']
    for k in range(int(w / 10) + 1):
        S.append(f'<path d="M{x+k*10},{SIDE_Y} l0,-60" stroke="#6a6670" stroke-width="1.6"/>')
    S.append(f'<path d="M{x},{SIDE_Y-60} l{w},0 M{x},{SIDE_Y-30} l{w},0" stroke="#6a6670" stroke-width="2"/>')
    for k in range(int(w / 6)):
        S.append(f'<path d="M{x+k*6},{SIDE_Y-60} l6,-5" stroke="#8a8494" stroke-width="1"/>')
    S.append(f'<rect x="{x+w/2-30}" y="{SIDE_Y-58}" width="60" height="14" fill="#f2b632" stroke="{INK}" stroke-width="1.2"/><text x="{x+w/2}" y="{SIDE_Y-47.5}" font-family="Oswald" font-weight="700" font-size="9" fill="{INK}" text-anchor="middle">PATIO DE CARGA</text>')
    # montones de arena y grava
    S.append(f'<path d="M{x+8},{SIDE_Y} q22,-34 44,0z" fill="#e2c48a" stroke="#9a7a4a" stroke-width="1.2"/><path d="M{x+46},{SIDE_Y} q20,-28 40,0z" fill="#a8a29a" stroke="#6a6670" stroke-width="1.2"/>')
    return "".join(S)

def ext_shop(stage):
    d, S0 = sky()
    S = [S0, clouds(W, stage + 10, 3)]
    r = random.Random(5)
    # vecinos
    S.append(little_house(-20, 60, 100, "#a8c4e8", r))
    if stage < 6: S.append(little_house(300, 80, 110, "#f0b07a", r, kind="changarro"))
    if stage >= 7:
        S.append(shop_building(20, 170, stage)); S.append(bodega(196, 76)); S.append(yard_fence(278, 82))
    elif stage >= 6:
        S.append(shop_building(40, 180, stage)); S.append(bodega(226, 76))
    else:
        S.append(shop_building(70, 200 if stage >= 4 else 190, stage))
    S.append(poste(28))
    S.append(ground(W))
    d += '<radialGradient id="glow"><stop offset="0" stop-color="#fff6c8" stop-opacity="0.75"/><stop offset="1" stop-color="#fff6c8" stop-opacity="0"/></radialGradient>'
    render(f"ext_shop_{stage}", W, H, "\n".join(S), d)

def ext_house(stage):
    d, S0 = sky()
    S = [S0, clouds(W, stage + 20, 3)]
    r = random.Random(8)
    S.append(little_house(-10, 80, 96, "#d8b0e0", r))
    S.append(little_house(290, 80, 104, "#c8e08a", r))
    x, w = 84, 196
    body = ["#b8ad98", "#c8bca4", "#e8c8a0", "#f2a6a0", "#9fd0b4", "#f4e0a0"][stage]
    h = 100 if stage < 4 else 130
    top = SIDE_Y - h
    S.append(f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{body}" stroke="#5a3a22" stroke-width="2"/>')
    if stage <= 1:
        S.append(f'<path d="M{x+20},{top+20} l10,16 l-6,10 M{x+150},{top+60} l-8,12" stroke="#8a7a62" stroke-width="1.2" fill="none"/>')
        for i in range(4): S.append(f'<path d="M{x+10+i*6},{top} l0,-14" stroke="#7a4a32" stroke-width="1.4"/>')
    if stage >= 4:   # segundo piso
        S.append(f'<rect x="{x+20}" y="{top+12}" width="40" height="28" fill="#cfe6f2" stroke="#5a3a22" stroke-width="1.6"/><rect x="{x+w-60}" y="{top+12}" width="40" height="28" fill="#cfe6f2" stroke="#5a3a22" stroke-width="1.6"/>')
        S.append(f'<path d="M{x-6},{top+48} l{w+12},0" stroke="#7a5232" stroke-width="4"/>')
    if stage >= 5:   # techo de teja y macetas
        S.append(f'<path d="M{x-10},{top} l{w/2+10},-30 l{w/2+10},30z" fill="#c0614a" stroke="#7e2e20" stroke-width="2"/>')
        for k in range(5): S.append(f'<circle cx="{x+30+k*36}" cy="{SIDE_Y-8}" r="7" fill="#4f9a4a" stroke="#2f6a32" stroke-width="1"/><rect x="{x+25+k*36}" y="{SIDE_Y-6}" width="10" height="6" fill="#c0614a"/>')
    else:
        S.append(f'<rect x="{x+w-46}" y="{top-22}" width="22" height="20" rx="3" fill="#2f2f36" stroke="#1a1a1e" stroke-width="1.2"/>')
    # puerta y ventana
    door = "#7a4a32" if stage < 3 else "#3f6aa8"
    S.append(f'<rect x="{x+30}" y="{SIDE_Y-50}" width="30" height="50" fill="{door}" stroke="{INK}" stroke-width="1.6"/><circle cx="{x+54}" cy="{SIDE_Y-25}" r="2" fill="#f2c14e"/>')
    wcol = "#7f9cab" if stage == 0 else "#cfe6f2"
    S.append(f'<rect x="{x+90}" y="{SIDE_Y-60}" width="56" height="36" fill="{wcol}" stroke="#5a3a22" stroke-width="1.6"/>')
    for i in range(1, 7): S.append(f'<path d="M{x+90+i*8},{SIDE_Y-60} l0,36" stroke="{INK}" stroke-width="0.9"/>')
    if stage == 0: S.append(f'<path d="M{x+92},{SIDE_Y-58} l20,20" stroke="{INK}" stroke-width="1"/>')
    if stage >= 2: S.append(f'<rect x="{x+86}" y="{SIDE_Y-22}" width="64" height="6" fill="#7a5232"/>')
    if stage >= 3:   # cochera
        S.append(f'<rect x="{x+160}" y="{SIDE_Y-46}" width="32" height="46" fill="#8a8494" stroke="#5a5468" stroke-width="1.4"/>')
    S.append(tree(46, 0.9))
    S.append(ground(W))
    render(f"ext_house_{stage}", W, H, "\n".join(S), d)

def intro_street_rain():
    """Noche de lluvia en la colonia (sin gotas: se animan en el juego)."""
    d, S0 = sky(night=True, w=W)
    S = [S0]
    r = random.Random(77)
    cols = ["#e8a0a0", "#f2d07a", "#9fd0b4", "#a8c4e8", "#f0b07a"]
    x = -10; i = 0
    while x < W:
        bw = r.choice([70, 90, 110])
        S.append(little_house(x, bw, r.uniform(80, 130), cols[i % 5], r, True, "changarro" if i == 2 else "casa"))
        x += bw; i += 1
    S.append(poste(250, True))
    S.append(ground(W, True))
    # charcos con reflejo
    for (cx, wd) in [(80, 46), (220, 60), (320, 30)]:
        S.append(f'<ellipse cx="{cx}" cy="{ROAD_Y+30}" rx="{wd}" ry="5" fill="#6a7a9a" opacity="0.55"/><ellipse cx="{cx+6}" cy="{ROAD_Y+29}" rx="{wd*0.4}" ry="1.5" fill="#ffd98a" opacity="0.5"/>')
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#1a2040" opacity="0.28"/>')
    d += '<radialGradient id="glow"><stop offset="0" stop-color="#fff6c8" stop-opacity="0.75"/><stop offset="1" stop-color="#fff6c8" stop-opacity="0"/></radialGradient>'
    render("intro_street", W, H, "\n".join(S), d)

def intro_office2():
    """Oficina con cubiculos, luz fria y el jefe al fondo (los personajes se dibujan en el juego)."""
    S = [f'<rect x="0" y="0" width="{W}" height="212" fill="#d6d9d4"/>']
    for x in range(0, W, 40): S.append(f'<rect x="{x+8}" y="6" width="24" height="6" fill="#f4f8f0" stroke="#b8bcb4" stroke-width="1"/>')
    S.append(f'<rect x="20" y="40" width="100" height="70" fill="#9fd4f2" stroke="#8a8f96" stroke-width="3"/><path d="M70,40 l0,70 M20,75 l100,0" stroke="#8a8f96" stroke-width="2"/>')
    S.append(f'<rect x="20" y="60" width="100" height="50" fill="#7a8fa8" opacity="0.35"/>')   # edificios afuera
    S.append('<rect x="150" y="50" width="70" height="44" rx="2" fill="#ffffff" stroke="#8a8494" stroke-width="1.4"/><path d="M158,64 l14,10 l12,-6 l12,14 l14,6" stroke="#c0432e" stroke-width="2.4" fill="none"/><text x="185" y="60" font-family="Oswald" font-size="8" fill="#c0432e" text-anchor="middle">VENTAS</text>')
    S.append('<rect x="250" y="40" width="90" height="120" fill="#b8a888" stroke="#7a6a52" stroke-width="2"/><rect x="256" y="46" width="78" height="20" fill="#e8e0d0"/><text x="295" y="60" font-family="Oswald" font-size="9" fill="#3a2618" text-anchor="middle">GERENCIA</text><circle cx="326" cy="110" r="3" fill="#f2c14e"/>')
    S.append(f'<path d="M0,212 l{W},0 l0,60 l-{W},0z" fill="#8a96a8"/>')
    for x in range(0, W, 30): S.append(f'<path d="M{x},212 l-12,60" stroke="#7a8698" stroke-width="1"/>')
    # cubiculos
    for cx in (10, 130):
        S.append(f'<rect x="{cx}" y="150" width="100" height="56" fill="#9aa4b4" stroke="#6a7484" stroke-width="2"/><rect x="{cx+30}" y="122" width="40" height="28" rx="2" fill="#3d3548" stroke="#24202c" stroke-width="1.4"/><rect x="{cx+33}" y="125" width="34" height="20" fill="#7fe0c4"/>')
    S.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#vignette)"/>')
    render("intro_office", W, H, "\n".join(S))

if __name__ == "__main__":
    street_tile(False); street_tile(True)
    for s in range(9): ext_shop(s)
    for s in range(6): ext_house(s)
    intro_street_rain(); intro_office2()
    print("ok street")
