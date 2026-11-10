extends Node
## Arte: carga texturas de assets/art y dibuja personajes por capas.
## Estilo: proporciones normales (no chibi), 22x42 px, contorno del color de cada parte.

const CW := 22         # ancho del lienzo del personaje
const CH := 42         # alto del lienzo del personaje
const FEET := 40       # fila donde apoyan los pies (para colocarlos sobre el piso)

var _tex_cache := {}
var _char_cache := {}

func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var t: Texture2D = null
	for folder in ["vec", "art"]:
		var path := "res://assets/%s/%s.png" % [folder, name]
		if ResourceLoader.exists(path):
			t = load(path)
			break
	_tex_cache[name] = t
	return t

const FACE_ORDER := ["normal", "feliz", "serio", "pecas", "bigote"]
const HAIR_ORDER := ["corto", "puntas", "rapado", "de_lado", "largo", "melena", "rizado", "chongo", "coleta"]
const ACC_ORDER := ["ninguno", "gorra", "casco", "sombrero", "paliacate", "lentes", "lentes_oscuros"]
const TOPS := ["mandil", "playera", "camisa", "sudadera", "overol", "chaleco", "overol_dorado"]
const BODY_ORDER := ["normal", "round", "broad", "thin"]

const SKINS := ["f6d0b1", "e8b48a", "c98f62", "a46b45", "7a4c30"]
const HAIR_COLORS := ["2b2226", "5a3622", "8c5a32", "d9a957", "b5532e", "b9b4b0", "3f63a8"]
const CLOTH_COLORS := ["3f8f8a", "d0533f", "2f4f8f", "e8b23a", "6fc2a8", "f2ede2", "3a3540", "a8475a", "5aa847", "e07a2e", "8f86c0", "7a5232"]
const PANTS_COLORS := ["2f4a7a", "34303a", "7a5232", "6b6670", "c4b28c", "1f3060"]
const SHOE_COLORS := ["2a2226", "6e4126", "efe9dc", "c84a3a"]

func default_look(gender: String) -> Dictionary:
	return {
		"gender": gender, "body": "normal", "skin": 1, "face": "normal",
		"hair": "corto" if gender == "m" else "largo", "hair_color": 1,
		"acc": "ninguno", "top": "mandil", "top_color": 0,
		"pants": "pantalon", "pants_color": 0, "shoes": 0,
	}

# ---------------------------------------------------------------- dibujo
var _img: Image
const OX := 1
const OY := 1

func _lt(c: Color, f := 0.25) -> Color: return c.lerp(Color.WHITE, f)
func _dk(c: Color, f := 0.25) -> Color: return c.lerp(Color("2a1a22"), f)

func _p(x: int, y: int, c: Color) -> void:
	var xx := x + OX; var yy := y + OY
	if xx >= 0 and yy >= 0 and xx < CW and yy < CH:
		_img.set_pixel(xx, yy, c)

