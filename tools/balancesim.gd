extends Node
## Simulador de balance: un "jugador" juega N dias con decisiones razonables y reporta el avance.
const DAYS := 22

func _ready() -> void:
	await get_tree().process_frame
	Game.new_game(2, "Bot", Art.default_look("m"))
	Game.playing = false
	# dia 1 (tutorial) resumido: limpiar y 2 clientes
	for i in 6: Game.clean_spot(i)
	Game.s["tutorial"] = 5
	Game.add_xp(2 * Game.xp_for_sale(60))
	Game.add_money(120)
	Game.sleep()
	var energy_short := 0
	for d in DAYS:
		var day := int(Game.s["day"])
		# --- manana: viajes a la mina y pedido al proveedor
		_mine_trips()
		_supplier_orders()
		Game.open_shop()
		# --- jornada
		var lost := 0
		var partial := 0
		var guard := 0
		while Game.phase() == "open" and guard < 400:
			guard += 1
			Game._spawn_timer = 0.0
			Game._tick_customers(0.01)
			for i in 20: Game._tick_clerk(0.5)
			for c in Game.customers.duplicate():
				if Game.can_fulfill(c):
					if float(Game.s["energy"]) < 1.0:
						energy_short += 1
						Game.s["energy"] = 1.0   # el jugador veria un anuncio o esperaria
					if not c.get("delivery", false) or not Game.deliver_order(c):
						Game.serve(c)
				else:
					# intenta traer de la mina o comprar urgente si conviene
					var miss := Game.missing_for(c)
					var fixed := true
					var mine_need := {}
					for m in miss:
						if DB.ITEMS[m["id"]]["source"] == "supplier":
							if not Game.buy_supply(m["id"], int(m["qty"]), true): fixed = false
						else: mine_need[m["id"]] = int(m["qty"])
					if not mine_need.is_empty() and Game.mine_open():
						# como el boton "ir por lo que falta"
						var got := false
						for v in Game.s["fleet"]:
							if v["trip"] != null: continue
							var tot := 0
							for k in mine_need: tot += int(mine_need[k])
							if tot > Game.vehicle_cap(v): continue
							if Game.send_trip(int(v["id"]), mine_need, not v["driver"]):
								Game.skip_trip(int(v["id"])); got = true; break
						if not got: fixed = false
					if fixed and Game.can_fulfill(c): Game.serve(c)
					elif Game.partial_value(c) >= int(c["price"]) / 3 and Game.serve_partial(c)["ok"]:
						partial += 1
					else:
						if day <= 0: print("  pierde: ", c["type"], " ", c["order"], " $", c["price"], " | dinero ", Game.money(), " energia ", int(Game.s["energy"]), " patio ", Game.patio_room(), " inv ", Game.s["inv"])
						Game.dismiss(c); lost += 1
		# --- tarde: mejoras
		_upgrades()
		var sm := {}
		var cb := func(x): sm.merge(x)
		Game.day_ended.connect(cb, CONNECT_ONE_SHOT)
		Game.sleep()
		var spent := 0
		for k in sm.get("spent", {}): spent += int(sm["spent"][k])
		print("DIA %2d %s lvl %2d xp %4d/%4d | dinero %7d | cuota %2d atendidos %2d (parcial %d) perdidos %2d | ventas %6d gastos %6d | local %d casa %d carretillas %d chofer %d empleada %d camionetas %d" % [
			day, Game.weekday(day), Game.level(), int(Game.s["xp"]), DB.xp_for_level(Game.level()), Game.money(), int(sm.get("served", 0)) + lost, int(sm.get("served", 0)), partial, lost,
			int(sm.get("earned", 0)), spent, Game.shop_stage(), Game.house_stage(), Game.count_type("wheelbarrow"), _drivers(), int(Game.s["clerks"]), Game.count_type("pickup")])
	print("SIN ENERGIA (veces): ", energy_short)
	Game.delete_slot(2)
	get_tree().quit()

func _drivers() -> int:
	var n := 0
	for v in Game.s["fleet"]:
		if v["driver"]: n += 1
	return n

