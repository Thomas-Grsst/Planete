extends Node2D

const TERRAIN_BANDS := 12
const BAND_SIZE := 8
const LAYERS := {
	"water": ["res://scripts/view/water_layer.gd", -10],
	"rivers": ["res://scripts/view/water_layer.gd", -8],
	"territory": ["res://scripts/view/territory_layer.gd", -7],
}

var entities: Node2D
var life: Node2D
var flora := {}
var layers: Array = []
var skip_flora := false


func build() -> void:
	layers.append(_layer("water"))
	for band in TERRAIN_BANDS:
		var terrain := Node2D.new()
		terrain.set_script(load("res://scripts/view/terrain_layer.gd"))
		terrain.band_start = band * BAND_SIZE
		terrain.band_end = (band + 1) * BAND_SIZE
		terrain.z_index = -9
		add_child(terrain)
		layers.append(terrain)
	var rivers := _layer("rivers")
	rivers.rivers_only = true
	layers.append(rivers)
	layers.append(_layer("territory"))
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	life = Node2D.new()
	life.set_script(load("res://scripts/view/life.gd"))
	add_child(life)
	life.setup(entities)
	life.world_fx.map_changed.connect(_on_map_changed)
	Sim.day_passed.connect(_on_day)
	Sim.power_used.connect(func(name, _answered): if name == "grow": _refresh_all_flora())
	Sim.world_loaded.connect(spawn_flora)


func _layer(key: String) -> Node2D:
	var node := Node2D.new()
	node.set_script(load(LAYERS[key][0]))
	node.z_index = LAYERS[key][1]
	add_child(node)
	return node


func _on_map_changed() -> void:
	for layer in layers:
		layer.queue_redraw()
	spawn_flora()


func _refresh_all_flora() -> void:
	for d in flora:
		flora[d].refresh()


func spawn_flora() -> void:
	for n in flora.values():
		n.queue_free()
	flora.clear()
	if skip_flora:
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
	if Weather.season(day) != Weather.season(day - 1) or day % 10 == 0:
		layers[TERRAIN_BANDS + 1].queue_redraw()
	var near := {}
	for s in Sim.state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		for r in range(-8, 9):
			near[s["x"] + s["y"] + r] = true
	for d in flora:
		if near.has(d) or day % 30 == 0:
			flora[d].refresh()
