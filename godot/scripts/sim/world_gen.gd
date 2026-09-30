class_name WorldGen
extends RefCounted

const CHUNK := TerrainGen.CHUNK
const SHIFT := 4
const LOCAL := CHUNK - 1
const VERSION := 2
const START_REVEAL := 24
const START_SEARCH := 320
const START_STEP := 4
const LAND_SAMPLES := 9
const LAND_SPACING := 4
const LAND_SHARE := 0.55
const HOME_BIOMES := ["plain"]
const HOME_REACH := 5
const HOME_FERTILE := 30


static func generate(seed_value: int) -> Dictionary:
	var world := {"version": VERSION, "seed": seed_value, "chunks": {}, "depleted": {}, "fished": {}, "rev": 0}
	var start := find_start(seed_value)
	world["start"] = start
	reveal_area(world, start.x, start.y, START_REVEAL)
	return world


static func key_of(x: int, y: int) -> Vector2i:
	return Vector2i(x >> SHIFT, y >> SHIFT)


static func origin(key: Vector2i) -> Vector2i:
	return key * CHUNK


static func tile_at(world: Dictionary, x: int, y: int):
	var c = world["chunks"].get(Vector2i(x >> SHIFT, y >> SHIFT))
	if c == null:
		return null
	return c["tiles"][((y & LOCAL) << SHIFT) | (x & LOCAL)]


static func known(world: Dictionary, x: int, y: int) -> bool:
	return world["chunks"].has(Vector2i(x >> SHIFT, y >> SHIFT))


static func is_walkable(world: Dictionary, x: int, y: int) -> bool:
	var t = tile_at(world, x, y)
	return t != null and Biomes.walkable(t["biome"])


static func neighbors(x: int, y: int) -> Array:
	return [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]


static func reveal_chunk(world: Dictionary, key: Vector2i) -> bool:
	if world["chunks"].has(key):
		return false
	world["chunks"][key] = TerrainGen.chunk(world["seed"], key.x, key.y)
	Regions.add_chunk(world, key)
	return true


static func reveal_area(world: Dictionary, x: int, y: int, radius: int) -> Array:
	var fresh: Array = []
	for cy in range((y - radius) >> SHIFT, ((y + radius) >> SHIFT) + 1):
		for cx in range((x - radius) >> SHIFT, ((x + radius) >> SHIFT) + 1):
			var key := Vector2i(cx, cy)
			if reveal_chunk(world, key):
				fresh.append(key)
	return fresh


static func random_known(world: Dictionary, rng: Rng) -> Vector2i:
	var key: Vector2i = rng.pick(world["chunks"].keys())
	return origin(key) + Vector2i(rng.range_int(0, LOCAL), rng.range_int(0, LOCAL))


static func find_start(seed_value: int) -> Vector2i:
	for r in range(0, START_SEARCH, START_STEP):
		for pos in _ring(r):
			if _good_start(seed_value, pos.x, pos.y):
				return pos
	return Vector2i.ZERO


static func _ring(r: int) -> Array:
	if r == 0:
		return [Vector2i.ZERO]
	var out: Array = []
	for i in range(-r, r + 1, START_STEP):
		out.append_array([Vector2i(i, -r), Vector2i(i, r), Vector2i(-r, i), Vector2i(r, i)])
	return out


static func _good_start(seed_value: int, x: int, y: int) -> bool:
	if not HOME_BIOMES.has(TerrainGen.tile(seed_value, x, y)["biome"]):
		return false
	var land := 0
	var half := LAND_SAMPLES / 2
	for j in range(-half, half + 1):
		for i in range(-half, half + 1):
			if TerrainGen.height(seed_value, x + i * LAND_SPACING, y + j * LAND_SPACING) >= 0.41:
				land += 1
	if land < LAND_SAMPLES * LAND_SAMPLES * LAND_SHARE:
		return false
	var water := false
	var fertile := 0
	for j in range(-HOME_REACH, HOME_REACH + 1):
		for i in range(-HOME_REACH, HOME_REACH + 1):
			var t := TerrainGen.tile(seed_value, x + i, y + j)
			if t["biome"] in ["river", "lake", "ocean"]:
				water = true
			if t["fertility"] >= 0.8:
				fertile += 1
	return water and fertile >= HOME_FERTILE
