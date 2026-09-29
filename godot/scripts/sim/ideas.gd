class_name Ideas
extends RefCounted

const MAX_DAILY_CHANCE := 0.5
const ADULTS_REF := 15.0
const NO_THINKER_FACTOR := 0.4
const SPREAD_RANGE := 12
const SPREAD_CHANCE := 0.002


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var colonies := 0
	for id in census:
		if census[id]["pop"] >= 3:
			colonies += 1
	var share := pow(max(1, colonies), -0.75)
	for id in census:
		var e: Dictionary = census[id]
		if e["pop"] < 3:
			continue
		_think(state, rng, e, share)
		_spread(state, rng, e)


static func _flag(state: Dictionary, e: Dictionary, flag: String) -> bool:
	var s: Dictionary = e["s"]
	var geo: Dictionary = s["geo"]
	if flag.begins_with("tech:"):
		return Techs.has_tech(s, flag.substr(5))
	match flag:
		"dream": return true
		"lightning": return state["weather"] == "storm" and geo["forest"] > 0
		"drought": return state["weather"] == "drought"
		"winter": return Weather.season(state["day"]) == 3
		"stone": return geo["mountain"] > 0
		"water": return geo["water"] > 0
		"river": return geo["river"]
		"forest": return geo["forest"] > 0
		"swamp": return geo["swamp"] > 0
		"fertile": return geo["fertile"] > 3
		"bone": return e["jobs"].get("chasseur", 0) > 0 and Herds.huntable_near(state, s) != null
		"hunger": return e["hungry"] >= max(2, e["pop"] * 0.25)
		"bigpop": return e["pop"] >= 40
	return geo["ores"].has(flag)


static func _people_factor(e: Dictionary) -> float:
	var inventors: int = min(6, e["traits"].get("inventif", 0))
	var curious: int = min(8, e["traits"].get("curieux", 0))
	var f: float = min(2.0, 0.4 + 0.6 * sqrt(e["adults"] / ADULTS_REF))
	f *= 1.0 + 0.08 * inventors + 0.04 * curious
	if inventors == 0 and curious == 0:
		f *= NO_THINKER_FACTOR
	return f


static func _think(state: Dictionary, rng: Rng, e: Dictionary, share: float) -> void:
	var s: Dictionary = e["s"]
	var pf := _people_factor(e)
	for key in Techs.ORDER:
		if not Techs.can_learn(s, key):
			continue
		var idea: Dictionary = IdeasData.DATA[key]
		var best = null
		for trig in idea["triggers"]:
			if _flag(state, e, trig[0]) and (best == null or trig[1] > best[1]):
				best = trig
		if best == null:
			continue
		var need := 1.0
		for flag in idea["needs"]:
			if _flag(state, e, flag):
				need *= idea["needs"][flag]
		if not rng.chance(min(MAX_DAILY_CHANCE, best[1] * need * pf * share / idea["mean"])):
			continue
		var who = _thinker(state, rng, e)
		if who != null:
			discover(state, s, key, who, _tell(best[2], who, s))
		return


static func _thinker(state: Dictionary, rng: Rng, e: Dictionary):
	var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p))
	if adults.is_empty():
		return null
	var weights: Array = adults.map(func(p): return 1.0 + (3.0 if p["traits"].has("inventif") else 0.0) + (2.0 if p["traits"].has("curieux") else 0.0))
	var r: float = rng.next() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in adults.size():
		r -= weights[i]
		if r <= 0:
			return adults[i]
	return adults[-1]


static func _tell(story: String, p: Dictionary, s: Dictionary) -> String:
	return story.replace("{name}", p["name"]).replace("{place}", s["name"]).replace("{Il}", "Elle" if p["sex"] == "F" else "Il")


static func discover(state: Dictionary, s: Dictionary, key: String, who, story: String) -> void:
	s["techs"].append(key)
	var first: bool = not state["discoveries"].has(key)
	if first:
		state["discoveries"][key] = {"day": state["day"], "person": who["id"] if who != null else -1, "name": who["name"] if who != null else "", "place": s["name"]}
	var extra := {"x": s["x"], "y": s["y"], "settlement": s["id"], "tech": key, "highlight": first}
	if who != null:
		extra["person"] = who["id"]
	Journal.log_event(state, "decouverte" if first else "diffusion", story, extra)


static func _spread(state: Dictionary, rng: Rng, e: Dictionary) -> void:
	var s: Dictionary = e["s"]
	if not rng.chance(SPREAD_CHANCE * e["mods"]["spread"]):
		return
	for o in state["settlements"]:
		if o["abandoned"] >= 0 or is_same(o, s) or absi(o["x"] - s["x"]) + absi(o["y"] - s["y"]) > SPREAD_RANGE:
			continue
		for key in o["techs"]:
			if Techs.can_learn(s, key):
				discover(state, s, key, null, "🧳 Des voyageurs %s apportent %s à %s." % [Names.of_place(o["name"]), Techs.DATA[key]["the"], s["name"]])
				return