func _r(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_p(x + i, y + j, c)

func _clear(x: int, y: int) -> void:
	var xx := x + OX; var yy := y + OY
	if xx >= 0 and yy >= 0 and xx < CW and yy < CH:
		_img.set_pixel(xx, yy, Color(0, 0, 0, 0))

func _idx(arr: Array, i) -> Color:
	return Color(arr[clampi(int(i), 0, arr.size() - 1)])

func character(look: Dictionary, frame := "idle") -> ImageTexture:
	var key := JSON.stringify(look) + "|" + frame
	if _char_cache.has(key):
		return _char_cache[key]
	_img = Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_draw_person(look, frame)
	_outline()
	var t := ImageTexture.create_from_image(_img)
	_char_cache[key] = t
	if _char_cache.size() > 800:
		_char_cache.clear()
	return t

func _draw_person(look: Dictionary, frame: String) -> void:
	var fem: bool = look.get("gender", "m") == "f"
	var skin := _idx(SKINS, look.get("skin", 1))
	var hair := _idx(HAIR_COLORS, look.get("hair_color", 1))
	var top := _idx(CLOTH_COLORS, look.get("top_color", 0))
	var pants := _idx(PANTS_COLORS, look.get("pants_color", 0))
	var shoe := _idx(SHOE_COLORS, look.get("shoes", 0))
	var top_style: String = look.get("top", "playera")
	var bottom: String = look.get("pants", "pantalon")
	var hair_style: String = look.get("hair", "corto")
	if top_style == "overol":
		pants = Color("2f5fa0")
	elif top_style == "overol_dorado":
		pants = Color("e8b23a"); top = Color("fff1b8")
	var walk_a := frame == "walk_a"
	var walk_b := frame == "walk_b"
	var happy := frame == "happy"

	# --- cabello de atras (largo)
	if hair_style == "largo":
		_r(4, 6, 12, 18, _dk(hair, 0.15)); _r(5, 24, 10, 1, _dk(hair, 0.15))
	elif hair_style == "melena":
		_r(4, 6, 12, 9, _dk(hair, 0.15))
	elif hair_style == "coleta":
		_r(15, 4, 3, 3, hair); _r(16, 7, 2, 8, _dk(hair, 0.1)); _p(16, 15, _dk(hair, 0.1))

	# --- piernas y zapatos
	var leg_col := pants
	var shin := pants if bottom == "pantalon" else skin
	var shin_from := 29 if bottom == "pantalon" else (31 if bottom == "short" else 32)
	_r(5, 26, 10, 3, pants)                      # cadera
	var lx := 5; var rx := 11; var l_up := 0; var r_up := 0
	if walk_a: lx = 4; rx = 12; l_up = 1
	elif walk_b: lx = 5; rx = 11; r_up = 1
	for y in range(29, 36):
		var lc: Color = leg_col if y < shin_from else shin
		_r(lx, y - l_up, 4, 1, lc)
		_r(rx, y - r_up, 4, 1, lc)
		_p(lx + 3, y - l_up, _dk(lc, 0.18)); _p(rx + 3, y - r_up, _dk(lc, 0.18))
	# zapatos
	_r(lx - 1, 36 - l_up, 5, 2, shoe); _r(lx - 1, 38 - l_up, 5, 1, _dk(shoe, 0.35)); _p(lx, 36 - l_up, _lt(shoe, 0.3))
	_r(rx, 36 - r_up, 5, 2, shoe); _r(rx, 38 - r_up, 5, 1, _dk(shoe, 0.35)); _p(rx + 1, 36 - r_up, _lt(shoe, 0.3))
	if bottom == "falda":
		for i in 6:
			var y := 24 + i
			var w := 10 + (i / 2) * 2
			_r(10 - w / 2, y, w, 1, pants if i < 5 else _dk(pants, 0.2))
		_p(6, 25, _lt(pants, 0.2))

	# --- torso
	var sh_l := 4 if not fem else 5
	var sh_w := 12 if not fem else 10
	_r(sh_l, 14, sh_w, 1, top)
	for y in range(15, 26):
		var x0 := 5; var w := 10
		if fem and y >= 20 and y <= 23: x0 = 6; w = 8
		_r(x0, y, w, 1, top)
		_p(x0, y, _lt(top, 0.18))
		_p(x0 + w - 1, y, _dk(top, 0.2)); _p(x0 + w - 2, y, _dk(top, 0.08))
	_r(5, 25, 10, 1, _dk(top, 0.15))
	if bottom != "falda":
		_r(5, 26, 10, 1, _dk(pants, 0.3))          # cinturon
		_p(9, 26, Color("c9a24a")); _p(10, 26, Color("c9a24a"))
	# brazos
	var long_sleeve := top_style in ["camisa", "sudadera"]
	var sleeve := top
	var arm_l_y := 15; var arm_r_y := 15
	if walk_a: arm_l_y = 16; arm_r_y = 14
	elif walk_b: arm_l_y = 14; arm_r_y = 16
	if happy:
		for y in range(8, 15):
			var c: Color = skin if y < 11 else sleeve
			if long_sleeve: c = sleeve if y >= 9 else skin
			_r(2, y, 2, 1, c); _r(16, y, 2, 1, c)
		_r(2, 7, 2, 2, skin); _r(16, 7, 2, 2, skin)
		_r(3, 14, 2, 1, sleeve); _r(15, 14, 2, 1, sleeve)
	else:
		for side in [[3, arm_l_y], [15, arm_r_y]]:
			var ax: int = side[0]; var ay: int = side[1]
			for y in range(ay, ay + 10):
				var c: Color = sleeve if (long_sleeve or y < ay + 4) else skin
				if long_sleeve and y == ay + 9: c = _lt(sleeve, 0.25)
				_r(ax, y, 2, 1, c)
				_p(ax + (1 if ax > 10 else 0), y, _dk(c, 0.12))
			_r(ax, ay + 10, 2, 2, skin)
			_p(ax + (1 if ax > 10 else 0), ay + 11, _dk(skin, 0.15))
	# detalles de la ropa
	match top_style:
		"camisa":
			_p(8, 14, Color("f6f1e6")); _p(11, 14, Color("f6f1e6")); _p(9, 15, Color("f6f1e6")); _p(10, 15, Color("f6f1e6"))
			for y in [17, 20, 23]: _p(10, y, _lt(top, 0.45))
			_r(6, 17, 2, 2, _dk(top, 0.15))
		"sudadera":
			_r(6, 13, 8, 1, _dk(top, 0.2))
			_p(8, 15, Color("f2ede2")); _p(8, 16, Color("f2ede2")); _p(11, 15, Color("f2ede2")); _p(11, 16, Color("f2ede2"))
			_r(7, 21, 6, 3, _dk(top, 0.12)); _r(7, 21, 6, 1, _dk(top, 0.25))
		"overol", "overol_dorado":
			_r(6, 18, 8, 8, pants); _r(6, 18, 8, 1, _lt(pants, 0.2))
			_r(6, 14, 1, 4, pants); _r(13, 14, 1, 4, pants)
			_p(6, 18, Color("e0c060")); _p(13, 18, Color("e0c060"))
			_r(8, 20, 4, 2, _dk(pants, 0.15))
		"chaleco":
			var v := Color("e8782a")
			_r(5, 14, 3, 12, v); _r(12, 14, 3, 12, v)
			_r(5, 20, 3, 1, Color("e8e4dc")); _r(12, 20, 3, 1, Color("e8e4dc"))
			_r(5, 23, 3, 1, Color("e8e4dc")); _r(12, 23, 3, 1, Color("e8e4dc"))
		"playera":
			_r(8, 14, 4, 1, _dk(top, 0.25))

	# --- cuello y cabeza
	_r(8, 12, 4, 2, _dk(skin, 0.12))
	_r(6, 3, 8, 1, skin)
	_r(5, 4, 10, 8, skin)
	_r(6, 12, 8, 1, skin)
	for y in range(4, 12): _p(14, y, _dk(skin, 0.1))
	_r(6, 12, 8, 1, _dk(skin, 0.06))
	_p(4, 7, _dk(skin, 0.1)); _p(4, 8, _dk(skin, 0.1)); _p(15, 7, _dk(skin, 0.15)); _p(15, 8, _dk(skin, 0.15))
	_p(6, 4, _lt(skin, 0.2))
	# cara
	var eye := Color("2a1f26")
	var brow := _dk(hair, 0.25)
	var mouth := skin.lerp(Color("a8404a"), 0.55) if not fem else skin.lerp(Color("c8405a"), 0.6)
	var face: String = look.get("face", "normal")
	match face:
		"feliz":
			_p(7, 7, eye); _p(6, 8, eye); _p(8, 8, eye)
			_p(12, 7, eye); _p(11, 8, eye); _p(13, 8, eye)
			_r(6, 6, 2, 1, brow); _r(12, 6, 2, 1, brow)
			_p(7, 10, mouth); _p(12, 10, mouth); _r(8, 11, 4, 1, mouth)
			_p(6, 10, skin.lerp(Color("f08080"), 0.45)); _p(13, 10, skin.lerp(Color("f08080"), 0.45))
		"serio":
			_r(6, 6, 3, 1, brow); _r(11, 6, 3, 1, brow)
			_p(7, 7, eye); _p(7, 8, eye); _p(12, 7, eye); _p(12, 8, eye)
			_r(9, 11, 2, 1, mouth)
		_:
			_r(6, 6, 2, 1, brow); _r(12, 6, 2, 1, brow)
			_p(7, 7, eye); _p(7, 8, eye); _p(12, 7, eye); _p(12, 8, eye)
			_p(8, 7, Color("f6f1e6")); _p(13, 7, Color("f6f1e6"))
			_r(8, 11, 4, 1, mouth)
	if fem:
		_p(6, 7, eye); _p(13, 7, eye)
		if face != "feliz":
			_p(6, 10, skin.lerp(Color("f08080"), 0.35)); _p(13, 10, skin.lerp(Color("f08080"), 0.35))
	_p(10, 9, _dk(skin, 0.18))
	if face == "pecas":
		for q in [[6, 9], [8, 9], [11, 9], [13, 9]]: _p(q[0], q[1], _dk(skin, 0.28))
	if face == "bigote":
		_r(7, 10, 6, 1, _dk(hair, 0.1)); _p(7, 11, _dk(hair, 0.1)); _p(12, 11, _dk(hair, 0.1))
		_r(9, 11, 2, 1, mouth)

	# --- cabello de enfrente
	var h := hair; var hl := _lt(hair, 0.22); var hd := _dk(hair, 0.22)
	match hair_style:
		"corto", "puntas", "de_lado", "coleta":
			_r(6, 1, 8, 1, h); _r(5, 2, 10, 1, h); _r(4, 3, 12, 2, h)
			_r(4, 5, 3, 1, h); _r(13, 5, 3, 1, h)
			_r(4, 6, 2, 2, hd); _r(14, 6, 2, 2, hd)
			_r(7, 2, 3, 1, hl); _r(8, 5, 2, 1, h)
			if hair_style == "puntas":
				_p(6, 0, h); _p(9, 0, h); _p(12, 0, h); _p(5, 1, h); _p(14, 1, h); _r(10, 5, 2, 1, h)
			if hair_style == "de_lado":
				_r(5, 5, 5, 1, h); _r(5, 6, 2, 1, h); _p(10, 4, hl)
		"rapado":
			_r(6, 2, 8, 1, hd); _r(5, 3, 10, 2, hd)
			_p(7, 3, h); _p(10, 3, h); _p(12, 4, h); _p(8, 4, h)
			_p(5, 5, hd); _p(14, 5, hd)
		"largo", "melena":
			_r(6, 1, 8, 1, h); _r(5, 2, 10, 1, h); _r(4, 3, 12, 2, h)
			_r(6, 5, 3, 1, h); _r(11, 5, 3, 1, h)
			var bottom_y := 23 if hair_style == "largo" else 14
			_r(3, 5, 3, bottom_y - 5, h); _r(14, 5, 3, bottom_y - 5, h)
			_r(3, 5, 1, bottom_y - 5, hl); _r(16, 5, 1, bottom_y - 5, hd)
			_r(7, 2, 3, 1, hl); _p(5, 3, hl)
		"rizado":
			_r(6, 0, 8, 1, h); _r(4, 1, 12, 1, h); _r(3, 2, 14, 4, h)
			_r(3, 6, 3, 4, h); _r(14, 6, 3, 4, h)
			for y in range(0, 10):
				for x in range(3, 17):
					if (x + y) % 3 == 0 and _img.get_pixel(x + OX, y + OY) == h: _p(x, y, hl)
					elif (x * 2 + y) % 5 == 0 and _img.get_pixel(x + OX, y + OY) == h: _p(x, y, hd)
		"chongo":
			_r(8, 0, 4, 2, h); _p(9, 0, hl)
			_r(5, 2, 10, 1, h); _r(4, 3, 12, 2, h); _r(4, 5, 2, 3, hd); _r(14, 5, 2, 3, hd)
			_r(7, 3, 3, 1, hl)

	# --- accesorios
	match String(look.get("acc", "ninguno")):
		"gorra":
			var c: Color = Color("c8423a")
			_r(5, 0, 10, 1, c); _r(4, 1, 12, 3, c); _r(6, 1, 3, 1, _lt(c, 0.3))
			_r(4, 4, 13, 1, _dk(c, 0.3)); _r(15, 4, 3, 1, _dk(c, 0.3))
			_p(9, 0, Color("f2ede2"))
		"casco":
			var c: Color = Color("f0b62e")
			_r(6, 0, 8, 1, c); _r(5, 1, 10, 3, c); _r(7, 1, 2, 2, _lt(c, 0.45)); _r(9, 0, 2, 4, _dk(c, 0.1))
			_r(3, 4, 14, 1, _dk(c, 0.18))
		"sombrero":
			var c: Color = Color("e3c47e")
			_r(6, 0, 8, 3, c); _r(6, 2, 8, 1, Color("b5463a")); _r(7, 0, 2, 2, _lt(c, 0.3))
			_r(0, 3, 20, 1, c); _r(1, 4, 18, 1, _dk(c, 0.22))
		"paliacate":
			var c: Color = Color("c0302a")
			_r(4, 2, 12, 3, c); _p(6, 3, Color("f2ede2")); _p(10, 2, Color("f2ede2")); _p(13, 3, Color("f2ede2"))
			_r(16, 3, 2, 2, c); _p(17, 5, c)
		"lentes":
			var c: Color = Color("2a1f26")
			_r(6, 7, 3, 1, c); _r(11, 7, 3, 1, c); _r(9, 7, 2, 1, c)
			_p(6, 8, c); _p(8, 8, c); _p(11, 8, c); _p(13, 8, c)
		"lentes_oscuros":
			var c: Color = Color("1f1a22")
			_r(6, 7, 3, 2, c); _r(11, 7, 3, 2, c); _r(9, 7, 2, 1, c); _p(7, 7, Color("6a6a7a")); _p(12, 7, Color("6a6a7a"))

func _outline() -> void:
	## contorno de color: cada hueco junto a un pixel se pinta con una version oscura de ese pixel
	var src := _img.duplicate()
	for y in CH:
		for x in CW:
			if src.get_pixel(x, y).a > 0.0: continue
			var n := Color(0, 0, 0, 0)
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= CW or q.y >= CH: continue
				var c: Color = src.get_pixel(q.x, q.y)
				if c.a > 0.0:
					n = c; break
			if n.a > 0.0:
				_img.set_pixel(x, y, n.lerp(Color("24161c"), 0.62))

# ---------------------------------------------------------------- variaciones
func random_look(rng: RandomNumberGenerator, gender := "") -> Dictionary:
	var g := gender if gender != "" else ("m" if rng.randf() < 0.55 else "f")
	var hairs_m := ["corto", "puntas", "rapado", "de_lado", "rizado"]
	var hairs_f := ["largo", "melena", "rizado", "chongo", "coleta"]
	var look := default_look(g)
	look["skin"] = rng.randi_range(0, SKINS.size() - 1)
	look["body"] = ["normal", "normal", "round", "broad", "thin"][rng.randi_range(0, 4)]
	look["hair"] = (hairs_m if g == "m" else hairs_f)[rng.randi_range(0, 4)]
	look["hair_color"] = rng.randi_range(0, 5)
	look["face"] = ["normal", "feliz", "serio", "pecas", "bigote" if g == "m" else "feliz"][rng.randi_range(0, 4)]
	look["top"] = ["playera", "camisa", "sudadera", "playera", "overol"][rng.randi_range(0, 4)]
	look["top_color"] = rng.randi_range(0, CLOTH_COLORS.size() - 1)
	look["pants"] = ["pantalon", "pantalon", "short", "falda" if g == "f" else "pantalon"][rng.randi_range(0, 3)]
	look["pants_color"] = rng.randi_range(0, PANTS_COLORS.size() - 1)
	look["shoes"] = rng.randi_range(0, SHOE_COLORS.size() - 1)
	var r := rng.randf()
	look["acc"] = "ninguno" if r < 0.55 else ["gorra", "sombrero", "paliacate", "lentes", "lentes_oscuros"][rng.randi_range(0, 4)]
	return look

func grandpa_look() -> Dictionary:
	return {"gender": "m", "body": "thin", "skin": 2, "face": "bigote", "hair": "rapado", "hair_color": 5, "acc": "sombrero",
		"top": "camisa", "top_color": 5, "pants": "pantalon", "pants_color": 2, "shoes": 1}

func sprite(name: String, pos := Vector2.ZERO) -> Sprite2D:
	## Sprite de arte vectorial (exportado a 3x) en coordenadas del escenario
	var sp := Sprite2D.new()
	sp.texture = tex(name)
	sp.centered = false
	sp.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	sp.position = pos
	return sp

func person(look: Dictionary) -> Node2D:
	var P = load("res://scripts/core/person.gd")
	var p = P.new()
	p.setup(look)
	return p
