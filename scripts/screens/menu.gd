extends Control
## Menu principal.

var walker: Node2D
var wb: Sprite2D
var _t := 0.0

func _ready() -> void:
	var main := get_parent()
	var scene := Node2D.new()
	add_child(scene)
	scene.add_child(Art.sprite("facade_new"))
	var latest := Game.latest_slot()
	var look := Art.default_look("m")
	if latest >= 0:
		var inf := Game.slot_info(latest)
		if inf.has("look") and inf["look"] is Dictionary and not inf["look"].is_empty(): look = inf["look"]
	wb = Art.sprite("veh_wheelbarrow_1")
	scene.add_child(wb)
	walker = Art.person(look)
	walker.scale = Vector2(0.42, 0.42)
	walker.position = Vector2(-40, 246)
	walker.walking = true
	walker.pushing = true
	scene.add_child(walker)

	var col := UI.vbox(10)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 26; col.offset_right = -26; col.offset_top = 284; col.offset_bottom = -20
	add_child(col)
	var t1 := UI.label(L.t("logo_top"), 18, UI.BONE)
	t1.add_theme_font_override("font", UI.f_ui_bold)
	t1.add_theme_font_size_override("font_size", 20)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t1)
	var t2 := Label.new()
	t2.text = L.t("logo_bottom")
	t2.add_theme_font_override("font", UI.f_title)
	t2.add_theme_font_size_override("font_size", 46)
	t2.add_theme_color_override("font_color", UI.YELLOW)
	t2.add_theme_color_override("font_outline_color", UI.BONE)
	t2.add_theme_constant_override("outline_size", 10)
	t2.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.06, 0.6))
	t2.add_theme_constant_override("shadow_offset_y", 4)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t2)
	var sub := UI.talk_label(L.t("subtitle"), 17, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(UI.spacer(false))
	if latest >= 0:
		var inf := Game.slot_info(latest)
		var cont := func() -> void:
			if Game.load_game(latest):
				main.goto("game")
		col.add_child(UI.btn(L.t("continue"), cont, "primary", 48))
		var info := UI.label("%s · %s %d · %s" % [inf["name"], L.t("day"), int(inf["day"]), UI.money(int(inf["money"]))], 15, UI.DIM)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(info)
	col.add_child(UI.btn(L.t("new_game"), func(): main.goto("slots", {"mode": "new"}), "primary" if latest < 0 else "normal", 46))
	if latest >= 0:
		col.add_child(UI.btn(L.t("load_game"), func(): main.goto("slots", {"mode": "load"}), "normal", 46))
	col.add_child(UI.btn(L.t("options"), func(): main.goto("options", {"back": "menu"}), "normal", 46))
	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version")) + " · " + L.t("prototype"), 12, UI.DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)

func _process(delta: float) -> void:
	_t += delta
	walker.position.x += delta * 34.0
	if walker.position.x > 420: walker.position.x = -60
	var hands: Vector2 = walker.hands_local() * 0.42
	var k := (-hands.y) / 16.0
	wb.scale = Vector2(k / 3.0, k / 3.0)
	wb.centered = false
	wb.position = Vector2(walker.position.x + absf(hands.x) - 4.0 * k, walker.position.y - 38.0 * k + (0.6 if int(_t * 8) % 2 == 0 else 0.0))

func on_back() -> void:
	Game.save_game()
	get_tree().quit()
