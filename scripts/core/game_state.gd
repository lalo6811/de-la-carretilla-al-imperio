extends Node
## Estado del juego, guardado en 3 ranuras, economia, clientes, viajes, idle.

signal changed                       # cualquier cambio de numeros (HUD)
signal toast(text: String)
signal level_up(level: int)
signal customer_arrived(c: Dictionary)
signal customer_left(c: Dictionary, happy: bool)
signal customers_changed
signal trip_finished(v: Dictionary)
signal day_ended(summary: Dictionary)
signal visitor_changed
signal tutorial_changed
signal passed_by
signal achievement(id: String, goal: int, bolts: int)
signal phase_changed

const SAVE_VERSION := 3
const SLOTS := 3

var s: Dictionary = {}          # estado guardado
var slot := -1
var playing := false            # la pantalla de juego esta activa
var paused := false
var customers: Array = []       # clientes en el local (no se guardan)
var visitor_active := false
var visitor_time := 0.0
var offline_report: Dictionary = {}
var settings := {"lang": "es", "music": 0.7, "sfx": 0.9, "vibration": true}

var clerk_customers: Array = []  # fila de la empleada (no se guarda)
var _spawn_timer := 4.0
var _clerk_spawn := 3.0
var _ach_t := 0.0
var _autosave_timer := 0.0
var _clerk_timer := 0.0
var _energy_acc := 0.0
var _cid := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if slot >= 0 and not s.is_empty():
			save_game()

static func now() -> float:
	return Time.get_unix_time_from_system()

# ================================================================ ajustes
func load_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d: settings[k] = d[k]
	else:
		var loc := OS.get_locale_language()
		settings["lang"] = "es" if loc == "es" else "en"

func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(settings))

# ================================================================ ranuras
func slot_path(i: int) -> String:
	return "user://slot_%d.json" % i

func slot_info(i: int) -> Dictionary:
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if not f: return {}
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary: return {}
	return {"name": d.get("name", "?"), "day": d.get("day", 1), "level": d.get("level", 1), "money": d.get("money", 0), "last": d.get("last_time", 0), "look": d.get("look", {})}

func latest_slot() -> int:
	var best := -1; var t := -1.0
	for i in SLOTS:
		var inf := slot_info(i)
		if not inf.is_empty() and float(inf["last"]) > t:
			t = float(inf["last"]); best = i
	return best

func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(slot_path(i))

func new_game(i: int, name: String, look: Dictionary) -> void:
	slot = i
	customers.clear()
	s = {
		"version": SAVE_VERSION, "name": name, "look": look, "seed": randi(), "created": now(), "last_time": now(),
		"day": 1, "minute": float(DB.DAY_START), "money": 400, "bolts": 10, "xp": 0, "level": 1, "energy": 20.0, "rep": 50.0,
		"inv": {"arena": 4, "grava": 2, "cemento": 2, "cal": 1, "clavos": 2},
		"shop_stage": 0, "dirt": [0, 1, 2, 3, 4, 5],
		"house_stage": 0, "transport": "pie", "transports": ["pie"], "tools": {}, "cosmetics": [],
		"wb_tier": 0, "fleet": [{"id": 1, "type": "wheelbarrow", "driver": false, "trip": null}], "next_vid": 2,
		"clerks": 0, "offline_tier": 0, "own_mine": false,
		"stats": {"served": 0, "earned": 0, "trips": 0, "lost": 0},
		"today": {"earned": 0, "served": 0},
		"ads": {"date": "", "counts": {}}, "no_ads": false, "starter": false,
		"tutorial": 0, "cust_counter": 0, "visitor_next": 120.0,
		"at_home": false, "reg_last": {}, "milestones": [], "lost_warned_day": 0,
	}
	_migrate()
	s["phase"] = "open"   # el dia 1 (tutorial) arranca con el local abierto
	s["day_quota"] = 2
	set_meta("arrive", true)
	save_game()

func load_game(i: int) -> bool:
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if not f: return false
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary: return false
	slot = i
	s = d
	customers.clear()
	# normaliza tipos que JSON convierte a float
	for k in s["inv"].keys():
		s["inv"][k] = int(s["inv"][k])
	if int(s.get("version", 1)) < 2:
		s["tutorial"] = 5 if int(s.get("shop_stage", 0)) >= 1 else 0
	_migrate()
	s["version"] = SAVE_VERSION
	compute_offline()
	_check_streak()
	set_meta("arrive", true)
	return true

func _migrate() -> void:
	## Campos nuevos con valores por defecto (partidas viejas)
	var defaults := {
		"at_home": false, "reg_last": {}, "milestones": [], "lost_warned_day": 0,
		"phase": "morning", "day_quota": 0, "day_spawned": 0, "day_handled": 0, "day_rejected": 0,
		"clerk_spawned": 0, "supplier_orders": {}, "encargos": [], "achievements": {},
		"regulars_served": {}, "streak": 0, "last_play_date": "",
	}
	for k in defaults:
		if not s.has(k): s[k] = defaults[k]
	for k in ["deliveries", "perfect_days"]:
		if not s["stats"].has(k): s["stats"][k] = 0
	if not s["today"].has("spent"): s["today"]["spent"] = {}
	if int(s["day_quota"]) <= 0 and int(s.get("tutorial", 0)) >= 5:
		s["day_quota"] = roll_quota()
	for k in s["supplier_orders"].keys():
		s["supplier_orders"][k] = int(s["supplier_orders"][k])

func save_game() -> void:
	if slot < 0 or s.is_empty(): return
	s["last_time"] = now()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(s))

# ================================================================ derivados
func level() -> int: return int(s.get("level", 1))
func money() -> int: return int(s.get("money", 0))
func bolts() -> int: return int(s.get("bolts", 0))
func shop_stage() -> int: return int(s.get("shop_stage", 0))
func house_stage() -> int: return int(s.get("house_stage", 0))
func has_tool(t: String) -> bool: return bool(s["tools"].get(t, false))
func energy_max() -> int: return int(DB.HOUSE_STAGES[house_stage()]["energy"])
func capacity() -> int: return space_cap("patio") + space_cap("shelf")
func space_cap(kind: String) -> int: return int(DB.SHOP_STAGES[shop_stage()][kind])
func queue_size() -> int: return int(DB.SHOP_STAGES[shop_stage()]["queue"])
func inv_qty(id: String) -> int: return int(s["inv"].get(id, 0))

func inv_used() -> int:
	var t := 0
	for k in s["inv"]: t += int(s["inv"][k])
	return t

func inv_free() -> int: return space_free("patio")

func space_used(kind: String) -> int:
	var t := 0
	for k in s["inv"]:
		if DB.space_kind(k) == kind: t += int(s["inv"][k])
	return t

