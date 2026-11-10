extends Node2D
## Personaje vectorial estilo "caricatura mexicana": linea gruesa cafe, ojos chicos,
## narices y bigotes exagerados. Se arma por piezas para animarlo:
## piernas, cuerpo, brazos y cabeza (con cara que parpadea y cambia de expresion).
## Origen = punto entre los pies. Altura ~190 unidades (complexion normal).

const Vec = preload("res://scripts/core/vec.gd")
const ArtS = preload("res://scripts/core/art.gd")
const LINE := Color("3a2618")
const LW := 2.6

var look: Dictionary = {}
var walking := false
var pushing := false          # brazos al frente agarrando la carretilla
var shoveling := false        # palea (minero)
var _has_shovel := false
var mood := "idle"            # idle / happy / think / sad / sleep
var _mood_timer := 0.0
var _t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _seed := 0.0

var n_hair_back: Part
var n_leg_l: Part
var n_leg_r: Part
var n_body: Part
var n_arm_l: Part
var n_arm_r: Part
var n_head: Part
var n_face: Part
var B: Dictionary     # medidas de la complexion

# =============================================================== complexiones
const BODIES := {
	"normal": {
		"hip": -56.0, "knee": -30.0,
		"leg_l": "M-15,-56 l13,0 l-1,52 l-12,0z", "leg_r": "M2,-56 l13,0 l1,52 l-12,0z",
		"thigh_l": "M-15,-56 l13,0 l-0.5,26 l-12.5,0z", "thigh_r": "M2,-56 l13,0 l0.5,26 l-12.5,0z",
		"shoe_l": "M-17,-4 q0,-7 8,-7 l7,0 l1,9 l-16,0z", "shoe_r": "M2,-11 l7,0 q9,0 9,9 l-16,0z",
		"torso": "M-26,-106 q0,-12 14,-14 l24,0 q14,2 14,14 l2,52 l-56,0z",
		"torso_f": "M-23,-106 q0,-12 13,-14 l20,0 q13,2 13,14 l-4,24 l5,28 l-50,0 l5,-28z",
		"shade": "M8,-118 q14,2 14,14 l2,50 l-14,0z",
		"belt": "M-27,-58 l56,0 l0,5 l-56,0z",
		"skirt": "M-22,-62 l46,0 l9,34 l-64,0z",
		"box": [-26.0, 28.0, -120.0, -54.0],
		"sh_l": Vector2(-22, -108), "sh_r": Vector2(23, -108),
		"arm": "M-2,4 q-14,14 -12,46 l10,0 q-2,-24 8,-38z", "hand": Vector2(-9, 54), "hand_r": 6.0,
		"sleeve": "M-2,4 q-9,7 -10,19 l11,2 q1,-10 5,-15z",
		"neck": "M-7,-124 l0,8 q7,5 14,0 l0,-8z",
		"head": Vector2(0, -150), "hr": 27.0, "head_shape": "oval",
	},
	"round": {
		"hip": -30.0, "knee": -16.0,
		"leg_l": "M-12,-30 l9,0 l0,26 l-9,0z", "leg_r": "M3,-30 l9,0 l0,26 l-9,0z",
		"thigh_l": "M-12,-30 l9,0 l0,14 l-9,0z", "thigh_r": "M3,-30 l9,0 l0,14 l-9,0z",
		"shoe_l": "M-16,-2 q0,-7 8,-7 l6,0 l0,9z", "shoe_r": "M2,-9 l6,0 q8,0 8,7 l-14,0z",
		"torso": "M-24,-30 q-6,-40 10,-50 l28,0 q16,10 10,50 q-24,6 -48,0z",
		"torso_f": "M-24,-30 q-6,-40 10,-50 l28,0 q16,10 10,50 q-24,6 -48,0z",
		"shade": "M8,-78 q14,10 10,44 l-10,0z",
		"belt": "M-25,-34 q25,8 50,0 l2,7 q-27,8 -54,0z",
		"skirt": "M-25,-36 q25,8 50,0 l6,16 q-31,8 -62,0z",
		"box": [-26.0, 26.0, -80.0, -30.0],
		"sh_l": Vector2(-18, -74), "sh_r": Vector2(18, -74),
		"arm": "M-2,0 q-8,14 -6,30 l9,0 q-1,-14 4,-24z", "hand": Vector2(-4, 32), "hand_r": 5.5,
		"sleeve": "M-2,0 q-5,7 -6,13 l9,1 q0,-6 3,-10z",
		"neck": "M-6,-82 l0,6 q6,4 12,0 l0,-6z",
		"head": Vector2(0, -104), "hr": 22.0, "head_shape": "round",
	},
	"broad": {
		"hip": -46.0, "knee": -24.0,
		"leg_l": "M-18,-46 l14,0 l-1,40 l-13,0z", "leg_r": "M4,-46 l14,0 l1,40 l-13,0z",
		"thigh_l": "M-18,-46 l14,0 l-0.5,22 l-13.5,0z", "thigh_r": "M4,-46 l14,0 l0.5,22 l-13.5,0z",
		"shoe_l": "M-22,-2 q0,-10 8,-10 l10,0 l1,12z", "shoe_r": "M3,-12 l10,0 q9,0 9,10 l-19,0z",
		"torso": "M-34,-110 q-4,-14 14,-16 l40,0 q18,2 14,16 l-6,64 l-56,0z",
		"torso_f": "M-30,-110 q-4,-14 14,-16 l34,0 q18,2 14,16 l-6,64 l-50,0z",
		"shade": "M14,-124 q18,2 14,16 l-6,62 l-14,0z",
		"belt": "M-28,-50 l56,0 l1,6 l-58,0z",
		"skirt": "M-28,-52 l56,0 l10,30 l-76,0z",
		"box": [-34.0, 34.0, -126.0, -46.0],
		"sh_l": Vector2(-30, -114), "sh_r": Vector2(30, -114),
		"arm": "M-2,2 q-16,16 -14,52 l12,0 q-2,-30 10,-42z", "hand": Vector2(-10, 58), "hand_r": 7.0,
		"sleeve": "M-2,2 q-10,8 -12,20 l12,2 q1,-10 6,-16z",
		"neck": "M-9,-128 l0,6 q9,5 18,0 l0,-6z",
		"head": Vector2(0, -152), "hr": 25.0, "head_shape": "square",
	},
	"thin": {
		"hip": -60.0, "knee": -32.0,
		"leg_l": "M-12,-60 l10,0 l-1,56 l-9,0z", "leg_r": "M2,-60 l10,0 l2,56 l-9,0z",
		"thigh_l": "M-12,-60 l10,0 l-0.5,28 l-9.5,0z", "thigh_r": "M2,-60 l10,0 l1,28 l-9.5,0z",
		"shoe_l": "M-15,-3 q0,-6 7,-6 l6,0 l0,9z", "shoe_r": "M4,-9 l6,0 q8,0 8,9 l-14,0z",
		"torso": "M-20,-110 q2,-14 18,-12 l14,0 q12,4 12,18 l-2,46 l-42,0z",
		"torso_f": "M-18,-110 q2,-14 16,-12 l12,0 q12,4 12,18 l-4,22 l4,24 l-40,0 l4,-24z",
		"shade": "M10,-120 q12,4 12,18 l-2,44 l-10,0z",
		"belt": "M-20,-64 l42,0 l1,6 l-44,0z",
		"skirt": "M-20,-66 l42,0 l8,32 l-58,0z",
		"box": [-20.0, 24.0, -122.0, -64.0],
		"sh_l": Vector2(-17, -106), "sh_r": Vector2(20, -106),
		"arm": "M-1,2 q-10,14 -8,36 l9,0 q-1,-20 5,-30z", "hand": Vector2(-5, 40), "hand_r": 5.5,
		"sleeve": "M-1,2 q-6,7 -7,15 l9,1 q0,-8 4,-12z",
		"neck": "M-4,-124 l0,6 q6,4 12,0 l0,-6z",
		"head": Vector2(4, -142), "hr": 21.0, "head_shape": "long",
	},
}

