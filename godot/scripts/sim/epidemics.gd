class_name Epidemics
extends RefCounted

const BASE_CHANCE := 0.0004
const COOLDOWN_DAYS := 180
const MIN_POP := 8
const SPREAD_CHANCE := 0.004
const SPREAD_RANGE := 10
const DEATH_MILESTONES := [5, 10, 20, 50]
const MUTATION_MIN_DAY := 14400
const MUTATION_REST := 7200
const MUTATION_MIN_DEATHS := 12
const MUTATION_MIN_POP := 40
const MUTATION_CHANCE := 0.05


static func _weight(state: Dictionary, key: String, s: Dictionary, e: Dictionary) -> float:
	var d: Dictionary = Diseases.DATA[key]
	if e["pop"] < d["min_pop"]:
		return 0.0
	var season := Weather.season(state["day"])
	var f := 1.0
	match key:
		"toux_rouge": f = (3.0 if season == 3 or state["weather"] == "snow" else 1.0) * (0.7 if Techs.has_tech(s, "feu") else 1.0)
		"fievre_marais": f = (1.0 + 0.5 * min(4, s["geo"]["swamp"]) if s["geo"]["swamp"] > 0 else 0.3) * (2.0 if season == 1 else 1.0)
		"mal_des_ventres": f = (3.0 if state["weather"] == "drought" else 1.0) * (2.0 if e["hungry"] > e["pop"] / 3 else 1.0)
		"peste_grise": f = e["density"] * e["density"]
	return d["weight"] * f


static func start(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, key: String, source_name: String) -> void:
	var d: Dictionary = Diseases.DATA[key]
	var patients: Array = []
	for draw in 6:
		var p = rng.pick(e["people"])
		if patients.size() > rng.range_int(0, 2) or p == null:
			break
		if p["alive"] and not Diseases.is_sick(p) and p.get("bitten", -1) < 0 and not Diseases.is_immune(p, key):
			Diseases.infect(state, rng, p, key)
			patients.append(p)
	if patients.is_empty():
		return
	s["outbreak"] = {"key": key, "since": state["day"], "deaths": 0, "recovered": 0, "rolled": false}
	var p0: Dictionary = patients[0]
	var text := "%s %s atteint %s par un voyageur %s." % [d["emoji"], FaithData.capitalize(d["label"]), s["name"], Names.of_place(source_name)] if source_name != "" \
		else "%s %s se déclare à %s. %s est %s." % [d["emoji"], FaithData.capitalize(d["label"]), s["name"], p0["name"], "la première touchée" if p0["sex"] == "F" else "le premier touché"]
	Journal.log_event(state, "epidemie", text, {"x": s["x"], "y": s["y"], "person": p0["id"], "settlement": s["id"]})


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if e["pop"] <= 0:
			continue
		if not s.has("outbreak"):
			s["outbreak"] = {}
		if s["outbreak"].is_empty():
			_try_start(state, rng, s, e)
			if e["sick"] > 0:
				var carrier = e["people"].filter(func(p): return Diseases.is_sick(p)).front()
				if carrier != null:
					s["outbreak"] = {"key": carrier["sick"]["key"], "since": state["day"], "deaths": 0, "recovered": 0, "rolled": false}
		if not s["outbreak"].is_empty():
			_progress(state, rng, s, e, census)


static func _try_start(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> void:
	if e["pop"] < MIN_POP or state["day"] - s.get("last_outbreak", -9999) <= COOLDOWN_DAYS:
		return
	if not rng.chance(BASE_CHANCE * sqrt(e["pop"] / 20.0) * e["density"] * e["mods"]["outbreak"]):
		return
	var weights: Array = Diseases.ORDER.map(func(k): return _weight(state, k, s, e))
	var total: float = weights.reduce(func(a, b): return a + b, 0.0)
	if total <= 0.0:
		return
	var r := rng.next() * total
	for i in Diseases.ORDER.size():
		r -= weights[i]
		if r <= 0.0:
			start(state, rng, s, e, Diseases.ORDER[i], "")
			return


static func _progress(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, census: Dictionary) -> void:
	var o: Dictionary = s["outbreak"]
	var d: Dictionary = Diseases.DATA[o["key"]]
	var r := Diseases.step_sick(state, rng, e)
	var before: int = o["deaths"]
	o["deaths"] += r["deaths"]
	o["recovered"] += r["recovered"]
	if DEATH_MILESTONES.any(func(m): return before < m and o["deaths"] >= m):
		Journal.log_event(state, "maladie", "💀 %s a déjà emporté %s %s." % [FaithData.capitalize(d["label"]), Names.plural(o["deaths"], "habitant"), Names.of_place(s["name"])], {"x": s["x"], "y": s["y"]})
	if rng.chance(SPREAD_CHANCE * e["mods"]["spread"]):
		_spread(state, rng, s, o["key"], census)
	if d["mutates"] and not o["rolled"] and o["deaths"] >= MUTATION_MIN_DEATHS and e["pop"] >= MUTATION_MIN_POP and state["day"] >= MUTATION_MIN_DAY \
			and not Techs.has_tech(s, "medecine") and not Zombies.active(state) and state["day"] - state.get("zombies", {}).get("last_end", -99999) > MUTATION_REST:
		o["rolled"] = true
		if rng.chance(MUTATION_CHANCE):
			state["apocalypse_request"] = {"settlement": s["id"], "cause": "mutation", "disease": o["key"]}
	if r["sick"] == 0:
		s["last_outbreak"] = state["day"]
		var days: int = state["day"] - o["since"]
		Journal.log_event(state, "epidemie_fin", "🕯️ %s s'éteint à %s après %s : %s, %s." % [FaithData.capitalize(d["label"]), s["name"], Names.plural(days, "jour"), Names.plural(o["deaths"], "mort"), Names.plural(o["recovered"], "guéri")], {"x": s["x"], "y": s["y"], "highlight": o["deaths"] >= 5})
		s["outbreak"] = {}


static func _spread(state: Dictionary, rng: Rng, from: Dictionary, key: String, census: Dictionary) -> void:
	for id in census:
		var t: Dictionary = census[id]["s"]
		if t["id"] == from["id"] or not t.get("outbreak", {}).is_empty() or absi(from["x"] - t["x"]) + absi(from["y"] - t["y"]) > SPREAD_RANGE:
			continue
		if state["day"] - t.get("last_outbreak", -9999) <= COOLDOWN_DAYS or census[id]["pop"] < MIN_POP:
			continue
		start(state, rng, t, census[id], key, from["name"])
		return