func space_free(kind: String) -> int:
	return space_cap(kind) - space_used(kind)

func pending_loads() -> int:
	## Lo que viene en camino de la mina (ocupa patio)
	var t := 0
	for v in s["fleet"]:
		if v["trip"] != null:
			for k in v["trip"]["load"]: t += int(v["trip"]["load"][k])
	return t

func pending_supplier() -> int:
	var t := 0
	for k in s["supplier_orders"]: t += int(s["supplier_orders"][k])
	return t

func patio_room() -> int: return space_free("patio") - pending_loads()
func shelf_room() -> int: return space_free("shelf") - pending_supplier()

func add_money(n: int, earned := true) -> void:
	s["money"] = money() + n
	if earned and n > 0:
		s["stats"]["earned"] = int(s["stats"]["earned"]) + n
		s["today"]["earned"] = int(s["today"]["earned"]) + n
	changed.emit()

func spend(n: int, cat := "other") -> bool:
	if money() < n:
		toast.emit(L.t("no_money"))
		Sfx.play("error")
		return false
	s["money"] = money() - n
	_log_spent(cat, n)
	changed.emit()
	return true

func _log_spent(cat: String, n: int) -> void:
	if n <= 0: return
	var sp: Dictionary = s["today"].get("spent", {})
	sp[cat] = int(sp.get(cat, 0)) + n
	s["today"]["spent"] = sp

func spend_bolts(n: int) -> bool:
	if bolts() < n:
		toast.emit(L.t("no_bolts"))
		Sfx.play("error")
		return false
	s["bolts"] = bolts() - n
	changed.emit()
	return true

func add_bolts(n: int) -> void:
	s["bolts"] = bolts() + n
	changed.emit()

func add_energy(n: float) -> void:
	s["energy"] = clampf(float(s["energy"]) + n, 0.0, float(energy_max()))
	changed.emit()

func use_energy(n: int) -> bool:
	if float(s["energy"]) < n:
		toast.emit(L.t("no_energy"))
		Sfx.play("error")
		return false
	s["energy"] = float(s["energy"]) - n
	changed.emit()
	return true

func add_xp(n: int) -> void:
	s["xp"] = int(s["xp"]) + n
	while int(s["xp"]) >= DB.xp_for_level(level()):
		s["xp"] = int(s["xp"]) - DB.xp_for_level(level())
		s["level"] = level() + 1
		Sfx.play("levelup")
		level_up.emit(level())
	changed.emit()

func add_item(id: String, n: int) -> void:
	s["inv"][id] = inv_qty(id) + n
	if int(s["inv"][id]) <= 0:
		s["inv"].erase(id)
	changed.emit()

# ================================================================ calendario y fases del dia
func weekday(day := -1) -> int:
	## 0 = lunes ... 6 = domingo (el dia 1 es lunes)
	if day < 0: day = int(s.get("day", 1))
	return (day - 1) % 7

func day_name(day := -1) -> String:
	return L.t("wd_%d" % weekday(day))

func supplier_today() -> bool: return DB.SUPPLIER_DAYS.has(weekday())
func mine_open() -> bool: return not DB.MINE_CLOSED_DAYS.has(weekday())

func next_supplier_day() -> int:
	## Siguiente dia (numero de dia del juego) en que pasa el proveedor, sin contar hoy
	var d := int(s["day"]) + 1
	while not DB.SUPPLIER_DAYS.has(weekday(d)): d += 1
	return d

func phase() -> String: return str(s.get("phase", "open"))

func clock_text() -> String:
	## Ya no hay reloj: se muestra la fase del dia
	if at_home(): return L.t("ph_night")
	match phase():
		"morning": return L.t("ph_morning")
		"closed": return L.t("ph_closed")
	if tutorial_on(): return L.t("ph_open")
	return "%d/%d" % [int(s["day_handled"]), int(s["day_quota"])]

func roll_quota() -> int:
	## Clientes del dia: crece con nivel, local y reputacion; varia cada dia (con la semilla)
	var r := _rng_for(-7)
	var base := 4.0 + level() * 1.0 + float(DB.SHOP_STAGES[shop_stage()]["demand"]) + (float(s["rep"]) - 50.0) / 25.0
	if has_tool("radio"): base += 1.0
	if weekday() == 6: base *= 0.7   # domingo mas tranquilo
	return clampi(int(round(base * r.randf_range(0.8, 1.25))), 3, 45)

func shop_open() -> bool:
	return shop_stage() >= 1 and phase() == "open" and not at_home()

func open_shop() -> void:
	if phase() != "morning" or at_home(): return
	s["phase"] = "open"
	_spawn_timer = 1.5
	_clerk_spawn = 3.0
	Sfx.play("click")
	phase_changed.emit()
	changed.emit()
	save_game()

func day_done() -> bool:
	## Ya llegaron todos los clientes del dia y no queda nadie en las filas
	return int(s["day_spawned"]) >= int(s["day_quota"]) and customers.is_empty() and _due_encargos().is_empty() \
		and (int(s["clerks"]) == 0 or (int(s["clerk_spawned"]) >= clerk_quota() and clerk_customers.is_empty()))

func _close_if_done() -> void:
	if phase() == "open" and not tutorial_on() and day_done():
		s["phase"] = "closed"
		if int(s["day_rejected"]) == 0 and int(s["day_handled"]) > 0:
			s["stats"]["perfect_days"] = int(s["stats"]["perfect_days"]) + 1
		toast.emit(L.t("day_all_served"))
		Sfx.play("levelup")
		phase_changed.emit()
		changed.emit()
		save_game()

func at_home() -> bool:
	return bool(s.get("at_home", false))

func go_home() -> void:
	## Ir a casa termina el dia: se cierra el local y los que esperaban se van
	s["at_home"] = true
	for c in customers:
		if not c.has("tut"): s["day_rejected"] = int(s["day_rejected"]) + 1
		customer_left.emit(c, false)
	customers.clear()
	for c in clerk_customers: customer_left.emit(c, false)
	clerk_customers.clear()
	customers_changed.emit()
	visitor_active = false
	save_game()
	changed.emit()

func _process(delta: float) -> void:
	if not s.is_empty(): L.female = str(s.get("look", {}).get("gender", "m")) == "f"
	if not playing or paused or s.is_empty():
		return
	# energia: se recupera poco a poco (y toda al dormir)
	_energy_acc += delta
	if _energy_acc >= 1.0:
		add_energy(float(DB.HOUSE_STAGES[house_stage()]["regen"]) * 0.5 * _energy_acc / 60.0)
		_energy_acc = 0.0
	update_trips()
	_tick_customers(delta)
	_tick_clerk(delta)
	_tick_visitor(delta)
	_ach_t -= delta
	if _ach_t <= 0.0:
		_ach_t = 1.0
		check_achievements()
	_autosave_timer += delta
	if _autosave_timer > 20.0:
		_autosave_timer = 0.0
		save_game()

