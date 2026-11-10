extends Node
## Pruebas de logica: recorre flujos y reporta errores.
var main: Node
var fails := 0

func ok(cond: bool, msg: String) -> void:
	if cond: print("PASS ", msg)
	else:
		fails += 1; print("FAIL ", msg)

func shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/L_%s.png" % name)

func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	await get_tree().process_frame
	Game.new_game(1, "Test", Art.default_look("f"))
	main.goto("game")
	await get_tree().create_timer(0.5).timeout
	var gs = main.current
	for i in 6: Game.clean_spot(i)
	ok(Game.shop_stage() == 1, "limpieza abre el local")
	await get_tree().create_timer(2.5).timeout
	ok(Game.customers.size() == 1 and int(Game.customers[0].get("tut", 0)) == 1, "tutorial: llega Dona Mari")
	ok(Game.serve(Game.customers[0])["ok"], "tutorial: entregar a Mari")
	await get_tree().create_timer(2.5).timeout
	ok(Game.customers.size() == 1 and int(Game.customers[0].get("tut", 0)) == 2, "tutorial: llega Don Chuy")
	ok(not Game.can_fulfill(Game.customers[0]), "tutorial: a Chuy le falta arena")
	ok(Game.send_trip(1, {"arena": 6}, true), "tutorial: viaje a la mina")
	ok(int(Game.s["tutorial"]) == 3, "tutorial: paso 3")
	ok(Game.free_skip_available(1), "tutorial: adelanto gratis disponible")
	Game.use_free_skip(1)
	ok(not Game.free_skip_available(1), "tutorial: adelanto gratis usado")
	ok(Game.serve(Game.customers[0])["ok"], "tutorial: entregar a Chuy")
	ok(int(Game.s["tutorial"]) == 4, "tutorial: ir a dormir")
	await get_tree().create_timer(4.0).timeout
	ok(Game.customers.is_empty(), "tutorial paso 4: ya no llegan clientes")
	await shot("tut_step4_spot")
	gs._nav_pressed("house")
	ok(Game.at_home(), "ir a casa cierra el dia")
	await shot("transit_home")
	await get_tree().create_timer(3.2).timeout
	ok(gs.tab == "house", "llegas a casa")
	await shot("tut_sleep")
	Game.sleep()
	await shot("day1_summary")
	var dp = UI.overlay.get_child(UI.overlay.get_child_count() - 1)
	var dbt: Array = dp.find_children("*", "Button", true, false)
	(dbt[dbt.size() - 1] as Button).pressed.emit()
	ok(int(Game.s["tutorial"]) == 5 and int(Game.s["day"]) == 2 and not Game.at_home(), "tutorial terminado al dormir")
	ok(Game.phase() == "morning" and int(Game.s["day_quota"]) >= 3, "dia 2 empieza en la manana con clientes por llegar")
	await get_tree().create_timer(3.5).timeout
	ok(gs.tab == "local", "de regreso al local")
	ok(Game.customers.is_empty(), "en la manana no llegan clientes")
	await shot("morning")
	# --- manana: la mina temprano
	ok(Game.mine_open(), "el martes la mina abre")
	var e0 := float(Game.s["energy"])
	ok(Game.send_trip(1, {"arena": 4}, true), "ir a la mina antes de abrir")
	ok(float(Game.s["energy"]) < e0, "ir a la mina gasta energia")
	Game.skip_trip(1)
	# --- abrir y la cuota del dia
	Game.open_shop()
	ok(Game.phase() == "open", "abrir el local")
	Game.s["energy"] = 50.0
	Game.s["day_quota"] = 3
	var served := 0
	for i in 40:
		Game._spawn_timer = 0.0
		Game._tick_customers(0.01)
		for cc in Game.customers.duplicate():
			for o in cc["order"]: Game.s["inv"][o["id"]] = maxi(Game.inv_qty(o["id"]), int(o["qty"]))
			if Game.serve(cc)["ok"]: served += 1
	ok(served == 3 and int(Game.s["day_spawned"]) == 3, "llegan solo los clientes del dia")
	ok(Game.phase() == "closed", "al atender al ultimo se cierra")
	ok(int(Game.s["stats"]["perfect_days"]) == 1, "dia perfecto contado")
	gs._set_tab("local")
	await shot("closed_card")
	# energia al atender
	Game.s["phase"] = "open"; Game.s["day_quota"] = 99
	var ce := Game.gen_customer()
	for o in ce["order"]: Game.s["inv"][o["id"]] = int(o["qty"]) + 1
	Game.customers.append(ce)
	Game.s["energy"] = 0.0
	ok(not Game.serve(ce)["ok"], "sin energia no puedes atender")
	Game.s["energy"] = 10.0
	ok(Game.serve(ce)["ok"] and float(Game.s["energy"]) <= 9.0, "atender gasta 1 de energia")
	Game.s["energy"] = 40.0
	gs._set_tab("local")
	# cliente y entrega
	var c := Game.gen_customer()
	Game.customers.append(c); Game.customer_arrived.emit(c); Game.customers_changed.emit()
	for o in c["order"]: Game.s["inv"][o["id"]] = int(o["qty"]) + 1
	var m0 := Game.money()
	gs.selected = c; gs._rebuild()
	await get_tree().process_frame
	await shot("note_columns")
	var paid0 := int(c["price"])
	gs._deliver(c)
	ok(Game.money() >= m0 + paid0, "entregar pedido paga el total")
	ok(not Game.gen_customer()["haggle"], "sin regateo")
	# frecuentes con agenda: no repiten el mismo dia
	Game.s["reg_last"] = {"mari": int(Game.s["day"]), "chuy": int(Game.s["day"])}
	var reg_hits := 0
	for i in 60:
		var cr := Game.gen_customer()
		if cr.has("regular"): reg_hits += 1
	ok(reg_hits == 0, "Mari y Chuy no regresan el mismo dia")
	# fila llena: nadie se pierde, esperan afuera
	var sp0 := int(Game.s["day_spawned"])
	while Game.customers.size() < Game.queue_size():
		Game.customers.append(Game.gen_customer())
	for i in 3:
		Game._spawn_timer = 0.0
		Game._tick_customers(0.01)
	ok(int(Game.s["day_spawned"]) == sp0, "con la fila llena esperan afuera")
	Game.customers.clear(); Game.customers_changed.emit()
	# frases con proyecto
	var proj_ok := true
	for i in 30:
		var cp := Game.gen_customer()
		var pr = null
		for p in DB.PROJECTS[cp["type"]]:
			if p["id"] == cp["project"]: pr = p
		if pr == null: proj_ok = false; continue
		for o in cp["order"]:
			if not pr["items"].has(o["id"]): proj_ok = false
	ok(proj_ok, "lo que pide el cliente es de su proyecto")
	# patio y anaqueles separados
	Game.s["inv"] = {"arena": Game.space_cap("patio")}
	ok(Game.space_free("shelf") == Game.space_cap("shelf"), "el patio lleno no quita lugar en anaqueles")
	Game.s["money"] = 9000
	ok(Game.buy_supply("cemento", 2, true), "compra urgente con el patio lleno")
	ok(not Game.send_trip(1, {"arena": 2}, true), "no cabe mas en el patio")
	# proveedor por dias
	var oc := Game.inv_qty("cal")
	var m1 := Game.money()
	ok(Game.buy_supply("cal", 3, false) and Game.inv_qty("cal") == oc and int(Game.s["supplier_orders"]["cal"]) == 3, "pedido normal llega despues")
	ok(m1 - Game.money() == int(DB.ITEMS["cal"]["cost"]) * 3, "pedido normal a precio normal")
	var m2 := Game.money()
	Game.buy_supply("cal", 1, true)
	ok(m2 - Game.money() == Game.supply_price("cal", true) and Game.supply_price("cal", true) > int(DB.ITEMS["cal"]["cost"]), "urgente cuesta mas")
	gs._set_tab("local"); gs.sub_local = "supplier"; gs._rebuild()
	await shot("supplier")
	gs.sub_local = "inventory"; gs._rebuild()
	await shot("inventory")
	gs.sub_local = "counter"
	# encargos
	Game.s["inv"] = {}
	var ce2 := Game.gen_customer(); ce2["order"] = [{"id": "grava", "qty": 5}]; ce2["price"] = 100
	Game.customers.append(ce2)
	var m3 := Game.money()
	ok(Game.take_encargo(ce2) and Game.money() == m3 + 30 and Game.s["encargos"].size() == 1, "tomar encargo con anticipo")
	Game.customers.clear(); Game.customers_changed.emit()
	# comprar faltante
	Game.s["inv"] = {"arena": 6, "grava": 6}
	Game.s["money"] = 5000
	var c3 := Game.gen_customer(); c3["order"] = [{"id": "cemento", "qty": 3}]
	Game.s["inv"].erase("cemento")
	Game.customers.append(c3)
	ok(not Game.can_fulfill(c3), "detecta faltante")
	gs._buy_missing(c3)
	await get_tree().process_frame
	var pop = UI.overlay.get_child(UI.overlay.get_child_count() - 1)
	# presiona el boton SI del confirm
	var btns := pop.find_children("*", "Button", true, false)
	(btns[btns.size() - 1] as Button).pressed.emit()
	await get_tree().process_frame
	ok(Game.can_fulfill(c3), "comprar faltante al proveedor")
	Game.customers.clear(); Game.customers_changed.emit()
	# viaje con popup
	gs._set_tab("mine")
	gs._load_popup(1, true)
	await get_tree().process_frame
	pop = UI.overlay.get_child(UI.overlay.get_child_count() - 1)
	var maxb: Array = pop.find_children("*", "Button", true, false).filter(func(b): return b.text == L.t("fill") and not b.disabled)
	maxb[0].pressed.emit()
	await shot("load_popup")
	var gob: Array = pop.find_children("*", "Button", true, false).filter(func(b): return b.text == L.t("go"))
	gob[0].pressed.emit()
	await get_tree().process_frame
	ok(Game.player_away(), "viaje propio enviado desde popup")
	Game.skip_trip(1)
	ok(not Game.player_away() and Game.inv_qty("arena") > 0, "adelantar viaje y descargar")
	# casa, closet, transporte
	gs._set_tab("house")
	Game.s["level"] = 3; Game.s["money"] = 50000
	ok(Game.upgrade_house(), "mejorar casa")
	ok(Game.buy_transport("bici") and Game.s["transport"] == "bici", "comprar bici")
	gs._rebuild()
	await shot("house_bike")
	# mejoras
	Game.s["level"] = 10
	ok(Game.upgrade_shop(), "mejorar local")
	Game.s["shop_stage"] = 3
	ok(Game.upgrade_wheelbarrow(), "mejorar carretilla")
	ok(Game.buy_tool("pico"), "comprar pico")
	ok(Game.hire_clerk(), "contratar empleada")
	ok(Game.upgrade_offline(), "turnos largos")
	ok(Game.buy_vehicle("pickup"), "comprar camioneta")
	ok(Game.hire_driver(2), "contratar chofer")
	ok(Game.buy_vehicle("wheelbarrow") and Game.count_type("wheelbarrow") == 2, "segunda carretilla")
	# pedido a domicilio
	Game.s["inv"]["cemento"] = 30
	var cd := Game.gen_customer(); cd["order"] = [{"id": "cemento", "qty": 4}]; cd["delivery"] = true; cd["fee"] = 80
	Game.customers.append(cd)
	var md := Game.money()
	ok(Game.deliver_order(cd) and Game.s["fleet"][1]["trip"] != null, "enviar pedido a domicilio")
	Game.s["fleet"][1]["trip"]["end"] = Game.now() - 1
	Game.update_trips()
	ok(Game.money() >= md + int(cd["price"]) + 80 and Game.s["fleet"][1]["trip"] == null, "cobro al regresar del domicilio")
	gs._set_tab("local")
	await shot("drivers_in_shop")
	gs._toggle_outside()
	await shot("outside_shop")
	gs._toggle_outside()
	gs._set_tab("upgrades")
	await shot("upgrades_mid")
	# chofer offline + empleada offline
	Game.s["inv"] = {}
	for id in DB.ITEM_ORDER: Game.s["inv"][id] = 0 if DB.ITEMS[id]["source"] == "mine" else 30
	Game.s["inv"]["arena"] = 10
	while not Game.mine_open(): Game.s["day"] = int(Game.s["day"]) + 1
	gs._fetch_missing({"grava": 5})
	await get_tree().process_frame
	await shot("send_for_missing")
	UI.clear_overlay()
	ok(Game.send_trip(2, {"grava": 10}, false), "mandar chofer")
	Game.save_game()
	var f := FileAccess.open(Game.slot_path(1), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()); f = null
	d["last_time"] = Game.now() - 3 * 3600
	d["phase"] = "open"; d["clerk_spawned"] = 0
	d["fleet"][1]["trip"]["end"] = Game.now() - 100
	var w := FileAccess.open(Game.slot_path(1), FileAccess.WRITE); w.store_string(JSON.stringify(d)); w = null
	var mb := Game.money()
	ok(Game.load_game(1), "cargar partida")
	print("offline report: ", Game.offline_report)
	ok(int(Game.offline_report.get("earned", 0)) > 0, "empleada vende offline")
	ok(Game.s["fleet"][1]["trip"] == null, "chofer regreso offline")
	main.goto("game")
	await shot("offline_report")
	UI.clear_overlay()
	gs = main.current
	Game.s["inv"]["arena"] = 0
	# fin de dia: llega el proveedor y regresan los encargos
	Game.skip_trip(1)
	var day := int(Game.s["day"])
	Game.s["inv"] = {"arena": 5}
	Game.s["supplier_orders"] = {"cal": 2}
	while not DB.SUPPLIER_DAYS.has(Game.weekday(int(Game.s["day"]) + 1)):
		Game.s["day"] = int(Game.s["day"]) + 1
	day = int(Game.s["day"])
	var cal0 := Game.inv_qty("cal")
	Game.sleep()
	await shot("day_end")
	ok(int(Game.s["day"]) == day + 1, "dormir pasa el dia")
	ok(Game.inv_qty("cal") == cal0 + 2 and Game.s["supplier_orders"].is_empty(), "el proveedor entrega lo pedido")
	UI.clear_overlay()
	# encargo que regresa
	Game.s["encargos"] = [{"day": int(Game.s["day"]), "deposit": 30, "c": {"name": "Toño", "look": Art.default_look("m"), "type": "vecino", "order": [{"id": "grava", "qty": 2}], "price": 100, "offer": 100, "haggle": false}}]
	Game.s["inv"]["grava"] = 5
	Game.open_shop()
	Game._spawn_timer = 0.0
	Game._tick_customers(0.01)
	var back = null
	for cc in Game.customers:
		if cc.has("encargo"): back = cc
	ok(back != null, "el del encargo regresa")
	gs._set_tab("local"); gs.selected = back if back != null else {}; gs._rebuild()
	await shot("encargo_back")
	var m4 := Game.money()
	if back != null: Game.serve(back)
	ok(Game.money() == m4 + 70, "cobras lo que resta del encargo")
	# empleada con su propia caja
	Game.customers.clear()
	Game.s["clerk_spawned"] = 0
	Game.s["inv"] = {}
	for id in DB.ITEM_ORDER: Game.s["inv"][id] = 40
	var srv0 := int(Game.s["stats"]["served"])
	for i in 60:
		Game._tick_clerk(0.5)
	ok(int(Game.s["stats"]["served"]) > srv0, "la empleada atiende su propia fila")
	# despedir
	ok(Game.fire_clerk() and int(Game.s["clerks"]) == 0, "despedir empleada")
	# mina en domingo
	while Game.weekday() != 6: Game.s["day"] = int(Game.s["day"]) + 1
	ok(not Game.mine_open() and not Game.send_trip(1, {"arena": 1}, true), "domingo no abre la mina")
	# mina propia: mas barato pero no gratis
	Game.s["own_mine"] = true
	ok(Game.mine_price("grava") > 0 and Game.mine_price("grava") < int(DB.ITEMS["grava"]["cost"]), "mina propia: material mas barato, no gratis")
	Game.s["own_mine"] = false
	# logros
	Game.s["stats"]["served"] = 12
	Game.s["achievements"] = {}
	var b0 := Game.bolts()
	Game.check_achievements()
	ok(Game.ach_level("served") == 1 and Game.bolts() == b0 + 5, "logro de 10 clientes")
	gs._achievements_popup()
	await shot("achievements")
	UI.clear_overlay()
	# pausa y opciones
	gs._pause_menu()
	await shot("pause")
	UI.clear_overlay(); Game.paused = false
	# compras simuladas
	Mon._grant("starter_pack")
	ok(Game.s["starter"] and Game.cosmetic_owned("top:overol_dorado"), "pack inicial")
	Mon._grant("no_ads")
	var got := [false]
	Mon.show_rewarded("energy", func(): got[0] = true)
	ok(got[0], "sin anuncios da premio directo")
	# closet
	main.goto("creator", {"mode": "edit"})
	await shot("closet")
	main.current.look["acc"] = "casco"
	main.current._refresh()
	await shot("closet_locked")
	# ingles
	Game.settings["lang"] = "en"
	main.goto("game", {"tab": "upgrades"})
	await shot("upgrades_en")
	Game.settings["lang"] = "es"
	Game.delete_slot(1)
	print("LOGIC DONE fails=", fails)
	get_tree().quit()
