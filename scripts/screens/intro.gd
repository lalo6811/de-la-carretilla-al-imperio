extends Control
## Intro en vinetas: pierdes tu trabajo, tu abuelo te deja el local y la carretilla.

var args := {}
var page := 0
var scene: Node2D
var text_label: Label
var hint: Label
var _shown := 0.0
var _full := ""
var _t := 0.0
var _actors: Array = []   # [person, kind]

class Rain extends Node2D:
	## Lluvia animada con gotas y salpicaduras
	var _t := 0.0
	var drops := []
	func _ready() -> void:
		var r := RandomNumberGenerator.new(); r.seed = 7
		for i in 90: drops.append([r.randf_range(0, 380), r.randf_range(0, 272), r.randf_range(260, 360)])
	func _process(delta: float) -> void:
		_t += delta
		for d in drops:
			d[1] += d[2] * delta; d[0] -= d[2] * 0.3 * delta
			if d[1] > 272:
				d[1] = -10; d[0] = randf_range(0, 400)
		queue_redraw()
	func _draw() -> void:
		for d in drops:
			draw_line(Vector2(d[0], d[1]), Vector2(d[0] - 3, d[1] + 10), Color(0.75, 0.82, 0.95, 0.55), 1.2)
		for i in 6:
			var x := fmod(i * 67.0 + _t * 40.0, 360.0)
			var a := fmod(_t * 3.0 + i * 0.37, 1.0)
			draw_arc(Vector2(x, 252 + (i % 3) * 6), 2.0 + a * 6.0, PI, TAU, 8, Color(0.8, 0.86, 1.0, 0.6 * (1.0 - a)), 1.0)

class Car extends Node2D:
	## Coche que pasa con faros (para la calle de noche)
	var _x := 420.0
	func _process(delta: float) -> void:
		_x -= delta * 120.0
		if _x < -160: _x = 520.0
		queue_redraw()
	func _draw() -> void:
		var y := 236.0
		draw_rect(Rect2(_x, y, 70, 18), Color("8a3a2a"))
		draw_rect(Rect2(_x + 14, y - 12, 36, 13), Color("6a2a1e"))
		draw_rect(Rect2(_x + 18, y - 9, 13, 8), Color("9fb4d0"))
		draw_rect(Rect2(_x + 34, y - 9, 13, 8), Color("9fb4d0"))
		draw_circle(Vector2(_x + 14, y + 18), 6, Color("1e1a20"))
		draw_circle(Vector2(_x + 56, y + 18), 6, Color("1e1a20"))
		draw_colored_polygon(PackedVector2Array([Vector2(_x, y + 6), Vector2(_x - 60, y - 4), Vector2(_x - 60, y + 22)]), Color(1, 0.95, 0.7, 0.25))
		draw_circle(Vector2(_x + 1, y + 6), 3, Color("fff2b0"))

const PAGES := [
	{"bg": "intro_office", "text": "intro_1", "who": "sad"},
	{"bg": "intro_street", "text": "intro_2", "who": "walk_rain"},
	{"bg": "intro_letter", "text": "intro_3", "who": "letter"},
	{"bg": "facade_old", "text": "intro_4", "who": "arrive"},
	{"bg": "facade_old", "text": "intro_5", "who": "determined"},
]

func _ready() -> void:
	var holder := Control.new()
	holder.position = Vector2(0, 60)
	holder.size = Vector2(360, 272)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	scene = Node2D.new()
	holder.add_child(scene)
	var top := UI.hbox()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12; top.offset_right = -12; top.offset_top = 12
	add_child(top)
	var t := UI.label(L.t("intro_title"), 16, UI.BONE, true)
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UI.btn(L.t("skip"), _finish, "ghost", 34))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.paper_style(14))
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14; box.offset_right = -14; box.offset_top = 348; box.offset_bottom = -64
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	text_label = UI.talk_label("", 21)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)
	hint = UI.label(L.t("tap_continue"), 14, UI.SAND)
	hint.add_theme_font_override("font", UI.f_ui_bold)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -52; hint.offset_bottom = -30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_show_page()

