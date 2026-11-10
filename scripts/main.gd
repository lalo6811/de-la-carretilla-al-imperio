extends Control
## Administrador de pantallas.

const SCREENS := {
	"menu": "res://scripts/screens/menu.gd",
	"slots": "res://scripts/screens/slots.gd",
	"options": "res://scripts/screens/options.gd",
	"creator": "res://scripts/screens/creator.gd",
	"intro": "res://scripts/screens/intro.gd",
	"game": "res://scripts/game/game_screen.gd",
}

var current: Control
var bg: ColorRect

func _ready() -> void:
	theme = UI.theme
	bg = ColorRect.new()
	bg.color = UI.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tile := TextureRect.new()
	tile.texture = Art.tex("bg_kraft")
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tile)
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	Sfx.apply_volume()
	goto("menu")
	if "--autotest" in OS.get_cmdline_user_args():
		add_child((load("res://tools/autotest.gd") as GDScript).new())
	if "--balance" in OS.get_cmdline_user_args():
		add_child((load("res://tools/balancesim.gd") as GDScript).new())
	if "--logictest" in OS.get_cmdline_user_args():
		add_child((load("res://tools/logictest.gd") as GDScript).new())

func goto(screen: String, args: Dictionary = {}) -> void:
	UI.clear_overlay()
	Game.playing = false
	if current:
		current.queue_free()
	var scr: GDScript = load(SCREENS[screen])
	var node: Control = scr.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.theme = UI.theme
	if "args" in node:
		node.args = args
	node.set_meta("main", self)
	Sfx.play_music("game" if screen == "game" else "menu")
	current = node
	add_child(node)
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, 0.18)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if UI.overlay.get_child_count() > 0:
			UI.overlay.get_child(UI.overlay.get_child_count() - 1).queue_free()
		elif current and current.has_method("on_back"):
			current.on_back()
		else:
			Game.save_game()
			get_tree().quit()
