extends Node2D

const TERRAIN := preload("res://scripts/view/chunk_terrain.gd")
const WATER := preload("res://scripts/view/chunk_water.gd")
const FLORA := preload("res://scripts/view/flora.gd")
const POLL_SECONDS := 0.25
const KEEP_MARGIN := 3
const SHOW_MARGIN := 1

var entities: Node2D
var skip_flora := false
var views := {}
var water_root := Node2D.new()
var terrain_root := Node2D.new()
var river_root := Node2D.new()
var fog: Node2D
var _poll := 0.0
var _known := 0
var _range := Rect2i()


func setup(entity_root: Node2D) -> void:
	entities = entity_root
	water_root.z_index = -10
	terrain_root.z_index = -9
	terrain_root.y_sort_enabled = true
	river_root.z_index = -8
	for n in [water_root, terrain_root, river_root]:
		add_child(n)
	fog = Node2D.new()
	fog.set_script(load("res://scripts/view/fog_layer.gd"))
	fog.z_index = -6
	add_child(fog)


func _process(delta: float) -> void:
	if Sim.state.is_empty():
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_SECONDS
	var count: int = Sim.state["world"]["chunks"].size()
	if count != _known:
		_known = count
		for v in views.values():
			v["water"].queue_redraw()
		fog.queue_redraw()
	_stream()


func rebuild() -> void:
	for key in views.keys():
		_drop(key)
	_known = Sim.state["world"]["chunks"].size() if not Sim.state.is_empty() else 0
	_range = Rect2i()
	_stream()


func visible_chunks() -> Rect2i:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2i()
	var half := get_viewport_rect().size / (2.0 * cam.zoom)
	var center := cam.get_screen_center_position()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var t := Iso.unproject(center + half * corner)
		lo = lo.min(t)
		hi = hi.max(t)
	var a := WorldGen.key_of(floori(lo.x), floori(lo.y))
	var b := WorldGen.key_of(ceili(hi.x), ceili(hi.y))
	return Rect2i(a, b - a + Vector2i.ONE)


func _stream() -> void:
	var r := visible_chunks()
	if r.size == Vector2i.ZERO:
		return
	var show := r.grow(SHOW_MARGIN)
	var keep := r.grow(KEEP_MARGIN)
	for key in views.keys():
		if not keep.has_point(key):
			_drop(key)
	var chunks: Dictionary = Sim.state["world"]["chunks"]
	for cy in range(show.position.y, show.end.y):
		for cx in range(show.position.x, show.end.x):
			var key := Vector2i(cx, cy)
			if chunks.has(key) and not views.has(key):
				_make(key)
	if show != _range:
		_range = show
		fog.show_range(show)


func _make(key: Vector2i) -> void:
	var water := Node2D.new()
	water.set_script(WATER)
	water.setup(key, false)
	water_root.add_child(water)
	var rivers := Node2D.new()
	rivers.set_script(WATER)
	rivers.setup(key, true)
	river_root.add_child(rivers)
	var terrain := Node2D.new()
	terrain.set_script(TERRAIN)
	terrain.setup(key, TERRAIN.draw_order(key))
	terrain_root.add_child(terrain)
	var flora := Node2D.new()
	flora.y_sort_enabled = true
	entities.add_child(flora)
	views[key] = {"water": water, "rivers": rivers, "terrain": terrain, "flora": flora}
	if not skip_flora:
		_plant(key, flora)


func _drop(key: Vector2i) -> void:
	for n in views[key].values():
		n.queue_free()
	views.erase(key)


func _plant(key: Vector2i, root: Node2D) -> void:
	var tiles: Array = Sim.state["world"]["chunks"][key]["tiles"]
	var o := WorldGen.origin(key)
	var lines := {}
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		var grows: bool = t["fertility"] > 0.3 and Biomes.walkable(t["biome"]) and t["biome"] != "river"
		if t["trees"] <= 0 and not grows and t["ore"] == "":
			continue
		var pos := o + Vector2i(i & WorldGen.LOCAL, i >> WorldGen.SHIFT)
		var d := roundi(Iso.depth(pos.x, pos.y))
		if not lines.has(d):
			lines[d] = []
		lines[d].append(pos)
	for d in lines:
		var node := Node2D.new()
		node.set_script(FLORA)
		node.position = Vector2(0, d * Iso.TILE_H * 0.5)
		root.add_child(node)
		node.setup(lines[d])


func refresh_terrain(force: bool) -> void:
	for v in views.values():
		v["terrain"].refresh(force)


func refresh_rivers() -> void:
	for v in views.values():
		v["rivers"].queue_redraw()


func refresh_flora(near: Rect2i = Rect2i()) -> void:
	for key in views:
		if near.size == Vector2i.ZERO or near.has_point(key):
			for n in views[key]["flora"].get_children():
				n.refresh()
