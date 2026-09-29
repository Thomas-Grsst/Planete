class_name Census
extends RefCounted

const HUNGRY_ABOVE := 30.0
const HELPER_AGE := 8


static func build(state: Dictionary) -> Dictionary:
	var census := {}
	for s in state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		census[s["id"]] = {
			"s": s, "people": [], "pop": 0, "adults": 0, "kids": 0, "jobs": {}, "traits": {}, "hungry": 0, "helpers": 0,
			"mods": Techs.mods_of(s),
		}
	for p in state["people"]:
		if not p["alive"] or not census.has(p["home"]):
			continue
		var e: Dictionary = census[p["home"]]
		e["people"].append(p)
		e["pop"] += 1
		if People.is_adult(state, p):
			e["adults"] += 1
			for t in p["traits"]:
				e["traits"][t] = e["traits"].get(t, 0) + 1
		else:
			e["kids"] += 1
			if People.age_of(state, p) >= HELPER_AGE:
				e["helpers"] += 1
		e["jobs"][p["job"]] = e["jobs"].get(p["job"], 0) + 1
		if p["hunger"] > HUNGRY_ABOVE:
			e["hungry"] += 1
	return census
