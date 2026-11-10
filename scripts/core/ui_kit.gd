extends Node
## Kit de interfaz: papel, madera, notas de remision y planos. Fuentes: Fredoka (interfaz),
## Oswald (letreros y titulos), Caveat (letra de mano), Patrick Hand (dialogos).

const NIGHT := Color("c9a57a")    # carton kraft (fondo)
const KRAFT_DK := Color("b8935f")
const PANEL := Color("f7eedb")    # papel crema
const PAPER := Color("fffbef")    # papel de nota
const LINE := Color("8c6a4a")     # borde cafe
const SAND := Color("b4530f")     # naranja tostado (precios)
const YELLOW := Color("f2b533")   # amarillo de seguridad
const MINT := Color("2f8a5b")     # verde
const CORAL := Color("c0432e")    # rojo sello
const BONE := Color("3a2618")     # texto principal
const DIM := Color("7d6450")      # texto secundario
const INK := Color("24170f")
const BLUE_INK := Color("2f4f8f") # tinta de pluma
const WOOD := Color("4a3427")
const WOOD_LT := Color("6b4c38")
const LIGHT := Color("f7eedb")
const BLUEPRINT := Color("2f5590")

const Person = preload("res://scripts/core/person.gd")

var f_ui: FontVariation
var f_ui_bold: FontVariation
var f_title: FontVariation
var f_hand: Font
var f_talk: FontFile
var font_title: Font   # compatibilidad
var font_body: Font
var theme: Theme
var overlay: CanvasLayer
var toast_layer: CanvasLayer
var _toast_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fr: FontFile = load("res://assets/fonts/Fredoka.ttf")
	var os_: FontFile = load("res://assets/fonts/Oswald.ttf")
	var cav: FontFile = load("res://assets/fonts/Caveat.ttf")
	f_talk = load("res://assets/fonts/PatrickHand.ttf")
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	f_ui = FontVariation.new(); f_ui.base_font = fr; f_ui.variation_opentype = {wght: 500}
	f_ui_bold = FontVariation.new(); f_ui_bold.base_font = fr; f_ui_bold.variation_opentype = {wght: 650}
	f_title = FontVariation.new(); f_title.base_font = os_; f_title.variation_opentype = {wght: 650}
	var hand_v := FontVariation.new(); hand_v.base_font = cav; hand_v.variation_opentype = {wght: 700}
	f_hand = hand_v
	font_title = f_title
	font_body = f_ui
	theme = _make_theme()
	overlay = CanvasLayer.new(); overlay.layer = 40
	toast_layer = CanvasLayer.new(); toast_layer.layer = 60
	get_tree().root.call_deferred("add_child", overlay)
	get_tree().root.call_deferred("add_child", toast_layer)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_box.offset_top = 70
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 4)
	toast_layer.add_child(_toast_box)