# =============================================================== pieza dibujable
class Part extends Node2D:
	var shapes: Array = []   # {polys:Array[PackedVector2Array], fill:Color, line:Color, lw:float, stroke_only:bool}
	func add(polys: Array, fill: Color, line := LINE, lw := LW, stroke_only := false) -> void:
		var clean := []
		for p in polys:
			clean.append(p if stroke_only else Vec.safe_polygon(p))
		shapes.append({"polys": clean, "fill": fill, "line": line, "lw": lw, "stroke_only": stroke_only})
	func clear_shapes() -> void:
		shapes.clear()
		queue_redraw()
	func _draw() -> void:
		for s in shapes:
			for p in s["polys"]:
				var pts: PackedVector2Array = p
				if pts.size() < 2: continue
				if not s["stroke_only"] and s["fill"].a > 0.0 and pts.size() >= 3:
					draw_colored_polygon(pts, s["fill"])
				if s["lw"] > 0.0:
					var closed := pts.duplicate()
					if not s["stroke_only"]: closed.append(pts[0])
					draw_polyline(closed, s["line"], s["lw"], true)

# =============================================================== colores
func _c(key: String) -> Color:
	var A = ArtS
	match key:
		"skin": return Color(A.SKINS[clampi(int(look.get("skin", 1)), 0, A.SKINS.size() - 1)])
		"hair": return Color(A.HAIR_COLORS[clampi(int(look.get("hair_color", 1)), 0, A.HAIR_COLORS.size() - 1)])
		"top": return Color(A.CLOTH_COLORS[clampi(int(look.get("top_color", 0)), 0, A.CLOTH_COLORS.size() - 1)])
		"pants": return Color(A.PANTS_COLORS[clampi(int(look.get("pants_color", 0)), 0, A.PANTS_COLORS.size() - 1)])
		"shoes": return Color(A.SHOE_COLORS[clampi(int(look.get("shoes", 0)), 0, A.SHOE_COLORS.size() - 1)])
	return Color.WHITE

