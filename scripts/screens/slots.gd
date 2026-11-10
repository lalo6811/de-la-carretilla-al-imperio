extends Control
## Ranuras de guardado (3). args.mode = "new" | "load"

var args := {}
var list: VBoxContainer

func _ready() -> void:
	var col := UI.vbox(10)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16; col.offset_right = -16; col.offset_top = 24; col.offset_bottom = -16
	add_child(col)
	var t := UI.label(L.t("choose_slot_new") if args.get("mode") == "new" else L.t("choose_slot_load"), 22, UI.BONE, true)
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	list = UI.vbox(10)
	col.add_child(list)
	col.add_child(UI.spacer(false))
	col.add_child(UI.btn(L.t("back"), func(): get_parent().goto("menu"), "normal", 42))
	_build()

func _build() -> void:
	for c in list.get_children(): c.queue_free()
	for i in Game.SLOTS:
		var inf := Game.slot_info(i)
		var card := UI.card(UI.PANEL, UI.LINE, 8)
		var h := UI.hbox(10)
		card.add_child(h)
		if inf.is_empty():
			h.add_child(UI.icon("ic_box", 44))
			var v := UI.vbox(2)
			v.add_child(UI.label(L.t("slot") + " %d" % (i + 1), 15, UI.DIM, true))
			v.add_child(UI.label(L.t("empty_slot"), 20, UI.LINE))
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			if args.get("mode") == "new":
				h.add_child(UI.btn(L.t("start"), func(): _new(i), "primary", 36))
		else:
			var look: Dictionary = inf["look"] if inf["look"] is Dictionary and not inf["look"].is_empty() else Art.default_look("m")
			h.add_child(UI.person_view(look, 54, "idle", true))
			var v := UI.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UI.label(L.t("slot") + " %d · %s" % [i + 1, inf["name"]], 16, UI.SAND, true))
			v.add_child(UI.label("%s %d · %s %d · %s" % [L.t("day"), int(inf["day"]), L.t("lvl_short"), int(inf["level"]), UI.money(int(inf["money"]))], 18))
			var dt := Time.get_datetime_dict_from_unix_time(int(inf["last"]) + int(Time.get_time_zone_from_system()["bias"]) * 60)
			v.add_child(UI.label("%02d/%02d %02d:%02d" % [dt["day"], dt["month"], dt["hour"], dt["minute"]], 16, UI.DIM))
			h.add_child(v)
			var bv := UI.vbox(4)
			if args.get("mode") == "new":
				bv.add_child(UI.btn(L.t("overwrite"), func(): UI.confirm(L.t("overwrite"), L.t("overwrite_q"), func(): _new(i)), "normal", 30))
			else:
				bv.add_child(UI.btn(L.t("play"), func(): _load(i), "primary", 30))
			var do_delete := func() -> void:
				Game.delete_slot(i)
				_build()
			var ask_delete := func() -> void:
				UI.confirm(L.t("delete"), L.t("delete_q"), do_delete)
			bv.add_child(UI.btn(L.t("delete"), ask_delete, "bad", 26))
			h.add_child(bv)
		list.add_child(card)

func _new(i: int) -> void:
	get_parent().goto("creator", {"mode": "new", "slot": i})

func _load(i: int) -> void:
	if Game.load_game(i):
		get_parent().goto("game")

func on_back() -> void:
	get_parent().goto("menu")
