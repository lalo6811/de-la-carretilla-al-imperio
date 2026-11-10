extends Node
## Monetizacion. Por ahora SIMULADA: muestra un anuncio de prueba y compras sin cobro.
##
## Para conectarlo de verdad:
## - Anuncios: plugin "Godot AdMob" (poing-studios/godot-admob-plugin). En show_rewarded()
##   reemplaza _fake_ad() por la carga/mostrado de RewardedAd y llama on_reward en
##   on_user_earned_reward. Necesitas tu App ID y los IDs de bloque de anuncios de AdMob.
## - Compras: plugin oficial "GodotGooglePlayBilling". En purchase() reemplaza
##   _fake_purchase() por billing.purchase(product_id) y entrega en el callback de compra.
##   Los product_id deben coincidir con los de DB.PRODUCTS y con Google Play Console.

const SIMULATED := true

func ads_removed() -> bool:
	return bool(Game.s.get("no_ads", false))

## placement: energy / offline_double / trip_skip / visitor / bolts / cosmetic
func show_rewarded(placement: String, on_reward: Callable) -> void:
	if Game.ad_left(placement) <= 0:
		UI.toast(L.t("ad_limit"))
		return
	if ads_removed():
		# Con el pack sin anuncios la recompensa se entrega directo
		Game.ad_used(placement)
		on_reward.call()
		return
	_fake_ad(func():
		Game.ad_used(placement)
		on_reward.call())

func purchase(product_id: String, on_done: Callable = Callable()) -> void:
	var p: Dictionary = DB.PRODUCTS[product_id]
	if product_id == "no_ads" and Game.s.get("no_ads", false):
		UI.toast(L.t("already_owned")); return
	if product_id == "starter_pack" and Game.s.get("starter", false):
		UI.toast(L.t("already_owned")); return
	var do_buy := func() -> void:
		_grant(product_id)
		if on_done.is_valid():
			on_done.call()
	UI.confirm(L.t("buy_title"), L.t("sim_purchase") % [L.t("prod_" + product_id), p["price"]], do_buy, L.t("buy"))

func _grant(product_id: String) -> void:
	var p: Dictionary = DB.PRODUCTS[product_id]
	if p.has("money"): Game.add_money(int(p["money"]), false)
	if p.has("bolts"): Game.add_bolts(int(p["bolts"]))
	for u in p.get("unlock", []):
		if String(u).begins_with("tr:"):
			var id := String(u).substr(3)
			if not Game.s["transports"].has(id): Game.s["transports"].append(id)
		else:
			Game.unlock_cosmetic(u)
	if product_id == "no_ads": Game.s["no_ads"] = true
	if product_id == "starter_pack": Game.s["starter"] = true
	Sfx.play("levelup")
	UI.toast(L.t("thanks_purchase"), UI.SAND)
	Game.save_game()
	Game.changed.emit()

func _fake_ad(on_complete: Callable) -> void:
	var root := Control.new()
	root.theme = UI.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new(); bg.color = Color("2a1d16"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(c)
	var v := UI.vbox(14); c.add_child(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UI.label(L.t("ad_test_title"), 10, Color("8fe0b0"), true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var art := UI.icon("veh_truck", 4)
	v.add_child(art)
	var info := UI.label(L.t("ad_test_body"), 20, Color("d8c4a8"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var count := UI.label("3", 16, UI.YELLOW, true)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(count)
	var skip := UI.btn(L.t("ad_close_no_reward"), func(): root.queue_free(), "bad")
	v.add_child(skip)
	UI.overlay.add_child(root)
	var tw := root.create_tween()
	for i in [2, 1]:
		tw.tween_interval(1.0)
		tw.tween_callback(func(): count.text = str(i))
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		root.queue_free()
		Sfx.play("coin")
		on_complete.call())
