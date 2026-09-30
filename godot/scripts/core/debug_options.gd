class_name DebugOptions
extends RefCounted


static func parse() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return out


static func _fake_conversion() -> void:
	var alive: Array = Sim.state["settlements"].filter(func(s): return s["abandoned"] < 0)
	if alive.size() < 2:
		return
	var s: Dictionary = alive[0]
	var rel = Religions.of(Sim.state, s)
	if rel == null:
		var prophet: Dictionary = Sim.state["people"].filter(func(p): return p["alive"] and p["home"] == s["id"])[0]
		rel = Religions.create(Sim.state, Sim.rng, s, prophet, "rain")
	Sim.event_logged.emit({"type": "conversion", "from": s["id"], "settlement": alive[1]["id"], "religion": rel["id"], "text": "🕯️ Test de pèlerinage."})


static func _fake_voyage() -> void:
	var alive: Array = Sim.state["settlements"].filter(func(s): return s["abandoned"] < 0)
	if alive.is_empty():
		return
	var a: Dictionary = alive[0]
	var b: Dictionary = alive[-1]
	var sea := Ports.has_port(a) and Ports.has_port(b)
	var trip := {"from": b["id"], "to": a["id"], "sea": sea, "icon": "🔥"} if b["id"] != a["id"] else {"from": a["id"], "to": a["id"], "sea": false, "icon": "🔥"}
	Sim.event_logged.emit({"type": "diffusion", "tech": "feu", "x": a["x"], "y": a["y"], "settlement": a["id"], "text": "⛵ Test de voyage.", "voyage": trip})


# --era=tent|hut|tiled|stone|brick [--level=N] [--houses=N] : habille le premier village pour tester son allure.
static func apply_era(options: Dictionary) -> void:
	var eras := {"tent": [[], 0], "hut": [["feu", "agriculture"], 2], "tiled": [["feu", "agriculture", "poterie"], 2],
		"stone": [["feu", "agriculture", "poterie", "architecture", "roue"], 3], "brick": [["feu", "agriculture", "poterie", "architecture", "roue", "machines", "electricite"], 4]}
	var era: Array = eras.get(options["era"], eras["hut"])
	var s: Dictionary = Sim.state["settlements"][0]
	for k in era[0]:
		if not s["techs"].has(k):
			s["techs"].append(k)
	if era[0].is_empty():
		s["techs"] = s["techs"].filter(func(k): return k == "feu")
	s["level"] = int(options.get("level", str(era[1])))
	s["houses"] = int(options.get("houses", str(4 + s["level"] * 4)))


static func panel_id(kind: String) -> int:
	var st: Dictionary = Sim.state
	var lists := {"settlement": st["settlements"], "faith": st.get("religions", []), "civ": st.get("civs", []), "person": st["people"].filter(func(p): return p["alive"])}
	var items: Array = lists.get(kind, [])
	return items[0]["id"] if not items.is_empty() else -1


static func _tap(host: Node, pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		host.get_viewport().push_input(e, true)


static func schedule_shot(host: Node, options: Dictionary) -> void:
	var after := float(options.get("after", "3"))
	if options.has("power"):
		await host.get_tree().create_timer(1.5).timeout
		print("power: ", Sim.use_power(options["power"]))
	if options.has("pilgrim"):
		await host.get_tree().create_timer(1.0).timeout
		_fake_conversion()
	if options.has("siege"):
		await host.get_tree().create_timer(1.0).timeout
		_fake_siege()
	if options.has("voyage"):
		await host.get_tree().create_timer(1.0).timeout
		_fake_voyage()
	if options.has("tap"):
		await host.get_tree().create_timer(after * 0.5).timeout
		_tap(host, host.get_viewport().get_visible_rect().size * 0.5 + Vector2(0, float(options["tap"])))
	await host.get_tree().create_timer(after * (0.5 if options.has("tap") else 1.0)).timeout
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	image.save_png(options["shot"])
	if host.has_method("debug_report"):
		print(host.debug_report())
	print("shot saved: ", options["shot"])
	host.get_tree().quit()


static func _fake_siege() -> void:
	var st: Dictionary = Sim.state
	var s: Dictionary = st["settlements"].filter(func(o): return o["abandoned"] < 0)[0]
	var civ = Civs.of(st, s)
	var by: int = civ["id"] if civ != null else -1
	s["walls"] = st["day"]
	s["stone_walls"] = Techs.has_tech(s, "architecture")
	s["siege"] = {"by": by, "since": st["day"], "until": st["day"] + 90}
	var spot = Ports._spot(st["world"], s)
	if spot != null:
		s["port"] = {"x": spot.x, "y": spot.y, "day": st["day"]}
		s["blockade"] = {"by": by, "until": st["day"] + 90}
	Sim.world_loaded.emit()
