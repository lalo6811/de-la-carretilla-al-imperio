extends Node2D
## Escenario del local (360x272). Capas: fondo, inventario, tu personaje, mostrador,
## basura, clientes en fila (con perspectiva hacia la puerta), visitante, luz.

signal customer_tapped(c: Dictionary)
signal visitor_tapped
signal driver_tapped(vid: int)

const FLOOR := 214.0
const PLAYER_POS := Vector2(206, 216)
const PSCALE := 0.62
const SLOTS := [Vector2(306, 258), Vector2(332, 242), Vector2(350, 230), Vector2(366, 222)]
const SLOT_SCALE := [0.62, 0.56, 0.51, 0.47]
const DOOR := Vector2(376, 224)
const CLERK_POS := Vector2(150, 216)
const CLERK_SLOTS := [Vector2(112, 260), Vector2(78, 264)]
const DIRT := [
	{"tex": "dirt_web", "pos": Vector2(4, 30), "z": 0},
	{"tex": "dirt_bag", "pos": Vector2(186, 226), "z": 1},
	{"tex": "dirt_box", "pos": Vector2(244, 226), "z": 1},
	{"tex": "dirt_rubble", "pos": Vector2(60, 232), "z": 1},
	{"tex": "dirt_stain", "pos": Vector2(140, 250), "z": 1},
	{"tex": "dirt_web", "pos": Vector2(292, 30), "z": 0},
]

var bg: Sprite2D
var stock: Node2D
var player: Node2D
var clerk: Node2D
var counter: Sprite2D
var dirt_layer: Node2D
var people_layer: Node2D
var visitor: Node2D
var light: Sprite2D
var top: Node2D
var ride: Sprite2D
var sprites := {}          # cid -> {p, c, pos, leaving, happy}
var selected_cid := -1
var _t := 0.0
var _busy := 0.0
var _player_x := PLAYER_POS.x
var _player_target := PLAYER_POS.x
var _arriving := false
var _arrive_y := DOOR.y
var drivers_layer: Node2D
var _drivers_sig := ""
var drivers := {}          # vid -> Person

class StockLayer extends Node2D:
	func _draw() -> void:
		var Gm = get_node("/root/Game")
		var A = get_node("/root/Art")
		# costales al fondo izquierdo
		var sacks := [["cemento", 2.0], ["cal", 64.0]]
		for s in sacks:
			var n: int = mini(Gm.inv_qty(s[0]) + (Gm.inv_qty("yeso") if s[0] == "cal" else 0), 6)
			var t: Texture2D = A.tex("stock_" + s[0])
			for i in n:
				var row := 0 if i < 3 else (1 if i < 5 else 2)
				var col := i if i < 3 else (i - 3 if i < 5 else 0)
				var x: float = s[1] + col * 19 + row * 9.5
				var y := 214.0 - row * 12
				draw_texture_rect(t, Rect2(x, y, 34, 19), false)
		# tabique, varilla y piedra
		if Gm.inv_qty("tabique") + Gm.inv_qty("block") > 0:
			draw_texture_rect(A.tex("stock_tabique"), Rect2(4, 236, 32, 20), false)
		if Gm.inv_qty("varilla") + Gm.inv_qty("castillo") > 0:
			draw_texture_rect(A.tex("stock_varilla"), Rect2(36, 248, 44, 15), false)
		var rocks: int = Gm.inv_qty("piedra") + Gm.inv_qty("tezontle")
		if rocks > 0:
			var w: float = 24.0 + minf(rocks, 40.0) * 0.5
			draw_texture_rect(A.tex("stock_piedra"), Rect2(108, 266 - w * 0.64, w, w * 0.64), false)
		# montones al frente
		var piles := [["arena", 42.0, 270.0], ["grava", 92.0, 268.0], ["tepetate", 136.0, 272.0]]
		for p in piles:
			var q: int = Gm.inv_qty(p[0])
			if q <= 0: continue
			var w: float = 34.0 + minf(q, 60.0) * 0.9
			var h := w * 34.0 / 80.0
			draw_texture_rect(A.tex("stock_" + p[0]), Rect2(p[1] - w / 2.0, p[2] - h, w, h), false)

