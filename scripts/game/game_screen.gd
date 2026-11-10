extends Control
## Pantalla principal: barra de madera arriba (caja registradora, tornillos, termo, reloj, flexometro),
## escenario, panel (nota de remision, inventario, proveedor, mina, casa, plano de mejoras, tienda)
## y barra de madera abajo con objetos.

var args := {}
var tab := "local"
var sub_local := "counter"

const HUD_H := 66
const WORLD_TOP := 66
const WORLD_H := 272
const NAV_H := 64
const OVERLAP := 8

var hud_money: Label
var hud_bolts: Label
var hud_energy: Label
var hud_day: Label
var hud_clock: Label
var hud_level: Label
var tape: Flexo
var spot: Control
var tut_targets := {}
var _sig := ""
var _release_t := 0.0
var _ms_t := 3.0
var _transit := false
var outside := false
var worlds := {}              # escenarios vivos (no se reinician al cambiar de lugar)
var pop_targets := {}         # objetivos del tutorial dentro de popups (no se borran al reconstruir)
var supplier_urgent := false
var world_holder: Control
var world: Node2D
var panel_scroll: ScrollContainer
var nav_buttons := {}
var dyn: Array = []
var _dirty := true
var _dirty_t := 0.0
var selected: Dictionary = {}
var _tip_hidden := ""

# ---------------------------------------------------------------- widgets
class Flexo extends Control:
	## Nivel como flexometro: estuche amarillo con el nivel y la cinta que sale con la experiencia
	var value := 0.0
	var max_value := 1.0
	var level := 1
	var font: Font
	var _shown := 0.0
	func _process(delta: float) -> void:
		var f := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
		if absf(_shown - f) > 0.001:
			_shown = move_toward(_shown, f, delta * 0.8) if f > _shown else f
			queue_redraw()
	func _draw() -> void:
		var h := size.y
		var case_w := h * 1.25
		var tape_h := h * 0.42
		var ty := h * 0.5 - tape_h * 0.5
		var x0 := case_w - 4.0
		var full := size.x - x0 - 6.0
		# riel vacio
		draw_rect(Rect2(x0, ty + tape_h * 0.35, full, tape_h * 0.3), Color(0, 0, 0, 0.25))
		var w := maxf(6.0, full * _shown)
		draw_rect(Rect2(x0, ty, w, tape_h), Color("f2d64a"))
		draw_rect(Rect2(x0, ty, w, tape_h), Color("3a2618"), false, 1.2)
		var i := 0
		var x := x0 + 4.0
		while x < x0 + w - 2.0:
			var tick := tape_h * (0.8 if i % 5 == 0 else 0.45)
			draw_line(Vector2(x, ty), Vector2(x, ty + tick), Color("3a2618"), 1.0)
			x += 5.0; i += 1
		# gancho de la punta
		draw_rect(Rect2(x0 + w - 1.0, ty - 3, 4, tape_h + 6), Color("8a8f96"))
		draw_rect(Rect2(x0 + w - 1.0, ty - 3, 4, tape_h + 6), Color("3a2618"), false, 1.0)
		# estuche
		var c := Rect2(0, 0, case_w, h)
		draw_rect(c, Color("f2b632"))
		draw_rect(Rect2(0, h * 0.62, case_w, h * 0.38), Color("d9952a"))
		draw_rect(c, Color("3a2618"), false, 2.0)
		draw_circle(Vector2(case_w * 0.5, h * 0.5), h * 0.36, Color("2b211b"))
		if font:
			var t := str(level)
			var fs := int(h * 0.48)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(case_w * 0.5 - tw * 0.5, h * 0.5 + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f2d64a"))

class RoadBar extends Control:
	## Camino a la mina con el vehiculo avanzando (de regreso va volteado)
	var value := 0.0
	var tex: Texture2D
	func _draw() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, h - 8, w, 6), Color("8a6a4a"))
		var x := 4.0
		while x < w:
			draw_rect(Rect2(x, h - 5.5, 6, 1.5), Color("f2d64a"))
			x += 12.0
		if tex:
			var th := h - 4.0
			var tw := th * tex.get_width() / float(tex.get_height())
			var p := clampf(value, 0.0, 1.0)
			var px := 0.0
			if p < 0.5: px = lerpf(0.0, w - tw, p * 2.0)
			else: px = lerpf(w - tw, 0.0, (p - 0.5) * 2.0)
			if p < 0.5:
				draw_texture_rect(tex, Rect2(px, 0, tw, th), false)
			else:
				draw_texture_rect(tex, Rect2(px + tw, 0, -tw, th), false)

# ---------------------------------------------------------------- inicio
func _ready() -> void:
	tab = args.get("tab", "local")
	_build_layout()
	Game.changed.connect(_mark_dirty)
	Game.customers_changed.connect(_mark_dirty)
	Game.toast.connect(_on_toast)
	Game.level_up.connect(_on_level_up)
	Game.day_ended.connect(_on_day_ended)
	Game.trip_finished.connect(_on_trip_finished)
	Game.tutorial_changed.connect(_mark_dirty)
	Game.customer_left.connect(_on_customer_left)
	Game.passed_by.connect(_on_passed_by)
	Game.achievement.connect(_on_achievement)
	Game.phase_changed.connect(_mark_dirty)
	Game.playing = true
	Game.paused = false
	spot = load("res://scripts/game/spotlight.gd").new()
	var spot_layer := CanvasLayer.new()
	spot_layer.layer = 50
	add_child(spot_layer)
	spot_layer.add_child(spot)
	if Game.at_home() and tab == "local": tab = "house"
	_set_tab(tab)
	if not Game.offline_report.is_empty() and (int(Game.offline_report.get("earned", 0)) > 0 or int(Game.offline_report.get("trips", 0)) > 0):
		_show_offline_report()
	Game.offline_report = {}

func _on_passed_by() -> void:
	if tab == "local":
		UI.toast(L.t("line_full"), UI.CORAL)

func _on_toast(t: String) -> void:
	UI.toast(t)

func _on_trip_finished(_v: Dictionary) -> void:
	_mark_dirty()

func _on_customer_left(c: Dictionary, _happy: bool) -> void:
	if not selected.is_empty() and selected.get("cid") == c["cid"]:
		selected = {}

# ---------------------------------------------------------------- layout
func _pill(parent: Control, ic: String, bg: Color, fg: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(bg, Color("7a5a1a"), 2, 6, false, 16))
	var h := UI.hbox(3)
	h.add_child(UI.icon(ic, 20))
	var l := Label.new()
	l.add_theme_font_override("font", UI.f_ui_bold)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", fg)
	h.add_child(l)
	p.add_child(h)
	parent.add_child(p)
	return l

