extends Control
## Opciones: idioma, musica, efectos, vibracion.

var args := {}

static func build(on_lang_changed: Callable = Callable()) -> VBoxContainer:
	var v := UI.vbox(12)
	v.add_child(UI.label(L.t("language"), 15, UI.DIM, true))
	var lh := UI.hbox(8)
	for code in ["es", "en"]:
		var on_lang := func() -> void:
			Game.settings["lang"] = code
			Game.save_settings()
			if on_lang_changed.is_valid():
				on_lang_changed.call()
		var b := UI.btn("ESPAÑOL" if code == "es" else "ENGLISH", on_lang, "primary" if Game.settings["lang"] == code else "normal", 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(b)
	v.add_child(lh)
	for key in ["music", "sfx"]:
		v.add_child(UI.label(L.t(key), 15, UI.DIM, true))
		var sl := HSlider.new()
		sl.min_value = 0; sl.max_value = 1; sl.step = 0.05
		sl.value = float(Game.settings[key])
		sl.custom_minimum_size = Vector2(0, 28)
		sl.value_changed.connect(func(val: float):
			Game.settings[key] = val
			Sfx.apply_volume()
			Game.save_settings())
		v.add_child(sl)
	var vib := UI.btn("", Callable(), "normal", 38)
	var refresh := func() -> void:
		vib.text = L.t("vibration") + ": " + (L.t("on") if Game.settings["vibration"] else L.t("off"))
	refresh.call()
	vib.pressed.connect(func():
		Game.settings["vibration"] = not Game.settings["vibration"]
		Game.save_settings()
		refresh.call())
	v.add_child(vib)
	return v

func _ready() -> void:
	var col := UI.vbox(12)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20; col.offset_right = -20; col.offset_top = 30; col.offset_bottom = -20
	add_child(col)
	var t := UI.label(L.t("options"), 22, UI.BONE, true)
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(build(func(): get_parent().goto("options", args)))
	col.add_child(UI.spacer(false))
	var credits := UI.wrap_label(L.t("credits"), 16, UI.DIM)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credits)
	col.add_child(UI.btn(L.t("back"), func(): get_parent().goto(args.get("back", "menu")), "normal", 42))

func on_back() -> void:
	get_parent().goto(args.get("back", "menu"))
