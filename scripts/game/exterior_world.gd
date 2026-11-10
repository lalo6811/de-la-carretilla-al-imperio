extends Node2D
## Vista por fuera del local o de la casa: se ven las mejoras, la flotilla y el transporte.

var which := "shop"
var bg: Sprite2D
var player: Node2D
var _t := 0.0
var _walkers: Array = []

func _ready() -> void:
	bg = Sprite2D.new(); bg.centered = false; bg.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(bg)
	var parked := Node2D.new(); add_child(parked)
	if which == "shop":
		bg.texture = Art.tex("ext_shop_%d" % Game.shop_stage())
		var x := 10.0
		for v in Game.s["fleet"]:
			if v["trip"] != null: continue
			var t := Art.tex(Game.vehicle_tex(v))
			var sp := Sprite2D.new(); sp.centered = false; sp.texture = t; sp.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
			var w := t.get_width() / 3.0
			if x + w > 356: break
			sp.position = Vector2(x, 262 - t.get_height() / 3.0)
			parked.add_child(sp)
			x += w + 6
	else:
		bg.texture = Art.tex("ext_house_%d" % Game.house_stage())
		var tr: String = DB.TRANSPORTS[Game.s["transport"]]["tex"]
		if tr != "":
			var t2 := Art.tex(tr)
			var s2 := Sprite2D.new(); s2.centered = false; s2.texture = t2; s2.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
			s2.position = Vector2(244, 222 - t2.get_height() / 3.0)
			parked.add_child(s2)
	player = Art.person(Game.s["look"])
	player.scale = Vector2(0.5, 0.5)
	player.position = Vector2(150 if which == "shop" else 130, 222)
	player.visible = not Game.player_away()
	add_child(player)
	# gente pasando por la banqueta
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.s["seed"]) + Game.shop_stage()
	for i in 2:
		var p := Art.person(Art.random_look(rng))
		p.scale = Vector2(0.46, 0.46)
		p.position = Vector2(rng.randf_range(0, 360), 224)
		p.walking = true
		add_child(p)
		_walkers.append([p, 18.0 + i * 9.0 if i % 2 == 0 else -22.0])

func _process(delta: float) -> void:
	_t += delta
	for w in _walkers:
		var p: Node2D = w[0]
		var sp: float = w[1]
		p.position.x += sp * delta
		p.scale.x = 0.46 * signf(sp)
		if p.position.x > 380: p.position.x = -20
		if p.position.x < -20: p.position.x = 380

func handle_tap(_pos: Vector2) -> void:
	player.set_mood("happy", 1.2)