class TopLayer extends Node2D:
	var world
	func _draw() -> void:
		if world == null: return
		var U = get_node("/root/UI")
		var Gm = get_node("/root/Game")
		var t: float = world._t
		# letrero de "vuelvo en" (o "cerrado") sobre el mostrador
		var Lz = get_node("/root/L")
		var sign_top := ""
		var sign_bot := ""
		if Gm.shop_stage() > 0 and not Gm.tutorial_on() and Gm.phase() != "open":
			sign_top = Lz.t("sign_closed"); sign_bot = Lz.t("sign_open_soon") if Gm.phase() == "morning" else Lz.t("sign_tomorrow")
		elif Gm.player_away() and Gm.shop_stage() > 0:
			sign_top = Lz.t("closed_short"); sign_bot = U.fmt_time(Gm.player_trip_left())
		if sign_top != "":
			var sw := 66.0
			draw_line(Vector2(190, 120), Vector2(176 + sw * 0.25, 134), Color("3a2618"), 1.2)
			draw_line(Vector2(190, 120), Vector2(176 + sw * 0.75, 134), Color("3a2618"), 1.2)
			draw_rect(Rect2(174, 134, sw, 32), Color("3a2618"))
			draw_rect(Rect2(176, 136, sw - 4, 28), Color("fffbef"))
			draw_string(U.f_title, Vector2(180, 149), sign_top, HORIZONTAL_ALIGNMENT_LEFT, sw - 8, 11, Color("c0432e"))
			draw_string(U.f_title, Vector2(180, 162), sign_bot, HORIZONTAL_ALIGNMENT_LEFT, sw - 8, 11, Color("3a2618"))
		# indicadores sobre clientes
		for cid in world.sprites:
			var d: Dictionary = world.sprites[cid]
			if d["leaving"]: continue
			var c: Dictionary = d["c"]
			var p: Node2D = d["p"]
			var s: float = absf(p.scale.x)
			var head: Vector2 = p.position + (p.B["head"] - Vector2(0, p.B["hr"] + 14)) * s
			if c.has("clerk"): continue
			var is_sel: bool = cid == world.selected_cid or (world.selected_cid == -1 and not Gm.customers.is_empty() and Gm.customers[0] == c)
			if is_sel:
				var by := head.y - 8 + sin(t * 5.0) * 2.0
				draw_colored_polygon(PackedVector2Array([Vector2(head.x - 7, by), Vector2(head.x + 7, by), Vector2(head.x, by + 8)]), Color("f2b533"))
				draw_polyline(PackedVector2Array([Vector2(head.x - 7, by), Vector2(head.x + 7, by), Vector2(head.x, by + 8), Vector2(head.x - 7, by)]), Color("3a2618"), 1.6, true)
			elif Gm.can_fulfill(c):
				draw_circle(head + Vector2(12, 4), 6, Color("3a2618"))
				draw_circle(head + Vector2(12, 4), 4.8, Color("6fd08c"))
				draw_polyline(PackedVector2Array([head + Vector2(9.5, 4), head + Vector2(11.5, 6), head + Vector2(14.5, 2)]), Color.WHITE, 1.6, true)
		# choferes listos para salir
		for vid in world.drivers:
			var dp: Node2D = world.drivers[vid]
			var hb: Vector2 = dp.position + Vector2(8, -118 + sin(t * 3.0 + vid) * 2.0)
			draw_circle(hb, 10, Color("3a2618"))
			draw_circle(hb, 8.6, Color("fffbef"))
			draw_string(U.f_title, hb + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c0432e"))
		# globo del visitante
		if world.visitor.visible:
			var v: Vector2 = world.visitor.position + Vector2(10, -132 + sin(t * 4.0) * 2.0)
			draw_circle(v, 13, Color("3a2618"))
			draw_circle(v, 11.5, Color("fffbef"))
			draw_string(U.f_title, v + Vector2(-5, 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("2f8a5b"))

func _ready() -> void:
	bg = Sprite2D.new(); bg.centered = false; bg.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(bg)
	stock = StockLayer.new(); add_child(stock)
	player = Art.person(Game.s["look"])
	player.scale = Vector2(PSCALE, PSCALE)
	player.position = PLAYER_POS
	add_child(player)
	clerk = Art.person(_clerk_look())
	clerk.scale = Vector2(PSCALE, PSCALE); clerk.position = CLERK_POS; clerk.visible = false
	add_child(clerk)
	ride = Sprite2D.new(); ride.centered = false; ride.scale = Vector2(1.0 / 3.0, 1.0 / 3.0); ride.visible = false
	add_child(ride)
	counter = Sprite2D.new(); counter.centered = false; counter.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(counter)
	dirt_layer = Node2D.new(); add_child(dirt_layer)
	drivers_layer = Node2D.new(); add_child(drivers_layer)
	people_layer = Node2D.new(); people_layer.y_sort_enabled = true; add_child(people_layer)
	visitor = Art.person(_visitor_look())
	visitor.scale = Vector2(PSCALE, PSCALE); visitor.position = Vector2(96, 262); visitor.visible = false
	add_child(visitor)
	light = Sprite2D.new(); light.centered = false; light.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(light)
	top = TopLayer.new(); top.world = self; add_child(top)
	if Game.has_meta("arrive") and Game.get_meta("arrive"):
		Game.set_meta("arrive", false)
		_arriving = true
		_player_x = DOOR.x
	Game.customer_arrived.connect(_on_arrived)
	Game.customer_left.connect(_on_left)
	Game.changed.connect(_refresh_static)
	Game.visitor_changed.connect(_refresh_static)
	for c in Game.customers:
		_on_arrived(c, true)
	_refresh_static()

func _refresh_static() -> void:
	if not is_inside_tree(): return
	var st := Game.shop_stage()
	bg.texture = Art.tex("shop_%d" % st)
	counter.texture = Art.tex("counter_%d" % (0 if st == 0 else (1 if st < 4 else (2 if st < 8 else 3))))
	light.texture = Art.tex("shop_light_2" if st >= 8 else "shop_light")
	for n in dirt_layer.get_children(): n.queue_free()
	if st == 0:
		for i in DIRT.size():
			if Game.s["dirt"].has(i):
				var sp := Art.sprite(DIRT[i]["tex"], DIRT[i]["pos"])
				sp.set_meta("idx", i)
				dirt_layer.add_child(sp)
	visitor.visible = Game.visitor_active
	stock.queue_redraw()
	_refresh_drivers()

func _refresh_drivers() -> void:
	## Choferes sin viaje esperan en el local: tocalos para mandarlos a la mina
	var ids := []
	if Game.shop_stage() > 0:
		for v in Game.s["fleet"]:
			if v["driver"] and v["trip"] == null: ids.append(int(v["id"]))
	var sig := str(ids)
	if sig == _drivers_sig: return
	_drivers_sig = sig
	for n in drivers_layer.get_children(): n.queue_free()
	drivers.clear()
	for i in ids.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(Game.s["seed"]) * 31 + ids[i] * 7
		var look := Art.random_look(rng, "m")
		look["top"] = "overol"; look["acc"] = "gorra"
		var p := Art.person(look)
		p.scale = Vector2(0.58, 0.58)
		p.position = Vector2(26 + i * 26, 230 + (i % 2) * 4)
		drivers_layer.add_child(p)
		drivers[ids[i]] = p

func tutorial_target() -> Rect2:
	## Rectangulo (coordenadas del escenario) que el tutorial quiere senalar
	if Game.shop_stage() == 0:
		for sp in dirt_layer.get_children():
			if sp.is_queued_for_deletion(): continue
			return Rect2(sp.position - Vector2(4, 4), Vector2(48, 44))
	return Rect2()

func _on_arrived(c: Dictionary, instant := false) -> void:
	var p := Art.person(c["look"])
	people_layer.add_child(p)
	var slot := _slot(c)
	p.position = slot[0] if instant else DOOR
	var s: float = slot[1] if instant else 0.46
	p.scale = Vector2(s, s)
	sprites[c["cid"]] = {"p": p, "c": c, "leaving": false, "happy": false}
	if not instant: Sfx.play("bell")

func _on_left(c: Dictionary, happy: bool) -> void:
	if not sprites.has(c["cid"]): return
	var d: Dictionary = sprites[c["cid"]]
	d["leaving"] = true
	d["happy"] = happy
	var p: Node2D = d["p"]
	if happy:
		p.set_mood("happy", 3.0)
		UI.float_text(self, p.position + Vector2(-16, -130), "+$%s" % UI.fmt(int(c.get("_paid", c["price"]))), UI.YELLOW)
		player.set_mood("happy", 1.6)
	else:
		p.set_mood("sad", 3.0)
	if selected_cid == c["cid"]: selected_cid = -1

func _slot(c: Dictionary) -> Array:
	if c.has("clerk"):
		var j := Game.clerk_customers.find(c)
		if j < 0: return [DOOR, 0.46]
		return [CLERK_SLOTS[mini(j, CLERK_SLOTS.size() - 1)], PSCALE]
	var i := Game.customers.find(c)
	if i < 0: return [DOOR, 0.46]
	i = mini(i, SLOTS.size() - 1)
	return [SLOTS[i], SLOT_SCALE[i]]

func play_serve_anim() -> void:
	_player_target = 246.0
	_busy = 1.0

func _process(delta: float) -> void:
	_t += delta
	var away := Game.player_away()
	if _busy > 0.0:
		_busy -= delta
		if _busy < 0.5: _player_target = PLAYER_POS.x
	if _arriving: _player_target = PLAYER_POS.x
	var moving := absf(_player_x - _player_target) > 0.6
	_player_x = move_toward(_player_x, _player_target, delta * (95.0 if _arriving else 130.0))
	player.visible = not away
	var y := PLAYER_POS.y
	if _arriving:
		var f := clampf((DOOR.x - _player_x) / (DOOR.x - PLAYER_POS.x), 0.0, 1.0)
		y = lerpf(DOOR.y, PLAYER_POS.y, f)
		if not moving: _arriving = false
	player.position = Vector2(_player_x, y)
	player.walking = moving
	var dir := -1.0 if _player_target < _player_x - 0.5 else 1.0
	player.scale = Vector2(PSCALE * (dir if moving else 1.0), PSCALE)
	# transporte al llegar
	var tr_tex: String = DB.TRANSPORTS[Game.s["transport"]]["tex"]
	ride.visible = _arriving and tr_tex != "" and _player_x > 290.0
	if ride.visible:
		ride.texture = Art.tex(tr_tex)
		ride.position = player.position + Vector2(-8, -ride.texture.get_height() / 3.0)
		ride.flip_h = true
	clerk.visible = int(Game.s["clerks"]) > 0 and Game.shop_stage() > 0
	# clientes
	var remove := []
	for cid in sprites:
		var d: Dictionary = sprites[cid]
		var p: Node2D = d["p"]
		var target: Vector2; var ts: float
		if d["leaving"]:
			target = DOOR + Vector2(16, 0); ts = 0.44
		else:
			var sl := _slot(d["c"]); target = sl[0]; ts = sl[1]
		var walking := p.position.distance_to(target) > 0.8
		p.position = p.position.move_toward(target, delta * 60.0)
		var sc := move_toward(absf(p.scale.y), ts, delta * 0.4)
		var face := -1.0 if (walking and target.x < p.position.x) else 1.0
		p.scale = Vector2(sc * face, sc)
		p.walking = walking
		p.modulate.a = clampf((DOOR.x + 18 - p.position.x) / 10.0, 0.0, 1.0) if d["leaving"] else 1.0
		if d["leaving"] and p.position.distance_to(target) < 1.0: remove.append(cid)
	for cid in remove:
		sprites[cid]["p"].queue_free()
		sprites.erase(cid)
	# tarde: despues de cerrar se oscurece un poco
	var night := 0.0
	if Game.phase() == "closed" or Game.at_home(): night = 1.0
	elif Game.phase() == "morning" and not Game.tutorial_on(): night = 0.25
	var target_mod := Color(1, 1, 1).lerp(Color(0.72, 0.68, 0.88), night)
	modulate = modulate.lerp(target_mod, minf(1.0, delta * 2.0))
	top.queue_redraw()

func _clerk_look() -> Dictionary:
	return {"gender": "f", "body": "normal", "skin": 2, "face": "feliz", "hair": "coleta", "hair_color": 0, "acc": "ninguno", "top": "mandil", "top_color": 3, "pants": "pantalon", "pants_color": 1, "shoes": 0}

func _visitor_look() -> Dictionary:
	return {"gender": "m", "body": "broad", "skin": 1, "face": "bigote", "hair": "corto", "hair_color": 0, "acc": "sombrero", "top": "camisa", "top_color": 1, "pants": "pantalon", "pants_color": 0, "shoes": 1}

func handle_tap(pos: Vector2) -> void:
	if Game.shop_stage() == 0:
		for sp in dirt_layer.get_children():
			var r := Rect2(sp.position - Vector2(8, 8), Vector2(56, 56))
			if r.has_point(pos):
				var idx: int = sp.get_meta("idx")
				if Game.clean_spot(idx):
					UI.float_text(self, sp.position, "-1 " + L.t("energy"), UI.YELLOW)
					_refresh_static()
				return
	for vid in drivers:
		var dp: Node2D = drivers[vid]
		if Rect2(dp.position - Vector2(18, 130), Vector2(36, 134)).has_point(pos):
			driver_tapped.emit(vid)
			return
	if visitor.visible and Rect2(visitor.position - Vector2(26, 140), Vector2(56, 144)).has_point(pos):
		visitor_tapped.emit()
		return
	for cid in sprites:
		var d: Dictionary = sprites[cid]
		if d["leaving"] or d["c"].has("clerk"): continue
		var p: Node2D = d["p"]
		var s := absf(p.scale.y)
		if Rect2(p.position - Vector2(30, 190) * s, Vector2(60, 194) * s).has_point(pos):
			selected_cid = cid
			customer_tapped.emit(d["c"])
			return
