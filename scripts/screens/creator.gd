extends Control
## Creador de personaje (nueva partida) y closet (editar desde la casa).
## args.mode = "new" (con args.slot) | "edit"

var args := {}
var look: Dictionary
var preview: CenterContainer
var name_edit: LineEdit
var rows_box: VBoxContainer
var lock_box: HBoxContainer
var _t := 0.0

const CATS := [
	["body", "cat_body"], ["skin", "cat_skin"], ["face", "cat_face"], ["hair", "cat_hair"], ["hair_color", "cat_hair_color"],
	["acc", "cat_acc"], ["top", "cat_top"], ["top_color", "cat_top_color"], ["pants", "cat_pants"],
	["pants_color", "cat_pants_color"], ["shoes", "cat_shoes"],
]

func _ready() -> void:
	var editing: bool = args.get("mode") == "edit"
	look = (Game.s["look"] as Dictionary).duplicate() if editing else Art.default_look("m")
	var col := UI.vbox(6)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12; col.offset_right = -12; col.offset_top = 12; col.offset_bottom = -10
	add_child(col)
	var t := UI.label(L.t("closet") if editing else L.t("create_char"), 22, UI.BONE, true)
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	# vista previa
	var stage := UI.card(Color("f3e2bf"), UI.LINE, 4)
	stage.custom_minimum_size = Vector2(0, 186)
	preview = CenterContainer.new()
	stage.add_child(preview)
	col.add_child(stage)
	lock_box = UI.hbox(6)
	lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(lock_box)
	# genero
	var gh := UI.hbox(8)
	for g in ["m", "f"]:
		var set_g := func() -> void:
			var keep := look.duplicate()
			look = Art.default_look(g)
			for k in ["skin", "top_color", "pants_color", "shoes", "body"]: look[k] = keep.get(k, look[k])
			_refresh()
		var b := UI.btn(L.t("male") if g == "m" else L.t("female"), set_g, "normal", 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("g", g)
		gh.add_child(b)
	col.add_child(gh)
	if not editing:
		name_edit = LineEdit.new()
		name_edit.placeholder_text = L.t("your_name")
		name_edit.max_length = 14
		name_edit.custom_minimum_size = Vector2(0, 34)
		name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_edit)
	rows_box = UI.vbox(3)
	col.add_child(UI.scroll(rows_box))
	var bh := UI.hbox(8)
	var do_random := func() -> void:
		var r := RandomNumberGenerator.new()
		r.randomize()
		var g: String = look["gender"]
		look = Art.random_look(r, g)
		for k in look.keys():
			if not _owned(k, look[k]):
				look[k] = Art.default_look(g)[k]
		_refresh()
	var rnd := UI.btn(L.t("random"), do_random, "normal", 40)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(rnd)
	if editing:
		var back := UI.btn(L.t("back"), func(): get_parent().goto("game", {"tab": "house"}), "normal", 40)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(back)
	var ok := UI.btn(L.t("ready"), _done, "primary", 40)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(ok)
	col.add_child(bh)
	_refresh()

func _options(cat: String) -> Array:
	match cat:
		"body": return Art.BODY_ORDER
		"skin": return range(Art.SKINS.size())
		"face": return Art.FACE_ORDER
		"hair": return Art.HAIR_ORDER
		"hair_color": return range(Art.HAIR_COLORS.size())
		"acc": return Art.ACC_ORDER
		"top": return Art.TOPS
		"top_color": return range(Art.CLOTH_COLORS.size())
		"pants": return ["pantalon", "short", "falda"]
		"pants_color": return range(Art.PANTS_COLORS.size())
		"shoes": return range(Art.SHOE_COLORS.size())
	return []

func _key(cat: String, val) -> String:
	return "%s:%s" % [cat, str(val)]

func _owned(cat: String, val) -> bool:
	if args.get("mode") != "edit" or Game.s.is_empty(): return not DB.COSMETICS.has(_key(cat, val))
	return Game.cosmetic_owned(_key(cat, val))

func _value_name(cat: String, val) -> String:
	if val is String: return L.t("opt_" + val)
	if cat.ends_with("color") or cat == "shoes" or cat == "skin": return "%d" % (int(val) + 1)
	return str(val)

func _cycle(cat: String, dir: int) -> void:
	var opts := _options(cat)
	var i := opts.find(look[cat])
	var editing: bool = args.get("mode") == "edit"
	for _n in opts.size():
		i = (i + dir + opts.size()) % opts.size()
		var v = opts[i]
		# en partida nueva se saltan los bloqueados (salvo los que se compran con dinero del juego, se ven en el closet)
		if editing or _owned(cat, v):
			look[cat] = v
			break
	_refresh()

