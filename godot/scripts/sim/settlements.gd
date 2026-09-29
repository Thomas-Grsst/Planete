class_name Settlements
extends RefCounted

const LEVELS := [[0, "Camp", "un camp"], [8, "Hameau", "un hameau"], [20, "Village", "un village"], [50, "Bourg", "un bourg"], [120, "Ville", "une ville"], [300, "Grande ville", "une grande ville"]]
const DEMOTE_RATIO := 0.8
const BUILD_COST := 8.0
const BUILD_BASE_SPEED := 0.12
const BUILD_PER_BUILDER := 0.1
const MIGRATION_MIN_POP := 12
const MIGRATION_CROWD := 32
const MIGRATION_CHANCE := 0.015


static func create(state: Dictionary, rng: Rng, x: int, y: int, parent = null) -> Dictionary:
	var taken := {}
	for o in state["settlements"]:
		taken[o["name"]] = true
	state["next_id"] += 1
	var s := {
		"id": state["next_id"], "name": Names.place_name(rng, taken), "x": x, "y": y, "houses": 1, "wood": 5.0, "food": 15.0,
		"founded_day": state["day"], "level": 0, "max_level": 0, "abandoned": -1, "construction": -1.0, "last_gain": 0.0,
		"techs": parent["techs"].duplicate() if parent != null else [], "geo": Geography.of(state["world"], x, y), "parent": parent["id"] if parent != null else -1,
		"faith": parent.get("faith", -1) if parent != null else -1, "devotion": parent.get("devotion", 0.0) * 0.8 if parent != null else 0.0,
		"temple": 0, "prayer": {}, "awe": {}, "converted_day": state["day"],
		"rooted": parent.get("rooted", []).duplicate() if parent != null else [], "keeper_name": {}, "outbreak": {},
		"civ": parent.get("civ", -1) if parent != null else -1, "conquered_day": -1, "chef": -1, "council": [],
	}
	state["settlements"].append(s)
	clear_land(state, s)
	return s


static func clear_radius(s: Dictionary) -> int:
	return 1 if s["houses"] <= 6 else (2 if s["houses"] <= 16 else 3)


static func clear_land(state: Dictionary, s: Dictionary) -> void:
	var r := clear_radius(s)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t = WorldGen.tile_at(state["world"], s["x"] + dx, s["y"] + dy)
			if t != null and t["trees"] > 0:
				s["wood"] += t["trees"]
				t["trees"] = 0


static func by_id(state: Dictionary, id: int):
	for s in state["settlements"]:
		if s["id"] == id:
			return s
	return null


static func level_name(s: Dictionary) -> String:
	return LEVELS[s["level"]][1]


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for s in state["settlements"].duplicate():
		if s["abandoned"] >= 0 or not census.has(s["id"]):
			continue
		var e = census.get(s["id"])
		if e == null or e["pop"] <= 0:
			s["abandoned"] = state["day"]
			Journal.log_event(state, "disparition", "🏚️ %s est abandonné." % s["name"], {"x": s["x"], "y": s["y"]})
			continue
		_build(state, s, e)
		_update_level(state, s, e["pop"])
		var crowded: bool = e["pop"] > MIGRATION_CROWD or e["hungry"] > e["pop"] * 0.2 or e["pop"] > s["houses"] * e["mods"]["capacity"] * 1.3
		if e["pop"] >= MIGRATION_MIN_POP and crowded and rng.chance(MIGRATION_CHANCE):
			Migration.depart(state, rng, s, e)


static func _build(state: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var capacity: int = s["houses"] * e["mods"]["capacity"]
	if s["construction"] < 0:
		if e["pop"] > capacity and s["wood"] >= BUILD_COST:
			s["wood"] -= BUILD_COST
			s["construction"] = 0.0
		return
	s["construction"] += (BUILD_BASE_SPEED + BUILD_PER_BUILDER * e["jobs"].get("bâtisseur", 0)) * e["mods"]["build"]
	if s["construction"] < 1.0:
		return
	s["construction"] = -1.0
	s["houses"] += 1
	clear_land(state, s)
	Journal.log_event(state, "construction", "🏠 Une nouvelle maison est construite à %s (%d maisons)." % [s["name"], s["houses"]], {"x": s["x"], "y": s["y"], "settlement": s["id"]})


static func _next_level(current: int, pop: int) -> int:
	var i := current
	while i + 1 < LEVELS.size() and pop >= LEVELS[i + 1][0]:
		i += 1
	while i > 0 and pop < LEVELS[i][0] * DEMOTE_RATIO:
		i -= 1
	return i


static func _update_level(state: Dictionary, s: Dictionary, pop: int) -> void:
	s["level"] = _next_level(s["level"], pop)
	if s["level"] <= s["max_level"]:
		return
	s["max_level"] = s["level"]
	Journal.log_event(state, "croissance", "📈 %s devient %s !" % [s["name"], LEVELS[s["level"]][2]], {"x": s["x"], "y": s["y"], "settlement": s["id"]})


static func initial_level(pop: int) -> int:
	return _next_level(0, pop)
