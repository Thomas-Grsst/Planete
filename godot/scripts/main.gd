extends Node2D

var world_view: Node2D
var camera: Camera2D
var hud
var options := {}


func _ready() -> void:
	options = DebugOptions.parse()
	Iso.turn = int(options.get("turn", "0")) % 4
	_build_scene()
	Sim.power_used.connect(_on_power)
	var offline := Boot.start(options)
	_on_world_loaded()
	Sim.world_loaded.connect(_on_world_loaded)
	Sim.resumed.connect(func(_days): _catch_up_screen())
	if offline > 0:
		_catch_up_screen()
	else:
		hud.welcome(0)
	if options.has("panel"):
		hud.show_info(options["panel"], DebugOptions.panel_id(options["panel"]))
	if options.has("shot"):
		DebugOptions.schedule_shot(self, options)


func _build_scene() -> void:
	world_view = Node2D.new()
	world_view.set_script(load("res://scripts/view/world_view.gd"))
	world_view.skip_flora = options.has("no-flora")
	add_child(world_view)
	world_view.build()
	var daylight := CanvasModulate.new()
	daylight.set_script(load("res://scripts/view/daylight.gd"))
	add_child(daylight)
	camera = Camera2D.new()
	camera.set_script(load("res://scripts/view/camera_rig.gd"))
	add_child(camera)
	camera.tapped.connect(func(pos): world_view.life.tap(pos))
	world_view.life.world_fx.shake.connect(func(amount): camera.shake(amount))
	var sound := Node.new()
	sound.name = "Soundscape"
	sound.set_script(load("res://scripts/view/soundscape.gd"))
	add_child(sound)
	var sky := CanvasLayer.new()
	sky.layer = 1
	sky.set_script(load("res://scripts/view/sky.gd"))
	add_child(sky)
	hud = CanvasLayer.new()
	hud.layer = 2
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)
	hud.focus_requested.connect(func(pos): camera.focus(pos))
	hud.rotate_requested.connect(_rotate)
	world_view.life.selected.connect(func(kind, id): hud.show_info(kind, id))
	var phone := Node.new()
	phone.name = "Phone"
	phone.set_script(load("res://scripts/core/phone.gd"))
	add_child(phone)


func _rotate() -> void:
	var tile := Iso.unproject(camera.target_pos)
	Iso.turn = (Iso.turn + 1) % 4
	world_view.rotate_view()
	camera.jump(Iso.project(tile.x, tile.y))


func _catch_up_screen() -> void:
	hud.start_catch_up()
	Sim.caught_up.connect(func(days): hud.welcome(days), CONNECT_ONE_SHOT)


func debug_report() -> String:
	var counts := {}
	for p in world_view.life.villagers.values():
		var key: String = p.activity + ("*" if p.walking else "")
		counts[key] = counts.get(key, 0) + 1
	var perf := "objects %d · draw calls %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	return "fps %d · villagers %d · %s · activities: %s" % [Engine.get_frames_per_second(), counts.values().reduce(func(a, b): return a + b, 0), perf, str(counts)]


func _on_power(_name: String, answered: Array) -> void:
	if answered.is_empty():
		return
	var s = Settlements.by_id(Sim.state, answered[0])
	if s != null:
		camera.focus(Iso.ground(Sim.state["world"], s["x"], s["y"]))


func _on_world_loaded() -> void:
	world_view.spawn_flora()
	var home = null
	for s in Sim.state["settlements"]:
		if s["abandoned"] < 0:
			home = s
			break
	if home != null:
		camera.jump(Iso.ground(Sim.state["world"], home["x"], home["y"]))
	if options.has("zoom"):
		camera.target_zoom = float(options["zoom"])
		camera.zoom = Vector2.ONE * camera.target_zoom