func salaries() -> int:
	var t := 0
	for v in s["fleet"]:
		if v["driver"]: t += int(DB.VEHICLES[v["type"]]["driver"])
	if int(s["clerks"]) >= 1: t += int(DB.CLERK["salary"])
	if int(s["clerks"]) >= 2: t += int(DB.CLERK2["salary"])
	return t

func light_bill() -> int:
	return DB.LIGHT_BILL_BASE + DB.LIGHT_BILL_PER_STAGE * shop_stage()

func sleep() -> void:
	var sal := salaries()
	var bill := 0
	if weekday() == 6: bill = light_bill()   # el domingo en la noche llega el recibo de luz
	var spent: Dictionary = s["today"].get("spent", {}).duplicate()
	if sal > 0: spent["salaries"] = sal
	if bill > 0: spent["light"] = bill
	var summary := {"day": int(s["day"]), "earned": int(s["today"]["earned"]), "served": int(s["today"]["served"]),
		"salaries": sal, "light": bill, "spent": spent, "rejected": int(s["day_rejected"])}
	s["money"] = money() - sal - bill
	s["day"] = int(s["day"]) + 1
	s["energy"] = float(energy_max())
	s["rep"] = lerpf(float(s["rep"]), 50.0, 0.1)
	s["today"] = {"earned": 0, "served": 0, "spent": {}}
	s["at_home"] = false
	if int(s["tutorial"]) >= 4: s["tutorial"] = 5
	for c in customers: customer_left.emit(c, false)
	customers.clear()
	clerk_customers.clear()
	# nuevo dia: manana libre para preparar
	s["phase"] = "morning"
	s["day_quota"] = roll_quota()
	s["day_spawned"] = 0
	s["day_handled"] = 0
	s["day_rejected"] = 0
	s["clerk_spawned"] = 0
	var arrived := _supplier_arrives()
	summary["supplier_arrived"] = arrived
	customers_changed.emit()
	set_meta("arrive", true)
	save_game()
	changed.emit()
	phase_changed.emit()
	day_ended.emit(summary)

# ================================================================ limpieza (etapa 0)
func clean_spot(idx: int) -> bool:
	if not s["dirt"].has(idx): return false
	if not use_energy(1): return false
	s["dirt"].erase(idx)
	add_xp(2)
	Sfx.play("clean")
	if s["dirt"].is_empty():
		s["shop_stage"] = 1
		toast.emit(L.t("shop_clean_done"))
		if int(s["tutorial"]) == 0: set_tutorial(1)
		_spawn_timer = 1.5
	changed.emit()
	return true

func set_tutorial(step: int) -> void:
	if int(s["tutorial"]) < step:
		s["tutorial"] = step
		tutorial_changed.emit()

# ================================================================ clientes
func _rng_for(counter: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(s["seed"]), int(s["day"]), counter])
	return r

func gen_customer(small := false) -> Dictionary:
	s["cust_counter"] = int(s["cust_counter"]) + 1
	var rng := _rng_for(int(s["cust_counter"]))
	var lv := level()
	var c := {}
	# cliente fijo?
	var regs := []
	var day := int(s["day"])
	for r in DB.REGULARS:
		var last := int(s["reg_last"].get(r["id"], -99))
		if lv >= int(r["lvl"]) and day - last >= int(r["every"]): regs.append(r)
	if not regs.is_empty() and not small and rng.randf() < 0.3:
		var r: Dictionary = regs[rng.randi_range(0, regs.size() - 1)]
		c["name"] = r["name"]; c["look"] = r["look"]; c["type"] = r["type"]; c["regular"] = r["id"]
		s["reg_last"][r["id"]] = day
	else:
		var types := []; var weights := []
		var w := {"vecino": 3.0, "albanil": 3.0, "plomero": 2.0, "maestro": 2.2, "ingeniero": 1.8, "constructora": 1.4}
		for t in DB.CUSTOMER_TYPES:
			if small and not (t in ["vecino", "albanil", "plomero"]): continue
			if lv >= int(DB.CUSTOMER_TYPES[t]["lvl"]):
				types.append(t); weights.append(w[t])
		var tot := 0.0
		for x in weights: tot += x
		var pick := rng.randf() * tot
		var tsel: String = types[0]
		for i in types.size():
			pick -= weights[i]
			if pick <= 0.0:
				tsel = types[i]; break
		c["type"] = tsel
		var look := Art.random_look(rng)
		if tsel == "albanil" or tsel == "maestro":
			if rng.randf() < 0.5: look["acc"] = "casco" if rng.randf() < 0.5 else "gorra"
		if tsel == "ingeniero" or tsel == "constructora":
			look["top"] = "camisa" if rng.randf() < 0.6 else "chaleco"
			if rng.randf() < 0.5: look["acc"] = "casco"
		c["look"] = look
		var names: Array = DB.NAMES_M if look["gender"] == "m" else DB.NAMES_F
		c["name"] = names[rng.randi_range(0, names.size() - 1)]
	var tdef: Dictionary = DB.CUSTOMER_TYPES[c["type"]]
	# pedido: el cliente viene por un proyecto y pide materiales de ese proyecto
	var projs := []
	for pr in DB.PROJECTS[c["type"]]:
		var ok_items := 0
		for id in pr["items"]:
			if DB.item_unlocked(id, lv, s["tools"]): ok_items += 1
		if ok_items > 0: projs.append(pr)
	var pool := []
	if projs.is_empty():
		c["project"] = ""
		for id in ["arena", "cemento"]: pool.append(id)
	else:
		var pr: Dictionary = projs[rng.randi_range(0, projs.size() - 1)]
		c["project"] = pr["id"]
		for id in pr["items"]:
			if DB.item_unlocked(id, lv, s["tools"]): pool.append(id)
	var n := rng.randi_range(int(tdef["items"][0]), int(tdef["items"][1]))
	if small: n = 1
	n = mini(n, 1 + lv / 2)   # al principio piden pocas cosas distintas
	n = mini(n, pool.size())
	var order := []
	var price := 0.0
	var cap_limit := maxi(4, mini(space_cap("patio"), space_cap("shelf")) / 3)
	# los primeros materiales del proyecto son los principales
	var picks := []
	for i in pool.size(): picks.append(pool[i])
	var chosen := []
	for i in n:
		var idx := 0 if i == 0 or rng.randf() < 0.5 else rng.randi_range(0, picks.size() - 1)
		chosen.append(picks[idx]); picks.remove_at(idx)
	for id in chosen:
		var p := float(DB.ITEMS[id]["sell"])
		var f := 1.0
		if p < 30.0: f = 2.5
		elif p >= 300.0: f = 0.35
		elif p >= 100.0: f = 0.6
		var q := int(round(rng.randi_range(int(tdef["qty"][0]), int(tdef["qty"][1])) * f * (1.0 + lv * 0.04)))
		if small: q = maxi(1, q / 2)
		if DB.ITEMS[id]["cat"] == "tool": q = 1 + (1 if lv >= 6 and rng.randf() < 0.3 else 0)
		q = clampi(q, 1, cap_limit)
		order.append({"id": id, "qty": q})
		price += p * q
	price *= float(tdef["mult"]) * (0.9 + float(s["rep"]) / 500.0)
	if has_tool("calculadora"): price *= 1.05
	c["order"] = order
	c["price"] = int(round(price))
	c["haggle"] = false
	c["offer"] = c["price"]
	if not small and can_deliver_any() and rng.randf() < float(DB.DELIVERY_CHANCE.get(c["type"], 0.0)):
		c["delivery"] = true
		c["dist"] = rng.randi_range(1, 3)
		c["fee"] = 30 + 20 * int(c["dist"]) + int(price * 0.08)
	if small: c["small"] = true
	c["patience_max"] = 1.0
	c["patience"] = 1.0
	c["rng_mood"] = rng.randf()
	_cid += 1
	c["cid"] = _cid
	return c

