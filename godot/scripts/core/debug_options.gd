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
