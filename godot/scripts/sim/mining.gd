class_name Mining
extends RefCounted

const METAL_ORES := ["cuivre", "etain", "fer", "charbon"]
const MINE_RADIUS := 6
const DIG_PER_SMITH := 0.25
const USE_PER_SMITH := 0.12
const METAL_CAP := 40.0
const VEIN_MIN := 200
const VEIN_MAX := 500
const GEO_REFRESH_RADIUS := 8


static func vein_amount(rng: Rng) -> float:
	return float(rng.range_int(VEIN_MIN, VEIN_MAX))


static func ore_left(t: Dictionary) -> float:
	return t.get("ore_left", float(VEIN_MIN + VEIN_MAX) * 0.5)


static func has_metal(s: Dictionary) -> bool:
	return s.get("metal", 0.0) > 0.5


static func has_supply(s: Dictionary) -> bool:
	return has_metal(s) or s["geo"]["ores"].any(func(o): return METAL_ORES.has(o))


static func step(state: Dictionary, s: Dictionary, smiths: int) -> void:
	if smiths <= 0:
		return
	var pos = _mine(state, s)
	if pos != null:
		var t: Dictionary = WorldGen.tile_at(state["world"], pos.x, pos.y)
		var dig: float = min(DIG_PER_SMITH * smiths, ore_left(t))
		t["ore_left"] = ore_left(t) - dig
		s["metal"] = min(METAL_CAP, s.get("metal", 0.0) + dig)
		if t["ore_left"] <= 0.0:
			_exhaust(state, s, pos, t)
	s["metal"] = max(0.0, s.get("metal", 0.0) - USE_PER_SMITH * smiths)


static func _mine(state: Dictionary, s: Dictionary) -> Variant:
	var known = s.get("mine")
	if known is Vector2i:
		var t = WorldGen.tile_at(state["world"], known.x, known.y)
		if t != null and METAL_ORES.has(t["ore"]):
			return known
	s.erase("mine")
	for o in Geography.offsets(MINE_RADIUS):
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		if t != null and METAL_ORES.has(t["ore"]):
			s["mine"] = Vector2i(s["x"] + o.x, s["y"] + o.y)
			return s["mine"]
	return null


static func _exhaust(state: Dictionary, s: Dictionary, pos: Vector2i, t: Dictionary) -> void:
	var ore: String = t["ore"]
	t["ore"] = ""
	t.erase("ore_left")
	s.erase("mine")
	for o in state["settlements"]:
		if o["abandoned"] < 0 and absi(o["x"] - pos.x) + absi(o["y"] - pos.y) <= GEO_REFRESH_RADIUS:
			o["geo"] = Geography.of(state["world"], o["x"], o["y"])
	Journal.log_event(state, "filon", "⛏️ Le filon %s près %s est épuisé. Les forgerons devront chercher le métal plus loin." % [Discovery._ore(ore).replace("le ", "de ").replace("l'", "d'"), Names.of_place(s["name"])], {"x": pos.x, "y": pos.y, "settlement": s["id"], "highlight": true})
