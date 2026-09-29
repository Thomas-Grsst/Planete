class_name People
extends RefCounted

const YEAR := 360
const ADULT_AGE := 14
const MIGRANT_MIN_AGE := 16
const BIRTH_CHANCE := 0.004
const BIRTH_SPACING_DAYS := 720
const WORLD_SOFT_CAP := 220
const WORLD_HARD_CAP := 320
const OLD_AGE := 55
const ACCIDENT_CHANCE := 0.00001

static var _index: Dictionary = {}
static var _indexed_state: Dictionary = {}


static func create(state: Dictionary, rng: Rng, age_years: float, home: int, parents: Array = []) -> Dictionary:
	var traits: Array = [rng.pick(Names.TRAITS)]
	var second: String = rng.pick(Names.TRAITS)
	if second != traits[0]:
		traits.append(second)
	var p := {
		"id": _next_id(state), "name": Names.person_name(rng), "sex": "F" if rng.chance(0.5) else "M",
		"birth_day": state["day"] - int(round(age_years * YEAR)), "home": home, "partner": -1,
		"parents": parents, "children": [], "traits": traits, "job": "enfant" if age_years < ADULT_AGE else "cueilleur",
		"health": 100.0, "hunger": 0.0, "happiness": float(rng.range_int(55, 85)), "alive": true, "death_day": -1, "history": [],
	}
	state["people"].append(p)
	_index[p["id"]] = p
	return p


static func _next_id(state: Dictionary) -> int:
	state["next_id"] += 1
	return state["next_id"]


static func by_id(state: Dictionary, id: int):
	if not is_same(_indexed_state, state):
		_reindex(state)
	var p = _index.get(id)
	if p == null and _index.size() != state["people"].size():
		_reindex(state)
		p = _index.get(id)
	return p


static func _reindex(state: Dictionary) -> void:
	_index = {}
	_indexed_state = state
	for p in state["people"]:
		_index[p["id"]] = p


static func age_of(state: Dictionary, p: Dictionary) -> int:
	return (state["day"] - p["birth_day"]) / YEAR


static func is_adult(state: Dictionary, p: Dictionary) -> bool:
	return age_of(state, p) >= ADULT_AGE


static func alive_count(state: Dictionary) -> int:
	var n := 0
	for p in state["people"]:
		if p["alive"]:
			n += 1
	return n


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var population := alive_count(state)
	for p in state["people"].duplicate():
		if not p["alive"]:
			continue
		var entry = census.get(p["home"])
		var age := age_of(state, p)
		if p["hunger"] > 40:
			p["health"] -= (p["hunger"] - 40) * 0.05
		elif p["health"] < 100:
			p["health"] = min(100.0, p["health"] + 0.3 + (entry["mods"]["heal"] if entry else 0.0))
		var mood := -0.4 if p["hunger"] > 30 else 0.15
		p["happiness"] = clamp(p["happiness"] + mood, 0.0, 100.0)
		if age > OLD_AGE and rng.chance((age - OLD_AGE) * 0.00008):
			kill(state, p, "de vieillesse")
		elif p["health"] <= 0:
			kill(state, p, "de faim")
		elif rng.chance(ACCIDENT_CHANCE):
			kill(state, p, "d'un accident")
		elif entry != null:
			_social(state, rng, p, age, entry, population)


static func _social(state: Dictionary, rng: Rng, p: Dictionary, age: int, entry: Dictionary, population: int) -> void:
	if age >= 16 and p["partner"] < 0 and rng.chance(0.02 if p["traits"].has("sociable") else 0.01):
		_find_partner(state, rng, p, entry)
	var rested: bool = state["day"] - p.get("last_birth", -99999) >= BIRTH_SPACING_DAYS
	if rested and p["partner"] >= 0 and p["sex"] == "F" and age >= 17 and age <= 42 and p["children"].size() < 6:
		if rng.chance(_birth_chance(entry, population)):
			_give_birth(state, rng, p)


static func _birth_chance(entry: Dictionary, population: int) -> float:
	if population >= WORLD_HARD_CAP:
		return 0.0
	var c := BIRTH_CHANCE
	if population > WORLD_SOFT_CAP:
		c *= 1.0 - float(population - WORLD_SOFT_CAP) / (WORLD_HARD_CAP - WORLD_SOFT_CAP)
	if entry["pop"] > entry["s"]["houses"] * entry["mods"]["capacity"] + 2:
		c *= 0.35
	if entry["hungry"] > entry["pop"] * 0.2:
		c *= 0.3
	return c


static func _find_partner(state: Dictionary, rng: Rng, p: Dictionary, entry: Dictionary) -> void:
	var options: Array = []
	for q in entry["people"]:
		if q["alive"] and q["id"] != p["id"] and q["partner"] < 0 and q["sex"] != p["sex"] and age_of(state, q) >= 16 and not _siblings(p, q):
			options.append(q)
	if options.is_empty():
		return
	var q: Dictionary = rng.pick(options)
	p["partner"] = q["id"]
	q["partner"] = p["id"]
	p["happiness"] = min(100.0, p["happiness"] + 15)
	q["happiness"] = min(100.0, q["happiness"] + 15)
	Journal.log_event(state, "couple", "💞 %s et %s forment un couple." % [p["name"], q["name"]], {"person": p["id"], "other": q["id"]})
	Journal.remember(state, q, "💞 %s et %s forment un couple." % [q["name"], p["name"]])


static func _siblings(a: Dictionary, b: Dictionary) -> bool:
	return not a["parents"].is_empty() and not b["parents"].is_empty() and (a["parents"][0] == b["parents"][0] or a["parents"][1] == b["parents"][1])


static func _give_birth(state: Dictionary, rng: Rng, mother: Dictionary) -> void:
	var child := create(state, rng, 0, mother["home"], [mother["id"], mother["partner"]])
	mother["children"].append(child["id"])
	mother["last_birth"] = state["day"]
	var father = by_id(state, mother["partner"])
	if father != null:
		father["children"].append(child["id"])
	var word := "une fille" if child["sex"] == "F" else "un garçon"
	Journal.log_event(state, "naissance", "👶 %s donne naissance à %s, %s." % [mother["name"], word, child["name"]], {"person": child["id"], "mother": mother["id"]})


static func kill(state: Dictionary, p: Dictionary, cause: String) -> void:
	var age := age_of(state, p)
	p["alive"] = false
	p["death_day"] = state["day"]
	if p["partner"] >= 0:
		var q = by_id(state, p["partner"])
		if q != null:
			q["partner"] = -1
	var home = Settlements.by_id(state, p["home"])
	var where := " à %s" % home["name"] if home != null else ""
	Journal.log_event(state, "deces", "🕯️ %s meurt %s à %d ans%s." % [p["name"], cause, age, where], {"person": p["id"]})
