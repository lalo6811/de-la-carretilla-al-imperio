extends RefCounted
## Utilidades vectoriales: convierte trazos tipo SVG (M, L, H, V, Q, C, Z y sus minusculas)
## en poligonos para dibujarlos con draw_colored_polygon / draw_polyline.

const CURVE_STEPS := 8

static func _tokens(d: String) -> Array:
	var re := RegEx.new()
	re.compile("[MmLlHhVvQqCcZz]|-?\\d*\\.?\\d+(?:e-?\\d+)?")
	var out := []
	for m in re.search_all(d):
		out.append(m.get_string())
	return out

static func path(d: String, offset := Vector2.ZERO, scale := 1.0) -> Array:
	## Devuelve un Array de PackedVector2Array (un subtrazo por cada M ... z)
	var toks := _tokens(d)
	var subs: Array = []
	var cur := PackedVector2Array()
	var p := Vector2.ZERO
	var start := Vector2.ZERO
	var cmd := ""
	var i := 0
	while i < toks.size():
		var t: String = toks[i]
		if t.length() == 1 and "MmLlHhVvQqCcZz".contains(t):
			cmd = t
			i += 1
			if cmd == "Z" or cmd == "z":
				p = start
				if cur.size() > 2: subs.append(cur)
				cur = PackedVector2Array()
			continue
		var rel := cmd == cmd.to_lower()
		match cmd.to_upper():
			"M":
				var v := Vector2(float(toks[i]), float(toks[i + 1])); i += 2
				p = p + v if rel else v
				if cur.size() > 2: subs.append(cur)
				cur = PackedVector2Array([p])
				start = p
				cmd = "l" if rel else "L"
			"L":
				var v := Vector2(float(toks[i]), float(toks[i + 1])); i += 2
				p = p + v if rel else v
				cur.append(p)
			"H":
				var x := float(toks[i]); i += 1
				p.x = p.x + x if rel else x
				cur.append(p)
			"V":
				var y := float(toks[i]); i += 1
				p.y = p.y + y if rel else y
				cur.append(p)
			"Q":
				var c1 := Vector2(float(toks[i]), float(toks[i + 1]))
				var e := Vector2(float(toks[i + 2]), float(toks[i + 3])); i += 4
				if rel: c1 += p; e += p
				for k in range(1, CURVE_STEPS + 1):
					var tt := float(k) / CURVE_STEPS
					cur.append(p.lerp(c1, tt).lerp(c1.lerp(e, tt), tt))
				p = e
			"C":
				var c1 := Vector2(float(toks[i]), float(toks[i + 1]))
				var c2 := Vector2(float(toks[i + 2]), float(toks[i + 3]))
				var e := Vector2(float(toks[i + 4]), float(toks[i + 5])); i += 6
				if rel: c1 += p; c2 += p; e += p
				for k in range(1, CURVE_STEPS + 2):
					var tt := float(k) / (CURVE_STEPS + 1)
					var a := p.lerp(c1, tt); var b := c1.lerp(c2, tt); var c := c2.lerp(e, tt)
					cur.append(a.lerp(b, tt).lerp(b.lerp(c, tt), tt))
				p = e
			_:
				i += 1
	if cur.size() > 2: subs.append(cur)
	if offset != Vector2.ZERO or scale != 1.0:
		for s in subs.size():
			var arr: PackedVector2Array = subs[s]
			for k in arr.size():
				arr[k] = arr[k] * scale + offset
			subs[s] = arr
	return subs

static func ellipse(c: Vector2, rx: float, ry: float, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func safe_polygon(pts: PackedVector2Array) -> PackedVector2Array:
	## Si el poligono no se puede triangular (se cruza), usa su envolvente convexa
	if pts.size() < 3: return pts
	if Geometry2D.triangulate_polygon(pts).is_empty():
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() > 3: hull.remove_at(hull.size() - 1)
		return hull
	return pts
