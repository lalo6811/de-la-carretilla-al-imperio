extends Node2D
## Escenario de la casa.

const FLOOR := 252.0
var bg: Sprite2D
var player: Node2D
var ride: Sprite2D
var overlay: Node2D
var _t := 0.0
var _x := 200.0
var _target := 200.0
var _wait := 2.0
var sleeping := 0.0

class Overlay extends Node2D:
	var world
	func _draw() -> void:
		if world == null or world.sleeping <= 0.0: return
		var a := clampf(world.sleeping, 0.0, 1.0)
		draw_rect(Rect2(0, 0, 360, 272), Color(0.08, 0.05, 0.12, 0.85 * a))
		var U = get_node("/root/UI")
		for i in 3:
			var y := 120.0 - fmod(world._t * 20.0 + i * 16.0, 50.0)
			draw_string(U.f_title, Vector2(160 + i * 12, y), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16 + i * 4, Color("f7eedb"))

func _ready() -> void:
	bg = Sprite2D.new(); bg.centered = false; bg.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(bg)
	ride = Sprite2D.new(); ride.centered = false; ride.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	add_child(ride)
	player = Art.person(Game.s["look"])
	player.scale = Vector2(0.62, 0.62)
	add_child(player)
	overlay = Overlay.new(); overlay.world = self; add_child(overlay)

func _process(delta: float) -> void:
	_t += delta
	bg.texture = Art.tex("house_%d" % Game.house_stage())
	var tex: String = DB.TRANSPORTS[Game.s["transport"]]["tex"]
	ride.visible = tex != ""
	if ride.visible:
		ride.texture = Art.tex(tex)
		ride.position = Vector2(318 - ride.texture.get_width() / 3.0, 254 - ride.texture.get_height() / 3.0)
	var moving := absf(_x - _target) > 0.6
	if not moving:
		_wait -= delta
		if _wait <= 0.0:
			_target = randf_range(150.0, 250.0)
			_wait = randf_range(2.5, 5.0)
	_x = move_toward(_x, _target, delta * 30.0)
	player.visible = not Game.player_away() and sleeping <= 0.0
	player.position = Vector2(_x, FLOOR)
	player.walking = moving
	player.scale = Vector2(0.62 * (-1.0 if moving and _target < _x else 1.0), 0.62)
	if sleeping > 0.0: sleeping -= delta
	overlay.queue_redraw()

func handle_tap(_pos: Vector2) -> void:
	player.set_mood("happy", 1.2)