static func dk(c: Color, f := 0.2) -> Color: return c.lerp(Color("2a1810"), f)
static func lt(c: Color, f := 0.2) -> Color: return c.lerp(Color.WHITE, f)

# =============================================================== construccion
func setup(l: Dictionary) -> void:
	look = l.duplicate()
	_seed = float(hash(JSON.stringify(look)) % 1000) / 100.0
	_next_blink = 1.0 + fmod(_seed, 3.0)
	for c in get_children(): c.queue_free()
	var body_key: String = look.get("body", "normal")
	if not BODIES.has(body_key): body_key = "normal"
	B = BODIES[body_key]
	n_hair_back = _mk(); n_leg_l = _mk(); n_leg_r = _mk(); n_body = _mk()
	n_arm_l = _mk(); n_arm_r = _mk(); n_head = _mk()
	n_face = Part.new(); n_head.add_child(n_face)
	_build()

func _mk() -> Part:
	var p := Part.new()
	add_child(p)
	return p

func _build() -> void:
	var fem: bool = look.get("gender", "m") == "f"
	var skin := _c("skin"); var hair := _c("hair"); var top := _c("top")
	var pants := _c("pants"); var shoes := _c("shoes")
	var top_style: String = look.get("top", "playera")
	var bottom: String = look.get("pants", "pantalon")
	if top_style == "overol": pants = Color("2f5fa0")
	elif top_style == "overol_dorado": pants = Color("e8b23a"); top = Color("fff1b8")
	var long_sleeve := top_style in ["camisa", "sudadera"]
	var hip: float = B["hip"]
	var shadow := Color(0.23, 0.1, 0.03, 0.18)

	# --- piernas (pivote en la cadera)
	for side in ["l", "r"]:
		var leg: Part = n_leg_l if side == "l" else n_leg_r
		var pivot := Vector2(-7 if side == "l" else 7, hip)
		leg.position = pivot
		var off := -pivot
		if bottom == "pantalon":
			leg.add(Vec.path(B["leg_" + side], off), pants)
		else:
			leg.add(Vec.path(B["leg_" + side], off), skin)
			if bottom == "short": leg.add(Vec.path(B["thigh_" + side], off), pants)
		leg.add(Vec.path(B["shoe_" + side], off), shoes)
		leg.add(Vec.path(B["shoe_" + side], off + Vector2(0, -1), 1.0), Color(1, 1, 1, 0.0), lt(shoes, 0.4), 1.2, true)

	# --- cabello largo atras (debajo del cuerpo)
	var hc: Vector2 = B["head"]
	var hr: float = B["hr"]
	var k := hr / 27.0
	n_hair_back.position = hc
	var hs: String = look.get("hair", "corto")
	if hs == "largo":
		n_hair_back.add(Vec.path("M-31,-4 q0,-31 31,-31 q31,0 31,31 l5,64 q-36,9 -72,0z", Vector2.ZERO, k), dk(hair, 0.12))
	elif hs == "melena":
		n_hair_back.add(Vec.path("M-31,-4 q0,-31 31,-31 q31,0 31,31 l3,30 q-34,7 -68,0z", Vector2.ZERO, k), dk(hair, 0.12))
	elif hs == "coleta":
		n_hair_back.add(Vec.path("M22,-14 q20,2 16,32 q-4,12 -12,6 q8,-16 -8,-28z", Vector2.ZERO, k), hair)

	# --- cuerpo
	var b := n_body
	b.add([Vec.ellipse(Vector2(0, 1), 30, 6)], shadow, LINE, 0.0)
	if bottom == "falda":
		b.add(Vec.path(B["skirt"]), pants)
	b.add(Vec.path(B["torso_f"] if fem else B["torso"]), top)
	b.add(Vec.path(B["shade"]), Color(0, 0, 0, 0.12), LINE, 0.0)
	if bottom != "falda" and top_style not in ["overol", "overol_dorado"]:
		b.add(Vec.path(B["belt"]), dk(pants, 0.3))
	_top_details(b, top_style, top, pants)
	b.add(Vec.path(B["neck"]), dk(skin, 0.12))

	# --- brazos (pivote en el hombro)
	for side in ["l", "r"]:
		var arm: Part = n_arm_l if side == "l" else n_arm_r
		arm.position = B["sh_" + side]
		var sx := 1.0 if side == "l" else -1.0
		var apath: Array = Vec.path(B["arm"])
		var spath: Array = Vec.path(B["sleeve"])
		if sx < 0:
			apath = _mirror(apath); spath = _mirror(spath)
		arm.add(apath, top if long_sleeve else skin)
		if not long_sleeve: arm.add(spath, top)
		var hp: Vector2 = B["hand"]
		hp.x *= sx
		arm.add([Vec.ellipse(hp, B["hand_r"], B["hand_r"])], skin)

	# --- cabeza
	n_head.position = hc
	var h := n_head
	h.add([Vec.ellipse(Vector2(-hr, 2 * k), 6 * k, 7 * k)], skin)
	h.add([Vec.ellipse(Vector2(hr, 2 * k), 6 * k, 7 * k)], skin)
	match String(B["head_shape"]):
		"square":
			h.add(Vec.path("M-22,-22 q22,-6 44,0 q6,10 4,26 q-4,22 -26,22 q-22,0 -26,-22 q-2,-16 4,-26z"), skin)
		"long":
			h.add([Vec.ellipse(Vector2.ZERO, hr * 0.95, hr * 1.12)], skin)
		"round":
			h.add([Vec.ellipse(Vector2.ZERO, hr, hr)], skin)
		_:
			h.add([Vec.ellipse(Vector2.ZERO, hr, hr * 1.05)], skin)
	h.add(Vec.path("M8,4 q14,-2 17,6 q-2,14 -16,18z", Vector2.ZERO, k), Color(0.45, 0.2, 0.08, 0.16), LINE, 0.0)
	_hair_front(h, hs, hair, k)
	_accessory(h, String(look.get("acc", "ninguno")), k)
	_draw_face()

