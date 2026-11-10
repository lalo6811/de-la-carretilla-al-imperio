extends Node2D
## Trayecto entre la casa y el local: la calle se recorre de lado con tu transporte.

signal finished

var to_home := true
var duration := 2.8
var _t := 0.0
var _a: Sprite2D
var _b: Sprite2D
var player: Node2D
var ride: Sprite2D
var _label: Label
var _done := false
const GROUND := 236.0

func _ready() -> void:
	var tex := Art.tex("street_night" if to_home else "street_day")
	_a = Sprite2D.new(); _a.centered = false; _a.texture = tex; _a.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	_b = Sprite2D.new(); _b.centered = false; _b.texture = tex; _b.scale = _a.scale
	add_child(_a); add_child(_b)
	var tr: String = DB.TRANSPORTS[Game.s["transport"]]["tex"]
	ride = Sprite2D.new(); ride.centered = false; ride.scale = Vector2(1.0 / 3.0, 1.0 / 3.0)
	ride.visible = tr != ""
	if ride.visible: ride.texture = Art.tex(tr)
	player = Art.person(Game.s["look"])
	player.scale = Vector2(0.6, 0.6)
	add_child(player)
	add_child(ride)
	if ride.visible and Game.s["transport"] != "vocho":
		move_child(ride, get_child_count() - 2)   # la persona va encima de la bici o moto
	_label = UI.label(L.t("walking_home") if to_home else L.t("walking_shop"), 18, UI.YELLOW, true)
	_label.position = Vector2(14, 10)
	var st := UI.sb(Color(0.16, 0.1, 0.06, 0.75), Color(0, 0, 0, 0), 0, 6, false, 8)
	_label.add_theme_stylebox_override("normal", st)
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	var speed := 60.0 if not ride.visible else (95.0 if Game.s["transport"] == "bici" else 140.0)
	var tile_w := 720.0
	var off := fmod(_t * speed, tile_w)
	# hacia la casa vamos a la izquierda, al local a la derecha
	var dir := -1.0 if to_home else 1.0
	_a.position.x = -off if dir > 0 else off - tile_w
	_b.position.x = _a.position.x + tile_w
	var cx := 180.0
	player.walking = not ride.visible
	player.scale = Vector2(0.6 * dir, 0.6)
	if ride.visible:
		var rw := ride.texture.get_width() / 3.0
		var rh := ride.texture.get_height() / 3.0
		ride.flip_h = dir < 0
		ride.position = Vector2(cx - rw / 2.0, GROUND + 14 - rh + sin(_t * 18.0) * 0.6)
		player.visible = Game.s["transport"] != "vocho"
		player.position = Vector2(cx - 2.0 * dir, GROUND - rh * 0.35)
	else:
		player.position = Vector2(cx, GROUND + 14)
	if _t >= duration and not _done:
		_done = true
		finished.emit()

func handle_tap(_pos: Vector2) -> void:
	pass
