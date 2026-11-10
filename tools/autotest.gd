extends Node
## Recorrido automatico para pruebas: toma capturas de cada pantalla.
## Uso: godot --path . -- --autotest

var out := "/tmp/shots"
var main: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	main = get_parent()
	_run()

func shot(name: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name)

func _run() -> void:
	Game.settings["lang"] = "es"
	await shot("01_menu")
	main.goto("slots", {"mode": "new"})
	await shot("02_slots")
	main.goto("creator", {"mode": "new", "slot": 2})
	await shot("03_creator")
	Game.new_game(2, "Eduardo", Art.default_look("m"))
	main.goto("intro")
	await shot("04_intro1")
	var intro = main.current
	for i in 2:
		intro._shown = 999; intro._advance()
	await shot("05_intro3")
	intro._shown = 999; intro._advance()
	await get_tree().create_timer(2.5).timeout
	await shot("06_intro4")
	main.goto("game")
	await shot("07_game_dirty")
	for i in 6: Game.clean_spot(i)
	await get_tree().create_timer(0.5).timeout
	Game._spawn_timer = 0.0
	await get_tree().create_timer(3.0).timeout
	await shot("08_game_customer")
	main.current._set_tab("mine")
	await shot("09_mine")
	Game.send_trip(1, {"arena": 4}, true)
	main.current._rebuild()
	await get_tree().create_timer(9.0).timeout
	await shot("10_mine_trip")
	main.current._set_tab("house")
	await shot("11_house")
	main.current._set_tab("upgrades")
	await shot("12_upgrades")
	main.current._set_tab("store")
	await shot("13_store")
	main.current._set_tab("local")
	main.current.sub_local = "supplier"; main.current._rebuild()
	await shot("14_supplier")
	# progreso avanzado
	Game.s["level"] = 12; Game.s["money"] = 500000; Game.s["shop_stage"] = 7; Game.s["house_stage"] = 4
	Game.s["inv"] = {"arena": 40, "grava": 30, "cemento": 12, "cal": 6, "tabique": 50, "piedra": 10}
	Game.s["transport"] = "moto"; Game.s["transports"].append("moto")
	Game.buy_vehicle("pickup"); Game.hire_driver(2)
	Game.s["clerks"] = 1
	Game.customers.clear()
	main.goto("game")
	Game._spawn_timer = 0.0
	await get_tree().create_timer(2.0).timeout
	Game._spawn_timer = 0.0
	await get_tree().create_timer(3.0).timeout
	main.current.sub_local = "inventory"; main.current._rebuild()
	await shot("15_shop_late")
	main.current._set_tab("house")
	await shot("16_house_late")
	Game.send_trip(2, {"grava": 20}, false)
	main.current._set_tab("mine")
	await get_tree().create_timer(15.0).timeout
	await shot("17_mine_pickup")
	Game.settings["lang"] = "en"
	main.goto("game", {"tab": "local"})
	await get_tree().create_timer(1.0).timeout
	await shot("18_english")
	Game.settings["lang"] = "es"
	Game.visitor_active = true; Game.visitor_time = 30; Game.visitor_changed.emit()
	await shot("19_visitor")
	main.current._visitor_popup()
	await shot("20_visitor_popup")
	UI.clear_overlay()
	Game.add_xp(5000)
	await shot("21_levelup")
	UI.clear_overlay()
	main.current._ask_sleep()
	await get_tree().create_timer(0.3).timeout
	await shot("22_sleep_q")
	Game.delete_slot(2)
	print("AUTOTEST DONE")
	get_tree().quit()
