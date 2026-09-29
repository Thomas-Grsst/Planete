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
