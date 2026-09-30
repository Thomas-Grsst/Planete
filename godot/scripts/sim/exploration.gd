class_name Exploration
extends RefCounted

const SETTLER_SIGHT := 10
const GEO_REACH := 12
const MIN_POP := 8
const CHANCE := 0.004
const LAND_REACH := 32
const WHEEL_REACH := 12
const RAFT_REACH := 28
const SHIP_REACH := 60
const PORT_REACH := 10
const LAND_SIGHT := 7
const SEA_SIGHT := 9
const SEA_SHARE := 0.6
const LOST := {"raft": 0.06, "ship": 0.02}
const DIRECTIONS := ["à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest", "au nord", "au nord-est"]


static func reveal(state: Dictionary, rng: Rng, x: int, y: int, radius: int) -> Array:
	var fresh := WorldGen.reveal_area(state["world"], x, y, radius)
	if fresh.is_empty():
		return fresh
	for key in fresh:
		Herds.populate(state, rng, key)
	_refresh_geo(state, fresh)
	return fresh


static func _refresh_geo(state: Dictionary, fresh: Array) -> void:
	for s in state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		for key in fresh:
			var o := WorldGen.origin(key)
			if s["x"] >= o.x - GEO_REACH and s["x"] < o.x + WorldGen.CHUNK + GEO_REACH and s["y"] >= o.y - GEO_REACH and s["y"] < o.y + WorldGen.CHUNK + GEO_REACH:
				s["geo"] = Geography.of(state["world"], s["x"], s["y"])
				break


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		Ports.check(state, s)
		if e["pop"] < MIN_POP:
			continue
		var drive: float = 1.0 + 0.4 * min(3, e["traits"].get("aventurier", 0)) + 0.2 * min(3, e["traits"].get("curieux", 0))
		if e["hungry"] > e["pop"] * 0.2 or e["density"] > 1.2:
			drive *= 1.8
		if rng.chance(CHANCE * drive):
			_expedition(state, rng, e)


static func _reach(s: Dictionary, sea: bool) -> int:
	if not sea:
		return LAND_REACH + (WHEEL_REACH if Techs.has_tech(s, "roue") else 0)
	return (SHIP_REACH if Techs.has_tech(s, "navigation") else RAFT_REACH) + PORT_REACH


static func _expedition(state: Dictionary, rng: Rng, e: Dictionary) -> void:
	var s: Dictionary = e["s"]
	var sea := Ports.has_port(s) and rng.chance(SEA_SHARE)
	var angle := rng.next() * TAU
	var target = _walk(state["world"], s, Vector2(cos(angle), sin(angle)), _reach(s, sea), sea)
	if target == null:
		return
	var explorer = _explorer(state, rng, e)
	if explorer == null:
		return
	var dir: String = DIRECTIONS[int(round(angle / (TAU / 8.0))) % 8]
	var extra := {"x": s["x"], "y": s["y"], "person": explorer["id"], "settlement": s["id"], "to_x": target.x, "to_y": target.y, "boat": sea}
	if sea and rng.chance(LOST["ship" if Techs.has_tech(s, "navigation") else "raft"]):
		extra["lost"] = true
		People.kill(state, explorer, "perdu en mer")
		Journal.log_event(state, "exploration", "🌊 %s a pris la mer %s %s et n'est jamais %s." % [explorer["name"], dir, Names.of_place(s["name"]), "revenue" if explorer["sex"] == "F" else "revenu"], extra)
		return
	var fresh := reveal(state, rng, target.x, target.y, SEA_SIGHT if sea else LAND_SIGHT)
	if fresh.is_empty():
		return
	var found := Discovery.describe(state, s, fresh)
	extra["highlight"] = found["island"]
	Fame.add(explorer, 2 if found["island"] else 1)
	Journal.log_event(state, "exploration", Discovery.story(explorer, s, dir, sea, found), extra)


static func _walk(world: Dictionary, s: Dictionary, dir: Vector2, reach: int, sea: bool) -> Variant:
	for step in range(1, reach + 1):
		var p := Vector2i(roundi(s["x"] + dir.x * step), roundi(s["y"] + dir.y * step))
		var t = WorldGen.tile_at(world, p.x, p.y)
		if t == null:
			return p
		if not sea and not Biomes.walkable(t["biome"]):
			return null
	return null


static func _explorer(state: Dictionary, rng: Rng, e: Dictionary) -> Variant:
	var pool: Array = e["people"].filter(func(p): return p["alive"] and People.age_of(state, p) >= People.MIGRANT_MIN_AGE and p["job"] != "chef")
	if pool.is_empty():
		return null
	var bold: Array = pool.filter(func(p): return p["traits"].has("aventurier") or p["traits"].has("curieux"))
	return rng.pick(bold if not bold.is_empty() else pool)
