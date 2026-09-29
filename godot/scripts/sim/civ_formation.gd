class_name CivFormation
extends RefCounted

const MIN_POP := 30
const MIN_LEVEL := 2
const FOUND_CHANCE := 0.01
const JOIN_RANGE := 12
const JOIN_CHANCE := 0.004
const SECESSION_RANGE := 16
const SECESSION_CHANCE := 0.0004
const CONQUERED_UNREST := 3
const CONQUERED_MEMORY := 3600
const CULTURE_BASE := 0.0008


static func _reachable(state: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	return Regions.same_landmass(state["world"], a["x"], a["y"], b["x"], b["y"]) or Techs.has_tech(a, "navigation") or Techs.has_tech(b, "navigation")


static func _can_found(state: Dictionary, s: Dictionary, e: Dictionary) -> bool:
	return e["pop"] >= MIN_POP and Governance.chef_of(state, s) != null and s["level"] >= MIN_LEVEL


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	Civs.ensure(state)
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if e["pop"] <= 0:
			continue
		if not s.has("civ"):
			s["civ"] = -1
		var civ = Civs.by_id(state, s["civ"])
		if civ != null and not civ["alive"]:
			s["civ"] = -1
			civ = null
		if civ == null:
			_unaffiliated(state, rng, s, e)
		else:
			_member(state, rng, s, e, civ)
	for civ in Civs.alive(state):
		_life(state, civ, census)


static func _proclaim(state: Dictionary, s: Dictionary) -> Dictionary:
	var chef = Governance.chef_of(state, s)
	var civ := Civs.create(state, s, chef)
	var who := "Sous la conduite de %s, " % chef["name"] if chef != null else ""
	var name := Civs.title(civ) if who != "" else Civs.title(civ, true)
	Journal.log_event(state, "civilisation", "🏰 %s%s est proclamé%s à %s." % [who, name, "e" if civ["article"] == "la" else "", s["name"]], {"x": s["x"], "y": s["y"], "civ": civ["id"], "settlement": s["id"]})
	return civ


static func _unaffiliated(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> void:
	if _can_found(state, s, e) and rng.chance(FOUND_CHANCE):
		_proclaim(state, s)
		return
	var near = null
	var best := JOIN_RANGE + 1
	for o in state["settlements"]:
		var d: int = absi(o["x"] - s["x"]) + absi(o["y"] - s["y"])
		if o["abandoned"] < 0 and o["id"] != s["id"] and o.get("civ", -1) >= 0 and d < best and _reachable(state, o, s):
			best = d
			near = o
	if near != null and rng.chance(JOIN_CHANCE * (2 if e["pop"] < MIN_POP else 1)):
		var civ: Dictionary = Civs.by_id(state, near["civ"])
		s["civ"] = civ["id"]
		Journal.log_event(state, "ralliement", "🏳️ %s rejoint %s." % [s["name"], Civs.title(civ)], {"x": s["x"], "y": s["y"], "civ": civ["id"], "settlement": s["id"]})


static func _member(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, civ: Dictionary) -> void:
	var capital = Settlements.by_id(state, civ["capital"])
	if capital == null or capital["id"] == s["id"] or not _can_found(state, s, e):
		return
	var far: bool = absi(capital["x"] - s["x"]) + absi(capital["y"] - s["y"]) > SECESSION_RANGE or not _reachable(state, capital, s)
	var conquered: bool = s.get("conquered_day", -1) >= 0 and state["day"] - s["conquered_day"] < CONQUERED_MEMORY
	var chef = Governance.chef_of(state, s)
	var unrest := (1 if far else 0) + (CONQUERED_UNREST if conquered else 0) + (1 if chef != null and chef["traits"].has("agressif") else 0)
	if unrest == 0 or not rng.chance(SECESSION_CHANCE * unrest):
		return
	var fresh := Civs.create(state, s, chef)
	var cause := "%s refuse le joug" % s["name"] if conquered else "%s, trop loin de sa capitale, se détache" % s["name"]
	Journal.log_event(state, "independance", "✊ %s %s et proclame son indépendance : naissance %s." % [cause, Civs.of_title(civ), Civs.of_title(fresh)], {"x": s["x"], "y": s["y"], "civ": fresh["id"], "settlement": s["id"], "highlight": true})


static func _life(state: Dictionary, civ: Dictionary, census: Dictionary) -> void:
	var members := Civs.members(state, civ)
	if members.is_empty():
		civ["alive"] = false
		civ["fall_day"] = state["day"]
		Journal.log_event(state, "chute", "🏚️ %s disparaît de l'histoire, %s après sa fondation." % [Civs.title(civ, true), Names.plural((state["day"] - civ["founded_day"]) / 360, "an")], {"civ": civ["id"], "highlight": true})
		state["wars"] = state["wars"].filter(func(w): return w["a"] != civ["id"] and w["b"] != civ["id"])
		return
	if not members.any(func(s): return s["id"] == civ["capital"]):
		var next: Dictionary = members[0]
		for s in members:
			if census.get(s["id"], {}).get("pop", 0) > census.get(next["id"], {}).get("pop", 0):
				next = s
		civ["capital"] = next["id"]
		Journal.log_event(state, "civilisation", "🏰 %s devient la nouvelle capitale %s." % [next["name"], Civs.of_title(civ)], {"x": next["x"], "y": next["y"], "civ": civ["id"]})
	var pop := 0
	var learned := 1.0
	for s in members:
		pop += census.get(s["id"], {}).get("pop", 0)
		if Techs.has_tech(s, "ecriture"):
			learned = max(learned, 2.0)
		if Techs.has_tech(s, "architecture"):
			learned = max(learned, 3.0)
	civ["culture"] = min(100.0, civ["culture"] + CULTURE_BASE * learned * sqrt(pop) / max(1.0, civ["culture"] / 20.0))
	_state_religion(state, civ)


static func _state_religion(state: Dictionary, civ: Dictionary) -> void:
	var capital = Settlements.by_id(state, civ["capital"])
	var rel = Religions.of(state, capital) if capital != null else null
	var id: int = rel["id"] if rel != null else -1
	if civ.get("religion", -1) == id:
		return
	civ["religion"] = id
	if rel != null:
		Journal.log_event(state, "religion_etat", "👑 %s fait %s sa religion officielle." % [Civs.title(civ, true), FaithData.of_name(rel["name"])], {"x": capital["x"], "y": capital["y"], "civ": civ["id"], "highlight": true})
