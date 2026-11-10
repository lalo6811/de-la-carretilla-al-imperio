extends Control
## Foco del tutorial: oscurece la pantalla menos los objetivos y marca con una flecha que rebota.
## No bloquea toques (mouse_filter IGNORE): solo guia la vista.

var targets: Array = []        # Controls a iluminar (el primero lleva la flecha)
var world_rect := Rect2()       # objetivo en el escenario (en coordenadas globales)
var dim_alpha := 0.42
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func clear() -> void:
	targets = []
	world_rect = Rect2()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _visible_ctrl(c) -> bool:
	return c is Control and is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree()

func _holes() -> Array:
	var r := []
	if world_rect.size != Vector2.ZERO: r.append(world_rect.grow(6))
	for c in targets:
		if _visible_ctrl(c):
			r.append((c as Control).get_global_rect().grow(5))
	return r

func _popup_open() -> bool:
	return UI.overlay.get_child_count() > 0

func _inside_popup(c: Control) -> bool:
	var n: Node = c
	while n:
		if n == UI.overlay: return true
		n = n.get_parent()
	return false

func _draw() -> void:
	var holes := _holes()
	if holes.is_empty(): return
	# con un popup abierto solo dibujamos si el objetivo esta dentro del popup
	var main_target: Control = null
	for c in targets:
		if _visible_ctrl(c):
			main_target = c; break
	if _popup_open() and (main_target == null or not _inside_popup(main_target)): return
	var vs := get_viewport_rect().size
	var col := Color(0.08, 0.04, 0.02, dim_alpha)
	# franjas horizontales segun los bordes de los huecos
	var ys := [0.0, vs.y]
	for h in holes:
		ys.append(clampf(h.position.y, 0, vs.y)); ys.append(clampf(h.end.y, 0, vs.y))
	ys.sort()
	for i in ys.size() - 1:
		var y0: float = ys[i]; var y1: float = ys[i + 1]
		if y1 - y0 <= 0.5: continue
		var xs := []
		for h in holes:
			if h.position.y <= y0 + 0.1 and h.end.y >= y1 - 0.1:
				xs.append([h.position.x, h.end.x])
		xs.sort_custom(func(a, b): return a[0] < b[0])
		var x := 0.0
		for seg in xs:
			if seg[0] > x: draw_rect(Rect2(x, y0, seg[0] - x, y1 - y0), col)
			x = maxf(x, seg[1])
		if x < vs.x: draw_rect(Rect2(x, y0, vs.x - x, y1 - y0), col)
	# marco y flecha sobre el objetivo principal
	var r: Rect2 = holes[0]
	if main_target != null: r = main_target.get_global_rect().grow(5)
	elif world_rect.size != Vector2.ZERO: r = world_rect.grow(6)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	draw_rect(r, Color(1.0, 0.85, 0.3, 0.55 + 0.45 * pulse), false, 3.0)
	var bob := sin(_t * 5.0) * 6.0
	var up := r.position.y > 90.0   # flecha arriba del objetivo apuntando hacia abajo
	var cx := clampf(r.get_center().x, 20, vs.x - 20)
	var tip := Vector2(cx, r.position.y - 4 + bob) if up else Vector2(cx, r.end.y + 4 - bob)
	var dir := 1.0 if up else -1.0
	var pts := PackedVector2Array([tip, tip + Vector2(-14, -18 * dir), tip + Vector2(-6, -18 * dir), tip + Vector2(-6, -34 * dir),
		tip + Vector2(6, -34 * dir), tip + Vector2(6, -18 * dir), tip + Vector2(14, -18 * dir)])
	var outline := pts.duplicate(); outline.append(tip)
	draw_colored_polygon(pts, Color("f2b632"))
	draw_polyline(outline, Color("3a2618"), 2.5, true)