func can_fulfill(c: Dictionary) -> bool:
	for o in c["order"]:
		if inv_qty(o["id"]) < int(o["qty"]): return false
	return true

func missing_for(c: Dictionary) -> Array:
	var m := []
	for o in c["order"]:
		var have := inv_qty(o["id"])
		if have < int(o["qty"]): m.append({"id": o["id"], "qty": int(o["qty"]) - have})
	return m

func _spawn_interval() -> float:
	## Ya no hay prisa: los clientes llegan cada pocos segundos hasta completar los del dia
	return 7.0 if level() < 3 else 5.5

func tutorial_on() -> bool:
	return int(s.get("tutorial", 5)) < 5

func _tutorial_customer(step: int) -> Dictionary:
	var reg: Dictionary = DB.REGULARS[1] if step == 1 else DB.REGULARS[0]
	var c := {"name": reg["name"], "look": reg["look"], "type": reg["type"], "regular": reg["id"], "tut": step}
	c["order"] = [{"id": "arena", "qty": 2}, {"id": "cemento", "qty": 1}] if step == 1 else [{"id": "arena", "qty": 6}, {"id": "grava", "qty": 2}]
	var price := 0
	for o in c["order"]: price += int(DB.ITEMS[o["id"]]["sell"]) * int(o["qty"])
	c["price"] = price; c["offer"] = price; c["haggle"] = false
	c["patience"] = 1.0; c["patience_max"] = 1.0; c["rng_mood"] = 1.0
	_cid += 1
	c["cid"] = _cid
	return c

func _has_tut_customer(step: int) -> bool:
	for c in customers:
		if int(c.get("tut", 0)) == step: return true
	return false

func _tick_customers(delta: float) -> void:
	# primer dia: clientes guiados
	var tut := int(s["tutorial"])
	if tut >= 1 and tut <= 3:
		var want := 1 if tut == 1 else 2
		if not _has_tut_customer(want):
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_timer = 1.5
				var c := _tutorial_customer(want)
				customers.append(c)
				customer_arrived.emit(c)
				customers_changed.emit()
		return
	if tut == 0 or tut == 4 or not shop_open(): return
	# los clientes del dia llegan uno tras otro; si la fila esta llena esperan afuera (no se pierden)
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or customers.size() >= queue_size(): return
	_spawn_timer = _spawn_interval() * randf_range(0.8, 1.2)
	# primero los encargos que regresan hoy
	var due := _due_encargos()
	if not due.is_empty():
		var e: Dictionary = due[0]
		s["encargos"].erase(e)
		var c: Dictionary = e["c"]
		c["encargo"] = int(e["deposit"])
		_cid += 1
		c["cid"] = _cid
		customers.append(c)
		customer_arrived.emit(c)
		customers_changed.emit()
		return
	if int(s["day_spawned"]) < int(s["day_quota"]):
		s["day_spawned"] = int(s["day_spawned"]) + 1
		var c := gen_customer()
		customers.append(c)
		customer_arrived.emit(c)
		customers_changed.emit()
		changed.emit()
	else:
		_close_if_done()

# ---------------------------------------------------------------- empleada (su propia caja)
func clerk_quota() -> int:
	var n := int(s["clerks"])
	if n <= 0: return 0
	return int(DB.CLERK["quota"]) + (int(DB.CLERK2["quota"]) if n >= 2 else 0) + level() / 3

func clerk_every() -> float:
	return float(DB.CLERK["every"]) if int(s["clerks"]) <= 1 else float(DB.CLERK2["every"])

func _tick_clerk(delta: float) -> void:
	if int(s["clerks"]) == 0 or not shop_open() or tutorial_on(): return
	_clerk_spawn -= delta
	if _clerk_spawn <= 0.0 and clerk_customers.size() < 2 and int(s["clerk_spawned"]) < clerk_quota():
		_clerk_spawn = clerk_every() * 1.2
		s["clerk_spawned"] = int(s["clerk_spawned"]) + 1
		var c := gen_customer(true)
		c["clerk"] = true
		clerk_customers.append(c)
		customer_arrived.emit(c)
		customers_changed.emit()
	if clerk_customers.is_empty(): return
	_clerk_timer += delta
	if _clerk_timer >= clerk_every():
		_clerk_timer = 0.0
		var c: Dictionary = clerk_customers[0]
		clerk_customers.erase(c)
		if can_fulfill(c):
			for o in c["order"]: add_item(o["id"], -int(o["qty"]))
			add_money(int(c["price"]))
			add_xp(maxi(1, xp_for_sale(int(c["price"])) / 2))
			s["stats"]["served"] = int(s["stats"]["served"]) + 1
			s["today"]["served"] = int(s["today"]["served"]) + 1
			c["_paid"] = int(c["price"])
			Sfx.play("cash")
			customer_left.emit(c, true)
		else:
			s["rep"] = maxf(0.0, float(s["rep"]) - 0.3)
			customer_left.emit(c, false)
		customers_changed.emit()
		_close_if_done()

# ---------------------------------------------------------------- encargos
func _due_encargos() -> Array:
	var r := []
	for e in s["encargos"]:
		if int(e["day"]) <= int(s["day"]): r.append(e)
	return r

