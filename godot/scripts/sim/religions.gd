class_name Religions
extends RefCounted

const LEGEND_CAP := 60
const RELIGION_LEGEND_CAP := 20
const FOUNDING_DEVOTION := 60.0


static func ensure(state: Dictionary) -> void:
	if not state.has("religions"):
		state["religions"] = []
	if not state.has("legends"):
		state["legends"] = []
	for s in state["settlements"]:
		if not s.has("faith"):
			s.merge({"faith": -1, "devotion": 0.0, "temple": 0, "prayer": {}, "awe": {}, "converted_day": -99999})


static func by_id(state: Dictionary, id: int) -> Variant:
	if id < 0:
		return null
	for r in state.get("religions", []):
		if r["id"] == id:
			return r
	return null


static func of(state: Dictionary, s: Dictionary) -> Variant:
	var rel = by_id(state, s.get("faith", -1))
	return rel if rel != null and rel["alive"] else null


static func alive(state: Dictionary) -> Array:
	return state.get("religions", []).filter(func(r): return r["alive"])


static func is_player(rel) -> bool:
	return rel != null and FaithData.SOURCES[rel["source"]]["player"]


static func members(state: Dictionary, rel: Dictionary) -> Array:
	return state["settlements"].filter(func(s): return s["abandoned"] < 0 and s.get("faith", -1) == rel["id"])


static func population(state: Dictionary, rel: Dictionary) -> int:
	var ids := {}
	for s in members(state, rel):
		ids[s["id"]] = true
	var n := 0
	for p in state["people"]:
		if p["alive"] and ids.has(p["home"]):
			n += 1
	return n


static func legend_by_id(state: Dictionary, id: int) -> Variant:
	for l in state.get("legends", []):
		if l["id"] == id:
			return l
	return null


static func create(state: Dictionary, rng: Rng, s: Dictionary, prophet: Dictionary, source: String, parent = null) -> Dictionary:
	var def: Dictionary = FaithData.SOURCES[source]
	state["next_id"] += 1
	var rel := {
		"id": state["next_id"], "name": _pick_name(state, rng, source, s, parent), "source": source, "emoji": def["emoji"],
		"deity": parent["deity"] if parent != null else def["deity"],
		"color": FaithData.SCHISM_COLORS[state["religions"].size() % FaithData.SCHISM_COLORS.size()] if parent != null else def["color"],
		"holy": s["id"], "holy_name": s["name"], "founder": prophet["id"], "founder_name": prophet["name"], "founded_day": state["day"],
		"parent": parent["id"] if parent != null else -1, "alive": true, "fall_day": -1, "prophet_gone": -1,
		"legends": parent["legends"].duplicate() if parent != null else [], "origin_legend": -1,
	}
	if parent == null and def["player"] and not s["awe"].is_empty():
		rel["legends"].append(s["awe"]["legend"])
		rel["origin_legend"] = s["awe"]["legend"]
	state["religions"].append(rel)
	adopt(state, s, rel, FOUNDING_DEVOTION)
	prophet["prophet_of"] = rel["id"]
	s["awe"] = {}
	return rel


static func _pick_name(state: Dictionary, rng: Rng, source: String, s: Dictionary, parent) -> String:
	if parent != null:
		return "%s %s" % [rng.pick(FaithData.SCHISM_NAMES), Names.of_place(s["name"])]
	var used := {}
	for r in state["religions"]:
		used[r["name"]] = true
	var free: Array = FaithData.SOURCES[source]["names"].filter(func(n): return not used.has(n))
	return rng.pick(free) if not free.is_empty() else "%s %s" % [FaithData.SOURCES[source]["names"][0], Names.of_place(s["name"])]


static func adopt(state: Dictionary, s: Dictionary, rel: Dictionary, devotion: float) -> void:
	s["faith"] = rel["id"]
	s["devotion"] = devotion
	s["converted_day"] = state["day"]


static func leave(s: Dictionary) -> void:
	s["faith"] = -1
	s["devotion"] = 0.0


static func remember_legend(state: Dictionary, legend: Dictionary) -> void:
	state["legends"].append(legend)
	if state["legends"].size() > LEGEND_CAP:
		state["legends"].pop_front()
	for rel in alive(state):
		if is_player(rel):
			rel["legends"].append(legend["id"])
			if rel["legends"].size() > RELIGION_LEGEND_CAP:
				rel["legends"].pop_front()


static func happiness_of(state: Dictionary, s: Dictionary) -> float:
	return 0.03 * clamp(s.get("devotion", 0.0), 0.0, 100.0) / 100.0 if of(state, s) != null else 0.0
