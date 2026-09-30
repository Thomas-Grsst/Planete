extends Node2D

const HALF_W := Iso.TILE_W * 0.5
const HALF_H := Iso.TILE_H * 0.5
const AUTUMN := Color("c9772e")
const DRY := Color("c9a54a")
const SNOW := Color("eef3ff")
const SPRING := Color("7ed957")

var key := Vector2i.ZERO
var order: Array = []
var _season := -1
var _weather := ""
var _mesh: MeshBuilder
var _built: ArrayMesh


static func draw_order(key: Vector2i) -> Array:
	var o := WorldGen.origin(key)
	var out: Array = []
	for i in WorldGen.CHUNK * WorldGen.CHUNK:
		out.append(i)
	out.sort_custom(func(a, b): return Iso.depth(o.x + (a & WorldGen.LOCAL), o.y + (a >> WorldGen.SHIFT)) < Iso.depth(o.x + (b & WorldGen.LOCAL), o.y + (b >> WorldGen.SHIFT)))
	return out


static func back_corner(key: Vector2i) -> Vector2:
	var o := WorldGen.origin(key)
	var best := Vector2.ZERO
	var best_depth := INF
	for c in [Vector2(o.x, o.y), Vector2(o.x + WorldGen.CHUNK, o.y), Vector2(o.x, o.y + WorldGen.CHUNK), Vector2(o.x + WorldGen.CHUNK, o.y + WorldGen.CHUNK)]:
		var d := Iso.depth(c.x, c.y)
		if d < best_depth:
			best_depth = d
			best = c
	return Iso.project(best.x, best.y)


func setup(chunk_key: Vector2i, draw_list: Array) -> void:
	key = chunk_key
	order = draw_list
	position = back_corner(key)


func refresh(force: bool = false) -> void:
	if force or Weather.season(Sim.state["day"]) != _season or Sim.state["weather"] != _weather:
		queue_redraw()


func _draw() -> void:
	var chunk = Sim.state["world"]["chunks"].get(key)
	if chunk == null:
		return
	_season = Weather.season(Sim.state["day"])
	_weather = Sim.state["weather"]
	_mesh = MeshBuilder.new()
	var o := WorldGen.origin(key)
	var tiles: Array = chunk["tiles"]
	for i in order:
		var t: Dictionary = tiles[i]
		if not Biomes.is_water(t["biome"]):
			_draw_tile(o.x + (i & WorldGen.LOCAL), o.y + (i >> WorldGen.SHIFT), t)
	_built = _mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _draw_tile(x: int, y: int, t: Dictionary) -> void:
	var lift := Iso.lift(t["height"], t["biome"])
	var c := Iso.project(x, y, lift) - position
	var top := _top_color(x, y, t)
	var n := c + Vector2(0, -HALF_H)
	var e := c + Vector2(HALF_W, 0)
	var s := c + Vector2(0, HALF_H)
	var w := c + Vector2(-HALF_W, 0)
	var down := Vector2(0, lift)
	_mesh.poly(PackedVector2Array([w, s, s + down, w + down]), top.darkened(0.38))
	_mesh.poly(PackedVector2Array([s, e, e + down, s + down]), top.darkened(0.22))
	_mesh.poly(PackedVector2Array([n, e, s, w]), top)
	_mesh.line(w, n, top.lightened(0.12), 1.0)
	_mesh.line(n, e, top.lightened(0.12), 1.0)


func _top_color(x: int, y: int, t: Dictionary) -> Color:
	var biome: String = t["biome"]
	var base: Color = Biomes.DATA[biome]["color"]
	var jitter := (float((x * 73856093) ^ (y * 19349663)) / 2147483647.0)
	base = base.lightened(0.04 * fmod(absf(jitter) * 10.0, 1.0)).darkened(0.03 * fmod(absf(jitter) * 7.0, 1.0))
	base = base.lightened(clamp((t["height"] - 0.5) * 0.35, 0.0, 0.2))
	if biome == "plain" or biome == "forest":
		var cap := Nature.food_cap(t)
		var depletion: float = 1.0 - t["food"] / cap if cap > 0 else 0.0
		base = base.lerp(DRY, clamp(depletion, 0.0, 1.0) * 0.35)
		if _season == 2:
			base = base.lerp(AUTUMN, 0.22 if biome == "plain" else 0.12)
		elif _season == 0:
			base = base.lerp(SPRING, 0.12)
	if _weather == "snow" and biome != "river":
		base = base.lerp(SNOW, 0.7)
	elif _season == 3 and (biome == "tundra" or biome == "mountain"):
		base = base.lerp(SNOW, 0.55)
	elif biome == "mountain" and t["height"] > 0.86:
		base = base.lerp(SNOW, 0.6)
	return base