func take_encargo(c: Dictionary) -> bool:
	## El cliente deja anticipo y regresa en dos dias por su pedido
	if not customers.has(c) or c.has("tut") or c.has("encargo"): return false
	if not use_energy(DB.SERVE_ENERGY): return false
	var dep := int(round(int(c["price"]) * DB.ENCARGO_DEPOSIT))
	add_money(dep)
	var keep := c.duplicate(true)
	keep.erase("cid")
	s["encargos"].append({"day": int(s["day"]) + 2, "deposit": dep, "c": keep})
	customers.erase(c)
	s["day_handled"] = int(s["day_handled"]) + 1
	toast.emit(L.t("encargo_taken") % [c["name"], day_name(int(s["day"]) + 2)])
	Sfx.play("cash")
	customer_left.emit(c, true)
	customers_changed.emit()
	changed.emit()
	save_game()
	_close_if_done()
	return true

func can_deliver_any() -> bool:
	for v in s["fleet"]:
		if v["type"] != "wheelbarrow" and v["driver"]: return true
	return false

func order_units(c: Dictionary) -> int:
	var t := 0
	for o in c["order"]: t += int(o["qty"])
	return t

func delivery_vehicle(c: Dictionary) -> Dictionary:
	## Un vehiculo con chofer, libre y con capacidad para el pedido
	var best := {}
	for v in s["fleet"]:
		if v["type"] == "wheelbarrow" or not v["driver"] or v["trip"] != null: continue
		if vehicle_cap(v) < order_units(c): continue
		if best.is_empty() or vehicle_cap(v) < vehicle_cap(best): best = v
	return best

func deliver_order(c: Dictionary) -> bool:
	if not customers.has(c) or not can_fulfill(c): return false
	var v := delivery_vehicle(c)
	if v.is_empty():
		toast.emit(L.t("no_delivery_vehicle")); return false
	for o in c["order"]:
		add_item(o["id"], -int(o["qty"]))
	var pay := int(c["price"]) + int(c.get("fee", 0))
	if not use_energy(DB.SERVE_ENERGY): return false
	var dist := int(c.get("dist", 2))
	v["trip"] = {"start": now(), "end": now() + vehicle_time(v) * (0.4 + 0.3 * dist), "load": {}, "self": false,
		"delivery": {"pay": pay, "xp": xp_for_sale(pay), "name": c["name"], "dist": dist}}
	s["stats"]["served"] = int(s["stats"]["served"]) + 1
	s["stats"]["deliveries"] = int(s["stats"]["deliveries"]) + 1
	s["day_handled"] = int(s["day_handled"]) + 1
	s["today"]["served"] = int(s["today"]["served"]) + 1
	s["rep"] = minf(100.0, float(s["rep"]) + 0.8)
	customers.erase(c)
	Sfx.play("truck")
	customer_left.emit(c, true)
	customers_changed.emit()
	changed.emit()
	save_game()
	_close_if_done()
	return true

func serve(c: Dictionary, haggled := false, by_clerk := false) -> Dictionary:
	## Entrega el pedido. Devuelve {ok, paid, bonus}
	if not customers.has(c): return {"ok": false}
	if not can_fulfill(c):
		toast.emit(L.t("missing_stock"))
		Sfx.play("error")
		return {"ok": false}
	if not c.has("tut") and not use_energy(DB.SERVE_ENERGY): return {"ok": false}
	for o in c["order"]:
		add_item(o["id"], -int(o["qty"]))
	var paid := int(c["price"]) - int(c.get("encargo", 0))
	var bonus := 0
	if c.has("regular") and not by_clerk and not c.has("tut"):
		bonus = int(round(paid * 0.1))
	add_money(paid + bonus)
	add_xp(xp_for_sale(int(c["price"])))
	if c.has("regular") and not c.has("tut"):
		s["regulars_served"][c["regular"]] = int(s["regulars_served"].get(c["regular"], 0)) + 1
	if not c.has("tut"): s["day_handled"] = int(s["day_handled"]) + 1
	s["rep"] = minf(100.0, float(s["rep"]) + 0.8)
	s["stats"]["served"] = int(s["stats"]["served"]) + 1
	s["today"]["served"] = int(s["today"]["served"]) + 1
	customers.erase(c)
	c["_paid"] = paid + bonus
	Sfx.play("cash")
	customer_left.emit(c, true)
	customers_changed.emit()
	if int(c.get("tut", 0)) == 1: set_tutorial(2)
	elif int(c.get("tut", 0)) == 2: set_tutorial(4)
	_spawn_timer = minf(_spawn_timer, 2.5)
	_close_if_done()
	return {"ok": true, "paid": paid, "bonus": bonus}

func partial_value(c: Dictionary) -> int:
	## Cuanto vale lo que si tienes del pedido
	var raw := 0; var have_v := 0
	for o in c["order"]:
		var p := int(DB.ITEMS[o["id"]]["sell"])
		raw += p * int(o["qty"])
		have_v += p * mini(inv_qty(o["id"]), int(o["qty"]))
	if raw <= 0: return 0
	return int(round(float(c["price"]) * have_v / raw))

func serve_partial(c: Dictionary) -> Dictionary:
	## "Llevese lo que hay": vende lo que tienes del pedido y el cliente se va medio contento
	if not customers.has(c) or c.has("tut") or c.has("encargo"): return {"ok": false}
	var paid := partial_value(c)
	if paid <= 0: return {"ok": false}
	if not use_energy(DB.SERVE_ENERGY): return {"ok": false}
	for o in c["order"]:
		var q := mini(inv_qty(o["id"]), int(o["qty"]))
		if q > 0: add_item(o["id"], -q)
	add_money(paid)
	add_xp(maxi(1, xp_for_sale(paid) - 1))
	s["stats"]["served"] = int(s["stats"]["served"]) + 1
	s["today"]["served"] = int(s["today"]["served"]) + 1
	s["day_handled"] = int(s["day_handled"]) + 1
	s["day_rejected"] = int(s["day_rejected"]) + 1   # no fue un dia perfecto
	customers.erase(c)
	c["_paid"] = paid
	Sfx.play("cash")
	customer_left.emit(c, true)
	customers_changed.emit()
	changed.emit()
	_close_if_done()
	return {"ok": true, "paid": paid}

func xp_for_sale(paid: int) -> int:
	return 3 + int(paid / 22.0)

func free_skip_available(vid: int) -> bool:
	## El primer viaje del tutorial se puede adelantar gratis una vez
	var v := vehicle(vid)
	return not v.is_empty() and v["trip"] != null and v["trip"]["self"] and int(s["tutorial"]) == 3 and not s.get("tut_free_skip", false)