# ---------------------------------------------------------------- estilos
func sb(bg: Color, border := LINE, bw := 2, pad := 8, chunky := false, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	if chunky and bw > 0:
		s.border_width_bottom = bw + 2
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad - 2; s.content_margin_bottom = pad - 1
	return s

func paper_style(pad := 10) -> StyleBoxFlat:
	var s := sb(PANEL, Color("c9b48c"), 1, pad, false, 6)
	s.shadow_color = Color(0.23, 0.15, 0.09, 0.28)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = f_ui
	t.default_font_size = 15
	t.set_color("font_color", "Label", BONE)
	t.set_stylebox("normal", "Button", sb(Color("f3e4c6"), LINE, 2, 8, true, 12))
	t.set_stylebox("hover", "Button", sb(Color("faeed6"), LINE, 2, 8, true, 12))
	t.set_stylebox("pressed", "Button", sb(Color("e4d0aa"), LINE, 2, 8, false, 12))
	t.set_stylebox("disabled", "Button", sb(Color("e6dac2"), Color("bba78a"), 2, 8, false, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", f_ui_bold)
	t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", BONE)
	t.set_color("font_pressed_color", "Button", SAND)
	t.set_color("font_disabled_color", "Button", Color("a8957d"))
	t.set_constant("icon_max_width", "Button", 22)
	t.set_stylebox("panel", "PanelContainer", paper_style())
	t.set_stylebox("panel", "Panel", paper_style())
	t.set_stylebox("normal", "LineEdit", sb(PAPER, LINE, 2, 8))
	t.set_stylebox("focus", "LineEdit", sb(PAPER, SAND, 2, 8))
	t.set_font("font", "LineEdit", f_ui)
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", Color("b8a488"))
	t.set_color("caret_color", "LineEdit", SAND)
	t.set_stylebox("grabber_area", "HSlider", sb(YELLOW, LINE, 1, 3, false, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(YELLOW, LINE, 1, 3, false, 6))
	t.set_stylebox("slider", "HSlider", sb(PANEL, LINE, 1, 3, false, 6))
	t.set_icon("grabber", "HSlider", _knob(YELLOW))
	t.set_icon("grabber_highlight", "HSlider", _knob(Color("ffd56a")))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 1, false, 4))
	t.set_stylebox("grabber", "VScrollBar", sb(Color(0.3, 0.2, 0.13, 0.45), Color(0, 0, 0, 0), 0, 2, false, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(0.3, 0.2, 0.13, 0.7), Color(0, 0, 0, 0), 0, 2, false, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(SAND, SAND, 0, 2, false, 4))
	t.set_stylebox("fill", "ProgressBar", sb(MINT, MINT, 0, 0, false, 5))
	t.set_stylebox("background", "ProgressBar", sb(Color("e8dcc2"), LINE, 1, 0, false, 5))
	t.set_font_size("font_size", "ProgressBar", 1)
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	return t

func _knob(c: Color) -> ImageTexture:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 22:
		for x in 22:
			var d := Vector2(x - 10.5, y - 10.5).length()
			if d < 10.5: img.set_pixel(x, y, Color("7a5a1a") if d > 8.5 else c)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- formato
func fmt(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out

func money(n: int) -> String:
	return "$" + fmt(n)

func fmt_time(sec: float) -> String:
	var t := int(ceil(sec))
	if t >= 3600: return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	return "%d:%02d" % [t / 60, t % 60]

func caps(t: String) -> String:
	return t

# ---------------------------------------------------------------- constructores
func label(text: String, size := 16, color := BONE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	if title:
		l.add_theme_font_override("font", f_title)
		l.add_theme_font_size_override("font_size", maxi(int(size * 1.7), 14) if size < 12 else size)
	else:
		l.add_theme_font_override("font", f_ui)
		l.add_theme_font_size_override("font_size", int(round(size * 0.82)) if size >= 16 else size)
	l.add_theme_color_override("font_color", color)
	return l

func hand_label(text: String, size := 22, color := BLUE_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f_hand)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func talk_label(text: String, size := 16, color := BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f_talk)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	# margen para que las letras inclinadas no se corten en la orilla
	var pad := StyleBoxEmpty.new()
	pad.content_margin_right = 6; pad.content_margin_bottom = 3; pad.content_margin_left = 1
	l.add_theme_stylebox_override("normal", pad)
	return l

func wrap_label(text: String, size := 16, color := BONE) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	return l

func btn(text: String, cb: Callable = Callable(), kind := "normal", min_h := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, maxi(min_h, 32))
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = false
	match kind:
		"primary":
			_btn_style(b, YELLOW, Color("8a6418"), INK)
		"good":
			_btn_style(b, Color("3f9a68"), Color("23603f"), LIGHT)
		"bad":
			_btn_style(b, Color("c9563f"), Color("7e2e20"), LIGHT)
		"ad":
			_btn_style(b, Color("2f8790"), Color("1d5559"), LIGHT)
		"stamp":
			_btn_style(b, CORAL, Color("7e2e20"), Color("fff6e8"), 8)
			b.add_theme_font_override("font", f_title)
			b.add_theme_font_size_override("font_size", 20)
		"ghost":
			_btn_style(b, Color(1, 1, 1, 0.35), LINE, BONE)
	if cb.is_valid():
		var on_press := func() -> void:
			Sfx.play("click")
			cb.call()
		b.pressed.connect(on_press)
	return b

func _btn_style(b: Button, bg: Color, border: Color, fc: Color, radius := 12) -> void:
	b.add_theme_stylebox_override("normal", sb(bg, border, 2, 8, true, radius))
	b.add_theme_stylebox_override("hover", sb(bg.lightened(0.08), border, 2, 8, true, radius))
	b.add_theme_stylebox_override("pressed", sb(bg.darkened(0.1), border, 2, 8, false, radius))
	b.add_theme_stylebox_override("disabled", sb(bg.lerp(Color("e6dac2"), 0.6), border.lerp(Color("bba78a"), 0.6), 2, 8, false, radius))
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", fc.lerp(Color("a8957d"), 0.5))

func wood_bar(pad := 5) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = Art.tex("wood_tile")
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.content_margin_left = pad; st.content_margin_right = pad
	st.content_margin_top = pad; st.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", st)
	return p

func _px(scale_or_px: int) -> int:
	return scale_or_px * 14 + 6 if scale_or_px <= 4 else scale_or_px

func icon(name: String, size := 2) -> TextureRect:
	return tex_rect(Art.tex(name), size)

func tex_rect(t: Texture2D, size := 2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var px := _px(size)
	if t:
		var asp := float(t.get_width()) / maxf(1.0, float(t.get_height()))
		tr.custom_minimum_size = Vector2(px * asp, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func person_view(look: Dictionary, height := 60.0, mood := "idle", head_only := false) -> Control:
	## Personaje vectorial dentro de un Control (para retratos en la interfaz)
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = head_only
	var p := Person.new()
	p.setup(look)
	var hc: Vector2 = p.B["head"]
	var hr: float = p.B["hr"]
	if head_only:
		var s := height / (hr * 3.0)
		p.scale = Vector2(s, s)
		c.custom_minimum_size = Vector2(height, height)
		p.position = Vector2(height / 2.0 - hc.x * s, height * 0.52 - hc.y * s)
	else:
		var total := -hc.y + hr * 1.5
		var s := height / total
		p.scale = Vector2(s, s)
		c.custom_minimum_size = Vector2(height * 0.55, height)
		p.position = Vector2(height * 0.275, height - 2)
	c.add_child(p)
	if mood != "idle": p.set_mood(mood)
	c.set_meta("person", p)
	return c

func hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func card(bg := PANEL, border := LINE, pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	if bg == PANEL and border == LINE:
		p.add_theme_stylebox_override("panel", paper_style(pad))
	else:
		var s := sb(bg, border, 2, pad, false, 8)
		s.shadow_color = Color(0.23, 0.15, 0.09, 0.22); s.shadow_size = 2; s.shadow_offset = Vector2(0, 2)
		p.add_theme_stylebox_override("panel", s)
	return p

func blueprint_card(pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sb(BLUEPRINT, Color("dce8ff"), 1, pad, false, 4)
	s.shadow_color = Color(0.1, 0.1, 0.2, 0.3); s.shadow_size = 2; s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	return p

func spacer(h := true) -> Control:
	var c := Control.new()
	if h: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func progress(value: float, max_v: float, color := MINT, h := 8) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = max_v; p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(20, h)
	p.add_theme_stylebox_override("fill", sb(color, color, 0, 0, false, int(h / 2)))
	p.add_theme_stylebox_override("background", sb(Color("e8dcc2"), LINE, 1, 0, false, int(h / 2)))
	return p

func scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc

func price_row(amount: int, kind := "money") -> HBoxContainer:
	var h := hbox(3)
	h.add_child(icon("ic_coin" if kind == "money" else ("ic_bolt" if kind == "bolts" else "ic_ad"), 18))
	h.add_child(label(money(amount) if kind == "money" else (str(amount) if kind == "bolts" else L.t("watch_ad")), 16, SAND if kind != "ad" else MINT))
	return h

# ---------------------------------------------------------------- popups
func popup(title: String, content: Control, buttons: Array = [], closable := true) -> Control:
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.14, 0.08, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := PanelContainer.new()
	var st := paper_style(14)
	st.border_width_top = 6; st.border_color = SAND
	box.add_theme_stylebox_override("panel", st)
	box.custom_minimum_size = Vector2(320, 0)
	center.add_child(box)
	var v := vbox(10)
	box.add_child(v)
	var head := hbox()
	var tl := label(title, 20, SAND, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(tl)
	if closable:
		var x := btn("✕", func(): close(root), "ghost", 32)
		x.custom_minimum_size.x = 34
		head.add_child(x)
	v.add_child(head)
	if content: v.add_child(content)
	if not buttons.is_empty():
		var row := hbox(8)
		for b in buttons:
			var cb: Callable = b[1]
			var action := func() -> void:
				close(root)
				if cb.is_valid():
					cb.call()
			var kind: String = b[2] if b.size() > 2 else "normal"
			var bt := btn(b[0], action, kind, 42)
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bt)
		v.add_child(row)
	overlay.add_child(root)
	box.pivot_offset = Vector2(160, 80)
	box.scale = Vector2(0.92, 0.92)
	root.modulate.a = 0.0
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.14)
	tw.tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root

func close(node: Control) -> void:
	if is_instance_valid(node):
		node.queue_free()

func message(title: String, text: String, ok_text := "") -> Control:
	return popup(title, wrap_label(text, 18), [[ok_text if ok_text != "" else L.t("ok"), Callable(), "primary"]])

func confirm(title: String, text: String, yes: Callable, yes_text := "") -> Control:
	return popup(title, wrap_label(text, 18), [[L.t("cancel"), Callable()], [yes_text if yes_text != "" else L.t("yes"), yes, "primary"]])

func clear_overlay() -> void:
	for c in overlay.get_children(): c.queue_free()

func toast(text: String, color := BONE) -> void:
	# no repetir el mismo aviso si ya se esta viendo
	for ch in _toast_box.get_children():
		if not ch.is_queued_for_deletion() and ch.get_meta("text", "") == text: return
	var p := PanelContainer.new()
	p.set_meta("text", text)
	var st := sb(PAPER, Color("c9b48c"), 1, 8, false, 6)
	st.border_width_left = 5; st.border_color = color if color != BONE else YELLOW
	st.shadow_color = Color(0.2, 0.12, 0.06, 0.3); st.shadow_size = 3; st.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := label(text, 17, color if color != YELLOW else BONE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 270
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	if _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func float_text(parent: Node, pos: Vector2, text: String, color := YELLOW) -> void:
	if color == SAND: color = YELLOW
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f_title)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 5)
	l.position = pos
	l.z_index = 50
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", pos.y - 30, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)
