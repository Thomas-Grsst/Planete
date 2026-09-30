class_name Festivals
extends RefCounted

# La vie des villages au fil de l'année : fête des moissons, feux du solstice, noces, funérailles et cimetière.

const HARVEST_DAY := 250
const SOLSTICE_DAY := 315
const MIN_POP := 6
const HARVEST_JOY := 8.0
const SOLSTICE_DEVOTION := 5.0
const FAMOUS := 4
const MAX_GRAVES := 12


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var doy: int = state["day"] % 360
	if doy < HARVEST_DAY or doy > SOLSTICE_DAY + 4:
		return
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if e["pop"] < MIN_POP or not _calm(state, s):
			continue
		var offset: int = s["id"] % 5
		if doy == HARVEST_DAY + offset and Techs.has_tech(s, "agriculture") and s["food"] >= Trade.food_cap(e) * 0.4:
			_harvest(state, s, e)
		elif doy == SOLSTICE_DAY + offset and Religions.of(state, s) != null:
			_solstice(state, s, e)


static func _calm(state: Dictionary, s: Dictionary) -> bool:
	return s.get("outbreak", {}).is_empty() and not Sieges.besieged(s) and not Wars.at_war_any(state, s)


static func today(state: Dictionary, s: Dictionary) -> String:
	var f: Dictionary = s.get("fete", {})
	return f.get("kind", "") if f.get("day", -1) == state["day"] else ""


static func _celebrate(state: Dictionary, s: Dictionary, kind: String) -> void:
	s["fete"] = {"kind": kind, "day": state["day"]}


static func _harvest(state: Dictionary, s: Dictionary, e: Dictionary) -> void:
	_celebrate(state, s, "moisson")
	for p in e["people"]:
		p["happiness"] = min(100.0, p["happiness"] + HARVEST_JOY)
	Journal.log_event(state, "fete", "🎉 %s fête la fin des moissons : ce soir, on danse autour du feu." % s["name"], {"x": s["x"], "y": s["y"], "settlement": s["id"]})


static func _solstice(state: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var rel = Religions.of(state, s)
	_celebrate(state, s, "solstice")
	s["devotion"] = min(100.0, s["devotion"] + SOLSTICE_DEVOTION)
	Journal.log_event(state, "fete", "🔥 Pour le solstice d'hiver, les fidèles %s allument de grands feux à %s." % [FaithData.of_name(rel["name"]), s["name"]], {"x": s["x"], "y": s["y"], "settlement": s["id"], "religion": rel["id"]})


# Le soir d'un mariage, le village danse (sauf si une fête plus grande a déjà lieu).
static func wedding(state: Dictionary, p: Dictionary) -> void:
	var s = Settlements.by_id(state, p["home"])
	if s != null and today(state, s) == "":
		_celebrate(state, s, "mariage")


static func cemetery(state: Dictionary, s: Dictionary) -> Variant:
	var known = s.get("cemetery")
	if known is Vector2i:
		return known
	var ring: int = Settlements.clear_radius(s) + 1
	for o in Geography.offsets(ring + 1):
		if max(absi(o.x), absi(o.y)) < ring:
			continue
		var pos := Vector2i(s["x"] + o.x, s["y"] + o.y)
		var t = WorldGen.tile_at(state["world"], pos.x, pos.y)
		if t == null or not Biomes.walkable(t["biome"]) or t["biome"] == "river" or t["ore"] != "" or t.has("field") or t.has("cemetery"):
			continue
		if s.get("mine") is Vector2i and s["mine"] == pos:
			continue
		s["wood"] += t["trees"]
		t["trees"] = 0
		t["cemetery"] = true
		s["cemetery"] = pos
		return pos
	return null


static func funeral(state: Dictionary, p: Dictionary, s) -> void:
	if s == null or s["abandoned"] >= 0 or cemetery(state, s) == null:
		return
	s["burials"] = s.get("burials", 0) + 1
	var fame: int = p.get("fame", 0)
	if fame < FAMOUS:
		return
	var graves: Array = s.get_or_add("graves", [])
	graves.append({"name": p["name"], "day": state["day"], "person": p["id"]})
	if graves.size() > MAX_GRAVES:
		graves.pop_front()
	_celebrate(state, s, "funerailles")
	Journal.log_event(state, "funerailles", "⚱️ Tout %s accompagne %s, %s, à sa dernière demeure." % [s["name"], p["name"], Fame.title(p)], {"x": s["x"], "y": s["y"], "settlement": s["id"], "person": p["id"]})