func use_free_skip(vid: int) -> void:
	s["tut_free_skip"] = true
	skip_trip(vid)

func dismiss(c: Dictionary) -> void:
	if not customers.has(c): return
	customers.erase(c)
	if c.has("encargo"):
		# no tuviste su encargo: le regresas el anticipo y se va enojado
		s["money"] = money() - int(c["encargo"])
		s["rep"] = maxf(0.0, float(s["rep"]) - 4.0)
		toast.emit(L.t("encargo_failed") % UI.money(int(c["encargo"])))
	else:
		s["rep"] = maxf(0.0, float(s["rep"]) - 1.0)
	if not c.has("tut"):
		s["day_handled"] = int(s["day_handled"]) + 1
		s["day_rejected"] = int(s["day_rejected"]) + 1
	customer_left.emit(c, false)
	customers_changed.emit()
	changed.emit()
	_close_if_done()

# ================================================================ proveedor
func supply_price(id: String, urgent: bool) -> int:
	var p := int(DB.ITEMS[id]["cost"])
	return int(ceil(p * DB.URGENT_MULT)) if urgent else p

func buy_supply(id: String, qty: int, urgent := true) -> bool:
	## urgent: llega hoy con sobreprecio. Si no, se pide y llega la proxima vez que pase el proveedor
	if qty <= 0: return false
	if shelf_room() < qty:
		toast.emit(L.t("no_space_shelf"))
		Sfx.play("error")
		return false
	var cost := supply_price(id, urgent) * qty
	if not spend(cost, "supplier"): return false
	if urgent:
		add_item(id, qty)
	else:
		s["supplier_orders"][id] = int(s["supplier_orders"].get(id, 0)) + qty
		changed.emit()
	Sfx.play("buy")
	save_game()
	return true

func _supplier_arrives() -> Dictionary:
	## Al empezar un dia de proveedor llega lo pedido (lo que no quepa espera a la siguiente visita)
	var got := {}
	if not supplier_today(): return got
	for id in s["supplier_orders"].keys():
		var q := int(s["supplier_orders"][id])
		var put := mini(q, space_free("shelf"))
		if put > 0:
			add_item(id, put)
			got[id] = put
		if q - put > 0: s["supplier_orders"][id] = q - put
		else: s["supplier_orders"].erase(id)
	return got

# ================================================================ flota y viajes
func vehicle(vid: int) -> Dictionary:
	for v in s["fleet"]:
		if int(v["id"]) == vid: return v
	return {}

func vehicle_tex(v: Dictionary) -> String:
	if v["type"] == "wheelbarrow":
		return "veh_wheelbarrow_%d" % int(s["wb_tier"])
	return DB.VEHICLES[v["type"]]["tex"]

func vehicle_cap(v: Dictionary) -> int:
	var cap := 0
	if v["type"] == "wheelbarrow": cap = int(DB.WHEELBARROW_TIERS[int(s["wb_tier"])]["cap"])
	else: cap = int(DB.VEHICLES[v["type"]]["cap"])
	if has_tool("pala_pro"): cap = int(round(cap * 1.25))
	return cap

func vehicle_time(v: Dictionary) -> float:
	var t := 0.0
	if v["type"] == "wheelbarrow": t = float(DB.WHEELBARROW_TIERS[int(s["wb_tier"])]["time"])
	else: t = float(DB.VEHICLES[v["type"]]["time"])
	if has_tool("gps"): t *= 0.85
	if s["own_mine"]: t *= 0.8
	return t

func trip_energy(v: Dictionary) -> int:
	var e := int(DB.VEHICLES[v["type"]]["energy"])
	if has_tool("guantes"): e -= 1
	return maxi(1, e)

func mine_price(id: String) -> int:
	var p := int(DB.ITEMS[id]["cost"])
	if s["own_mine"]: return maxi(1, int(ceil(p * float(DB.OWN_MINE["price_mult"]))))
	return p

func player_away() -> bool:
	for v in s["fleet"]:
		if v["trip"] != null and v["trip"]["self"] and float(v["trip"]["end"]) > now():
			return true
	return false

func player_trip_left() -> float:
	for v in s["fleet"]:
		if v["trip"] != null and v["trip"]["self"]:
			return maxf(0.0, float(v["trip"]["end"]) - now())
	return 0.0

func trip_cost(v: Dictionary, load: Dictionary) -> int:
	var c := int(DB.VEHICLES[v["type"]]["gas"])
	for k in load: c += mine_price(k) * int(load[k])
	return c

func send_trip(vid: int, load: Dictionary, self_go: bool) -> bool:
	var v := vehicle(vid)
	if v.is_empty() or v["trip"] != null: return false
	var total := 0
	for k in load: total += int(load[k])
	if total <= 0:
		toast.emit(L.t("load_empty")); return false
	if total > vehicle_cap(v):
		toast.emit(L.t("load_too_big")); return false
	if not mine_open():
		toast.emit(L.t("mine_closed_today")); Sfx.play("error"); return false
	if patio_room() < total:
		toast.emit(L.t("no_space_patio")); Sfx.play("error"); return false
	if self_go:
		if player_away():
			toast.emit(L.t("already_away")); return false
		if float(s["energy"]) < trip_energy(v):
			toast.emit(L.t("no_energy")); Sfx.play("error"); return false
	elif not v["driver"]:
		toast.emit(L.t("need_driver")); return false
	var gas := int(DB.VEHICLES[v["type"]]["gas"])
	var cost := trip_cost(v, load)
	if money() < cost and cost - money() <= 150 and money() > -150:
		# sin dinero: en la mina te fian poquito para que no te quedes atorado
		s["money"] = money() - cost
		_log_spent("mine", cost)
		toast.emit(L.t("mine_credit"))
	elif not spend(cost, "mine"): return false
	if gas > 0:
		# separa la gasolina en el resumen del dia
		var sp: Dictionary = s["today"]["spent"]
		sp["mine"] = int(sp.get("mine", 0)) - gas
		sp["gas"] = int(sp.get("gas", 0)) + gas
	if self_go: use_energy(trip_energy(v))
	v["trip"] = {"start": now(), "end": now() + vehicle_time(v), "load": load, "self": self_go}
	s["stats"]["trips"] = int(s["stats"]["trips"]) + 1
	Sfx.play("truck")
	if int(s["tutorial"]) == 2: set_tutorial(3)
	changed.emit()
	save_game()
	return true

func skip_trip(vid: int) -> void:
	var v := vehicle(vid)
	if v.is_empty() or v["trip"] == null: return
	v["trip"]["end"] = now()
	update_trips()