class Shovel extends Node2D:
	## Pala agarrada con las dos manos: el palo pasa por ambas manos y la pala sale despues de la derecha
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var hand_r := 6.0
	var skin := Color.WHITE
	func _draw() -> void:
		var dir := (b - a).normalized()
		if dir == Vector2.ZERO: dir = Vector2(0, 1)
		var start := a - dir * 14.0
		var end := b + dir * 46.0
		var n := Vector2(-dir.y, dir.x)
		var shaft := PackedVector2Array([start + n * 2.6, end + n * 2.6, end - n * 2.6, start - n * 2.6])
		draw_colored_polygon(shaft, Color("a8783e"))
		draw_polyline(PackedVector2Array([start + n * 2.6, end + n * 2.6, end - n * 2.6, start - n * 2.6, start + n * 2.6]), Color("3a2618"), 1.6, true)
		var blade := PackedVector2Array([end + n * 11.0, end + n * 11.0 + dir * 22.0, end + dir * 30.0, end - n * 11.0 + dir * 22.0, end - n * 11.0])
		draw_colored_polygon(blade, Color("9aa0a8"))
		var bl := blade.duplicate(); bl.append(blade[0])
		draw_polyline(bl, Color("3a2618"), 1.8, true)
		# manos encima del palo
		for p in [a, b]:
			draw_circle(p, hand_r, skin)
			draw_arc(p, hand_r, 0, TAU, 16, Color("3a2618"), 1.6, true)

var _shovel: Shovel

func give_shovel() -> void:
	## Pala con las dos manos (para el minero)
	if _has_shovel: return
	_has_shovel = true
	_shovel = Shovel.new()
	_shovel.hand_r = float(B["hand_r"])
	_shovel.skin = _c("skin")
	add_child(_shovel)

func hands_local() -> Vector2:
	## Punto medio de las dos manos (coordenadas del personaje, sin escala)
	var hl: Vector2 = B["hand"]
	var hr: Vector2 = B["hand"]; hr.x *= -1.0
	var a := n_arm_l.position + hl.rotated(n_arm_l.rotation)
	var b := n_arm_r.position + hr.rotated(n_arm_r.rotation)
	return (a + b) * 0.5

const PUSH_ROT := -0.5

func _mirror(polys: Array) -> Array:
	var out := []
	for p in polys:
		var q := PackedVector2Array()
		for v in p: q.append(Vector2(-v.x, v.y))
		out.append(q)
	return out

