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
			"s": s, "people": [], "pop": 0, "adults": 0, "kids": 0, "jobs": {}, "traits": {}, "hungry": 0, "helpers": 0, "sick": 0, "bitten": 0, "density": 1.0,
			"mods": Techs.mods_of(s),
		}
		census[s["id"]]["mods"]["happiness"] += Religions.happiness_of(state, s)
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
		if not p.get("sick", {}).is_empty():
			e["sick"] += 1
		if p.get("bitten", -1) >= 0:
			e["bitten"] += 1
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		e["density"] = clamp(e["pop"] / max(1.0, s["houses"] * e["mods"]["capacity"]), 0.5, 3.0)
		Governance.mods(state, s, e)
		_job_mods(e)
	return census


static func _job_mods(e: Dictionary) -> void:
	var m: Dictionary = e["mods"]
	if e["jobs"].get("forgeron", 0) >= 1:
		m["defense"] *= 1.2
		m["hunt"] *= 1.2
		m["build"] *= 1.2
	var healers: int = min(3, e["jobs"].get("guérisseur", 0))
	if healers > 0:
		m["care"] *= 1.0 - 0.1 * healers
		m["contagion"] *= 1.0 - 0.1 * healers
		m["outbreak"] *= 1.0 - 0.08 * healers
		m["heal"] += 0.1 * healers