func update_trips() -> void:
	var t := now()
	for v in s["fleet"]:
		if v["trip"] != null and float(v["trip"]["end"]) <= t and v["trip"].has("delivery"):
			var dl: Dictionary = v["trip"]["delivery"]
			v["trip"] = null
			add_money(int(dl["pay"]))
			add_xp(int(dl["xp"]))
			toast.emit(L.t("delivery_done") % [dl["name"], UI.money(int(dl["pay"]))])
			Sfx.play("cash")
			trip_finished.emit(v)
			changed.emit()
			continue
		if v["trip"] != null and float(v["trip"]["end"]) <= t:
			var load: Dictionary = v["trip"]["load"]
			var left := {}
			var free := space_free("patio")
			for k in load:
				var q := int(load[k])
				var put := mini(q, free)
				if put > 0:
					add_item(k, put); free -= put
				if q - put > 0: left[k] = q - put
			if left.is_empty():
				var was_self: bool = v["trip"]["self"]
				v["trip"] = null
				add_xp(2)
				trip_finished.emit(v)
				toast.emit(L.t("trip_back_self") if was_self else L.t("trip_back_driver") % L.t("veh_" + v["type"]))
				Sfx.play("unload")
			else:
				v["trip"]["load"] = left
				v["trip"]["self"] = false
			changed.emit()

func buy_vehicle(type: String) -> bool:
	var d: Dictionary = DB.VEHICLES[type]
	var count := 0
	for v in s["fleet"]:
		if v["type"] == type: count += 1
	if count >= int(d["max"]):
		toast.emit(L.t("max_vehicles")); return false
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if d.has("shop") and shop_stage() < int(d["shop"]):
		toast.emit(L.t("need_shop") % L.t("shop_stage_%d" % int(d["shop"]))); return false
	if not spend(vehicle_price(type), "upgrades"): return false
	s["fleet"].append({"id": int(s["next_vid"]), "type": type, "driver": false, "trip": null})
	s["next_vid"] = int(s["next_vid"]) + 1
	Sfx.play("levelup")
	changed.emit(); save_game()
	return true

func vehicle_price(type: String) -> int:
	var count := 0
	for v in s["fleet"]:
		if v["type"] == type: count += 1
	if type == "wheelbarrow": count -= 1
	return int(round(float(DB.VEHICLES[type]["cost"]) * pow(1.5, maxi(count, 0))))

func count_type(type: String) -> int:
	var n := 0
	for v in s["fleet"]:
		if v["type"] == type: n += 1
	return n

# ================================================================ mini tutoriales (dia 3+)
func pending_milestone() -> String:
	if s.is_empty() or tutorial_on(): return ""
	var done: Array = s["milestones"]
	var d := int(s["day"])
	if not done.has("morning") and int(s["day"]) >= 2 and phase() == "morning": return "morning"
	if not done.has("upgrade_shop") and d >= 3 and shop_stage() == 1 and level() >= int(DB.SHOP_STAGES[2]["lvl"]) and money() >= int(DB.SHOP_STAGES[2]["cost"]): return "upgrade_shop"
	if not done.has("wheelbarrow2") and d >= 3 and count_type("wheelbarrow") == 1 and level() >= 2 and money() >= vehicle_price("wheelbarrow"): return "wheelbarrow2"
	if not done.has("clerk") and level() >= int(DB.CLERK["lvl"]) and int(s["clerks"]) == 0: return "clerk"
	if not done.has("pickup") and count_type("pickup") > 0: return "pickup"
	return ""

func mark_milestone(id: String) -> void:
	if not s["milestones"].has(id): s["milestones"].append(id)
	save_game()

func hire_driver(vid: int) -> bool:
	var v := vehicle(vid)
	if v.is_empty() or v["driver"]: return false
	var cost := int(DB.VEHICLES[v["type"]]["driver"]) * 3
	if not spend(cost, "staff"): return false
	v["driver"] = true
	Sfx.play("buy")
	changed.emit(); save_game()
	return true

func fire_driver(vid: int) -> bool:
	var v := vehicle(vid)
	if v.is_empty() or not v["driver"] or v["trip"] != null: return false
	v["driver"] = false
	changed.emit(); save_game()
	return true

func fire_clerk() -> bool:
	if int(s["clerks"]) <= 0: return false
	s["clerks"] = int(s["clerks"]) - 1
	if int(s["clerks"]) == 0:
		for c in clerk_customers: customer_left.emit(c, false)
		clerk_customers.clear()
		customers_changed.emit()
	changed.emit(); save_game()
	return true

func upgrade_wheelbarrow() -> bool:
	var t := int(s["wb_tier"]) + 1
	if t >= DB.WHEELBARROW_TIERS.size(): return false
	var d: Dictionary = DB.WHEELBARROW_TIERS[t]
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if not spend(int(d["cost"]), "upgrades"): return false
	s["wb_tier"] = t
	Sfx.play("levelup")
	changed.emit(); save_game()
	return true

# ================================================================ mejoras
func upgrade_shop() -> bool:
	var nxt := shop_stage() + 1
	if nxt >= DB.SHOP_STAGES.size() or shop_stage() == 0: return false
	var d: Dictionary = DB.SHOP_STAGES[nxt]
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if not spend(int(d["cost"]), "upgrades"): return false
	s["shop_stage"] = nxt
	Sfx.play("levelup")
	toast.emit(L.t("shop_upgraded") % L.t("shop_stage_%d" % nxt))
	changed.emit(); save_game()
	return true

func upgrade_house() -> bool:
	var nxt := house_stage() + 1
	if nxt >= DB.HOUSE_STAGES.size(): return false
	var d: Dictionary = DB.HOUSE_STAGES[nxt]
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if not spend(int(d["cost"]), "upgrades"): return false
	s["house_stage"] = nxt
	add_energy(5)
	Sfx.play("levelup")
	changed.emit(); save_game()
	return true

func buy_tool(id: String) -> bool:
	if has_tool(id): return false
	var d: Dictionary = DB.TOOLS[id]
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if not spend(int(d["cost"]), "upgrades"): return false
	s["tools"][id] = true
	Sfx.play("buy")
	changed.emit(); save_game()
	return true

func hire_clerk() -> bool:
	var n := int(s["clerks"])
	if n >= 2: return false
	var d: Dictionary = DB.CLERK if n == 0 else DB.CLERK2
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if not spend(int(d["hire"]), "staff"): return false
	s["clerks"] = n + 1
	Sfx.play("levelup")
	changed.emit(); save_game()
	return true

func upgrade_offline() -> bool:
	var t := int(s["offline_tier"]) + 1
	if t >= DB.OFFLINE_HOURS.size(): return false
	if not spend(int(DB.OFFLINE_HOURS[t]["cost"]), "upgrades"): return false
	s["offline_tier"] = t
	Sfx.play("buy")
	changed.emit(); save_game()
	return true

