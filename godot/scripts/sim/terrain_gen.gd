class_name TerrainGen
extends RefCounted

const CHUNK := 16
const MASK := 0xFFFFFFFF
const HEIGHT_WAVES := [128.0, 64.0, 32.0, 16.0, 8.0]
const MOIST_WAVES := [72.0, 24.0, 9.0]
const TEMP_WAVES := [180.0, 60.0]
const RIVER_WAVES := [44.0, 14.0]
const LAKE_WAVE := 20.0
const RIVER_WIDTH := 0.02
const RIVER_BANKS := 0.05
const LAKE_LEVEL := 0.86
const CONTRAST := 2.3
const SHIFT := -0.12
const CLIMATE_CONTRAST := 1.8
const ORE_CHANCE := {"cuivre": 0.35, "etain": 0.22, "fer": 0.3, "charbon": 0.22, "obsidienne": 0.15, "argile": 0.5, "pierre": 0.9, "or": 0.1, "diamant": 0.35}
# Le diamant ne se forme que sur les îles : un morceau de carte surtout couvert d'océan.
const ISLAND_LAND_SHARE := 0.35
const VEIN_RADIUS := 2
const VEIN_TRIES := 30


static func hash_int(seed_value: int, x: int, y: int, salt: int) -> int:
	var h: int = (seed_value ^ (x * 374761393) ^ (y * 668265263) ^ (salt * 1442695041)) & MASK
	h = ((h ^ (h >> 13)) * 1274126177) & MASK
	h = ((h ^ (h >> 16)) * 1540483477) & MASK
	return h ^ (h >> 15)


static func hash01(seed_value: int, x: int, y: int, salt: int) -> float:
	return float(hash_int(seed_value, x, y, salt) & 0xFFFFFF) / 16777216.0


static func _value(seed_value: int, x: float, y: float, wave: float, salt: int) -> float:
	var gx := x / wave
	var gy := y / wave
	var x0 := floori(gx)
	var y0 := floori(gy)
	var fx := smoothstep(0.0, 1.0, gx - x0)
	var fy := smoothstep(0.0, 1.0, gy - y0)
	var top: float = lerp(hash01(seed_value, x0, y0, salt), hash01(seed_value, x0 + 1, y0, salt), fx)
	var bottom: float = lerp(hash01(seed_value, x0, y0 + 1, salt), hash01(seed_value, x0 + 1, y0 + 1, salt), fx)
	return lerp(top, bottom, fy)


static func fbm(seed_value: int, x: float, y: float, waves: Array, salt: int) -> float:
	var total := 0.0
	var amp := 1.0
	var sum := 0.0
	for i in waves.size():
		total += _value(seed_value, x, y, waves[i], salt + i * 101) * amp
		sum += amp
		amp *= 0.5
	return total / sum


static func height(seed_value: int, x: int, y: int) -> float:
	return clamp(0.5 + (fbm(seed_value, x, y, HEIGHT_WAVES, 11) - 0.5) * CONTRAST + SHIFT, 0.0, 1.0)


static func _river(seed_value: int, x: int, y: int) -> float:
	return absf(fbm(seed_value, x, y, RIVER_WAVES, 311) - 0.5)


static func _biome(seed_value: int, x: int, y: int, h: float, river: float) -> String:
	if h < 0.38:
		return "ocean"
	if h < 0.41:
		return "beach"
	if h > 0.78:
		return "mountain"
	if river < RIVER_WIDTH and h < 0.74:
		return "river"
	if h < 0.62 and _value(seed_value, x, y, LAKE_WAVE, 421) > LAKE_LEVEL:
		return "lake"
	var temp := 0.5 + (fbm(seed_value, x, y, TEMP_WAVES, 521) - 0.5) * CLIMATE_CONTRAST
	var moist := 0.5 + (fbm(seed_value, x, y, MOIST_WAVES, 611) - 0.5) * CLIMATE_CONTRAST
	if temp < 0.18 and h < 0.7:
		return "tundra"
	if moist < 0.3 and temp > 0.5 and h < 0.6:
		return "desert"
	if moist > 0.7 and h < 0.48:
		return "swamp"
	if moist > 0.53:
		return "forest"
	return "plain"


static func tile(seed_value: int, x: int, y: int) -> Dictionary:
	var h := height(seed_value, x, y)
	var river := _river(seed_value, x, y)
	var biome := _biome(seed_value, x, y, h, river)
	var fertility: float = Biomes.DATA[biome]["food"]
	if biome != "river" and fertility > 0.1 and river < RIVER_BANKS and h >= 0.41:
		fertility = min(1.0, fertility + 0.3)
	var roll := hash_int(seed_value, x, y, 733)
	var trees := 0
	if biome == "forest":
		trees = 4 + roll % 6
	elif biome == "plain" or biome == "swamp":
		trees = roll % 3
	return {
		"biome": biome, "height": h, "ore": "", "trees": trees,
		"stone": 5 + (roll >> 8) % 8 if biome == "mountain" else 0,
		"food": fertility * Nature.FOOD_CAP, "fertility": fertility,
	}


static func chunk(seed_value: int, cx: int, cy: int) -> Dictionary:
	var tiles: Array = []
	tiles.resize(CHUNK * CHUNK)
	for ly in CHUNK:
		for lx in CHUNK:
			tiles[ly * CHUNK + lx] = tile(seed_value, cx * CHUNK + lx, cy * CHUNK + ly)
	_place_ores(tiles, Rng.new(hash_int(seed_value, cx, cy, 977)))
	return {"tiles": tiles}


static func _place_ores(tiles: Array, rng: Rng) -> void:
	var land := 0
	for t in tiles:
		if not Biomes.is_water(t["biome"]):
			land += 1
	var island: bool = land < tiles.size() * ISLAND_LAND_SHARE
	for key in Biomes.ORES:
		if not rng.chance(ORE_CHANCE[key]) or (key == "diamant" and not island):
			continue
		var biomes: Array = Biomes.ORES[key]["biomes"]
		for tries in VEIN_TRIES:
			var cx := rng.range_int(0, CHUNK - 1)
			var cy := rng.range_int(0, CHUNK - 1)
			var center: Dictionary = tiles[cy * CHUNK + cx]
			if center["ore"] != "" or not biomes.has(center["biome"]):
				continue
			for dy in range(-VEIN_RADIUS, VEIN_RADIUS + 1):
				for dx in range(-VEIN_RADIUS, VEIN_RADIUS + 1):
					var x := cx + dx
					var y := cy + dy
					if x < 0 or y < 0 or x >= CHUNK or y >= CHUNK or absi(dx) + absi(dy) > VEIN_RADIUS or not rng.chance(0.55):
						continue
					var t: Dictionary = tiles[y * CHUNK + x]
					if biomes.has(t["biome"]) and t["ore"] == "":
						t["ore"] = key
						t["ore_left"] = Mining.vein_amount(rng)
			break
