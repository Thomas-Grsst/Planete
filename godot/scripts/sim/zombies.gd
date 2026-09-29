class_name Zombies
extends RefCounted

const TIMEOUT_DAYS := 400
const INCUBATION_DAYS := 3
const BITE_DAMAGE := 20.0
const TURN_CHANCE := 0.25
const CURE_CHANCE := 0.3
const POWER_HORDE_MIN := 10
const POWER_HORDE_SHARE := 0.35
const MUTATION_HORDE_BASE := 6
const COOLDOWN := 1440


static func ensure(state: Dictionary) -> Dictionary:
	if not state.has("zombies"):
		state["zombies"] = {"active": false, "start": -1, "hordes": [], "dead": 0, "fallen": [], "fled": [], "last_end": -99999, "count": 0, "timed_out": false, "power_day": -99999}
	return state["zombies"]


static func active(state: Dictionary) -> bool:
	return state.get("zombies", {}).get("active", false)


static func cooldown_left(state: Dictionary) -> int:
	return max(0, COOLDOWN - (state["day"] - ensure(state)["power_day"]))


static func start(state: Dictionary, rng: Rng, s: Dictionary, cause: String, disease: String = "") -> bool:
	var z := ensure(state)
	if z["active"]:
		return false
	var residents: Array = state["people"].filter(func(p): return p["alive"] and p["home"] == s["id"])
	if residents.is_empty():
		return false
	var p0: Dictionary = rng.pick(residents)
	var deaths: int = s.get("outbreak", {}).get("deaths", 0)
	var size: int = min(Hordes.CAP, MUTATION_HORDE_BASE + deaths) if cause == "mutation" else max(POWER_HORDE_MIN, int(round(POWER_HORDE_SHARE * residents.size())))
	z.merge({"active": true, "start": state["day"], "hordes": [], "dead": 1, "fallen": [], "fled": [], "timed_out": false}, true)
	People.kill(state, p0, "et se relève d'entre les morts")
	var spot := Hordes.spawn_spot(state, rng, s)
	Hordes.spawn(state, spot.x, spot.y, size)
	var text := "🧟 Un frisson parcourt %s : %s se relève d'entre les morts. L'apocalypse zombie commence." % [s["name"], p0["name"]]
	if cause == "mutation" and disease != "":
		text = "🧟 À %s, les morts %s se relèvent. L'apocalypse zombie commence." % [s["name"], Diseases.DATA[disease]["de"]]
	Journal.log_event(state, "apocalypse", text, {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})
	return true


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var z := ensure(state)
	var req: Dictionary = state.get("apocalypse_request", {})
	if not req.is_empty():
		state["apocalypse_request"] = {}
		var s = Settlements.by_id(state, req["settlement"])
		if s != null:
			start(state, rng, s, req["cause"], req.get("disease", ""))
	if not z["active"]:
		return
	_step_bitten(state, rng, census, z)
	for h in z["hordes"].duplicate():
		var target = Hordes.target(state, census, h)
		Hordes.move(state, rng, h, target)
		Hordes.rot(state, h)
		if target != null and absi(h["x"] - target["x"]) + absi(h["y"] - target["y"]) <= 1:
			Hordes.attack(state, rng, h, target, census[target["id"]], census)
	Hordes.merge(state)
	_mark_fallen(state, census, z)
	if state["day"] - z["start"] >= TIMEOUT_DAYS and not z["hordes"].is_empty():
		z["hordes"] = []
		if not z["timed_out"]:
			Journal.log_event(state, "zombie", "🧟 Les derniers zombies s'effondrent, rongés par le temps.")
		z["timed_out"] = true
	if z["hordes"].is_empty() and not state["people"].any(func(p): return p["alive"] and p.get("bitten", -1) >= 0):
		_end(state, z)


static func _step_bitten(state: Dictionary, rng: Rng, census: Dictionary, z: Dictionary) -> void:
	for p in state["people"]:
		if not p["alive"] or p.get("bitten", -1) < 0:
			continue
		var e = census.get(p["home"])
		var cared: bool = e != null and Techs.has_tech(e["s"], "medecine") and e["jobs"].get("guérisseur", 0) > 0
		if state["day"] - p["bitten"] >= INCUBATION_DAYS and cared and rng.chance(CURE_CHANCE):
			p["bitten"] = -1
			Journal.remember(state, p, "🌿 %s survit à sa morsure." % p["name"])
			continue
		p["health"] -= BITE_DAMAGE
		if p["health"] <= 0 or rng.chance(TURN_CHANCE):
			People.kill(state, p, "des suites d'une morsure")
			z["dead"] += 1
			var home = Settlements.by_id(state, p["home"])
			if home != null and not z["timed_out"]:
				Hordes.turn(state, home["x"], home["y"])


static func _mark_fallen(state: Dictionary, census: Dictionary, z: Dictionary) -> void:
	for s in state["settlements"]:
		if s["abandoned"] >= 0 or s.get("fallen", -1) >= 0 or not census.has(s["id"]):
			continue
		if census[s["id"]]["pop"] == 0 and z["hordes"].any(func(h): return absi(h["x"] - s["x"]) + absi(h["y"] - s["y"]) <= 2):
			s["fallen"] = state["day"]
			z["fallen"].append(s["name"])
			Journal.log_event(state, "zombie", "🏚️ %s est tombé. Il n'y a plus personne." % s["name"], {"x": s["x"], "y": s["y"], "highlight": true})


static func _end(state: Dictionary, z: Dictionary) -> void:
	z["active"] = false
	z["last_end"] = state["day"]
	z["count"] += 1
	var survivors := People.alive_count(state)
	var lost := ", %s perdu%s" % [", ".join(z["fallen"]), "s" if z["fallen"].size() > 1 else ""] if not z["fallen"].is_empty() else ""
	Journal.log_event(state, "apocalypse_fin", "🕊️ L'apocalypse zombie prend fin après %s : %s, %s%s." % [Names.plural(state["day"] - z["start"], "jour"), Names.plural(survivors, "survivant"), Names.plural(z["dead"], "mort"), lost], {"highlight": true})