func buy_own_mine() -> bool:
	if s["own_mine"]: return false
	if level() < int(DB.OWN_MINE["lvl"]):
		toast.emit(L.t("need_level") % int(DB.OWN_MINE["lvl"])); return false
	if not spend(int(DB.OWN_MINE["cost"]), "upgrades"): return false
	s["own_mine"] = true
	Sfx.play("levelup")
	toast.emit(L.t("own_mine_done"))
	changed.emit(); save_game()
	return true

func buy_transport(id: String) -> bool:
	if s["transports"].has(id):
		s["transport"] = id; changed.emit(); return true
	var d: Dictionary = DB.TRANSPORTS[id]
	if level() < int(d["lvl"]):
		toast.emit(L.t("need_level") % int(d["lvl"])); return false
	if int(d["bolts"]) > 0:
		if not spend_bolts(int(d["bolts"])): return false
	elif not spend(int(d["cost"]), "upgrades"): return false
	s["transports"].append(id)
	s["transport"] = id
	Sfx.play("buy")
	changed.emit(); save_game()
	return true

func cosmetic_owned(key: String) -> bool:
	return not DB.COSMETICS.has(key) or s["cosmetics"].has(key)

func unlock_cosmetic(key: String) -> void:
	if not s["cosmetics"].has(key): s["cosmetics"].append(key)
	changed.emit()

# ================================================================ visitante con regalo (anuncio)
func _tick_visitor(delta: float) -> void:
	if shop_stage() < 1: return
	if visitor_active:
		visitor_time -= delta
		if visitor_time <= 0.0:
			visitor_active = false
			visitor_changed.emit()
		return
	s["visitor_next"] = float(s["visitor_next"]) - delta
	if float(s["visitor_next"]) <= 0.0:
		s["visitor_next"] = randf_range(150.0, 260.0)
		if ad_left("visitor") > 0:
			visitor_active = true
			visitor_time = 30.0
			visitor_changed.emit()

func visitor_reward() -> int:
	return maxi(120, level() * 140 + mini(int(money() * 0.03), level() * 260))

func claim_visitor() -> void:
	visitor_active = false
	visitor_changed.emit()
	add_money(visitor_reward())
	Sfx.play("cash")

# ================================================================ anuncios (contador diario)
func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func ad_left(placement: String) -> int:
	if s.is_empty(): return 0
	if s["ads"]["date"] != _today():
		s["ads"] = {"date": _today(), "counts": {}}
	return int(DB.AD_DAILY_LIMITS.get(placement, 5)) - int(s["ads"]["counts"].get(placement, 0))

func ad_used(placement: String) -> void:
	ad_left(placement)
	s["ads"]["counts"][placement] = int(s["ads"]["counts"].get(placement, 0)) + 1

# ================================================================ idle / offline
func offline_hours_cap() -> float:
	return float(DB.OFFLINE_HOURS[int(s["offline_tier"])]["hours"])

func compute_offline() -> void:
	offline_report = {}
	var elapsed := now() - float(s.get("last_time", now()))
	if elapsed < 60.0:
		update_trips()
		return
	var trips_before := 0
	for v in s["fleet"]:
		if v["trip"] != null and float(v["trip"]["end"]) <= now(): trips_before += 1
	update_trips()
	add_energy(float(DB.HOUSE_STAGES[house_stage()]["regen"]) * elapsed / 60.0)
	var sold := 0; var earned := 0
	if int(s["clerks"]) > 0 and shop_open() and not tutorial_on():
		# la empleada atiende su fila del dia aunque cierres la app
		var secs := minf(elapsed, offline_hours_cap() * 3600.0)
		var n := mini(int(secs / clerk_every()), clerk_quota() - int(s["clerk_spawned"]))
		for i in maxi(n, 0):
			s["clerk_spawned"] = int(s["clerk_spawned"]) + 1
			var c := gen_customer(true)
			if can_fulfill(c):
				for o in c["order"]:
					s["inv"][o["id"]] = inv_qty(o["id"]) - int(o["qty"])
					if int(s["inv"][o["id"]]) <= 0: s["inv"].erase(o["id"])
				earned += int(c["price"])
				sold += 1
		if earned > 0:
			add_money(earned)
			add_xp(int(earned / 50.0))
	offline_report = {"seconds": elapsed, "sold": sold, "earned": earned, "trips": trips_before, "clerk": int(s["clerks"]) > 0}

# ================================================================ logros y racha
func _check_streak() -> void:
	## Racha de dias reales jugando
	var today := _today()
	var last := str(s.get("last_play_date", ""))
	if last == today: return
	var y := Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	var yl := Time.get_unix_time_from_datetime_string(last + "T00:00:00") if last != "" else -1
	if yl > 0 and int((y - yl) / 86400) == 1: s["streak"] = int(s["streak"]) + 1
	else: s["streak"] = 1
	s["last_play_date"] = today

func ach_value(id: String) -> int:
	match id:
		"served": return int(s["stats"]["served"])
		"earned": return int(s["stats"]["earned"])
		"trips": return int(s["stats"]["trips"])
		"deliveries": return int(s["stats"].get("deliveries", 0))
		"perfect_days": return int(s["stats"].get("perfect_days", 0))
		"regulars":
			var n := 0
			for k in s["regulars_served"]:
				if int(s["regulars_served"][k]) >= 10: n += 1
			return n
		"shop_max": return 1 if shop_stage() >= DB.SHOP_STAGES.size() - 1 else 0
		"house_max": return 1 if house_stage() >= DB.HOUSE_STAGES.size() - 1 else 0
		"own_mine": return 1 if s["own_mine"] else 0
		"fleet_all":
			for t in ["pickup", "truck", "bigtruck"]:
				var ok := false
				for v in s["fleet"]:
					if v["type"] == t and v["driver"]: ok = true
				if not ok: return 0
			return 1
		"streak": return int(s.get("streak", 0))
	return 0

func ach_level(id: String) -> int:
	## Cuantas metas de este logro ya se cobraron
	return int(s["achievements"].get(id, 0))

func check_achievements() -> void:
	if s.is_empty() or tutorial_on(): return
	for a in DB.ACHIEVEMENTS:
		var id: String = a["id"]
		var lvl := ach_level(id)
		var goals: Array = a["goals"]
		if lvl >= goals.size(): continue
		if ach_value(id) >= int(goals[lvl]):
			s["achievements"][id] = lvl + 1
			var b := int(a["bolts"][lvl])
			add_bolts(b)
			Sfx.play("levelup")
			achievement.emit(id, int(goals[lvl]), b)
			save_game()
			return