func _top_details(b: Part, style: String, top: Color, pants: Color) -> void:
	var bx: Array = B["box"]
	var x0: float = bx[0]; var x1: float = bx[1]; var y0: float = bx[2]; var y1: float = bx[3]
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0; var hh := y1 - y0
	match style:
		"playera":
			b.add(Vec.path("M%f,%f q8,6 16,0" % [cx - 8, y0 + 3]), Color(0, 0, 0, 0), dk(top, 0.4), 2.0, true)
		"camisa":
			b.add(Vec.path("M%f,%f l9,9 l9,-9z" % [cx - 9, y0 + 2]), Color("f6f1e6"))
			for i in 3:
				b.add([Vec.ellipse(Vector2(cx + 1, y0 + 16 + i * hh * 0.22), 1.6, 1.6)], Color("f6f1e6"), LINE, 1.0)
		"sudadera":
			b.add(Vec.path("M%f,%f l%f,0 l-3,%f l%f,0z" % [cx - w * 0.25, y1 - hh * 0.38, w * 0.5, hh * 0.28, -w * 0.5 + 6]), dk(top, 0.15))
			b.add(Vec.path("M%f,%f l0,12 M%f,%f l0,12" % [cx - 5, y0 + 5, cx + 5, y0 + 5]), Color(0, 0, 0, 0), Color("f2ede2"), 1.8, true)
		"overol", "overol_dorado":
			b.add(Vec.path("M%f,%f l%f,0 l2,%f l%f,0z" % [cx - w * 0.28, y0 + hh * 0.38, w * 0.56, hh * 0.62 + 2, -w * 0.56 - 4]), pants)
			b.add(Vec.path("M%f,%f l-4,%f M%f,%f l4,%f" % [cx - w * 0.24, y0 + hh * 0.4, -hh * 0.36, cx + w * 0.24, y0 + hh * 0.4, -hh * 0.36]), Color(0, 0, 0, 0), pants, 4.0, true)
			b.add([Vec.ellipse(Vector2(cx - w * 0.22, y0 + hh * 0.44), 2, 2), Vec.ellipse(Vector2(cx + w * 0.22, y0 + hh * 0.44), 2, 2)], Color("e8c45a"), LINE, 1.0)
		"chaleco":
			var vest := Color("e8782a")
			b.add(Vec.path("M%f,%f l%f,0 l0,%f l%f,0z" % [x0 + 2, y0 + 4, w * 0.3, hh - 4, -w * 0.3]), vest)
			b.add(Vec.path("M%f,%f l%f,0 l0,%f l%f,0z" % [x1 - 2 - w * 0.3, y0 + 4, w * 0.3, hh - 4, w * 0.3]), vest)
			for f in [0.55, 0.78]:
				b.add(Vec.path("M%f,%f l%f,0 l0,4 l%f,0z" % [x0 + 2, y0 + hh * f, w * 0.3, -w * 0.3]), Color("eae6dc"), LINE, 1.2)
				b.add(Vec.path("M%f,%f l%f,0 l0,4 l%f,0z" % [x1 - 2 - w * 0.3, y0 + hh * f, w * 0.3, -w * 0.3]), Color("eae6dc"), LINE, 1.2)
		"mandil":
			var ap := Color("efd3a0")
			b.add(Vec.path("M%f,%f l%f,0 l3,%f l%f,0z" % [cx - w * 0.28, y0 + hh * 0.22, w * 0.56, hh * 0.78 + 6, -w * 0.56 - 6]), ap)
			b.add(Vec.path("M%f,%f l-6,%f M%f,%f l6,%f" % [cx - w * 0.28, y0 + hh * 0.22, -hh * 0.2, cx + w * 0.28, y0 + hh * 0.22, -hh * 0.2]), Color(0, 0, 0, 0), Color("c9a46a"), 3.2, true)
			var px := cx - 8; var py := y0 + hh * 0.5
			b.add(Vec.path("M%f,%f l16,0 l0,12 l-16,0z" % [px, py]), Color("dcbc84"), LINE, 2.0)
			b.add(Vec.path("M%f,%f l0,-8" % [px + 4, py]), Color(0, 0, 0, 0), Color("c0432e"), 2.4, true)
			b.add(Vec.path("M%f,%f l1,-9" % [px + 10, py]), Color(0, 0, 0, 0), Color("2f4f8f"), 2.4, true)