func _mine_items() -> Array:
	var r := []
	for id in DB.ITEM_ORDER:
		if DB.ITEMS[id]["source"] == "mine" and DB.item_unlocked(id, Game.level(), Game.s["tools"]): r.append(id)
	return r

func _mine_trips() -> void:
	if not Game.mine_open(): return
	var items := _mine_items()
	for round_i in 6:
		for v in Game.s["fleet"]:
			if v["trip"] != null: continue
			var room := Game.patio_room()
			if room <= 2: return
			var cap := mini(Game.vehicle_cap(v), room)
			# llena lo que tenga menos
			var load := {}
			var weights := {"arena": 3, "grava": 2, "tepetate": 1, "piedra": 1, "tezontle": 1}
			var wsum := 0
			for id in items: wsum += int(weights[id])
			for id in items: load[id] = maxi(1, cap * int(weights[id]) / wsum)
			var tot := 0
			for id in load: tot += int(load[id])
			var safety := 0
			while tot > cap and safety < 500:
				safety += 1
				for id in load.keys():
					if tot > cap and int(load[id]) > 0:
						load[id] = int(load[id]) - 1; tot -= 1
						if int(load[id]) == 0: load.erase(id)
			var self_go: bool = not v["driver"]
			if self_go and float(Game.s["energy"]) < Game.trip_energy(v) + int(Game.s["day_quota"]): continue
			if Game.send_trip(int(v["id"]), load, self_go):
				Game.skip_trip(int(v["id"]))

func _supplier_orders() -> void:
	for id in DB.ITEM_ORDER:
		if DB.ITEMS[id]["source"] != "supplier" or Game.level() < int(DB.ITEMS[id]["lvl"]): continue
		var want := 3 if int(DB.ITEMS[id]["cost"]) < 150 else 1
		if id == "cemento": want = 5
		if Game.level() >= 5: want *= 2
		var have := Game.inv_qty(id) + int(Game.s["supplier_orders"].get(id, 0))
		if have < want and Game.money() > 400 + int(DB.ITEMS[id]["cost"]) * (want - have):
			Game.buy_supply(id, want - have, false)

func _upgrades() -> void:
	for i in 3:
		var nxt := Game.shop_stage() + 1
		if nxt < DB.SHOP_STAGES.size() and Game.level() >= int(DB.SHOP_STAGES[nxt]["lvl"]) and Game.money() > int(DB.SHOP_STAGES[nxt]["cost"]) * 1.3: Game.upgrade_shop()
		var hn := Game.house_stage() + 1
		if hn < DB.HOUSE_STAGES.size() and Game.level() >= int(DB.HOUSE_STAGES[hn]["lvl"]) and Game.money() > int(DB.HOUSE_STAGES[hn]["cost"]) * 1.5: Game.upgrade_house()
		var wt := int(Game.s["wb_tier"]) + 1
		if wt < DB.WHEELBARROW_TIERS.size() and Game.level() >= int(DB.WHEELBARROW_TIERS[wt]["lvl"]) and Game.money() > int(DB.WHEELBARROW_TIERS[wt]["cost"]) * 1.3: Game.upgrade_wheelbarrow()
		if Game.count_type("wheelbarrow") < 2 and Game.level() >= 2 and Game.money() > Game.vehicle_price("wheelbarrow") + 500:
			Game.buy_vehicle("wheelbarrow")
		for v in Game.s["fleet"]:
			if not v["driver"] and int(v["id"]) != 1 and Game.money() > 600: Game.hire_driver(int(v["id"]))
		if int(Game.s["clerks"]) == 0 and Game.level() >= int(DB.CLERK["lvl"]) and Game.money() > 2500: Game.hire_clerk()
		if Game.count_type("pickup") == 0 and Game.level() >= 5 and Game.shop_stage() >= 3 and Game.money() > 8000: Game.buy_vehicle("pickup")
		if not Game.has_tool("pico") and Game.level() >= 3 and Game.money() > 1200: Game.buy_tool("pico")
