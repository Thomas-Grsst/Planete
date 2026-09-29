class_name Diseases
extends RefCounted

const DATA := {
	"toux_rouge": {"name": "Toux rouge", "label": "la toux rouge", "de": "de la toux rouge", "emoji": "🤧", "contagion": 0.30, "lethal": 0.006, "dmg": 3.0, "duration": [8, 14], "weight": 1.0, "min_pop": 0, "mutates": false},
	"fievre_marais": {"name": "Fièvre des marais", "label": "la fièvre des marais", "de": "de la fièvre des marais", "emoji": "🦟", "contagion": 0.22, "lethal": 0.012, "dmg": 4.0, "duration": [12, 20], "weight": 1.0, "min_pop": 0, "mutates": false},
	"mal_des_ventres": {"name": "Mal des ventres", "label": "le mal des ventres", "de": "du mal des ventres", "emoji": "🤢", "contagion": 0.20, "lethal": 0.005, "dmg": 3.0, "duration": [6, 10], "weight": 1.0, "min_pop": 0, "mutates": false},
	"peste_grise": {"name": "Peste grise", "label": "la peste grise", "de": "de la peste grise", "emoji": "🐀", "contagion": 0.45, "lethal": 0.03, "dmg": 7.0, "duration": [10, 16], "weight": 0.35, "min_pop": 30, "mutates": true},
}
const ORDER := ["toux_rouge", "fievre_marais", "mal_des_ventres", "peste_grise"]


static func is_sick(p: Dictionary) -> bool:
	return not p.get("sick", {}).is_empty()


static func is_immune(p: Dictionary, key: String) -> bool:
	return p.get("immune", []).has(key)


static func infect(state: Dictionary, rng: Rng, p: Dictionary, key: String) -> void:
	var d: Dictionary = DATA[key]
	p["sick"] = {"key": key, "since": state["day"], "duration": rng.range_int(d["duration"][0], d["duration"][1])}
	Journal.remember(state, p, "%s %s tombe malade : %s." % [d["emoji"], p["name"], d["label"]])


static func step_sick(state: Dictionary, rng: Rng, e: Dictionary) -> Dictionary:
	var m: Dictionary = e["mods"]
	var result := {"sick": 0, "deaths": 0, "recovered": 0}
	for p in e["people"].filter(func(q): return is_sick(q)):
		if not p["alive"]:
			continue
		var d: Dictionary = DATA[p["sick"]["key"]]
		var age := People.age_of(state, p)
		var frail := 1.8 if age > 55 or age < 5 else 1.0
		p["health"] -= d["dmg"] * m["care"]
		if p["health"] <= 0 or rng.chance(d["lethal"] * m["care"] * frail):
			var key: String = p["sick"]["key"]
			p["sick"] = {}
			People.kill(state, p, DATA[key]["de"])
			result["deaths"] += 1
			continue
		if state["day"] - p["sick"]["since"] >= p["sick"]["duration"]:
			_recover(state, p, d)
			result["recovered"] += 1
			continue
		result["sick"] += 1
		if not rng.chance(d["contagion"] * m["contagion"] * min(2.0, e["density"])):
			continue
		var q = rng.pick(e["people"])
		if q != null and q["alive"] and not is_sick(q) and q.get("bitten", -1) < 0 and not is_immune(q, p["sick"]["key"]):
			infect(state, rng, q, p["sick"]["key"])
			result["sick"] += 1
	return result


static func _recover(state: Dictionary, p: Dictionary, d: Dictionary) -> void:
	var key: String = p["sick"]["key"]
	p["sick"] = {}
	if not p.has("immune"):
		p["immune"] = []
	if not p["immune"].has(key):
		p["immune"].append(key)
	p["health"] = max(p["health"], 20.0)
	Journal.remember(state, p, "🌿 %s guérit %s." % [p["name"], d["de"]])


static func label_of(state: Dictionary, p: Dictionary) -> String:
	if not is_sick(p):
		return ""
	var d: Dictionary = DATA[p["sick"]["key"]]
	return "%s %s (depuis %d j)" % [d["emoji"], d["name"], state["day"] - p["sick"]["since"]]