func _refresh() -> void:
	for c in preview.get_children(): c.queue_free()
	var pv := UI.person_view(look, 176)
	preview.add_child(pv)
	for c in rows_box.get_children(): c.queue_free()
	for cat in CATS:
		var h := UI.hbox(4)
		var l := UI.label(L.t(cat[1]), 16, UI.DIM)
		l.custom_minimum_size.x = 112
		h.add_child(l)
		var bl := UI.btn("<", func(): _cycle(cat[0], -1), "ghost", 30); bl.custom_minimum_size.x = 34
		h.add_child(bl)
		var val = look[cat[0]]
		var vl := UI.label(_value_name(cat[0], val), 18, UI.BONE if _owned(cat[0], val) else UI.CORAL)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if cat[0].ends_with("color") or cat[0] == "skin" or cat[0] == "shoes":
			var sw := ColorRect.new()
			sw.custom_minimum_size = Vector2(18, 18)
			sw.color = _swatch(cat[0], int(val))
			var hh := UI.hbox(4); hh.alignment = BoxContainer.ALIGNMENT_CENTER
			hh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hh.add_child(sw); hh.add_child(UI.label(_value_name(cat[0], val), 18, UI.BONE if _owned(cat[0], val) else UI.CORAL))
			h.add_child(hh)
		else:
			h.add_child(vl)
		if not _owned(cat[0], val): h.add_child(UI.icon("ic_lock", 18))
		var br := UI.btn(">", func(): _cycle(cat[0], 1), "ghost", 30); br.custom_minimum_size.x = 34
		h.add_child(br)
		rows_box.add_child(h)
	_update_lock()

func _swatch(cat: String, i: int) -> Color:
	match cat:
		"skin": return Color(Art.SKINS[i])
		"hair_color": return Color(Art.HAIR_COLORS[i])
		"top_color": return Color(Art.CLOTH_COLORS[i])
		"pants_color": return Color(Art.PANTS_COLORS[i])
		"shoes": return Color(Art.SHOE_COLORS[i])
	return Color.WHITE

func _locked_keys() -> Array:
	var out := []
	for cat in CATS:
		if not _owned(cat[0], look[cat[0]]): out.append(_key(cat[0], look[cat[0]]))
	return out

func _update_lock() -> void:
	for c in lock_box.get_children(): c.queue_free()
	var locked := _locked_keys()
	if locked.is_empty():
		lock_box.add_child(UI.label(" ", 12))
		return
	var key: String = locked[0]
	var d: Dictionary = DB.COSMETICS[key]
	var on_unlock := func() -> void:
		Game.unlock_cosmetic(key)
		Sfx.play("buy")
		_refresh()
	match String(d["type"]):
		"money":
			var buy_m := func() -> void:
				if Game.spend(int(d["price"])):
					on_unlock.call()
			lock_box.add_child(UI.btn(L.t("buy") + " " + UI.money(int(d["price"])), buy_m, "primary", 30))
		"bolts":
			var buy_b := func() -> void:
				if Game.spend_bolts(int(d["price"])):
					on_unlock.call()
			lock_box.add_child(UI.btn(L.t("buy") + " %d " % int(d["price"]) + L.t("bolts_short"), buy_b, "primary", 30))
		"ad":
			var buy_ad := func() -> void:
				Mon.show_rewarded("cosmetic", on_unlock)
			lock_box.add_child(UI.btn(L.t("unlock_with_ad"), buy_ad, "ad", 30))
		"pack":
			lock_box.add_child(UI.label(L.t("in_starter_pack"), 18, UI.SAND))

func _done() -> void:
	var editing: bool = args.get("mode") == "edit"
	if not _locked_keys().is_empty():
		UI.toast(L.t("locked_items"), UI.CORAL)
		return
	if editing:
		Game.s["look"] = look
		Game.save_game()
		get_parent().goto("game", {"tab": "house"})
		return
	var nm := name_edit.text.strip_edges()
	if nm == "": nm = L.t("default_name_m") if look["gender"] == "m" else L.t("default_name_f")
	Game.new_game(int(args.get("slot", 0)), nm, look)
	get_parent().goto("intro")

func on_back() -> void:
	if args.get("mode") == "edit": get_parent().goto("game", {"tab": "house"})
	else: get_parent().goto("slots", {"mode": "new"})