func _show_page() -> void:
	for c in scene.get_children(): c.queue_free()
	_actors.clear()
	var p: Dictionary = PAGES[page]
	scene.add_child(Art.sprite(p["bg"]))
	var look: Dictionary = Game.s.get("look", Art.default_look("m"))
	match String(p["who"]):
		"sad":
			# compañeros en sus cubiculos y el jefe en la puerta de gerencia
			var r := RandomNumberGenerator.new(); r.seed = 11
			for cx in [60.0, 180.0]:
				var cw := _add(Art.random_look(r), Vector2(cx, 214), "idle")
				cw.scale = Vector2(0.42, 0.42)
				cw.set_mood("think")
				scene.move_child(cw, 1)
			var boss := {"gender": "m", "body": "round", "skin": 0, "face": "serio", "hair": "de_lado", "hair_color": 1, "acc": "lentes",
				"top": "camisa", "top_color": 7, "pants": "pantalon", "pants_color": 0, "shoes": 0}
			var bp := _add(boss, Vector2(296, 248), "idle")
			bp.scale = Vector2(-0.56, 0.56)
			var a := _add(look, Vector2(150, 262), "sad")
			a.set_mood("sad")
			scene.add_child(Art.sprite("dirt_box", Vector2(172, 228)))
		"walk_rain":
			scene.add_child(Car.new())
			_add(look, Vector2(-30, 250), "walk").set_mood("sad")
			scene.add_child(Rain.new())
		"letter":
			var gp := _add(Art.grandpa_look(), Vector2(40, 262), "idle")
			gp.modulate = Color(1, 1, 1, 0.7)
			gp.set_mood("smile")
			var lbl := UI.hand_label(L.t("letter_text"), 17, Color("4a3424"))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.position = Vector2(86, 32); lbl.size = Vector2(196, 210)
			lbl.rotation = deg_to_rad(-2)
			scene.add_child(lbl)
		"arrive":
			_add(look, Vector2(-30, 246), "walk_to")
			scene.add_child(Art.sprite("veh_wheelbarrow_0", Vector2(230, 212)))
		"determined":
			var a := _add(look, Vector2(170, 246), "happy")
			a.set_mood("happy")
			scene.add_child(Art.sprite("veh_wheelbarrow_0", Vector2(196, 222)))
	_full = L.t(p["text"])
	_shown = 0.0
	text_label.text = ""
	Sfx.play("page")

func _add(look: Dictionary, pos: Vector2, kind: String) -> Node2D:
	var p := Art.person(look)
	p.position = pos
	p.scale = Vector2(0.6, 0.6)
	scene.add_child(p)
	_actors.append([p, kind])
	return p

func _process(delta: float) -> void:
	_t += delta
	if _shown < _full.length():
		_shown += delta * 38.0
		text_label.text = _full.substr(0, int(_shown))
	hint.visible = _shown >= _full.length() and int(_t * 2) % 2 == 0
	for a in _actors:
		var p: Node2D = a[0]
		match String(a[1]):
			"walk":
				p.walking = true
				p.position.x += delta * 30.0
				if p.position.x > 400: p.position.x = -40
			"walk_to":
				p.walking = p.position.x < 190
				if p.walking: p.position.x += delta * 50.0
			"happy":
				if p.mood != "happy": p.set_mood("happy")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _advance() -> void:
	if _shown < _full.length():
		_shown = _full.length()
		text_label.text = _full
		return
	page += 1
	if page >= PAGES.size():
		_finish()
	else:
		_show_page()

func _finish() -> void:
	Game.s["intro_seen"] = true
	Game.save_game()
	get_parent().goto("game")

func on_back() -> void:
	_finish()
