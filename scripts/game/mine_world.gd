extends Node2D
## Escenario de la mina. Muestra los viajes en curso con vehiculos y personas.

const GROUND := 252.0
const PILES := [["arena", 36], ["grava", 98], ["tepetate", 156], ["piedra", 204], ["tezontle", 242]]
var bg: Sprite2D
var _t := 0.0
var _vehs := {}   # vid -> Sprite2D
var _people := {} # vid -> Person
var labels: Node2D
var miner: Node2D
var dust: CPUParticles2D
const WB_PS := 0.42

class Labels extends Node2D:
	func _draw() -> void:
		var U = get_node("/root/UI")
		var Gm = get_node("/root/Game")
		for l in PILES:
			var id: String = l[0]
			var ok: bool = get_node("/root/DB").item_unlocked(id, Gm.level(), Gm.s["tools"])
			var txt: String = get_node("/root/L").t("item_" + id) if ok else "?"
			var w: float = U.f_ui_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var x: float = float(l[1]) - w / 2.0
			draw_rect(Rect2(x - 4, 219, w + 8, 14), Color(0.23, 0.15, 0.09, 0.78))
			draw_string(U.f_ui_bold, Vector2(x, 230), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f7eedb") if ok else Color("c9b9a6"))

func _ready() -> void:
	bg = Sprite2D.new(); bg.centered = false; bg.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(bg)
	labels = Labels.new(); add_child(labels)
	# minero que carga los vehiculos
	var mlook := {"gender": "m", "body": "broad", "skin": 3, "face": "bigote", "hair": "corto", "hair_color": 0, "acc": "paliacate",
		"top": "playera", "top_color": 6, "pants": "pantalon", "pants_color": 1, "shoes": 1}
	miner = Art.person(mlook)
	miner.scale = Vector2(0.48, 0.48)
	miner.position = Vector2(300, GROUND)
	add_child(miner)
	miner.give_shovel()
	dust = CPUParticles2D.new()
	dust.amount = 14
	dust.lifetime = 0.9
	dust.emitting = false
	dust.direction = Vector2(-1, -0.6)
	dust.spread = 35.0
	dust.initial_velocity_min = 14.0
	dust.initial_velocity_max = 30.0
	dust.gravity = Vector2(0, 18)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.5
	dust.color = Color(0.85, 0.74, 0.55, 0.7)
	dust.z_index = 20
	add_child(dust)

func _process(delta: float) -> void:
	_t += delta
	bg.texture = Art.tex("mine_own" if Game.s["own_mine"] else "mine")
	var active := {}
	var lane := 0
	var loading_x := -1.0
	var loading_keys := []
	var loading_u := 0.0
	for v in Game.s["fleet"]:
		if v["trip"] == null or v["trip"].has("delivery"): continue
		var vid: int = int(v["id"])
		active[vid] = true
		if not _vehs.has(vid):
			var sp := Sprite2D.new(); sp.centered = false; sp.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
			add_child(sp); _vehs[vid] = sp
			var look: Dictionary = Game.s["look"] if v["trip"]["self"] else _driver_look(vid)
			var pp := Art.person(look)
			add_child(pp); _people[vid] = pp
		var sp: Sprite2D = _vehs[vid]
		var pp: Node2D = _people[vid]
		sp.texture = Art.tex(Game.vehicle_tex(v))
		var tr: Dictionary = v["trip"]
		var dur := maxf(1.0, float(tr["end"]) - float(tr["start"]))
		var p := clampf((Game.now() - float(tr["start"])) / dur, 0.0, 1.0)
		var w := sp.texture.get_width() / 3.0
		var h := sp.texture.get_height() / 3.0
		var park := 40.0 + (lane % 3) * 90.0
		var x := 0.0
		var leaving := false
		if p < 0.3: x = lerpf(-w - 40.0, park, p / 0.3)
		elif p < 0.7: x = park
		else:
			x = lerpf(park, -w - 60.0, (p - 0.7) / 0.3); leaving = true
		var gy := GROUND + (lane % 2) * 14.0
		var bounce := 1.0 if (p >= 0.3 and p < 0.7 and int(_t * 6) % 2 == 0) else 0.0
		sp.position = Vector2(x, gy - h - bounce)
		sp.flip_h = leaving
		sp.z_index = 2 + lane * 2
		var walking := p < 0.3 or p >= 0.7
		var is_wb: bool = v["type"] == "wheelbarrow"
		var ps := 0.5
		if p >= 0.3 and p < 0.7 and loading_x < 0.0:
			loading_x = x + w * 0.5
			loading_keys = tr["load"].keys()
			loading_u = (p - 0.3) / 0.4
		if is_wb:
			# la carretilla se escala para que las agarraderas queden en las manos
			ps = WB_PS
			pp.pushing = true
			pp.visible = true
			var hands: Vector2 = pp.hands_local() * ps
			var k := (-hands.y) / 16.0
			sp.scale = Vector2(k / 3.0, k / 3.0)
			w = 64.0 * k
			if p < 0.3: x = lerpf(-w - 40.0, park, p / 0.3)
			elif p >= 0.7: x = lerpf(park, -w - 60.0, (p - 0.7) / 0.3)
			sp.position = Vector2(x, gy - 38.0 * k - bounce * 0.0)
			if leaving:
				pp.position = Vector2(x + (64.0 - 4.0) * k + absf(hands.x), gy)
			else:
				pp.position = Vector2(x + 4.0 * k - absf(hands.x), gy)
			pp.z_index = 3 + lane * 2
			sp.z_index = 4 + lane * 2
		else:
			pp.visible = p >= 0.3 and p < 0.7
			pp.pushing = false
			pp.position = Vector2(x + w + 16.0, gy)
		pp.scale = Vector2(ps * (-1.0 if leaving else 1.0), ps)
		pp.walking = walking
		if not walking and pp.mood == "idle": pp.set_mood("happy", 1.5)
		if not is_wb: pp.z_index = 3 + lane * 2
		lane += 1
	# el minero va al monton de cada material, palea y lo echa al vehiculo
	var mx := 300.0
	var at_pile := false
	var pile_x := 0.0
	if loading_x >= 0.0 and not loading_keys.is_empty():
		var k := loading_keys.size()
		var idx := mini(int(loading_u * k), k - 1)
		var u := loading_u * k - idx
		pile_x = _pile_x(str(loading_keys[idx]))
		if u < 0.65:
			mx = pile_x + 22.0
			at_pile = u > 0.2
		else:
			mx = loading_x + 30.0
	var mmoving := absf(miner.position.x - mx) > 1.5
	miner.position.x = move_toward(miner.position.x, mx, delta * 110.0)
	miner.walking = mmoving
	miner.shoveling = not mmoving and at_pile
	var face := 1.0
	if mmoving: face = 1.0 if mx > miner.position.x else -1.0
	elif at_pile: face = -1.0
	miner.scale = Vector2(0.48 * face, 0.48)
	miner.z_index = 30
	dust.position = Vector2(pile_x + 4.0, GROUND - 14.0)
	var up := sin((miner._t + miner._seed) * 4.5) < -0.5
	dust.emitting = miner.shoveling and up
	for vid in _vehs.keys():
		if not active.has(vid):
			_vehs[vid].queue_free(); _people[vid].queue_free()
			_vehs.erase(vid); _people.erase(vid)

func _pile_x(id: String) -> float:
	for pl in PILES:
		if pl[0] == id: return float(pl[1])
	return 60.0

func _driver_look(vid: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(Game.s["seed"]), vid, "driver"])
	var l := Art.random_look(r, "m")
	l["acc"] = "gorra"; l["body"] = "broad"
	return l

func handle_tap(_pos: Vector2) -> void:
	pass