func _build_layout() -> void:
	# --- barra de arriba (madera)
	var hud := UI.wood_bar(6)
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = HUD_H
	add_child(hud)
	var hv := UI.vbox(4)
	hud.add_child(hv)
	var r1 := UI.hbox(5)
	hv.add_child(r1)
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override("panel", UI.sb(Color("1f3a2e"), Color("1b120c"), 3, 6, false, 6))
	lcd.custom_minimum_size = Vector2(98, 0)
	hud_money = Label.new()
	hud_money.add_theme_font_override("font", UI.f_title)
	hud_money.add_theme_font_size_override("font_size", 19)
	hud_money.add_theme_color_override("font_color", Color("8fe8ab"))
	hud_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcd.add_child(hud_money)
	r1.add_child(lcd)
	hud_bolts = _pill(r1, "ic_bolt", UI.YELLOW, UI.INK)
	hud_energy = _pill(r1, "ic_energy", UI.PANEL, UI.INK)
	r1.add_child(UI.spacer())
	var ck := UI.hbox(3)
	ck.add_child(UI.icon("ic_note", 26) if ResourceLoader.exists("res://assets/vec/ic_note.png") else UI.icon("ic_clock", 28))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", -4)
	hud_day = UI.label("", 12, UI.LIGHT)
	hud_clock = Label.new()
	hud_clock.add_theme_font_override("font", UI.f_ui_bold)
	hud_clock.add_theme_font_size_override("font_size", 15)
	hud_clock.add_theme_color_override("font_color", UI.YELLOW)
	cv.add_child(hud_day); cv.add_child(hud_clock)
	ck.add_child(cv)
	r1.add_child(ck)
	var r2 := UI.hbox(6)
	hv.add_child(r2)
	tape = Flexo.new()
	tape.font = UI.f_title
	tape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tape.custom_minimum_size = Vector2(0, 22)
	tape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(tape)
	var mb := UI.btn("", _pause_menu, "primary", 22)
	mb.icon = Art.tex("ic_menu")
	mb.custom_minimum_size = Vector2(34, 22)
	mb.add_theme_constant_override("icon_max_width", 14)
	mb.add_theme_stylebox_override("normal", UI.sb(UI.YELLOW, Color("3a2618"), 1, 2, false, 4))
	r2.add_child(mb)
	# --- escenario
	world_holder = Control.new()
	world_holder.position = Vector2(0, WORLD_TOP)
	world_holder.size = Vector2(360, WORLD_H)
	world_holder.clip_contents = true
	world_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	world_holder.gui_input.connect(_on_world_input)
	add_child(world_holder)
	move_child(world_holder, 0)
	# --- panel
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_scroll.offset_top = WORLD_TOP + WORLD_H - OVERLAP
	panel_scroll.offset_bottom = -NAV_H
	panel_scroll.offset_left = 8
	panel_scroll.offset_right = -8
	add_child(panel_scroll)
	# --- barra de abajo (madera con objetos)
	var nav := UI.wood_bar(4)
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -NAV_H
	add_child(nav)
	var nh := UI.hbox(2)
	nav.add_child(nh)
	for t in [["local", "nav_local"], ["mine", "nav_mine"], ["house", "nav_house"], ["upgrades", "nav_up"], ["store", "nav_shop"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Art.tex("ic_" + t[1])
		b.text = L.t("tab_" + t[0])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.add_theme_font_override("font", UI.f_ui_bold)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_constant_override("icon_max_width", 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, NAV_H - 8)
		var tname: String = t[0]
		b.pressed.connect(func():
			Sfx.play("click")
			_nav_pressed(tname))
		nh.add_child(b)
		nav_buttons[t[0]] = b

func _set_tab(t: String) -> void:
	tab = t
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		var on: bool = k == t
		var st := UI.sb(Color(1, 1, 1, 0.12) if on else Color(0, 0, 0, 0), UI.YELLOW if on else Color(0, 0, 0, 0), 2, 3, false, 10)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		b.add_theme_color_override("font_color", UI.YELLOW if on else Color("e4d2b8"))
		b.add_theme_color_override("font_hover_color", UI.YELLOW if on else UI.LIGHT)
	_load_world()
	_rebuild()

func _world_key() -> String:
	if tab == "mine": return "mine"
	var home := tab == "house" or ((tab == "upgrades" or tab == "store") and Game.at_home())
	if outside and (tab == "local" or tab == "house"): return "ext_house" if home else "ext_shop"
	return "house" if home else "shop"

func _load_world() -> void:
	## Los escenarios se crean una vez y solo se esconden: la gente sigue donde estaba
	var key := _world_key()
	# la casa y la vista de afuera se rehacen si cambio la etapa
	var stamp := "%d-%d-%d-%s" % [Game.shop_stage(), Game.house_stage(), Game.s["fleet"].size(), Game.s["transport"]]
	if worlds.has(key) and key != "shop" and key != "mine" and worlds[key].get_meta("stamp", "") != stamp:
		worlds[key].queue_free()
		worlds.erase(key)
	for k in worlds:
		worlds[k].visible = k == key
	if not worlds.has(key):
		var path := "res://scripts/game/shop_world.gd"
		match key:
			"mine": path = "res://scripts/game/mine_world.gd"
			"house": path = "res://scripts/game/house_world.gd"
			"ext_shop", "ext_house": path = "res://scripts/game/exterior_world.gd"
		var w: Node2D = (load(path) as GDScript).new()
		if key.begins_with("ext_"): w.which = "house" if key == "ext_house" else "shop"
		w.set_meta("stamp", stamp)
		world_holder.add_child(w)
		if w.has_signal("customer_tapped"):
			w.customer_tapped.connect(_on_customer_tapped)
			w.visitor_tapped.connect(_visitor_popup)
			w.driver_tapped.connect(_on_driver_tapped)
		worlds[key] = w
	world = worlds[key]

func _on_driver_tapped(vid: int) -> void:
	Sfx.play("click")
	_load_popup(vid, false)

func _toggle_outside() -> void:
	outside = not outside
	# la vista de afuera siempre se arma de nuevo (muestra lo que tienes ahorita)
	for k in ["ext_shop", "ext_house"]:
		if worlds.has(k):
			worlds[k].queue_free()
			worlds.erase(k)
	_load_world()
	_rebuild()

func _nav_pressed(t: String) -> void:
	if _transit: return
	var step := int(Game.s.get("tutorial", 5))
	if t == "house" and not Game.at_home():
		if Game.tutorial_on() and step < 4:
			UI.toast(_tutorial_text(), UI.SAND)
			return
		if step == 4:
			_go_home()
		else:
			UI.confirm(L.t("go_home"), L.t("go_home_q"), _go_home, L.t("go_home"))
		return
	if Game.at_home() and t == "local":
		UI.toast(L.t("at_home_locked"), UI.SAND)
		return
	outside = false
	_set_tab(t)

func _go_home() -> void:
	Game.go_home()
	outside = false
	_play_transit(true, func(): _set_tab("house"))

func _play_transit(to_home: bool, done: Callable) -> void:
	## Animacion de la calle entre la casa y el local
	_transit = true
	for k in worlds: worlds[k].visible = false
	var st = load("res://scripts/game/street_world.gd").new()
	st.to_home = to_home
	world = st
	world_holder.add_child(st)
	for c in panel_scroll.get_children(): c.queue_free()
	dyn.clear()
	st.finished.connect(func():
		_transit = false
		st.queue_free()
		done.call())

func _on_customer_tapped(c: Dictionary) -> void:
	selected = c
	if tab != "local": _set_tab("local")
	if world and "selected_cid" in world: world.selected_cid = int(c["cid"])
	sub_local = "counter"
	_rebuild()

func _mark_dirty() -> void:
	_dirty = true

func _signature() -> String:
	## Todo lo que cambia la forma del panel. El dinero solo cuenta donde decide si se puede comprar.
	var gs := Game.s
	var parts := [tab, sub_local, gs["tutorial"], gs["at_home"], Game.player_away(), Game.shop_open(), Game.level(), Game.phase(),
		gs["day"], gs["encargos"].size(), str(gs["supplier_orders"]), supplier_urgent, outside, int(gs["energy"]) < DB.SERVE_ENERGY,
		gs["shop_stage"], gs["house_stage"], gs["wb_tier"], gs["clerks"], gs["tools"].size(), gs["transport"], gs["transports"].size(),
		gs["offline_tier"], gs["own_mine"], gs["starter"], gs["no_ads"], gs["dirt"].size(), int(gs["energy"]) if tab == "house" else 0]
	for v in gs["fleet"]:
		parts.append([v["id"], v["driver"], v["trip"] != null, v["trip"] != null and float(v["trip"]["end"]) <= Game.now()])
	if tab == "local":
		parts.append(selected.get("cid", -1))
		for c in Game.customers: parts.append(c["cid"])
		parts.append(gs["inv"].hash())
	if tab in ["upgrades", "store", "house"] or (tab == "local" and sub_local == "supplier"):
		var m := Game.money()
		parts.append(int(m / 25))
	if tab == "store":
		parts.append(str(gs["ads"]))
	return str(parts)

func _process(delta: float) -> void:
	hud_money.text = UI.money(Game.money())
	hud_bolts.text = str(Game.bolts())
	hud_energy.text = "%d/%d" % [int(Game.s["energy"]), Game.energy_max()]
	hud_day.text = "%s · %s %d" % [L.t("wds_%d" % Game.weekday()), L.t("day"), int(Game.s["day"])]
	hud_clock.text = Game.clock_text()
	hud_clock.add_theme_color_override("font_color", Color("ff9a7a") if Game.phase() != "open" or Game.at_home() else UI.YELLOW)
	tape.level = Game.level()
	tape.max_value = DB.xp_for_level(Game.level())
	tape.value = int(Game.s["xp"])
	for f in dyn:
		if f.is_valid(): f.call()
	# reconstruir el panel solo si cambio algo que se ve, y nunca a mitad de un toque
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_t = 0.18
	else:
		_release_t -= delta
	_dirty_t -= delta
	if _dirty and _dirty_t <= 0.0 and _release_t <= 0.0 and not _transit:
		_dirty = false
		_dirty_t = 0.2
		var sig := _signature()
		if sig != _sig: _rebuild()
	_update_spotlight()
	_check_milestone(delta)

func _update_spotlight() -> void:
	## Decide que senalar segun el paso del tutorial
	if spot == null: return
	spot.clear()
	if _transit or not Game.tutorial_on(): return
	var step := int(Game.s["tutorial"])
	var tgt = null
	match step:
		0:
			if tab == "local" and world and world.has_method("tutorial_target"):
				var r: Rect2 = world.tutorial_target()
				if r.size != Vector2.ZERO:
					spot.world_rect = Rect2(world_holder.global_position + r.position, r.size)
			else: tgt = nav_buttons["local"]
		1:
			tgt = tut_targets.get("stamp") if tab == "local" else nav_buttons["local"]
		2:
			if tab != "mine": tgt = nav_buttons["mine"]
			elif tut_targets.has("fill") and is_instance_valid(tut_targets["fill"]): tgt = tut_targets["fill"]
			else: tgt = tut_targets.get("go_self")
		3:
			var on_trip := false
			for v in Game.s["fleet"]:
				if v["trip"] != null: on_trip = true
			if on_trip:
				tgt = tut_targets.get("free_skip") if tab == "mine" else nav_buttons["mine"]
			else:
				tgt = tut_targets.get("stamp") if tab == "local" else nav_buttons["local"]
		4:
			tgt = tut_targets.get("sleep") if tab == "house" else nav_buttons["house"]
	# dentro del popup de carga: primero LLENAR, despues IR
	var fill = pop_targets.get("fill")
	if step == 2 and fill != null and is_instance_valid(fill):
		tgt = fill
		var go = pop_targets.get("go")
		if int(fill.get_meta("tot", 0)) > 0 and go != null and is_instance_valid(go): tgt = go
		var ptip = pop_targets.get("tip")
		spot.targets = [tgt] + ([ptip] if ptip != null and is_instance_valid(ptip) else [])
		return
	if tgt != null and is_instance_valid(tgt):
		var tip = tut_targets.get("tip")
		spot.targets = [tgt] + ([tip] if tip != null and is_instance_valid(tip) else [])

func _check_milestone(delta: float) -> void:
	_ms_t -= delta
	if _ms_t > 0.0: return
	_ms_t = 2.0
	if _transit or UI.overlay.get_child_count() > 0 or Game.tutorial_on(): return
	var ms := Game.pending_milestone()
	if ms == "": return
	Game.mark_milestone(ms)
	var content := UI.hbox(8)
	var face := UI.person_view(Art.grandpa_look(), 70, "happy", true)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(face)
	var tl := UI.talk_label(L.t("ms_" + ms), 17)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(tl)
	var go_tab := "upgrades" if ms != "pickup" else "mine"
	if ms == "morning": go_tab = "mine"
	UI.popup(L.t("ms_title"), content, [[L.t("later"), Callable()], [L.t("ms_go"), func(): _nav_pressed(go_tab), "primary"]])

func _on_world_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if world and world.has_method("handle_tap"):
			world.handle_tap(event.position)

# ---------------------------------------------------------------- consejos del abuelo
func _tutorial_text() -> String:
	var step := int(Game.s.get("tutorial", 5))
	match step:
		0: return L.t("tut_0")
		1: return L.t("tut_1")
		2: return L.t("tut_mine") if tab == "mine" else L.t("tut_2")
		3: return L.t("tut_3_mine") if tab == "mine" else L.t("tut_3")
		4: return L.t("tut_4_house") if tab == "house" else L.t("tut_4")
	return ""

func _tip_text() -> String:
	var t := _tutorial_text()
	if t != "": return t
	if tab == "local" and sub_local == "counter" and Game.phase() == "morning": return L.t("tip_morning")
	if tab == "local" and sub_local == "counter" and Game.phase() == "closed": return L.t("tip_closed")
	if tab == "mine" and not Game.mine_open(): return L.t("tip_mine_sunday")
	if tab == "local" and sub_local == "counter" and Game.customers.is_empty():
		if not Game.shop_open(): return L.t("tip_night")
		if Game.inv_qty("arena") < 4: return L.t("tip_sand")
		if int(Game.s["clerks"]) == 0 and Game.level() >= int(DB.CLERK["lvl"]): return L.t("tip_clerk")
		var tips := ["tip_smile", "tip_regulars", "tip_line", "tip_mine_cheap", "tip_rest"]
		return L.t(tips[int(Game.s["day"]) % tips.size()])
	if tab == "house" and float(Game.s["energy"]) < 5: return L.t("tip_rest")
	return ""

func _abuelo_tip(v: Control, text: String) -> Control:
	if text == "": return null
	var h := UI.hbox(6)
	var face := UI.person_view(Art.grandpa_look(), 50, "idle", true)
	var circ := PanelContainer.new()
	circ.add_theme_stylebox_override("panel", UI.sb(Color("f3e6c8"), UI.BONE, 2, 1, false, 26))
	circ.add_child(face)
	circ.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(circ)
	var bub := PanelContainer.new()
	bub.add_theme_stylebox_override("panel", UI.sb(Color("fff6d6"), UI.BONE, 2, 8, false, 10))
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	var tl := Label.new()
	tl.text = L.t("grandpa_tip")
	tl.add_theme_font_override("font", UI.f_ui_bold)
	tl.add_theme_font_size_override("font_size", 10)
	tl.add_theme_color_override("font_color", UI.SAND)
	bv.add_child(tl)
	bv.add_child(UI.talk_label(text, 16))
	bub.add_child(bv)
	h.add_child(bub)
	v.add_child(h)
	if Game.tutorial_on(): tut_targets["tip"] = h
	return h

# ---------------------------------------------------------------- panel
func _rebuild() -> void:
	_sig = _signature()
	tut_targets.clear()
	var sv := panel_scroll.scroll_vertical
	for c in panel_scroll.get_children(): c.queue_free()
	dyn.clear()
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.add_child(v)
	var top_pad := Control.new(); top_pad.custom_minimum_size = Vector2(0, OVERLAP + 2)
	v.add_child(top_pad)
	var tut := _tutorial_text()
	if tut != "": _abuelo_tip(v, tut)
	match tab:
		"local": _panel_local(v)
		"mine": _panel_mine(v)
		"house": _panel_house(v)
		"upgrades": _panel_upgrades(v)
		"store": _panel_store(v)
	if tut == "":
		_abuelo_tip(v, _tip_text())
	if (tab == "local" or tab == "house") and not Game.tutorial_on():
		var ob := UI.btn(L.t("view_inside") if outside else L.t("view_outside"), _toggle_outside, "ghost", 34)
		v.add_child(ob)
	var bottom_pad := Control.new(); bottom_pad.custom_minimum_size = Vector2(0, 6)
	v.add_child(bottom_pad)
	await get_tree().process_frame
	if is_instance_valid(panel_scroll): panel_scroll.scroll_vertical = sv

func _section(v: Control, title: String, color := UI.BONE) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_override("font", UI.f_title)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	v.add_child(l)

func _row_card(v: Control, blueprint := false) -> HBoxContainer:
	var c := UI.blueprint_card(8) if blueprint else UI.card(UI.PANEL, UI.LINE, 8)
	var h := UI.hbox(8)
	c.add_child(h)
	v.add_child(c)
	return h

func _texts(h: Control, title: String, sub: String, sub_col := UI.DIM, blueprint := false) -> VBoxContainer:
	var tv := UI.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", UI.f_title if blueprint else UI.f_ui_bold)
	tl.add_theme_font_size_override("font_size", 15)
	tl.add_theme_color_override("font_color", UI.LIGHT if blueprint else UI.BONE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(tl)
	if sub != "":
		var sl := UI.wrap_label(sub, 13, Color("c8d8f4") if blueprint else sub_col)
		tv.add_child(sl)
	h.add_child(tv)
	return tv

func _folder_tabs(v: Control, items: Array, current: String, on_pick: Callable) -> void:
	var tabs := UI.hbox(4)
	for st in items:
		var key: String = st[0]
		var pick := func() -> void:
			on_pick.call(key)
		var b := UI.btn(L.t(st[1]), pick, "primary" if current == key else "ghost", 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		tabs.add_child(b)
	v.add_child(tabs)

# ---------------------------------------------------------------- LOCAL
func _panel_local(v: VBoxContainer) -> void:
	var pick := func(k: String) -> void:
		sub_local = k
		_rebuild()
	_folder_tabs(v, [["counter", "sub_counter"], ["inventory", "sub_inventory"], ["supplier", "sub_supplier"]], sub_local, pick)
	match sub_local:
		"counter": _local_counter(v)
		"inventory": _local_inventory(v)
		"supplier": _local_supplier(v)

func _local_counter(v: VBoxContainer) -> void:
	if Game.shop_stage() == 0:
		var h := _row_card(v)
		h.add_child(UI.icon("dirt_bag", 40))
		_texts(h, L.t("clean_title"), L.t("clean_desc") % Game.s["dirt"].size())
		return
	if Game.phase() == "morning" and not Game.tutorial_on():
		_morning_card(v)
		return
	if Game.phase() == "closed" and Game.customers.is_empty():
		var hc := _row_card(v)
		hc.add_child(UI.icon("ic_star", 40))
		_texts(hc, L.t("closed_title"), L.t("closed_desc"))
		v.add_child(UI.btn(L.t("go_home"), func(): _nav_pressed("house"), "primary", 44))
		return
	if not Game.tutorial_on(): _quota_bar(v)
	if Game.player_away():
		var h := _row_card(v)
		h.add_child(UI.icon("veh_wheelbarrow_0", 40))
		var tv := _texts(h, L.t("you_are_away"), "")
		var tl := UI.label("", 15, UI.SAND)
		tv.add_child(tl)
		dyn.append(func():
			if is_instance_valid(tl): tl.text = L.t("back_in") + " " + UI.fmt_time(Game.player_trip_left()) + ("" if int(Game.s["clerks"]) == 0 else " · " + L.t("clerk_covering")))
		v.add_child(UI.wrap_label(L.t("away_wait"), 14, UI.DIM))
		return
	if Game.customers.is_empty():
		if Game.shop_open():
			var h := _row_card(v)
			h.add_child(UI.icon("ic_clock", 40))
			_texts(h, L.t("waiting_customers"), L.t("waiting_desc"))
		return
	if selected.is_empty() or not Game.customers.has(selected):
		selected = Game.customers[0]
	var c: Dictionary = selected
	if Game.customers.size() > 1:
		var q := UI.hbox(6)
		for cc in Game.customers:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(46, 46)
			var on: bool = cc == c
			b.add_theme_stylebox_override("normal", UI.sb(Color("fff6d6") if on else UI.PANEL, UI.SAND if on else UI.LINE, 2, 2, false, 23))
			b.add_theme_stylebox_override("hover", UI.sb(Color("fff6d6"), UI.SAND, 2, 2, false, 23))
			b.add_theme_stylebox_override("pressed", UI.sb(Color("fff6d6"), UI.SAND, 2, 2, false, 23))
			var face := UI.person_view(cc["look"], 42, "idle", true)
			face.position = Vector2(2, 2)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(face)
			var sel := func() -> void:
				selected = cc
				if world and "selected_cid" in world: world.selected_cid = int(cc["cid"])
				_rebuild()
			b.pressed.connect(sel)
			q.add_child(b)
		v.add_child(q)
	v.add_child(_order_note(c))
	# sello y acciones debajo de la nota
	var ok := Game.can_fulfill(c)
	var paid := int(c["price"])
	var row := UI.hbox(8)
	v.add_child(row)
	var is_del: bool = c.get("delivery", false)
	if is_del and ok and not Game.delivery_vehicle(c).is_empty():
		var fee := int(c.get("fee", 0))
		var send := UI.btn(L.t("send_delivery"), func(): _send_delivery(c), "stamp", 62)
		send.rotation = deg_to_rad(-3)
		send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(send)
		var gl := UI.label("+%s · +%d xp" % [UI.money(paid + fee), Game.xp_for_sale(paid + fee)], 12, UI.SAND)
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gl)
		row = UI.hbox(8)
		v.add_child(row)
		var self_b := UI.btn(L.t("pickup_self"), func(): _deliver(c), "ghost", 34)
		self_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(self_b)
	else:
		var stamp := UI.btn(L.t("deliver") if ok else L.t("missing"), func(): _deliver(c), "stamp" if ok else "ghost", 62)
		stamp.disabled = not ok
		stamp.rotation = deg_to_rad(-3)
		stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(stamp)
		tut_targets["stamp"] = stamp
		var gain := UI.label("+%s\n+%d xp" % [UI.money(paid - int(c.get("encargo", 0))), Game.xp_for_sale(paid)], 13, UI.SAND)
		gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gain)
	if not c.has("tut"):
		var no := UI.btn(L.t("sorry"), func(): Game.dismiss(c), "ghost", 34)
		no.custom_minimum_size.x = 96
		row.add_child(no)
	if not ok:
		var miss := Game.missing_for(c)
		var fix := UI.hbox(6)
		var any_supplier := false
		var any_mine := false
		for m in miss:
			if DB.ITEMS[m["id"]]["source"] == "supplier": any_supplier = true
			else: any_mine = true
		if any_supplier:
			var bs := UI.btn(L.t("buy_missing"), func(): _buy_missing(c), "good", 38)
			bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fix.add_child(bs)
		if any_mine:
			var mine_need := {}
			for m in miss:
				if DB.ITEMS[m["id"]]["source"] == "mine": mine_need[m["id"]] = int(m["qty"])
			var pick := _best_vehicle_for(mine_need)
			var lbl := L.t("send_for_missing") if not pick.is_empty() and pick["driver"] else L.t("go_for_missing")
			var bm := UI.btn(lbl, func(): _fetch_missing(mine_need), "primary", 38)
			bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bm.disabled = pick.is_empty() or not Game.mine_open()
			fix.add_child(bm)
		v.add_child(fix)
		var pv := Game.partial_value(c)
		if pv > 0 and not c.has("tut") and not c.has("encargo"):
			var pb := UI.btn(L.t("sell_partial") % UI.money(pv), func():
				if Game.serve_partial(c)["ok"]:
					if world and world.has_method("play_serve_anim"): world.play_serve_anim()
					selected = {}
					_rebuild(), "good", 36)
			v.add_child(pb)
		if not c.has("tut") and not c.has("encargo"):
			var dep := int(round(int(c["price"]) * DB.ENCARGO_DEPOSIT))
			var eb := UI.btn(L.t("take_encargo") % UI.money(dep), func():
				if Game.take_encargo(c):
					selected = {}
					_rebuild(), "ghost", 36)
			v.add_child(eb)

func _morning_card(v: VBoxContainer) -> void:
	## Antes de abrir: preparas material y luego abres la cortina
	var c := UI.card(UI.PAPER, Color("e2d4b4"), 10)
	var cv := UI.vbox(4)
	c.add_child(cv)
	cv.add_child(UI.label(L.t("morning_title") % Game.day_name(), 18, UI.CORAL, true))
	cv.add_child(UI.hand_label(L.t("morning_quota") % int(Game.s["day_quota"]), 24))
	var sup := L.t("sup_today") if Game.supplier_today() else L.t("sup_next") % Game.day_name(Game.next_supplier_day())
	cv.add_child(UI.label("• " + sup, 14, UI.BONE))
	cv.add_child(UI.label("• " + (L.t("mine_open_today") if Game.mine_open() else L.t("mine_closed_today")), 14, UI.BONE))
	var enc := 0
	for e in Game.s["encargos"]:
		if int(e["day"]) <= int(Game.s["day"]): enc += 1
	if enc > 0: cv.add_child(UI.label("• " + L.t("encargos_today") % enc, 14, UI.CORAL))
	if int(Game.s["clerks"]) > 0: cv.add_child(UI.label("• " + L.t("clerk_line_info") % Game.clerk_quota(), 14, UI.BONE))
	v.add_child(c)
	var ob := UI.btn(L.t("open_shop"), func():
		Game.open_shop()
		_rebuild(), "stamp", 60)
	ob.rotation = deg_to_rad(-2)
	v.add_child(ob)

func _quota_bar(v: VBoxContainer) -> void:
	var h := UI.hbox(6)
	h.add_child(UI.label(L.t("today_customers") % [int(Game.s["day_handled"]), int(Game.s["day_quota"])], 14, UI.BONE))
	h.add_child(UI.spacer())
	if int(Game.s["clerks"]) > 0:
		var cl := UI.label("", 13, UI.MINT)
		h.add_child(cl)
		dyn.append(func():
			if is_instance_valid(cl): cl.text = L.t("clerk_box") % [Game.clerk_customers.size(), int(Game.s["clerk_spawned"]), Game.clerk_quota()])
	v.add_child(h)
	v.add_child(UI.progress(int(Game.s["day_handled"]), maxi(1, int(Game.s["day_quota"])), UI.SAND, 6))

func _best_vehicle_for(need: Dictionary) -> Dictionary:
	## Elige el vehiculo libre que mejor sirve: primero con chofer, luego tu mismo
	var total := 0
	for k in need: total += int(need[k])
	var best := {}
	for v in Game.s["fleet"]:
		if v["trip"] != null or not v["driver"]: continue
		if best.is_empty(): best = v; continue
		var fits: bool = Game.vehicle_cap(v) >= total
		var best_fits: bool = Game.vehicle_cap(best) >= total
		if (fits and not best_fits) or (fits == best_fits and (Game.vehicle_cap(v) < Game.vehicle_cap(best) if fits else Game.vehicle_cap(v) > Game.vehicle_cap(best))):
			best = v
	if best.is_empty() and not Game.player_away() and not Game.at_home():
		for v in Game.s["fleet"]:
			if v["trip"] == null and (best.is_empty() or Game.vehicle_cap(v) > Game.vehicle_cap(best)): best = v
	return best

func _fetch_missing(need: Dictionary) -> void:
	var v := _best_vehicle_for(need)
	if v.is_empty(): return
	_load_popup(int(v["id"]), not v["driver"], need)

func _unit(id: String, qty: int) -> String:
	var u: String = DB.ITEMS[id].get("unit", "pza")
	return L.t("u_" + u + ("" if qty == 1 else "_pl"))

func _cell(text: String, w: float, size: int, color := UI.BLUE_INK, align := HORIZONTAL_ALIGNMENT_LEFT, hand := true) -> Label:
	var l := UI.hand_label(text, size, color) if hand else UI.label(text, size, color)
	l.custom_minimum_size.x = w
	l.horizontal_alignment = align
	l.clip_text = true
	if w <= 0: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _order_note(c: Dictionary) -> Control:
	## Nota de remision: Cant. | Material | P.U. | Importe
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tear := TextureRect.new()
	tear.texture = Art.tex("note_tear")
	tear.stretch_mode = TextureRect.STRETCH_TILE
	tear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tear.custom_minimum_size = Vector2(0, 8)
	wrap.add_child(tear)
	var note := PanelContainer.new()
	var st := UI.sb(UI.PAPER, Color("e2d4b4"), 0, 10, false, 0)
	st.corner_radius_bottom_left = 3; st.corner_radius_bottom_right = 3
	st.shadow_color = Color(0.23, 0.15, 0.09, 0.3); st.shadow_size = 3; st.shadow_offset = Vector2(0, 3)
	note.add_theme_stylebox_override("panel", st)
	wrap.add_child(note)
	var v := UI.vbox(2)
	note.add_child(v)
	var hh := UI.hbox(4)
	hh.add_child(UI.label(L.t("note_title"), 13, UI.CORAL, true))
	if c.get("delivery", false):
		var dt := UI.label(" · " + L.t("delivery_tag"), 12, UI.BLUE_INK, true)
		hh.add_child(dt)
	if c.has("encargo"):
		hh.add_child(UI.label(" · " + L.t("encargo_tag"), 12, UI.BLUE_INK, true))
	hh.add_child(UI.spacer())
	hh.add_child(UI.label("Nº %04d" % int(c["cid"]), 12, UI.CORAL, true))
	v.add_child(hh)
	var line := ColorRect.new(); line.color = UI.CORAL; line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	var ch := UI.hbox(6)
	var face := UI.person_view(c["look"], 40, "idle", true)
	ch.add_child(face)
	var nv := UI.vbox(-4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(UI.hand_label(c["name"], 24))
	nv.add_child(UI.label(_ctype(c) + ("  ★ " + L.t("regular") if c.has("regular") else ""), 11, UI.DIM))
	ch.add_child(nv)
	v.add_child(ch)
	v.add_child(UI.talk_label("“" + _order_phrase(c) + "”", 15, Color("5a4030")))
	# encabezado de columnas
	var head := UI.hbox(4)
	head.add_child(_cell(L.t("col_qty"), 62, 10, UI.CORAL, HORIZONTAL_ALIGNMENT_LEFT, false))
	head.add_child(_cell(L.t("col_item"), 0, 10, UI.CORAL, HORIZONTAL_ALIGNMENT_LEFT, false))
	head.add_child(_cell(L.t("col_unit_price"), 44, 10, UI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT, false))
	head.add_child(_cell(L.t("col_amount"), 60, 10, UI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT, false))
	v.add_child(head)
	var hl := ColorRect.new(); hl.color = Color("e8b0a0"); hl.custom_minimum_size = Vector2(0, 1)
	v.add_child(hl)
	var sum := 0
	var raw := 0
	for o in c["order"]:
		raw += int(DB.ITEMS[o["id"]]["sell"]) * int(o["qty"])
	var k := float(c["price"]) / maxf(1.0, float(raw))
	var orders: Array = c["order"]
	for i in orders.size():
		var o: Dictionary = orders[i]
		var qty := int(o["qty"])
		var have := Game.inv_qty(o["id"])
		var enough := have >= qty
		var unit_p := int(round(int(DB.ITEMS[o["id"]]["sell"]) * k))
		var amount := unit_p * qty
		if i == orders.size() - 1: amount = int(c["price"]) - sum   # que cuadre el total
		sum += amount
		var r := UI.hbox(4)
		var qv := UI.vbox(-6)
		qv.custom_minimum_size.x = 62
		qv.add_child(UI.hand_label(str(qty), 24))
		qv.add_child(UI.label(_unit(o["id"], qty), 10, UI.DIM))
		r.add_child(qv)
		var mv := UI.vbox(-4)
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.hand_label(L.t("item_" + o["id"]), 21)
		nm.clip_text = true
		mv.add_child(nm)
		if enough: mv.add_child(UI.label("✓ " + L.t("have_ok"), 10, Color("2f8a5b")))
		else: mv.add_child(UI.label(L.t("have_of") % [have, qty], 10, UI.CORAL))
		r.add_child(mv)
		var pu := _cell(UI.money(unit_p), 44, 17, Color("6a5a7a"), HORIZONTAL_ALIGNMENT_RIGHT)
		pu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pu)
		var am := _cell(UI.money(amount), 60, 20, UI.BLUE_INK, HORIZONTAL_ALIGNMENT_RIGHT)
		am.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(am)
		v.add_child(r)
		var rl := ColorRect.new(); rl.color = Color("e4dac4"); rl.custom_minimum_size = Vector2(0, 1)
		v.add_child(rl)
	if c.get("delivery", false):
		var fr := UI.hbox(4)
		fr.add_child(UI.spacer())
		fr.add_child(UI.hand_label(L.t("delivery_fee") % UI.money(int(c.get("fee", 0))), 18, Color("6a5a7a")))
		v.add_child(fr)
	var tr := UI.hbox(4)
	var tl := UI.label("TOTAL", 14, UI.BONE, true)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(tl)
	tr.add_child(UI.spacer())
	tr.add_child(UI.hand_label(UI.money(int(c["price"])), 28))
	v.add_child(tr)
	if c.has("encargo"):
		var er := UI.hbox(4)
		er.add_child(UI.label(L.t("encargo_paid") % UI.money(int(c["encargo"])), 12, UI.DIM))
		er.add_child(UI.spacer())
		er.add_child(UI.hand_label(L.t("encargo_rest") % UI.money(int(c["price"]) - int(c["encargo"])), 20, UI.CORAL))
		v.add_child(er)
	wrap.rotation = deg_to_rad(-0.8)
	return wrap

func _ctype(c: Dictionary) -> String:
	var k: String = "ctype_" + c["type"]
	if str(c["look"].get("gender", "m")) == "f" and L.has(k + "_f"): k += "_f"
	return L.t(k)

func _order_phrase(c: Dictionary) -> String:
	## Frase del cliente segun su proyecto (los frecuentes saludan primero)
	if c.has("tut"): return L.t("phrase_tut_%d" % int(c["tut"]))
	var female: bool = str(c["look"].get("gender", "m")) == "f"
	var key: String = "proj_" + str(c.get("project", ""))
	if not L.has(key): key = "phrase_generic_%d" % (int(c["cid"]) % 4)
	if female and L.has(key + "_f"): key += "_f"
	var txt := L.t(key)
	if c.has("encargo"): txt = L.t("encargo_back")
	if c.has("regular"):
		var rk := "phrase_reg_%s_%d" % [c["regular"], int(c["cid"]) % 2]
		if L.has(rk): txt = L.t(rk) + " " + txt
	return txt

func _buy_missing(c: Dictionary) -> void:
	var total := 0
	var miss := Game.missing_for(c)
	for m in miss:
		if DB.ITEMS[m["id"]]["source"] == "supplier": total += Game.supply_price(m["id"], true) * int(m["qty"])
	UI.confirm(L.t("supplier"), L.t("buy_missing_q") % UI.money(total), func():
		for m in miss:
			if DB.ITEMS[m["id"]]["source"] == "supplier":
				if not Game.buy_supply(m["id"], int(m["qty"]), true): break
		_rebuild())

func _deliver(c: Dictionary) -> void:
	var res := Game.serve(c)
	if res.get("ok", false):
		Sfx.vibrate(25)
		if world and world.has_method("play_serve_anim"): world.play_serve_anim()
		if int(res["bonus"]) > 0: UI.toast(L.t("regular_tip") % UI.money(int(res["bonus"])), UI.MINT)
		selected = {}
		_rebuild()

func _send_delivery(c: Dictionary) -> void:
	if Game.deliver_order(c):
		Sfx.vibrate(25)
		selected = {}
		_rebuild()

func _local_inventory(v: VBoxContainer) -> void:
	for kind in ["patio", "shelf"]:
		var used := Game.space_used(kind); var cap := Game.space_cap(kind)
		var h := UI.hbox(6)
		h.add_child(UI.icon("ic_arena" if kind == "patio" else "ic_box", 24))
		h.add_child(UI.label(L.t("space_" + kind) + " %d / %d" % [used, cap], 16, UI.CORAL if used >= cap else UI.BONE))
		v.add_child(h)
		v.add_child(UI.progress(used, cap, UI.SAND if used < cap else UI.CORAL, 8))
	v.add_child(UI.wrap_label(L.t("space_help"), 12, UI.DIM))
	var pend := Game.pending_loads()
	if pend > 0: v.add_child(UI.label(L.t("incoming") % pend, 14, UI.MINT))
	if Game.pending_supplier() > 0: v.add_child(UI.label(L.t("incoming_supplier") % [Game.pending_supplier(), Game.day_name(Game.next_supplier_day() if not Game.supplier_today() or Game.phase() != "morning" else int(Game.s["day"]))], 14, UI.MINT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var any := false
	for id in DB.ITEM_ORDER:
		var q := Game.inv_qty(id)
		if q <= 0: continue
		any = true
		var c := UI.card(UI.PANEL, UI.LINE, 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UI.vbox(0)
		var ic := UI.icon("ic_" + id, 40)
		cv.add_child(ic)
		var nl := UI.label(L.t("item_" + id), 12)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		cv.add_child(nl)
		var ql := UI.hand_label("x%d" % q, 24)
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(ql)
		c.add_child(cv)
		grid.add_child(c)
	if any: v.add_child(grid)
	else: v.add_child(UI.wrap_label(L.t("inv_empty"), 15, UI.DIM))

func _local_supplier(v: VBoxContainer) -> void:
	var nd := Game.next_supplier_day()
	var info := L.t("sup_days") + " " + (L.t("sup_came_today") if Game.supplier_today() else "") + L.t("sup_next") % Game.day_name(nd)
	v.add_child(UI.wrap_label(info, 14, UI.DIM))
	# pedidos pendientes
	if not Game.s["supplier_orders"].is_empty():
		var pend := []
		for id in Game.s["supplier_orders"]:
			pend.append("%d %s" % [int(Game.s["supplier_orders"][id]), L.t("item_" + id)])
		v.add_child(UI.wrap_label(L.t("sup_pending") % [", ".join(pend), Game.day_name(nd)], 14, UI.MINT))
	var pick := func(k: String) -> void:
		supplier_urgent = k == "urgent"
		_rebuild()
	_folder_tabs(v, [["order", "sup_mode_order"], ["urgent", "sup_mode_urgent"]], "urgent" if supplier_urgent else "order", pick)
	v.add_child(UI.wrap_label((L.t("sup_urgent_desc") if supplier_urgent else L.t("sup_order_desc") % Game.day_name(nd)) + " " + L.t("shelf_room") % Game.shelf_room(), 13, UI.DIM))
	for id in DB.ITEM_ORDER:
		var it: Dictionary = DB.ITEMS[id]
		if it["source"] != "supplier": continue
		var unlocked := Game.level() >= int(it["lvl"])
		var h := _row_card(v)
		h.add_child(UI.icon("ic_" + id if unlocked else "ic_lock", 38))
		if not unlocked:
			_texts(h, L.t("item_" + id), L.t("unlocks_at") % int(it["lvl"]))
			continue
		var price := Game.supply_price(id, supplier_urgent)
		_texts(h, L.t("item_" + id), L.t("cost_sell") % [UI.money(price), UI.money(int(it["sell"])), Game.inv_qty(id)])
		for n in [1, 5, 10]:
			var urgent := supplier_urgent
			var buy := func() -> void:
				if Game.buy_supply(id, n, urgent): _rebuild()
			var b := UI.btn("+%d" % n, buy, "good" if Game.money() >= price * n else "ghost", 34)
			b.custom_minimum_size.x = 40
			h.add_child(b)

# ---------------------------------------------------------------- MINA
func _panel_mine(v: VBoxContainer) -> void:
	if Game.s["own_mine"]: v.add_child(UI.wrap_label(L.t("own_mine_info"), 14, UI.MINT))
	v.add_child(UI.label((L.t("mine_open_today") if Game.mine_open() else L.t("mine_closed_today")) + " · " + L.t("patio_room") % Game.patio_room(), 14, UI.BONE if Game.mine_open() else UI.CORAL))
	_section(v, L.t("dispatch"))
	for veh in Game.s["fleet"]:
		var card := UI.card(UI.PANEL, UI.LINE, 8)
		var cv := UI.vbox(6)
		card.add_child(cv)
		v.add_child(card)
		var h := UI.hbox(8)
		h.add_child(UI.icon(Game.vehicle_tex(veh), 40))
		var name := L.t("veh_" + veh["type"]) if veh["type"] != "wheelbarrow" else L.t("wb_tier_%d" % int(Game.s["wb_tier"]))
		_texts(h, name, L.t("veh_stats") % [Game.vehicle_cap(veh), int(Game.vehicle_time(veh))] + (" · " + L.t("has_driver") if veh["driver"] else ""))
		cv.add_child(h)
		var vid: int = veh["id"]
		if veh["trip"] != null:
			var tr: Dictionary = veh["trip"]
			var road := RoadBar.new()
			road.custom_minimum_size = Vector2(0, 30)
			road.tex = Art.tex(Game.vehicle_tex(veh))
			var dur0 := maxf(1.0, float(tr["end"]) - float(tr["start"]))
			road.value = clampf((Game.now() - float(tr["start"])) / dur0, 0.0, 1.0)
			cv.add_child(road)
			var loads := []
			for k in tr["load"]: loads.append("%d %s %s" % [int(tr["load"][k]), _unit(k, int(tr["load"][k])), L.t("item_" + k)])
			if tr.has("delivery"): loads = [L.t("delivering_to") % [str(tr["delivery"]["name"]), int(tr["delivery"].get("dist", 2))]]
			cv.add_child(UI.wrap_label(", ".join(loads), 13, UI.DIM))
			var row := UI.hbox(6)
			var tl := UI.label("", 15, UI.SAND)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(tl)
			var waiting := float(tr["end"]) <= Game.now()
			if waiting:
				tl.text = L.t("no_space_unload")
				row.add_child(UI.btn(L.t("retry"), func(): Game.update_trips(), "normal", 34))
			elif Game.free_skip_available(vid):
				var fs := UI.btn(L.t("skip_free"), func():
					Game.use_free_skip(vid), "good", 36)
				row.add_child(fs)
				tut_targets["free_skip"] = fs
			else:
				var ad := UI.btn(L.t("skip_ad"), func():
					Mon.show_rewarded("trip_skip", func(): Game.skip_trip(vid)), "ad", 34)
				ad.icon = Art.tex("ic_ad")
				row.add_child(ad)
				var skip_b := func() -> void:
					if Game.spend_bolts(3):
						Game.skip_trip(vid)
				var sbb := UI.btn("3", skip_b, "normal", 34)
				sbb.icon = Art.tex("ic_bolt")
				row.add_child(sbb)
			cv.add_child(row)
			dyn.append(func():
				if not is_instance_valid(road): return
				var dur := maxf(1.0, float(tr["end"]) - float(tr["start"]))
				road.value = clampf((Game.now() - float(tr["start"])) / dur, 0.0, 1.0)
				road.queue_redraw()
				if float(tr["end"]) > Game.now():
					tl.text = (L.t("delivering") if tr.has("delivery") else (L.t("trip_you") if tr["self"] else L.t("trip_driver"))) + " " + UI.fmt_time(float(tr["end"]) - Game.now()))
		else:
			var row := UI.hbox(6)
			var go_self := UI.btn(L.t("go_myself") + " -%d" % Game.trip_energy(veh), func(): _load_popup(vid, true), "primary", 40)
			go_self.icon = Art.tex("ic_energy")
			go_self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			go_self.disabled = Game.player_away() or Game.at_home() or not Game.mine_open()
			row.add_child(go_self)
			if not tut_targets.has("go_self"): tut_targets["go_self"] = go_self
			if veh["driver"]:
				var gd := UI.btn(L.t("send_driver"), func(): _load_popup(vid, false), "good", 40)
				gd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gd.disabled = not Game.mine_open()
				row.add_child(gd)
				var fire := UI.btn("✕", func():
					UI.confirm(L.t("fire_driver"), L.t("fire_driver_q"), func():
						Game.fire_driver(vid)
						_rebuild()), "ghost", 40)
				fire.custom_minimum_size.x = 40
				fire.tooltip_text = L.t("fire_driver")
				row.add_child(fire)
			elif Game.tutorial_on() == false:
				var cost := int(DB.VEHICLES[veh["type"]]["driver"]) * 3
				var hd := UI.btn(L.t("driver_short") + " " + UI.money(cost), func():
					UI.confirm(L.t("hire_driver"), L.t("hire_driver_q") % [UI.money(cost), UI.money(int(DB.VEHICLES[veh["type"]]["driver"]))], func():
						Game.hire_driver(vid)
						_rebuild()), "ghost", 40)
				hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(hd)
			cv.add_child(row)
	if not Game.tutorial_on():
		v.add_child(UI.btn(L.t("more_vehicles"), func(): _set_tab("upgrades"), "ghost", 36))

func _load_popup(vid: int, self_go: bool, preload_need := {}) -> void:
	var veh := Game.vehicle(vid)
	if veh.is_empty() or veh["trip"] != null: return
	if not Game.mine_open():
		UI.toast(L.t("mine_closed_today"), UI.CORAL); return
	var cap := Game.vehicle_cap(veh)
	var load := {}
	var tut := int(Game.s.get("tutorial", 5)) == 2 and self_go
	pop_targets.clear()
	var content := UI.vbox(6)
	if tut:
		var tip := _abuelo_tip(content, L.t("tut_pick_sand"))
		pop_targets["tip"] = tip
	# fichas para cambiar de vehiculo sin cerrar
	if not tut:
		var chips := UI.hbox(4)
		var any_chip := false
		for ov in Game.s["fleet"]:
			if ov["trip"] != null: continue
			var can_self: bool = not Game.player_away() and not Game.at_home()
			if not ov["driver"] and not can_self: continue
			var oid := int(ov["id"])
			var oself: bool = not ov["driver"]
			var on: bool = oid == vid and oself == self_go
			var cb := UI.btn("", func():
				UI.clear_overlay()
				_load_popup(oid, oself, load.duplicate() if not load.is_empty() else preload_need), "primary" if on else "ghost", 40)
			cb.icon = Art.tex(Game.vehicle_tex(ov))
			cb.expand_icon = true
			cb.custom_minimum_size = Vector2(54, 40)
			cb.tooltip_text = L.t("veh_" + ov["type"])
			chips.add_child(cb)
			any_chip = true
		if any_chip and chips.get_child_count() > 1:
			content.add_child(UI.label(L.t("pick_vehicle") + " · " + (L.t("you_go") if self_go else L.t("driver_goes")), 13, UI.DIM))
			content.add_child(chips)
	var info := UI.label("", 16, UI.SAND)
	var cost_l := UI.label("", 16, UI.BONE)
	content.add_child(info)
	var rows := UI.vbox(4)
	content.add_child(rows)
	content.add_child(cost_l)
	var free := Game.patio_room()
	var limit := maxi(mini(cap, free), 0)
	var sliders := {}
	var qlabels := {}
	var fill_btn: Button = null
	var total := func() -> int:
		var t := 0
		for k in load: t += int(load[k])
		return t
	var refresh := func() -> void:
		var tot: int = total.call()
		info.text = L.t("load_info") % [tot, cap, free]
		cost_l.text = L.t("trip_cost") % UI.money(Game.trip_cost(veh, load))
		for k in qlabels:
			var n := int(load.get(k, 0))
			qlabels[k].text = "%d %s" % [n, _unit(k, n)]
		var fbt = pop_targets.get("fill")
		if fbt != null and is_instance_valid(fbt): fbt.set_meta("tot", tot)
	var set_amount := func(id: String, want: int) -> void:
		var others: int = total.call() - int(load.get(id, 0))
		var nv := clampi(want, 0, maxi(limit - others, 0))
		if nv <= 0: load.erase(id)
		else: load[id] = nv
		if sliders.has(id): sliders[id].set_value_no_signal(nv)
		refresh.call()
	for id in DB.ITEM_ORDER:
		var it: Dictionary = DB.ITEMS[id]
		if it["source"] != "mine": continue
		var unlocked := DB.item_unlocked(id, Game.level(), Game.s["tools"])
		var rowp := PanelContainer.new()
		var hl: bool = tut and id == "arena"
		rowp.add_theme_stylebox_override("panel", UI.sb(Color("ffe9a0") if hl else Color(0, 0, 0, 0), UI.SAND if hl else Color(0, 0, 0, 0), 2, 4, false, 8))
		var rv := UI.vbox(2)
		rowp.add_child(rv)
		var h := UI.hbox(6)
		rv.add_child(h)
		h.add_child(UI.icon("ic_" + id if unlocked else "ic_lock", 30))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(L.t("item_" + id), 16))
		if not unlocked:
			var why := L.t("unlocks_at") % int(it["lvl"])
			if it.has("needs") and Game.level() >= int(it["lvl"]): why = L.t("needs_tool") % L.t("tool_" + it["needs"])
			tv.add_child(UI.label(why, 12, UI.DIM))
			h.add_child(tv)
			rows.add_child(rowp)
			continue
		tv.add_child(UI.label(L.t("per_unit") % UI.money(Game.mine_price(id)) + " · " + L.t("sells_at") % UI.money(int(it["sell"])) + " · " + L.t("have_n") % Game.inv_qty(id), 12, UI.DIM))
		h.add_child(tv)
		var ql := UI.hand_label("0", 22, UI.SAND)
		ql.custom_minimum_size.x = 70
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qlabels[id] = ql
		h.add_child(ql)
		var dis: bool = tut and id != "arena"
		var sr := UI.hbox(6)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = maxi(limit, 1)
		sl.step = 1
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.custom_minimum_size = Vector2(0, 28)
		sl.editable = not dis and limit > 0
		sl.focus_mode = Control.FOCUS_NONE
		var item_id: String = id
		sl.value_changed.connect(func(val: float): set_amount.call(item_id, int(val)))
		sliders[id] = sl
		sr.add_child(sl)
		var fb := UI.btn(L.t("fill"), func(): set_amount.call(item_id, 99999), "good", 32)
		fb.custom_minimum_size.x = 76
		fb.disabled = dis or limit <= 0
		sr.add_child(fb)
		if hl:
			fill_btn = fb
			pop_targets["fill"] = fb
		rv.add_child(sr)
		rows.add_child(rowp)
	# precargar lo que le falta a un cliente
	for k in preload_need:
		if sliders.has(k): set_amount.call(k, int(preload_need[k]))
	refresh.call()
	var title := L.t("trip_to_mine_self") if self_go else L.t("trip_to_mine_driver")
	var pop := UI.popup(title, content, [[L.t("cancel"), Callable()], [L.t("go"), func():
		if Game.send_trip(vid, load, self_go):
			_rebuild()
			if self_go: UI.toast(L.t("you_left"), UI.SAND), "primary"]])
	if tut:
		# el boton IR del popup es el ultimo boton
		var btns := pop.find_children("*", "Button", true, false)
		if not btns.is_empty(): pop_targets["go"] = btns[btns.size() - 1]

# ---------------------------------------------------------------- CASA
func _panel_house(v: VBoxContainer) -> void:
	if Game.at_home():
		var ah := _row_card(v)
		ah.add_child(UI.icon("nav_house", 36))
		_texts(ah, L.t("at_home_title"), L.t("at_home_desc"))
	var sh := UI.hbox(6)
	var sleep_b := UI.btn(L.t("sleep"), _ask_sleep, "primary", 44)
	tut_targets["sleep"] = sleep_b
	sleep_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sleep_b)
	var closet := UI.btn(L.t("closet"), func(): get_parent().goto("creator", {"mode": "edit"}), "ghost", 44)
	closet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(closet)
	v.add_child(sh)
	var ach := UI.btn(L.t("achievements"), _achievements_popup, "normal", 38)
	ach.icon = Art.tex("ic_star")
	v.add_child(ach)
	var eh := _row_card(v)
	eh.add_child(UI.icon("ic_energy", 36))
	_texts(eh, L.t("energy") + " %d/%d" % [int(Game.s["energy"]), Game.energy_max()], L.t("energy_desc") % str(DB.HOUSE_STAGES[Game.house_stage()]["regen"]))
	var ad_e := UI.btn("+10", func(): Mon.show_rewarded("energy", func(): Game.add_energy(10)), "ad", 36)
	ad_e.icon = Art.tex("ic_ad")
	eh.add_child(ad_e)
	_section(v, L.t("house_upgrade"))
	var hs := Game.house_stage()
	var h := _row_card(v)
	h.add_child(UI.icon("nav_house", 36))
	if hs + 1 < DB.HOUSE_STAGES.size():
		var d: Dictionary = DB.HOUSE_STAGES[hs + 1]
		_texts(h, L.t("house_stage_%d" % (hs + 1)), L.t("house_benefit") % [int(d["energy"]), str(d["regen"])] + _req_text(int(d["lvl"])))
		h.add_child(_buy_btn(int(d["cost"]), func(): return Game.upgrade_house(), int(d["lvl"])))
	else:
		_texts(h, L.t("house_stage_%d" % hs), L.t("maxed"))
	_section(v, L.t("transport"))
	v.add_child(UI.wrap_label(L.t("transport_desc"), 13, UI.DIM))
	for id in DB.TRANSPORT_ORDER:
		var d: Dictionary = DB.TRANSPORTS[id]
		var r := _row_card(v)
		r.add_child(UI.icon(d["tex"] if d["tex"] != "" else "ic_person", 36))
		var owned: bool = Game.s["transports"].has(id)
		var using: bool = Game.s["transport"] == id
		_texts(r, L.t("tr_" + id), L.t("in_use") if using else (L.t("owned") if owned else _req_text(int(d["lvl"])).trim_prefix(" · ")))
		if using:
			pass
		elif owned:
			r.add_child(UI.btn(L.t("use"), func(): Game.buy_transport(id), "ghost", 34))
		elif int(d["bolts"]) > 0:
			var bb := UI.btn(str(int(d["bolts"])), func(): Game.buy_transport(id), "primary", 34)
			bb.icon = Art.tex("ic_bolt")
			r.add_child(bb)
		else:
			r.add_child(_buy_btn(int(d["cost"]), func(): return Game.buy_transport(id), int(d["lvl"])))

func _ask_sleep() -> void:
	var early := false
	var go := func() -> void:
		if world and "sleeping" in world: world.sleeping = 1.6
		Sfx.play("page")
		await get_tree().create_timer(0.8).timeout
		Game.sleep()
	if early: UI.confirm(L.t("sleep"), L.t("sleep_early_q"), go)
	else: go.call()

# ---------------------------------------------------------------- MEJORAS (plano)
func _req_text(lvl: int) -> String:
	if Game.level() >= lvl: return ""
	return " · " + L.t("need_level") % lvl

func _buy_btn(cost: int, action: Callable, lvl := 1) -> Button:
	var can := Game.level() >= lvl
	var b := UI.btn(UI.money(cost), func():
		if action.call(): _rebuild(), "primary" if can and Game.money() >= cost else "ghost", 38)
	b.disabled = not can
	b.custom_minimum_size.x = 92
	return b

func _panel_upgrades(v: VBoxContainer) -> void:
	var BP := true
	var LB := Color("dce8ff")
	_section(v, L.t("up_shop"))
	var st := Game.shop_stage()
	var h := _row_card(v, BP)
	h.add_child(UI.icon("nav_local", 36))
	if st == 0:
		_texts(h, L.t("shop_stage_0"), L.t("clean_first"), LB, BP)
	elif st + 1 < DB.SHOP_STAGES.size():
		var d: Dictionary = DB.SHOP_STAGES[st + 1]
		_texts(h, L.t("shop_stage_%d" % (st + 1)), L.t("shop_benefit") % [int(d["patio"]), int(d["shelf"]), int(d["queue"]), int(d["demand"]) - int(DB.SHOP_STAGES[st]["demand"])] + _req_text(int(d["lvl"])), LB, BP)
		h.add_child(_buy_btn(int(d["cost"]), func(): return Game.upgrade_shop(), int(d["lvl"])))
	else:
		_texts(h, L.t("shop_stage_%d" % st), L.t("maxed"), LB, BP)
	_section(v, L.t("up_vehicles"))
	var wt := int(Game.s["wb_tier"])
	h = _row_card(v, BP)
	h.add_child(UI.icon("veh_wheelbarrow_%d" % mini(wt + 1, 2), 36))
	if wt + 1 < DB.WHEELBARROW_TIERS.size():
		var d: Dictionary = DB.WHEELBARROW_TIERS[wt + 1]
		_texts(h, L.t("wb_tier_%d" % (wt + 1)), L.t("veh_stats") % [int(d["cap"]), int(d["time"])] + _req_text(int(d["lvl"])), LB, BP)
		h.add_child(_buy_btn(int(d["cost"]), func(): return Game.upgrade_wheelbarrow(), int(d["lvl"])))
	else:
		_texts(h, L.t("wb_tier_%d" % wt), L.t("maxed"), LB, BP)
	var nwb := Game.count_type("wheelbarrow")
	h = _row_card(v, BP)
	h.add_child(UI.icon("veh_wheelbarrow_%d" % mini(wt, 2), 36))
	var dwb: Dictionary = DB.VEHICLES["wheelbarrow"]
	_texts(h, L.t("wb_extra") + " (%d/%d)" % [nwb, int(dwb["max"])], L.t("wb_extra_desc") + _req_text(int(dwb["lvl"])), LB, BP)
	if nwb < int(dwb["max"]):
		h.add_child(_buy_btn(Game.vehicle_price("wheelbarrow"), func(): return Game.buy_vehicle("wheelbarrow"), int(dwb["lvl"])))
	for type in ["pickup", "truck", "bigtruck"]:
		var d: Dictionary = DB.VEHICLES[type]
		h = _row_card(v, BP)
		h.add_child(UI.icon(d["tex"], 36))
		var count := 0
		for vv in Game.s["fleet"]:
			if vv["type"] == type: count += 1
		var req := _req_text(int(d["lvl"]))
		if d.has("shop") and Game.shop_stage() < int(d["shop"]): req += " · " + L.t("need_shop") % L.t("shop_stage_%d" % int(d["shop"]))
		_texts(h, L.t("veh_" + type) + " (%d/%d)" % [count, int(d["max"])], L.t("veh_stats") % [int(d["cap"]), int(d["time"])] + " · " + L.t("gas") % UI.money(int(d["gas"])) + req, LB, BP)
		if count < int(d["max"]):
			h.add_child(_buy_btn(Game.vehicle_price(type), func(): return Game.buy_vehicle(type), int(d["lvl"])))
	_section(v, L.t("up_tools"))
	for id in DB.TOOL_ORDER:
		var d: Dictionary = DB.TOOLS[id]
		h = _row_card(v, BP)
		h.add_child(UI.icon("ic_star" if Game.has_tool(id) else "nav_up", 36))
		_texts(h, L.t("tool_" + id), L.t("tool_" + id + "_desc") + _req_text(int(d["lvl"])), LB, BP)
		if Game.has_tool(id): h.add_child(UI.label(L.t("owned"), 14, Color("8fe8ab")))
		else: h.add_child(_buy_btn(int(d["cost"]), func(): return Game.buy_tool(id), int(d["lvl"])))
	_section(v, L.t("up_staff"))
	var n := int(Game.s["clerks"])
	h = _row_card(v, BP)
	h.add_child(UI.person_view({"gender": "f", "body": "normal", "skin": 2, "face": "feliz", "hair": "coleta", "hair_color": 0, "acc": "ninguno", "top": "mandil", "top_color": 3, "pants": "pantalon", "pants_color": 1, "shoes": 0}, 40, "idle", true))
	if n < 2:
		var d: Dictionary = DB.CLERK if n == 0 else DB.CLERK2
		_texts(h, L.t("clerk_%d" % (n + 1)), L.t("clerk_desc_%d" % (n + 1)) % UI.money(int(d["salary"])) + _req_text(int(d["lvl"])), LB, BP)
		h.add_child(_buy_btn(int(d["hire"]), func(): return Game.hire_clerk(), int(d["lvl"])))
	else:
		_texts(h, L.t("clerk_2"), L.t("maxed"), LB, BP)
	if n > 0:
		var fb := UI.btn(L.t("fire_clerk"), func():
			UI.confirm(L.t("fire_clerk"), L.t("fire_clerk_q"), func():
				Game.fire_clerk()
				_rebuild()), "ghost", 32)
		v.add_child(fb)
	var ot := int(Game.s["offline_tier"])
	h = _row_card(v, BP)
	h.add_child(UI.icon("ic_clock", 36))
	if ot + 1 < DB.OFFLINE_HOURS.size():
		var d: Dictionary = DB.OFFLINE_HOURS[ot + 1]
		_texts(h, L.t("offline_up"), L.t("offline_up_desc") % [int(DB.OFFLINE_HOURS[ot]["hours"]), int(d["hours"])] + ("" if n > 0 else " · " + L.t("needs_clerk")), LB, BP)
		var b := _buy_btn(int(d["cost"]), func(): return Game.upgrade_offline(), 1)
		b.disabled = n == 0
		h.add_child(b)
	else:
		_texts(h, L.t("offline_up"), L.t("maxed"), LB, BP)
	_section(v, L.t("up_mine"))
	h = _row_card(v, BP)
	h.add_child(UI.icon("nav_mine", 36))
	if Game.s["own_mine"]:
		_texts(h, L.t("own_mine"), L.t("own_mine_info"), LB, BP)
	else:
		_texts(h, L.t("own_mine"), L.t("own_mine_desc") + _req_text(int(DB.OWN_MINE["lvl"])), LB, BP)
		h.add_child(_buy_btn(int(DB.OWN_MINE["cost"]), func(): return Game.buy_own_mine(), int(DB.OWN_MINE["lvl"])))

# ---------------------------------------------------------------- TIENDA
func _panel_store(v: VBoxContainer) -> void:
	v.add_child(UI.wrap_label(L.t("store_sim_note"), 13, UI.DIM))
	var c := UI.card(Color("fde7a8"), UI.SAND, 10)
	var cv := UI.vbox(4)
	c.add_child(cv)
	var t := UI.label(L.t("prod_starter_pack"), 18, UI.SAND, true)
	t.add_theme_font_size_override("font_size", 18)
	cv.add_child(t)
	cv.add_child(UI.wrap_label(L.t("starter_desc"), 15))
	var sb := UI.btn(L.t("owned") if Game.s["starter"] else DB.PRODUCTS["starter_pack"]["price"], func(): Mon.purchase("starter_pack", _rebuild), "primary", 40)
	sb.disabled = Game.s["starter"]
	cv.add_child(sb)
	v.add_child(c)
	var h := _row_card(v)
	h.add_child(UI.icon("ic_ad", 36))
	_texts(h, L.t("prod_no_ads"), L.t("no_ads_desc"))
	var nb := UI.btn(L.t("owned") if Game.s["no_ads"] else DB.PRODUCTS["no_ads"]["price"], func(): Mon.purchase("no_ads", _rebuild), "primary", 38)
	nb.disabled = Game.s["no_ads"]
	h.add_child(nb)
	_section(v, L.t("bolts_title"))
	for pid in ["bolts_small", "bolts_mid", "bolts_big"]:
		h = _row_card(v)
		h.add_child(UI.icon("ic_bolt", 36))
		_texts(h, L.t("prod_" + pid), L.t("bolts_desc"))
		h.add_child(UI.btn(DB.PRODUCTS[pid]["price"], func(): Mon.purchase(pid), "primary", 38))
	_section(v, L.t("free_rewards"))
	for item in [["bolts", "free_bolts", func(): Game.add_bolts(5)], ["energy", "free_energy", func(): Game.add_energy(10)]]:
		h = _row_card(v)
		h.add_child(UI.icon("ic_bolt" if item[0] == "bolts" else "ic_energy", 36))
		_texts(h, L.t(item[1]), L.t("ads_left") % Game.ad_left(item[0]))
		var reward: Callable = item[2]
		var placement: String = item[0]
		var b := UI.btn(L.t("watch"), func():
			Mon.show_rewarded(placement, func():
				reward.call()
				_rebuild()), "ad", 38)
		b.icon = Art.tex("ic_ad")
		b.disabled = Game.ad_left(placement) <= 0
		h.add_child(b)
	_section(v, L.t("bolts_uses_title"))
	v.add_child(UI.wrap_label(L.t("bolts_uses"), 13, UI.DIM))

# ---------------------------------------------------------------- popups
func _visitor_popup() -> void:
	var reward := Game.visitor_reward()
	var content := UI.hbox(8)
	content.add_child(UI.person_view({"gender": "m", "body": "broad", "skin": 1, "face": "bigote", "hair": "corto", "hair_color": 0, "acc": "sombrero", "top": "camisa", "top_color": 1, "pants": "pantalon", "pants_color": 0, "shoes": 1}, 70, "happy", true))
	var tl := UI.talk_label(L.t("visitor_text") % UI.money(reward), 17)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(tl)
	UI.popup(L.t("visitor_title"), content, [[L.t("no_thanks"), func():
		Game.visitor_active = false
		Game.visitor_changed.emit()], [L.t("watch_ad"), func():
		Mon.show_rewarded("visitor", func():
			Game.claim_visitor()
			UI.toast("+" + UI.money(reward), UI.MINT)), "ad"]])

func _on_level_up(lvl: int) -> void:
	var content := UI.vbox(6)
	var unlocks := []
	for id in DB.ITEM_ORDER:
		if int(DB.ITEMS[id]["lvl"]) == lvl: unlocks.append(L.t("item_" + id))
	for t in DB.CUSTOMER_TYPES:
		if int(DB.CUSTOMER_TYPES[t]["lvl"]) == lvl: unlocks.append(L.t("new_customer") % L.t("ctype_" + t))
	for i in DB.SHOP_STAGES.size():
		if int(DB.SHOP_STAGES[i]["lvl"]) == lvl and i > 1: unlocks.append(L.t("shop_stage_%d" % i))
	for id in DB.TOOL_ORDER:
		if int(DB.TOOLS[id]["lvl"]) == lvl: unlocks.append(L.t("tool_" + id))
	for t in DB.VEHICLES:
		if int(DB.VEHICLES[t]["lvl"]) == lvl and t != "wheelbarrow": unlocks.append(L.t("veh_" + t))
	if int(DB.CLERK["lvl"]) == lvl: unlocks.append(L.t("clerk_1"))
	if int(DB.CLERK2["lvl"]) == lvl: unlocks.append(L.t("clerk_2"))
	for i in DB.HOUSE_STAGES.size():
		if int(DB.HOUSE_STAGES[i]["lvl"]) == lvl and i > 1: unlocks.append(L.t("house_stage_%d" % i))
	for i in DB.WHEELBARROW_TIERS.size():
		if int(DB.WHEELBARROW_TIERS[i]["lvl"]) == lvl and i > 1: unlocks.append(L.t("wb_tier_%d" % i))
	if int(DB.VEHICLES["wheelbarrow"]["lvl"]) == lvl: unlocks.append(L.t("wb_extra"))
	for id in DB.TRANSPORT_ORDER:
		if int(DB.TRANSPORTS[id]["lvl"]) == lvl and id != "pie": unlocks.append(L.t("tr_" + id))
	if int(DB.OWN_MINE["lvl"]) == lvl: unlocks.append(L.t("own_mine"))
	var big := UI.label(L.t("level_reached") % lvl, 26, UI.MINT, true)
	big.add_theme_font_size_override("font_size", 26)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(big)
	if unlocks.is_empty():
		content.add_child(UI.wrap_label(L.t("keep_going"), 15, UI.DIM))
	else:
		content.add_child(UI.label(L.t("unlocked") + ":", 15, UI.DIM))
		for u in unlocks:
			var r := UI.hbox(4)
			r.add_child(UI.icon("ic_star", 18))
			r.add_child(UI.label(u, 16))
			content.add_child(r)
	Game.add_bolts(2)
	content.add_child(UI.label(L.t("level_bonus"), 14, UI.SAND))
	UI.popup(L.t("level_up"), content, [[L.t("great"), Callable(), "primary"]])

func _on_day_ended(sm: Dictionary) -> void:
	var content := UI.vbox(4)
	content.add_child(UI.hand_label(L.t("day_summary") % int(sm["day"]), 26, UI.BLUE_INK))
	content.add_child(UI.label(L.t("sum_served") % int(sm["served"]), 16))
	if int(sm.get("rejected", 0)) > 0: content.add_child(UI.label(L.t("sum_rejected") % int(sm["rejected"]), 14, UI.DIM))
	var earned := int(sm["earned"])
	var row := func(label: String, amount: int, col: Color) -> void:
		var h := UI.hbox(4)
		h.add_child(UI.label(label, 15, col))
		h.add_child(UI.spacer())
		h.add_child(UI.hand_label(("-" if amount < 0 else "+") + UI.money(absi(amount)), 20, col))
		content.add_child(h)
	row.call(L.t("sum_sales"), earned, UI.MINT)
	var spent: Dictionary = sm.get("spent", {})
	var total_spent := 0
	for cat in ["supplier", "mine", "gas", "salaries", "light", "upgrades", "staff", "other"]:
		if int(spent.get(cat, 0)) > 0:
			row.call(L.t("spent_" + cat), -int(spent[cat]), UI.CORAL)
			total_spent += int(spent[cat])
	var line := ColorRect.new(); line.color = UI.LINE; line.custom_minimum_size = Vector2(0, 1)
	content.add_child(line)
	row.call(L.t("sum_net"), earned - total_spent, UI.MINT if earned >= total_spent else UI.CORAL)
	var arrived: Dictionary = sm.get("supplier_arrived", {})
	if not arrived.is_empty():
		var parts := []
		for k in arrived: parts.append("%d %s" % [int(arrived[k]), L.t("item_" + k)])
		content.add_child(UI.wrap_label(L.t("supplier_arrived") % ", ".join(parts), 14, UI.SAND))
	content.add_child(UI.wrap_label(L.t("new_day2") % [Game.day_name(), int(Game.s["day"])], 14, UI.DIM))
	UI.popup(L.t("good_night"), content, [[L.t("next_day"), func():
		outside = false
		_play_transit(false, func(): _set_tab("local")), "primary"]])

# ---------------------------------------------------------------- logros
func _ach_name(id: String, goal: int) -> String:
	var k := "ach_" + id
	if id == "earned": return L.t(k) % UI.money(goal)
	return L.t(k) % goal if L.t(k).contains("%") else L.t(k)

func _on_achievement(id: String, goal: int, bolts: int) -> void:
	UI.toast("★ " + L.t("ach_unlocked") + ": " + _ach_name(id, goal) + "  +%d" % bolts, UI.YELLOW)

func _achievements_popup() -> void:
	var content := UI.vbox(6)
	for a in DB.ACHIEVEMENTS:
		var id: String = a["id"]
		var lvl := Game.ach_level(id)
		var goals: Array = a["goals"]
		var done := lvl >= goals.size()
		var goal: int = goals[mini(lvl, goals.size() - 1)]
		var h := UI.hbox(6)
		h.add_child(UI.icon("ic_star" if lvl > 0 else "ic_lock", 26))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(_ach_name(id, goal), 15, UI.BONE if not done else UI.MINT))
		var val := mini(Game.ach_value(id), goal)
		if not done:
			tv.add_child(UI.progress(val, goal, UI.SAND, 6))
			tv.add_child(UI.label("%d / %d · +%d" % [val, goal, int(a["bolts"][lvl])], 11, UI.DIM))
		else:
			tv.add_child(UI.label(L.t("ach_done"), 11, UI.MINT))
		h.add_child(tv)
		content.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	UI.popup(L.t("achievements"), sc, [[L.t("ok"), Callable(), "primary"]])

func _show_offline_report() -> void:
	var r := Game.offline_report
	var content := UI.vbox(6)
	content.add_child(UI.label(L.t("away_for") % UI.fmt_time(float(r["seconds"])), 16, UI.DIM))
	if int(r["trips"]) > 0: content.add_child(UI.label(L.t("away_trips") % int(r["trips"]), 16))
	var earned := int(r["earned"])
	if earned > 0:
		content.add_child(UI.label(L.t("away_sold") % int(r["sold"]), 16))
		content.add_child(UI.hand_label(L.t("away_earned") % UI.money(earned), 28, UI.MINT))
	var btns := [[L.t("collect"), Callable(), "primary"]]
	if earned > 0 and Game.ad_left("offline_double") > 0:
		btns.append([L.t("double_ad"), func():
			Mon.show_rewarded("offline_double", func():
				Game.add_money(earned)
				UI.toast("+" + UI.money(earned), UI.MINT)), "ad"])
	UI.popup(L.t("while_away"), content, btns)

func _pause_menu() -> void:
	Game.paused = true
	var content := UI.vbox(8)
	var stats: Dictionary = Game.s["stats"]
	content.add_child(UI.label("%s · %s %d" % [Game.s["name"], L.t("lvl_short"), Game.level()], 18, UI.SAND))
	content.add_child(UI.label(L.t("stats_line") % [int(stats["served"]), UI.money(int(stats["earned"])), int(stats["trips"])], 14, UI.DIM))
	var pop: Control
	content.add_child(UI.btn(L.t("resume"), func():
		Game.paused = false
		UI.close(pop), "primary", 42))
	content.add_child(UI.btn(L.t("achievements"), func():
		UI.close(pop)
		_achievements_popup(), "normal", 42))
	content.add_child(UI.btn(L.t("save"), func():
		Game.save_game()
		UI.toast(L.t("saved"), UI.MINT), "normal", 42))
	content.add_child(UI.btn(L.t("options"), func():
		var opts = load("res://scripts/screens/options.gd").build(func():
			UI.clear_overlay()
			Game.paused = false
			get_parent().goto("game", {"tab": tab}))
		UI.popup(L.t("options"), opts, [[L.t("ok"), Callable(), "primary"]]), "normal", 42))
	content.add_child(UI.btn(L.t("exit_menu"), func():
		Game.save_game()
		Game.paused = false
		get_parent().goto("menu"), "bad", 42))
	pop = UI.popup(L.t("paused"), content, [], true)
	pop.tree_exited.connect(func(): Game.paused = false)

func on_back() -> void:
	_pause_menu()
