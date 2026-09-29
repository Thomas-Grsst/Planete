class_name Geography
extends RefCounted

const SPOT_TRIES := 60
const MIN_SPACING := 6
const FISHING_VALUE := 0.55
const COAST_BONUS := 3.0


static func of(world: Dictionary, x: int, y: int) -> Dictionary:
	var geo := {"water": 0, "coast": false, "river": false, "forest": 0, "swamp": 0, "mountain": 0, "fertile": 0, "ores": []}
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var t = WorldGen.tile_at(world, x + dx, y + dy)
			if t == null:
				continue
			var reach: int = max(absi(dx), absi(dy))
			if t["biome"] == "mountain":
				geo["mountain"] += 1
			if t["ore"] != "" and not geo["ores"].has(t["ore"]):
				geo["ores"].append(t["ore"])
			if reach > 3:
				continue
			if t["biome"] == "forest":
				geo["forest"] += 1
			if t["biome"] == "swamp":
				geo["swamp"] += 1
			if t["fertility"] >= 0.8:
				geo["fertile"] += 1
			if reach > 2:
				continue
			if Biomes.is_water(t["biome"]) or t["biome"] == "river":
				geo["water"] += 1
			if Biomes.is_water(t["biome"]):
				geo["coast"] = true
			if t["biome"] == "river":
				geo["river"] = true
	return geo


static func is_coastal(world: Dictionary, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t = WorldGen.tile_at(world, x + dx, y + dy)
			if t != null and Biomes.is_water(t["biome"]):
				return true
	return false


static func find_spot(state: Dictionary, rng: Rng, cx: int, cy: int, radius: int, any_land: bool = false) -> Variant:
	var world: Dictionary = state["world"]
	var best = null
	var best_score := 0.0
	for tries in SPOT_TRIES:
		var x := clampi(cx + rng.range_int(-radius, radius), 1, WorldGen.SIZE - 2)
		var y := clampi(cy + rng.range_int(-radius, radius), 1, WorldGen.SIZE - 2)
		var t = WorldGen.tile_at(world, x, y)
		if t == null or not Biomes.walkable(t["biome"]) or t["biome"] == "river" or t["biome"] == "mountain":
			continue
		if not any_land and not Regions.same_landmass(world, cx, cy, x, y):
			continue
		if _too_close(state, x, y):
			continue
		var score := _score(world, x, y)
		if score > best_score:
			best_score = score
			best = Vector2i(x, y)
	return best


static func _too_close(state: Dictionary, x: int, y: int) -> bool:
	for s in state["settlements"]:
		if s["abandoned"] < 0 and absi(s["x"] - x) + absi(s["y"] - y) < MIN_SPACING:
			return true
	return false


static func _score(world: Dictionary, x: int, y: int) -> float:
	var score := 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n = WorldGen.tile_at(world, x + dx, y + dy)
			if n != null:
				score += FISHING_VALUE if Biomes.is_water(n["biome"]) else n["fertility"] + n["trees"] * 0.05
	if is_coastal(world, x, y):
		score += COAST_BONUS
	return score
