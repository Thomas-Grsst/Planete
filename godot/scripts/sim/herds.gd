class_name Herds
extends RefCounted

const SPECIES := {
	"deer": {"name": "Cerfs", "emoji": "🦌", "biomes": ["forest", "plain"], "growth": 0.004, "cap": 40.0, "prey": ""},
	"sheep": {"name": "Moutons", "emoji": "🐑", "biomes": ["plain", "beach"], "growth": 0.005, "cap": 30.0, "prey": ""},
	"wolf": {"name": "Loups", "emoji": "🐺", "biomes": ["forest", "mountain", "tundra"], "growth": 0.002, "cap": 14.0, "prey": "deer"},
}
const HUNT_RANGE := 6
const HUNTABLE_MIN := 8.0
const MOVE_CHANCE := 0.3
const WOLF_FLOOR := 3.0


static func seed_herds(state: Dictionary, rng: Rng) -> void:
	for key in SPECIES:
		var sp: Dictionary = SPECIES[key]
		for n in (3 if key == "wolf" else 6):
			for tries in 60:
				var x := rng.range_int(0, WorldGen.SIZE - 1)
				var y := rng.range_int(0, WorldGen.SIZE - 1)
				var t = WorldGen.tile_at(state["world"], x, y)
				if t != null and sp["biomes"].has(t["biome"]):
					state["next_id"] += 1
					state["herds"].append({"id": state["next_id"], "species": key, "x": x, "y": y, "count": float(rng.range_int(6, 14))})
					break


static func huntable_near(state: Dictionary, s: Dictionary):
	var best = null
	var best_d := HUNT_RANGE + 1
	for h in state["herds"]:
		if h["species"] == "wolf" or h["count"] < HUNTABLE_MIN:
			continue
		var d: int = absi(h["x"] - s["x"]) + absi(h["y"] - s["y"])
		if d < best_d:
			best_d = d
			best = h
	return best


static func step(state: Dictionary, rng: Rng) -> void:
	var world: Dictionary = state["world"]
	for h in state["herds"]:
		var sp: Dictionary = SPECIES[h["species"]]
		if rng.chance(MOVE_CHANCE):
			var nx: int = h["x"] + rng.range_int(-1, 1)
			var ny: int = h["y"] + rng.range_int(-1, 1)
			var t = WorldGen.tile_at(world, nx, ny)
			if t != null and Biomes.walkable(t["biome"]) and (sp["biomes"].has(t["biome"]) or rng.chance(0.2)):
				h["x"] = nx
				h["y"] = ny
		var here = WorldGen.tile_at(world, h["x"], h["y"])
		var suitable: bool = here != null and sp["biomes"].has(here["biome"])
		var growth: float = sp["growth"] * (1.0 if suitable else -0.6) * (1.0 - h["count"] / sp["cap"])
		if sp["prey"] != "":
			growth = _predator_growth(state, h, sp)
		h["count"] = clamp(h["count"] + h["count"] * growth + (0.3 if suitable and rng.chance(0.15) else 0.0), 0.0, sp["cap"])
		if sp["prey"] != "" and h["count"] < WOLF_FLOOR:
			h["count"] = WOLF_FLOOR


static func _predator_growth(state: Dictionary, h: Dictionary, sp: Dictionary) -> float:
	for prey in state["herds"]:
		if prey["species"] == sp["prey"] and absi(prey["x"] - h["x"]) + absi(prey["y"] - h["y"]) <= 8 and prey["count"] > 5:
			prey["count"] -= 0.02 * h["count"]
			return sp["growth"] * (1.0 - h["count"] / sp["cap"])
	return -0.002
