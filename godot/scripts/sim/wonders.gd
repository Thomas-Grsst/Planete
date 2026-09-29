class_name Wonders
extends RefCounted

const ALIEN_CHANCE := 0.000004
const ARCHAEOLOGY_CHANCE := 0.002
const RUIN_MIN_AGE := 18000
const MUTANT_CHANCE := 0.00002
const REBEL_CHANCE := 0.00003


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if Techs.has_tech(s, "ecriture") and rng.chance(ARCHAEOLOGY_CHANCE):
			_dig(state, rng, s)
		if Techs.has_tech(s, "electricite") and Techs.has_tech(s, "machines") and rng.chance(REBEL_CHANCE):
			_rebellion(state, rng, s)
		if Techs.has_tech(s, "electricite") and rng.chance(ALIEN_CHANCE):
			_aliens(state, rng, s)
	if rng.chance(MUTANT_CHANCE):
		_mutants(state, rng)


static func _dig(state: Dictionary, rng: Rng, s: Dictionary) -> void:
	for ruin in state["settlements"]:
		if ruin["abandoned"] < 0 or ruin.get("dug", false) or state["day"] - ruin["abandoned"] < RUIN_MIN_AGE:
			continue
		if absi(ruin["x"] - s["x"]) + absi(ruin["y"] - s["y"]) > 10:
			continue
		ruin["dug"] = true
		var lost: Array = ruin["techs"].filter(func(k): return Techs.can_learn(s, k))
		var years: int = (state["day"] - ruin["founded_day"]) / 360
		var gift := ""
		if not lost.is_empty():
			var key: String = rng.pick(lost)
			s["techs"].append(key)
			Lore.learned(s, key, null)
			gift = " Dans les ruines, on retrouve le secret %s." % Techs.DATA[key]["de"]
		Journal.log_event(state, "archeologie", "🏺 Les savants %s fouillent les ruines de %s, cité oubliée fondée il y a %s.%s" % [Names.of_place(s["name"]), ruin["name"], Names.plural(years, "an"), gift], {"x": ruin["x"], "y": ruin["y"], "settlement": s["id"], "highlight": true})
		return


static func _rebellion(state: Dictionary, rng: Rng, s: Dictionary) -> void:
	if state.get("raiders", []).any(func(b): return b["kind"] == "machine"):
		return
	var size := rng.range_int(8, 16)
	Raiders.spawn(state, "machine", s["x"] + 2, s["y"] + 1, size, s["id"])
	Journal.log_event(state, "raid", "🤖 À %s, les machines refusent d'obéir et se retournent contre leurs créateurs !" % s["name"], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})


static func _aliens(state: Dictionary, rng: Rng, s: Dictionary) -> void:
	if state.get("aliens_day", -1) >= 0:
		return
	state["aliens_day"] = state["day"]
	var pool: Array = Techs.ORDER.filter(func(k): return Techs.can_learn(s, k))
	var gift := ""
	if not pool.is_empty():
		var key: String = pool[0]
		s["techs"].append(key)
		Lore.learned(s, key, null)
		gift = " Avant de repartir, les visiteurs laissent le secret %s." % Techs.DATA[key]["de"]
	Journal.log_event(state, "contact", "🛸 Une lumière inconnue descend du ciel au-dessus de %s. Pour la première fois, des êtres venus d'ailleurs saluent les habitants.%s" % [s["name"], gift], {"x": s["x"], "y": s["y"], "settlement": s["id"], "aliens": true, "highlight": true})


static func _mutants(state: Dictionary, rng: Rng) -> void:
	var wolves: Array = state["herds"].filter(func(h): return h["species"] == "wolf" and not h.get("mutant", false))
	if wolves.is_empty():
		return
	var h: Dictionary = rng.pick(wolves)
	h["mutant"] = true
	h["count"] = max(h["count"], 6.0)
	Journal.log_event(state, "mutant", "🐺 Des loups géants aux yeux luisants rôdent désormais dans la région. Nul ne sait d'où ils viennent.", {"x": h["x"], "y": h["y"], "highlight": true})
