extends SceneTree
func _init() -> void:
	var art = load("res://scripts/core/art.gd").new()
	var looks := []
	looks.append(art.default_look("m")); looks.append(art.default_look("f")); looks.append(art.grandpa_look())
	var r := RandomNumberGenerator.new(); r.seed = 7
	for i in 9: looks.append(art.random_look(r))
	var l2 = art.default_look("m"); l2["top"] = "chaleco"; l2["acc"] = "casco"; looks.append(l2)
	var l3 = art.default_look("f"); l3["top"] = "overol"; l3["hair"] = "coleta"; l3["acc"] = "gorra"; looks.append(l3)
	var frames := ["idle", "walk_a", "walk_b", "happy"]
	var sheet := Image.create(24 * looks.size(), 44 * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e9dcc2"))
	for i in looks.size():
		for f in frames.size():
			var t: ImageTexture = art.character(looks[i], frames[f])
			sheet.blend_rect(t.get_image(), Rect2i(0, 0, 22, 42), Vector2i(i * 24 + 1, f * 44 + 1))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png("/tmp/chars.png")
	print("ok")
	quit()
