class_name Harvest
extends RefCounted

const FISH_PER_FISHER := 1.6
const FISH_TAKE_SHARE := 0.3
const FISH_BASE_RADIUS := 3
const OVERFISHED := 0.35
const RECOVERED := 0.6
const WARN_EVERY := 1800
const FARM_PER_FARMER := 3.2
const FIELD_RADIUS := 3
const FIELD_MIN_FERTILITY := 0.35
const FIELD_REFRESH := 60
const FARMERS_PER_FIELD := 0.6
const SOIL_WEAR := 0.003
const SOIL_REST := 0.004
const SOIL_MIN := 0.45
const SOIL_WARN := 0.65
const NO_FIELDS := ["river", "mountain", "beach", "desert", "lava", "rock"]


static func fish_radius(s: Dictionary) -> int:
	var r := FISH_BASE_RADIUS
	if Techs.has_tech(s, "radeau"):
		r += 1
	if Techs.has_tech(s, "navigation"):
		r += 3
	if s.get("port", {}).size() > 0:
		r += 2
	return r


static func fish(state: Dictionary, s: Dictionary, fishers: int, mod: float) -> float:
	if fishers <= 0:
		return 0.0
	var world: Dictionary = state["world"]
	var wanted: float = fishers * FISH_PER_FISHER * mod
	var got := 0.0
	for pos in _waters(state, s):
		if got >= wanted:
			break
		var t = WorldGen.tile_at(world, pos.x, pos.y)
		if t == null or Nature.fish_cap(t) <= 0.0:
			continue
		got += Nature.take_fish(world, pos.x, pos.y, t, min(Nature.fish_of(t) * FISH_TAKE_SHARE, wanted - got))
	s["fish_rate"] = lerp(float(s.get("fish_rate", 1.0)), got / wanted, 0.05)
	if s["fish_rate"] > RECOVERED:
		s.erase("fish_low")
	if s["fish_rate"] < OVERFISHED and not s.has("fish_low") and state["day"] - s.get("fish_warned", -99999) > WARN_EVERY:
		s["fish_low"] = true
		s["fish_warned"] = state["day"]
		Journal.log_event(state, "surpeche", "🐟 Les filets %s reviennent presque vides : les poissons se font rares autour du village." % Names.of_place(s["name"]), {"x": s["x"], "y": s["y"], "settlement": s["id"]})
	return got


static func _waters(state: Dictionary, s: Dictionary) -> Array:
	var r := fish_radius(s)
	var cached: Dictionary = s.get("waters", {})
	if not cached.is_empty() and cached["r"] == r and state["day"] - cached["day"] < FIELD_REFRESH:
		return cached["tiles"]
	var tiles: Array = []
	for o in Geography.offsets(r):
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		if t != null and Nature.fish_cap(t) > 0.0:
			tiles.append(Vector2i(s["x"] + o.x, s["y"] + o.y))
	s["waters"] = {"r": r, "day": state["day"], "tiles": tiles}
	return tiles


static func _field_radius(s: Dictionary) -> int:
	return FIELD_RADIUS + (1 if s["level"] >= 3 else 0) + (1 if s["level"] >= 4 else 0)


# Une case peut devenir un champ : hors du cœur du village (les maisons), ni gisement, ni mine, ni port.
static func can_farm(s: Dictionary, pos: Vector2i, t) -> bool:
	if t == null or not Biomes.walkable(t["biome"]) or NO_FIELDS.has(t["biome"]) or t["fertility"] < FIELD_MIN_FERTILITY or t["ore"] != "" or t.has("cemetery"):
		return false
	if max(absi(pos.x - s["x"]), absi(pos.y - s["y"])) <= Settlements.clear_radius(s):
		return false
	if s.get("mine") is Vector2i and s["mine"] == pos:
		return false
	return not (Ports.has_port(s) and Ports.tile(s) == pos)


# Les champs réellement tracés autour du village, les plus proches d'abord (le même choix pour la vue et la simulation).
static func field_tiles(state: Dictionary, s: Dictionary, limit: int) -> Array:
	var out: Array = []
	for o in Geography.offsets(_field_radius(s)):
		if out.size() >= limit:
			break
		var pos := Vector2i(s["x"] + o.x, s["y"] + o.y)
		if can_farm(s, pos, WorldGen.tile_at(state["world"], pos.x, pos.y)):
			out.append(pos)
	return out


static func shown_fields(s: Dictionary) -> int:
	return clampi(2 + s["houses"] / 2, 2, 9)


static func fields(state: Dictionary, s: Dictionary, store: bool = true) -> Dictionary:
	var cached: Dictionary = s.get("fields", {})
	if not cached.is_empty() and state["day"] - cached["day"] < FIELD_REFRESH and cached["houses"] == s["houses"]:
		return cached
	var count := 0
	var fert := 0.0
	for o in Geography.offsets(_field_radius(s)):
		var pos := Vector2i(s["x"] + o.x, s["y"] + o.y)
		var t = WorldGen.tile_at(state["world"], pos.x, pos.y)
		if not can_farm(s, pos, t):
			continue
		count += 1
		fert += t["fertility"]
	cached = {"count": count, "fert": fert / max(1, count), "day": state["day"], "houses": s["houses"]}
	if store:
		s["fields"] = cached
		if Techs.has_tech(s, "agriculture"):
			_plough(state, s)
	return cached


# On défriche les champs tracés : leurs arbres donnent du bois et ne repoussent plus.
static func _plough(state: Dictionary, s: Dictionary) -> void:
	for pos in field_tiles(state, s, shown_fields(s)):
		var t: Dictionary = WorldGen.tile_at(state["world"], pos.x, pos.y)
		if t["trees"] > 0:
			s["wood"] += t["trees"]
			t["trees"] = 0
		t["field"] = s["id"]


static func farm(state: Dictionary, s: Dictionary, farmers: int, mod: float, weather: float) -> float:
	if farmers <= 0 or mod <= 0.0:
		return 0.0
	var f := fields(state, s)
	var capacity: float = f["count"] * FARMERS_PER_FIELD
	var worked: float = min(float(farmers), capacity)
	var intensity: float = worked / max(1.0, capacity)
	var soil: float = s.get("soil", 1.0)
	soil = clamp(soil + SOIL_REST * (1.0 - soil) - SOIL_WEAR * max(0.0, intensity - 0.5), SOIL_MIN, 1.0)
	if soil < SOIL_WARN and s.get("soil", 1.0) >= SOIL_WARN:
		Journal.log_event(state, "sol_epuise", "🌾 À force d'être cultivée, la terre autour de %s s'épuise : les récoltes baissent." % s["name"], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
	s["soil"] = soil
	return worked * FARM_PER_FARMER * mod * weather * (0.4 + 0.75 * f["fert"]) * soil