func _hair_front(h: Part, style: String, hair: Color, k: float) -> void:
	var hl := lt(hair, 0.25)
	match style:
		"corto":
			h.add(Vec.path("M-27,2 q-6,-30 22,-32 q26,-2 30,20 q2,8 -1,14 q-6,-14 -20,-16 q2,8 -10,12 q-2,-8 -8,-10 q-4,10 -13,12z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M-8,-24 q8,-4 16,0", Vector2.ZERO, k), Color(0, 0, 0, 0), hl, 2.6, true)
		"puntas":
			h.add(Vec.path("M-28,4 q-4,-26 14,-30 l-2,-9 l10,6 l4,-11 l6,10 l9,-7 l1,11 q14,6 14,22 q0,8 -3,12 q-6,-14 -22,-14 q-4,8 -14,10 q-2,-6 -6,-8 q-4,8 -11,10z", Vector2.ZERO, k), hair)
		"rapado":
			h.add(Vec.path("M-26,-2 q0,-24 26,-26 q26,2 26,26 q-7,-10 -26,-12 q-19,2 -26,12z", Vector2.ZERO, k), dk(hair, 0.1))
		"de_lado":
			h.add(Vec.path("M-27,4 q-4,-32 26,-32 q28,2 28,22 l-2,10 q-10,-16 -30,-12 q-10,4 -18,4 q-2,4 -4,8z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M-6,-26 q14,-2 22,8", Vector2.ZERO, k), Color(0, 0, 0, 0), hl, 2.6, true)
		"largo", "melena":
			h.add(Vec.path("M-28,6 q-3,-34 28,-34 q31,0 28,34 q-8,-15 -20,-15 q-4,8 -12,8 q-6,-6 -10,-6 q-6,6 -14,13z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M-29,2 l-3,30 l7,0 l2,-28z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M29,2 l3,30 l-7,0 l-2,-28z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M-10,-26 q10,-4 18,0", Vector2.ZERO, k), Color(0, 0, 0, 0), hl, 2.6, true)
		"rizado":
			var pts := []
			for i in 11:
				var a := deg_to_rad(195 + i * 15)
				pts.append(Vec.ellipse(Vector2(cos(a) * 27, sin(a) * 27 + 2) * k, 10 * k, 10 * k, 14))
			h.add(pts, hair)
			h.add(Vec.path("M-24,-2 q0,-22 24,-24 q24,2 24,24 q-10,-8 -24,-8 q-14,0 -24,8z", Vector2.ZERO, k), hair, LINE, 0.0)
		"chongo":
			h.add([Vec.ellipse(Vector2(2, -33) * k, 10 * k, 10 * k)], hair)
			h.add(Vec.path("M-28,4 q-3,-32 28,-32 q30,0 28,30 q-8,-14 -20,-12 q-12,2 -20,8 q-10,-2 -16,6z", Vector2.ZERO, k), hair)
			h.add(Vec.path("M-8,-24 q8,-4 16,0", Vector2.ZERO, k), Color(0, 0, 0, 0), hl, 2.6, true)
		"coleta":
			h.add(Vec.path("M-28,4 q-3,-32 28,-32 q30,0 28,30 q-8,-14 -20,-12 q-12,2 -20,8 q-10,-2 -16,6z", Vector2.ZERO, k), hair)
			h.add([Vec.ellipse(Vector2(24, -12) * k, 5 * k, 5 * k)], Color("c0432e"), LINE, 1.6)

func _accessory(h: Part, acc: String, k: float) -> void:
	match acc:
		"gorra":
			var c := Color("c8423a")
			h.add(Vec.path("M-27,-6 q2,-25 27,-25 q25,0 27,25z", Vector2.ZERO, k), c)
			h.add(Vec.path("M-4,-7 l42,0 q2,6 -4,8 l-38,0z", Vector2.ZERO, k), dk(c, 0.25))
			h.add(Vec.path("M-8,-24 q8,-4 16,0", Vector2.ZERO, k), Color(0, 0, 0, 0), lt(c, 0.35), 2.4, true)
		"casco":
			var c := Color("f0b62e")
			h.add(Vec.path("M-29,-5 q0,-29 29,-29 q29,0 29,29z", Vector2.ZERO, k), c)
			h.add(Vec.path("M-35,-7 l70,0 l0,6 l-70,0z", Vector2.ZERO, k), dk(c, 0.18))
			h.add(Vec.path("M-4,-33 l8,0 l0,26 l-8,0z", Vector2.ZERO, k), dk(c, 0.08), LINE, 1.6)
		"sombrero":
			var c := Color("e3c47e")
			h.add(Vec.path("M-15,-12 q0,-26 15,-28 q15,2 15,28z", Vector2.ZERO, k), c)
			h.add(Vec.path("M-15,-17 q15,-4 30,0 l0,5 q-15,-4 -30,0z", Vector2.ZERO, k), Color("b5463a"), LINE, 1.6)
			h.add(Vec.path("M-42,-10 q42,-16 84,0 q-4,8 -12,7 q-30,-8 -60,0 q-8,1 -12,-7z", Vector2.ZERO, k), c)
		"paliacate":
			var c := Color("c0302a")
			h.add(Vec.path("M-28,-6 q28,-14 56,0 l0,9 q-28,-12 -56,0z", Vector2.ZERO, k), c)
			h.add(Vec.path("M26,-4 l12,-4 l-2,12z", Vector2.ZERO, k), c)
			for p in [Vector2(-14, -7), Vector2(0, -10), Vector2(14, -7)]:
				h.add([Vec.ellipse(p * k, 1.6 * k, 1.6 * k)], Color("f2ede2"), LINE, 0.0)
		"lentes":
			for sx in [-1, 1]:
				h.add([Vec.ellipse(Vector2(9 * sx, 2) * k, 7 * k, 6.5 * k)], Color(1, 1, 1, 0.22), Color("6e4126"), 1.8)
			h.add(Vec.path("M-2,1 q2,-2 4,0", Vector2.ZERO, k), Color(0, 0, 0, 0), Color("6e4126"), 1.8, true)
		"lentes_oscuros":
			for sx in [-1, 1]:
				h.add([Vec.ellipse(Vector2(9 * sx, 2) * k, 7.5 * k, 6 * k)], Color("231c22"), LINE, 1.6)
				h.add([Vec.ellipse(Vector2(9 * sx - 3, 0) * k, 2 * k, 1.4 * k)], Color(1, 1, 1, 0.5), LINE, 0.0)
			h.add(Vec.path("M-2,1 q2,-2 4,0", Vector2.ZERO, k), Color(0, 0, 0, 0), Color("231c22"), 2.0, true)

