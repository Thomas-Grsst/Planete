class_name Wars
extends RefCounted

const BATTLE_CHANCE := 0.02
const FRONT_RANGE := 25
const HOME_ADVANTAGE := 1.2
const MAX_LOSER_DEATHS := 6
const LOSER_SHARE := 0.2
const CONQUEST_RATIO := 1.5
const CONQUEST_CHANCE := 0.35
const SIEGE_CONQUEST_CHANCE := 0.6
const HOLD_DAYS := 720


static func at_war(state: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var ca = Civs.of(state, a)
	var cb = Civs.of(state, b)
	return ca != null and cb != null and ca["id"] != cb["id"] and Civs.war_between(state, ca, cb) != null


static func at_war_any(state: Dictionary, s: Dictionary) -> bool:
	var c = Civs.of(state, s)
	return c != null and state.get("wars", []).any(func(w): return w["a"] == c["id"] or w["b"] == c["id"])


static func _front(state: Dictionary, attacker: Dictionary, defender: Dictionary) -> Variant:
	var best = null
	for s in Civs.members(state, attacker):
		for o in Civs.members(state, defender):
			var d: int = absi(s["x"] - o["x"]) + absi(s["y"] - o["y"])
			var land := Regions.same_landmass(state["world"], s["x"], s["y"], o["x"], o["y"])
			var cost: int = d if land else d + Naval.SEA_PENALTY
			if best != null and cost >= best["cost"]:
				continue
			if (land and d <= FRONT_RANGE) or (not land and Naval.can_land(s, d)):
				best = {"from": s, "to": o, "d": d, "cost": cost, "sea": not land}
	return best


static func _power(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, home: bool) -> float:
	var chef = Governance.chef_of(state, s)
	var fierce := 1.2 if chef != null and chef["traits"].has("agressif") else 1.0
	var walls: float = Sieges.wall_bonus(s) if home else 1.0
	return max(0.5, Threats.defense(state, e)) * fierce * walls * (HOME_ADVANTAGE if home else 1.0) * (0.7 + rng.next() * 0.6)


static func _fighters(state: Dictionary, e: Dictionary) -> Array:
	var adults: Array = e["people"].filter(func(p): return p["alive"] and People.is_adult(state, p))
	var rank := func(p): return (3 if p["job"] == "gardien" else 0) + (2 if p["traits"].has("courageux") else 0) + (1 if p["traits"].has("agressif") else 0)
	adults.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	return adults


static func _casualties(state: Dictionary, rng: Rng, e: Dictionary, count: int) -> int:
	var pool: Array = _fighters(state, e).slice(0, max(count * 3, 6))
	var dead := 0
	while dead < count and not pool.is_empty():
		var victim: Dictionary = pool.pop_at(rng.range_int(0, pool.size() - 1))
		People.kill(state, victim, "au combat")
		dead += 1
	return dead


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for war in state.get("wars", []).duplicate():
		var a = Civs.by_id(state, war["a"])
		var b = Civs.by_id(state, war["b"])
		if a == null or b == null or not a["alive"] or not b["alive"]:
			state["wars"].erase(war)
			continue
		if rng.chance(BATTLE_CHANCE):
			var pair := [a, b] if rng.chance(0.6) else [b, a]
			_battle(state, rng, census, war, pair[0], pair[1])
		Sieges.try_blockade(state, rng, a, b)
		Sieges.try_blockade(state, rng, b, a)


static func _battle(state: Dictionary, rng: Rng, census: Dictionary, war: Dictionary, attacker: Dictionary, defender: Dictionary) -> void:
	var f = _front(state, attacker, defender)
	if f == null or not census.has(f["from"]["id"]) or not census.has(f["to"]["id"]):
		return
	var ea: Dictionary = census[f["from"]["id"]]
	var ed: Dictionary = census[f["to"]["id"]]
	if ea["pop"] < 3 or ed["pop"] < 1:
		return
	if f["sea"] and not Naval.cross(state, rng, war, f, attacker, defender, ea, ed):
		return
	var pa := _power(state, rng, f["from"], ea, false)
	var pd := _power(state, rng, f["to"], ed, true)
	var wins := pa > pd
	var win_e: Dictionary = ea if wins else ed
	var lose_e: Dictionary = ed if wins else ea
	var ratio: float = max(pa, pd) / max(0.1, min(pa, pd))
	var loser_deaths: int = min(MAX_LOSER_DEATHS, max(1, int(round(1 + ratio))), ceili(_fighters(state, lose_e).size() * LOSER_SHARE))
	var heroes := _fighters(state, win_e)
	var hero = heroes[0] if not heroes.is_empty() else null
	var dead := _casualties(state, rng, lose_e, loser_deaths) + _casualties(state, rng, win_e, 1 if rng.chance(0.5) else 0)
	war["deaths"] += dead
	war["battles"] += 1
	if hero != null and hero["alive"]:
		Fame.add(hero, 2)
	var verb := "les troupes %s l'emportent" % Civs.of_title(attacker) if wins else "%s repousse l'assaut %s" % [f["to"]["name"], Civs.of_title(attacker)]
	var lead := ", menées par %s" % hero["name"] if wins and hero != null and hero["alive"] else ""
	var extra := {"x": f["to"]["x"], "y": f["to"]["y"], "from": f["from"]["id"], "settlement": f["to"]["id"], "civ": (attacker if wins else defender)["id"], "sea": f["sea"]}
	var title := "⛵ Débarquement près %s" % Names.of_place(f["to"]["name"]) if f["sea"] else "⚔️ Bataille %s" % Names.of_place(f["to"]["name"])
	Journal.log_event(state, "bataille", "%s : %s%s. %s." % [title, verb, lead, Names.plural(dead, "mort")], extra)
	var held: bool = f["to"].get("conquered_day", -1) >= 0 and state["day"] - f["to"]["conquered_day"] < HOLD_DAYS
	var starving: bool = Sieges.besieged(f["to"]) and ed["hungry"] > ed["pop"] * 0.3
	var chance: float = SIEGE_CONQUEST_CHANCE if starving else CONQUEST_CHANCE
	if wins and not held and (ratio >= CONQUEST_RATIO or starving) and ed["pop"] - dead < ea["pop"] and rng.chance(chance):
		_conquer(state, war, attacker, defender, f["to"])
	elif wins:
		Sieges.start(state, f["to"], attacker, f["from"])


static func _conquer(state: Dictionary, war: Dictionary, winner: Dictionary, loser: Dictionary, s: Dictionary) -> void:
	s["civ"] = winner["id"]
	s["conquered_day"] = state["day"]
	s.erase("siege")
	s.erase("blockade")
	winner["conquests"] += 1
	var capital := " Sa capitale est tombée !" if s["id"] == loser["capital"] else ""
	Journal.log_event(state, "conquete", "🏴 %s passe sous la bannière %s.%s" % [s["name"], Civs.of_title(winner), capital], {"x": s["x"], "y": s["y"], "civ": winner["id"], "settlement": s["id"], "highlight": true})
	if Civs.members(state, loser).is_empty():
		state["wars"].erase(war)


static func line(state: Dictionary, war: Dictionary) -> String:
	var a = Civs.by_id(state, war["a"])
	var b = Civs.by_id(state, war["b"])
	if a == null or b == null:
		return ""
	return "⚔️ %s contre %s · %s · %s · %s" % [Civs.title(a, true), Civs.title(b), Names.plural(state["day"] - war["start"], "jour"), Names.plural(war["battles"], "bataille"), Names.plural(war["deaths"], "mort")]
