extends Node2D

var world_root: Node2D
var entities: Node2D
var camera: Camera2D
var flora := {}
var hud
var options := {}

const TERRAIN_BANDS := 12
const BAND_SIZE := 8


func _ready() -> void:
	options = DebugOptions.parse()
	_build_scene()
	Sim.day_passed.connect(_on_day)
	var offline := Boot.start(options)
	_on_world_loaded()
	Sim.world_loaded.connect(_on_world_loaded)
	if offline > 0:
		hud.start_catch_up()
		Sim.caught_up.connect(func(days): hud.welcome(days), CONNECT_ONE_SHOT)
	else:
		hud.welcome(0)
	if options.has("panel"):
		hud.show_info(options["panel"], Sim.state["settlements"][0]["id"] if options["panel"] == "settlement" else -1)
	if options.has("shot"):
		DebugOptions.schedule_shot(self, options)


func _build_scene() -> void:
	world_root = Node2D.new()
	add_child(world_root)
	var water := Node2D.new()
	water.set_script(load("res://scripts/view/water_layer.gd"))
	water.z_index = -10
	world_root.add_child(water)
	for band in TERRAIN_BANDS:
		var terrain := Node2D.new()
		terrain.set_script(load("res://scripts/view/terrain_layer.gd"))
		terrain.band_start = band * BAND_SIZE
		terrain.band_end = (band + 1) * BAND_SIZE
		terrain.z_index = -9
		world_root.add_child(terrain)
	var rivers := Node2D.new()
	rivers.set_script(load("res://scripts/view/water_layer.gd"))
	rivers.rivers_only = true
	rivers.z_index = -8
	world_root.add_child(rivers)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	world_root.add_child(entities)
	var life := Node2D.new()
	life.set_script(load("res://scripts/view/life.gd"))
	world_root.add_child(life)
	life.setup(entities)
	var daylight := CanvasModulate.new()
	daylight.set_script(load("res://scripts/view/daylight.gd"))
	add_child(daylight)
	camera = Camera2D.new()
	camera.set_script(load("res://scripts/view/camera_rig.gd"))
	add_child(camera)
	camera.tapped.connect(func(pos): life.tap(pos))
	var sky := CanvasLayer.new()
	sky.layer = 1
	sky.set_script(load("res://scripts/view/sky.gd"))
	add_child(sky)
	hud = CanvasLayer.new()
	hud.layer = 2
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)
	hud.focus_requested.connect(func(pos): camera.focus(pos))
	life.selected.connect(func(kind, id): hud.show_info(kind, id))


func debug_report() -> String:
	var counts := {}
	for v in world_root.get_children():
		if v.has_method("tap"):
			for p in v.villagers.values():
				var key: String = p.activity + ("*" if p.walking else "")
				counts[key] = counts.get(key, 0) + 1
	var perf := "process %.1f ms · physics %.1f ms · objects %d · draw calls %d · items %d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
	return "fps %d · villagers %d · %s · activities: %s" % [Engine.get_frames_per_second(), counts.values().reduce(func(a, b): return a + b, 0), perf, str(counts)]


func _on_world_loaded() -> void:
	_spawn_flora()
	_center_camera()


func _spawn_flora() -> void:
	for n in flora.values():
		n.queue_free()
	flora.clear()
	if options.has("no-flora"):
		return
	var tiles: Array = Sim.state["world"]["tiles"]
	var diagonals := {}
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		var grows: bool = t["fertility"] > 0.3 and Biomes.walkable(t["biome"]) and t["biome"] != "river"
		if t["trees"] > 0 or grows:
			var d: int = i % WorldGen.SIZE + i / WorldGen.SIZE
			if not diagonals.has(d):
				diagonals[d] = []
			diagonals[d].append(i)
	for d in diagonals:
		var node := Node2D.new()
		node.set_script(load("res://scripts/view/flora.gd"))
		node.position = Vector2(0, d * Iso.TILE_H * 0.5)
		entities.add_child(node)
		node.setup(diagonals[d])
		flora[d] = node


func _on_day(day: int) -> void:
	var near := {}
	for s in Sim.state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		for r in range(-8, 9):
			near[s["x"] + s["y"] + r] = true
	for d in flora:
		if near.has(d) or day % 30 == 0:
			flora[d].refresh()


func _center_camera() -> void:
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