# =============================================================== cara (se redibuja al parpadear / cambiar expresion)
func _draw_face() -> void:
	var f := n_face
	f.shapes.clear()
	var hr: float = B["hr"]
	var k := hr / 27.0
	var fem: bool = look.get("gender", "m") == "f"
	var face: String = look.get("face", "normal")
	var hair := _c("hair")
	var skin := _c("skin")
	var acc: String = look.get("acc", "ninguno")
	var eye := Color("2a1f26")
	var none := Color(0, 0, 0, 0)
	var m := mood
	if face == "feliz" and m == "idle": m = "smile"
	var brow_w := 3.0 * k
	# cejas
	match m:
		"think", "sad":
			f.add(Vec.path("M-14,-8 q5,-5 10,-3 M4,-11 q5,-2 10,3", Vector2.ZERO, k), none, LINE, brow_w, true)
		_:
			if face == "serio":
				f.add(Vec.path("M-15,-10 l10,3 M5,-7 l10,-3", Vector2.ZERO, k), none, LINE, brow_w + 0.6, true)
			else:
				f.add(Vec.path("M-14,-9 q5,-4 10,-1 M4,-10 q5,-3 10,1", Vector2.ZERO, k), none, LINE, brow_w, true)
	# ojos
	var closed := _blink > 0.0 or m == "sleep"
	if acc == "lentes_oscuros":
		pass
	elif closed:
		f.add(Vec.path("M-12,3 l7,0 M5,3 l7,0", Vector2.ZERO, k), none, eye, 2.4 * k, true)
	elif m == "happy" or m == "smile" and face == "feliz":
		f.add(Vec.path("M-13,4 q4,-5 8,0 M5,4 q4,-5 8,0", Vector2.ZERO, k), none, eye, 2.6 * k, true)
	else:
		for sx in [-1, 1]:
			f.add([Vec.ellipse(Vector2(9 * sx, 2) * k, 3 * k, 4.4 * k, 14)], eye, LINE, 0.0)
			f.add([Vec.ellipse(Vector2(9 * sx + 1, 0.4) * k, 1.1 * k, 1.1 * k, 8)], Color.WHITE, LINE, 0.0)
		if fem:
			f.add(Vec.path("M-12,-1 l-3,-2 M12,-1 l3,-2", Vector2.ZERO, k), none, eye, 1.8 * k, true)
	# nariz grande
	f.add(Vec.path("M-2,5 q6,1 6,7 q-4,3 -9,1z", Vector2.ZERO, k), dk(skin, 0.18), LINE, 1.8 * k)
	# boca
	if face == "bigote":
		f.add(Vec.path("M-16,13 q8,-8 16,-3 q8,-5 16,3 q-2,6 -9,4 q-4,-3 -7,-1 q-3,-2 -7,1 q-7,2 -9,-4z", Vector2.ZERO, k), dk(hair, 0.15), LINE, 2.0 * k)
	match m:
		"happy":
			f.add(Vec.path("M-8,16 q8,8 16,0 q-8,3 -16,0z", Vector2.ZERO, k), Color("7a2a2a"), LINE, 2.0 * k)
			f.add(Vec.path("M-6,16.6 l12,0", Vector2.ZERO, k), none, Color.WHITE, 1.8 * k, true)
		"think", "sad":
			f.add(Vec.path("M-5,19 q5,-3 10,0", Vector2.ZERO, k), none, Color("7a3a2e"), 2.4 * k, true)
		"sleep":
			f.add([Vec.ellipse(Vector2(0, 18) * k, 3 * k, 2.5 * k)], Color("7a2a2a"), LINE, 1.6 * k)
		_:
			if face == "serio":
				f.add(Vec.path("M-5,18 l10,0", Vector2.ZERO, k), none, Color("7a3a2e"), 2.4 * k, true)
			else:
				f.add(Vec.path("M-7,15 q7,6 14,0", Vector2.ZERO, k), none, Color("7a3a2e"), 2.4 * k, true)
	# cachetes y pecas
	if m != "think":
		f.add([Vec.ellipse(Vector2(-16, 11) * k, 4.4 * k, 2.6 * k), Vec.ellipse(Vector2(16, 11) * k, 4.4 * k, 2.6 * k)], Color(0.94, 0.48, 0.44, 0.4), LINE, 0.0)
	if face == "pecas":
		for p in [Vector2(-13, 8), Vector2(-17, 9), Vector2(13, 8), Vector2(17, 9), Vector2(-15, 12), Vector2(15, 12)]:
			f.add([Vec.ellipse(p * k, 1 * k, 1 * k, 6)], dk(skin, 0.35), LINE, 0.0)
	f.queue_redraw()

