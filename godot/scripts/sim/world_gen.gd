class_name WorldGen
extends RefCounted

const SIZE := 48
const RIVERS := 4
const VEIN_RADIUS := 2
const VEIN_TRIES := 200


static func generate(seed_value: int) -> Dictionary:
	var rng := Rng.new(seed_value)
	var heights := _noise(rng, 4)
	var moisture := _noise(rng, 3)
	var tiles: Array = []
	for i in SIZE * SIZE:
		var x := i % SIZE
		var y := i / SIZE
		var edge := float(min(min(x, y), min(SIZE - 1 - x, SIZE - 1 - y))) / (SIZE / 2.0)
		var h: float = heights[i] * min(1.0, edge * 2.2 + 0.35)
		heights[i] = h
		var biome := _pick_biome(h, moisture[i], y)
		tiles.append({
			"biome": biome, "height": h, "ore": "",
			"trees": rng.range_int(4, 9) if biome == "forest" else (rng.range_int(0, 2) if biome == "plain" or biome == "swamp" else 0),
			"stone": rng.range_int(5, 12) if biome == "mountain" else 0,
			"food": 0.0, "fertility": 0.0,
		})
	_carve_rivers(tiles, heights, rng)
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		t["fertility"] = Biomes.DATA[t["biome"]]["food"]
		if t["biome"] != "river":
			for j in neighbors(i):
				if tiles[j]["biome"] == "river" and t["fertility"] > 0.1:
					t["fertility"] = min(1.0, t["fertility"] + 0.3)
		t["food"] = t["fertility"] * 10.0
	var world := {"size": SIZE, "tiles": tiles}
	_place_ores(world, Rng.new(seed_value ^ 0x5eed0e5))
	return world


static func _noise(rng: Rng, octaves: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var amp := 1.0
	var total := 0.0
	for o in octaves:
		var step: int = max(2, SIZE >> o)
		var cells: int = int(ceil(float(SIZE) / step)) + 2
		var grid := PackedFloat32Array()
		grid.resize(cells * cells)
		for k in grid.size():
			grid[k] = rng.next()
		for y in SIZE:
			for x in SIZE:
				var gx := float(x) / step
				var gy := float(y) / step
				var x0 := int(floor(gx))
				var y0 := int(floor(gy))
				var fx := smoothstep(0.0, 1.0, gx - x0)
				var fy := smoothstep(0.0, 1.0, gy - y0)
				var top: float = lerp(grid[y0 * cells + x0], grid[y0 * cells + x0 + 1], fx)
				var bottom: float = lerp(grid[(y0 + 1) * cells + x0], grid[(y0 + 1) * cells + x0 + 1], fx)
				out[y * SIZE + x] += lerp(top, bottom, fy) * amp
		total += amp
		amp *= 0.5
	for i in out.size():
		out[i] /= total
	return out


static func _pick_biome(h: float, m: float, y: int) -> String:
	if h < 0.38:
		return "ocean"
	if h < 0.41:
		return "beach"
	if h > 0.78:
		return "mountain"
	var polar := absf(y - SIZE / 2.0) / (SIZE / 2.0)
	if polar > 0.82 and h < 0.7:
		return "tundra"
	if m < 0.3 and h < 0.6:
		return "desert"
	if m > 0.75 and h < 0.48:
		return "swamp"
	if m > 0.55:
		return "forest"
	return "plain"


static func _carve_rivers(tiles: Array, heights: PackedFloat32Array, rng: Rng) -> void:
	var peaks: Array = []
	for i in tiles.size():
		if heights[i] > 0.72:
			peaks.append(i)
	for r in min(RIVERS, peaks.size()):
		var i: int = rng.pick(peaks)
		for steps in SIZE * 2:
			var t: Dictionary = tiles[i]
			if Biomes.is_water(t["biome"]):
				break
			if t["biome"] != "mountain":
				t["biome"] = "river"
			var best := -1
			var best_h := heights[i]
			for j in neighbors(i):
				if heights[j] < best_h:
					best_h = heights[j]
					best = j
			if best < 0:
				if t["biome"] != "mountain":
					t["biome"] = "lake"
				break
			i = best


static func neighbors(i: int) -> Array:
	var x := i % SIZE
	var y := i / SIZE
	var out: Array = []
	if x > 0: out.append(i - 1)
	if x < SIZE - 1: out.append(i + 1)
	if y > 0: out.append(i - SIZE)
	if y < SIZE - 1: out.append(i + SIZE)
	return out


static func tile_at(world: Dictionary, x: int, y: int):
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return null
	return world["tiles"][y * SIZE + x]


static func is_walkable(world: Dictionary, x: int, y: int) -> bool:
	var t = tile_at(world, x, y)
	return t != null and Biomes.walkable(t["biome"])


static func _place_ores(world: Dictionary, rng: Rng) -> void:
	for key in Biomes.ORES:
		var ore: Dictionary = Biomes.ORES[key]
		for v in rng.range_int(ore["veins"][0], ore["veins"][1]):
			_place_vein(world, rng, key, ore["biomes"])


static func _place_vein(world: Dictionary, rng: Rng, key: String, biomes: Array) -> void:
	for tries in VEIN_TRIES:
		var cx := rng.range_int(0, SIZE - 1)
		var cy := rng.range_int(0, SIZE - 1)
		var center = tile_at(world, cx, cy)
		if center == null or center["ore"] != "" or not biomes.has(center["biome"]):
			continue
		for dy in range(-VEIN_RADIUS, VEIN_RADIUS + 1):
			for dx in range(-VEIN_RADIUS, VEIN_RADIUS + 1):
				var t = tile_at(world, cx + dx, cy + dy)
				if absi(dx) + absi(dy) <= VEIN_RADIUS and rng.chance(0.55) and t != null and biomes.has(t["biome"]) and t["ore"] == "":
					t["ore"] = key
		return
