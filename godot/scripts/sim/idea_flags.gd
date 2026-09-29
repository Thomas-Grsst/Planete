class_name IdeaFlags
extends RefCounted

const TRADE_RANGE := 14
const LOST_LORE_DAYS := 720
const STORM_DAMAGE_DAYS := 360
const WOLF_REACH := 4


static func check(state: Dictionary, e: Dictionary, flag: String) -> bool:
	if flag.contains("+"):
		for part in flag.split("+"):
			if not check(state, e, part):
				return false
		return true
	var s: Dictionary = e["s"]
	var geo: Dictionary = s["geo"]
	if flag.begins_with("tech:"):
		return Techs.has_tech(s, flag.substr(5))
	if flag.begins_with("trade:"):
		return _traded(state, s, flag.substr(6))
	match flag:
		"dream": return true
		"lightning": return state["weather"] == "storm" and geo["forest"] > 0
		"storm": return state["weather"] == "storm"
		"drought": return state["weather"] == "drought"
		"winter": return Weather.season(state["day"]) == 3
		"stone": return geo["mountain"] > 0
		"water": return geo["water"] > 0
		"river": return geo["river"]
		"coast": return geo["coast"]
		"sea": return geo.get("sea", false)
		"island": return geo.get("island", false)
		"forest": return geo["forest"] > 0
		"swamp": return geo["swamp"] > 0
		"fertile": return geo["fertile"] > 3
		"bone": return e["jobs"].get("chasseur", 0) > 0 and Herds.huntable_near(state, s) != null
		"hunger": return e["hungry"] >= max(2, e["pop"] * 0.25)
		"bigpop": return e["pop"] >= 40
		"pop30": return e["pop"] >= 30
		"crowded": return e["pop"] > s["houses"] * e["mods"]["capacity"]
		"sick": return not s.get("outbreak", {}).is_empty()
		"wolves": return _wolves_near(state, s)
		"zombies": return state.get("zombies", {}).get("active", false)
		"lostLore": return state["day"] - s.get("lost_lore_day", -99999) <= LOST_LORE_DAYS
		"stormDamage": return state["day"] - s.get("storm_damage_day", -99999) <= STORM_DAMAGE_DAYS
		"council": return s.get("council", []).size() >= 3
		"chef": return s.get("chef", -1) >= 0
	return geo["ores"].has(flag)


static func _traded(state: Dictionary, s: Dictionary, ore: String) -> bool:
	for o in state["settlements"]:
		if o["abandoned"] < 0 and o["id"] != s["id"] and absi(o["x"] - s["x"]) + absi(o["y"] - s["y"]) <= TRADE_RANGE and o["geo"]["ores"].has(ore):
			return true
	return false


static func _wolves_near(state: Dictionary, s: Dictionary) -> bool:
	for h in state["herds"]:
		if h["species"] == "wolf" and h["count"] >= 1 and absi(h["x"] - s["x"]) + absi(h["y"] - s["y"]) <= WOLF_REACH:
			return true
	return false