# =============================================================== animacion
func set_mood(m: String, seconds := 0.0) -> void:
	if mood != m:
		mood = m
		_draw_face()
	_mood_timer = seconds

func _process(delta: float) -> void:
	if B.is_empty(): return
	_t += delta
	# parpadeo
	if _blink > 0.0:
		_blink -= delta
		if _blink <= 0.0: _draw_face()
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 0.13
			_next_blink = randf_range(2.2, 5.0)
			_draw_face()
	if _mood_timer > 0.0:
		_mood_timer -= delta
		if _mood_timer <= 0.0: set_mood("idle")
	var t := _t + _seed
	if walking:
		var s := sin(t * 10.0)
		n_leg_l.rotation = s * 0.32
		n_leg_r.rotation = -s * 0.32
		n_arm_l.rotation = PUSH_ROT if pushing else -s * 0.28
		n_arm_r.rotation = PUSH_ROT if pushing else s * 0.28
		var bob := -absf(cos(t * 10.0)) * 3.0
		n_body.position.y = bob; n_head.position = B["head"] + Vector2(0, bob); n_hair_back.position = n_head.position
		n_arm_l.position = B["sh_l"] + Vector2(0, bob); n_arm_r.position = B["sh_r"] + Vector2(0, bob)
	else:
		n_leg_l.rotation = lerpf(n_leg_l.rotation, 0.0, delta * 10.0)
		n_leg_r.rotation = lerpf(n_leg_r.rotation, 0.0, delta * 10.0)
		var breath := sin(t * 2.2) * 1.0
		n_body.position.y = 0.0
		n_head.position = B["head"] + Vector2(0, breath)
		n_hair_back.position = n_head.position
		n_head.rotation = sin(t * 0.9) * 0.025
		n_arm_l.position = B["sh_l"] + Vector2(0, breath * 0.6)
		n_arm_r.position = B["sh_r"] + Vector2(0, breath * 0.6)
		if shoveling:
			# clava la pala abajo y la levanta (las dos manos juntas)
			var sw := (sin(t * 4.5) + 1.0) * 0.5
			n_arm_r.rotation = lerpf(-0.15, -1.35, sw)
			n_arm_l.rotation = lerpf(-0.9, -2.1, sw)
			n_body.rotation = lerpf(0.1, -0.04, sw)
		elif pushing:
			n_arm_l.rotation = PUSH_ROT
			n_arm_r.rotation = PUSH_ROT
		elif mood == "happy":
			n_arm_r.rotation = lerpf(n_arm_r.rotation, -2.5 + sin(t * 9.0) * 0.25, delta * 12.0)
			n_arm_l.rotation = lerpf(n_arm_l.rotation, sin(t * 2.0) * 0.05, delta * 8.0)
			n_head.position.y -= absf(sin(t * 6.0)) * 2.0
		elif mood == "think":
			n_arm_r.rotation = lerpf(n_arm_r.rotation, 2.5, delta * 8.0)
			n_arm_l.rotation = lerpf(n_arm_l.rotation, 0.0, delta * 8.0)
		else:
			n_arm_l.rotation = lerpf(n_arm_l.rotation, sin(t * 2.2) * 0.04, delta * 8.0)
			n_arm_r.rotation = lerpf(n_arm_r.rotation, -sin(t * 2.2) * 0.04, delta * 8.0)
	if _shovel:
		var hl: Vector2 = B["hand"]
		var hr: Vector2 = B["hand"]; hr.x *= -1.0
		_shovel.a = n_arm_l.position + hl.rotated(n_arm_l.rotation)
		_shovel.b = n_arm_r.position + hr.rotated(n_arm_r.rotation)
		_shovel.queue_redraw()
