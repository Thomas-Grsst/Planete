extends Node2D

const HALF_W := Iso.TILE_W * 0.5
const HALF_H := Iso.TILE_H * 0.5
const SHORE := Color(1, 1, 1, 0.35)
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var water_material: ShaderMaterial

var key := Vector2i.ZERO
var rivers_only := false
var _mesh: MeshBuilder
var _built: ArrayMesh


func setup(chunk_key: Vector2i, rivers: bool) -> void:
	key = chunk_key
	rivers_only = rivers
	if not rivers_only:
		if water_material == null:
			water_material = ShaderMaterial.new()
			water_material.shader = load("res://shaders/water.gdshader")
		material = water_material


func _draw() -> void:
	var world: Dictionary = Sim.state["world"]
	var chunk = world["chunks"].get(key)
	if chunk == null:
		return
	_mesh = MeshBuilder.new()
	var o := WorldGen.origin(key)
	var tiles: Array = chunk["tiles"]
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		var x: int = o.x + (i & WorldGen.LOCAL)
		var y: int = o.y + (i >> WorldGen.SHIFT)
		if not rivers_only and Biomes.is_water(t["biome"]):
			_draw_water(world, x, y, t)
		elif rivers_only and t["biome"] == "river":
			_draw_river(x, y, t)
	_built = _mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _diamond(c: Vector2, k: float = 1.0) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -HALF_H * k), c + Vector2(HALF_W * k, 0), c + Vector2(0, HALF_H * k), c + Vector2(-HALF_W * k, 0)])


func _draw_water(world: Dictionary, x: int, y: int, t: Dictionary) -> void:
	var c := Iso.project(x, y)
	var depth: float = clamp((Iso.SEA_LEVEL - t["height"]) * 4.0, 0.0, 1.0)
	var color: Color = Biomes.DATA[t["biome"]]["color"].darkened(depth * 0.35)
	_mesh.poly(_diamond(c), color)
	if _touches_land(world, x, y):
		var d := _diamond(c, 0.82)
		for k in 4:
			_mesh.line(d[k], d[(k + 1) % 4], SHORE, 1.2)


func _draw_river(x: int, y: int, t: Dictionary) -> void:
	var c := Iso.project(x, y, Iso.lift(t["height"], t["biome"]) + 0.5)
	var frozen: bool = Weather.season(Sim.state["day"]) == 3 and (Sim.state["weather"] == "snow" or t["height"] > 0.6)
	_mesh.poly(_diamond(c, 0.7), Color("dfeef7") if frozen else Biomes.DATA["river"]["color"])


func _touches_land(world: Dictionary, x: int, y: int) -> bool:
	for o in SIDES:
		var n = WorldGen.tile_at(world, x + o.x, y + o.y)
		if n != null and not Biomes.is_water(n["biome"]):
			return true
	return false
