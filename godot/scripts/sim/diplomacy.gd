class_name Diplomacy
extends RefCounted

const DECAY := 0.998
const CLOSE_BORDER := 10
const BORDER := 16
const TRADE_RANGE := 22
const WAR_THRESHOLD := -50.0
const WAR_CHANCE := 0.01
const TRADE_THRESHOLD := 40.0
const ALLIANCE_THRESHOLD := 70.0
const PACT_CHANCE := 0.01
const ALLIANCE_CHANCE := 0.005
const BREAK_THRESHOLD := 10.0
const TRUCE_DAYS := 1800
const PEACE_MIN_DAYS := 120
const TRADE_TECH_CHANCE := 0.003
const SHARED_FAITH := 0.04
const NAVAL_BORDER := 45


static func _distance(state: Dictionary, a: Dictionary, b: Dictionary) -> int:
	var best := 9999
	for s in Civs.members(state, a):
		for o in Civs.members(state, b):
			best = min(best, absi(s["x"] - o["x"]) + absi(s["y"] - o["y"]))
	return best


static func _chef_trait(state: Dictionary, civ: Dictionary, t: String) -> bool:
	var capital = Settlements.by_id(state, civ["capital"])
	var chef = Governance.chef_of(state, capital) if capital != null else null
	return chef != null and chef["traits"].has(t)


static func _naval(state: Dictionary, civ: Dictionary) -> bool:
	return Civs.members(state, civ).any(func(s): return Ports.has_port(s) and Techs.has_tech(s, "navigation"))


static func trades(state: Dictionary, civ: Dictionary) -> bool:
	return Civs.members(state, civ).any(func(s): return Techs.has_tech(s, "roue") or Techs.has_tech(s, "navigation"))


static func _drift(state: Dictionary, rng: Rng, a: Dictionary, b: Dictionary, rel: Dictionary, d: int) -> void:
	var delta := 0.0
	if d < CLOSE_BORDER:
		delta -= 0.12
	elif d < BORDER:
		delta -= 0.05
	if d < TRADE_RANGE and trades(state, a) and trades(state, b):
		delta += 0.06
	for c in [a, b]:
		delta += (-0.07 if _chef_trait(state, c, "agressif") else 0.0) + (0.04 if _chef_trait(state, c, "sociable") else 0.0)
	if rel["pact"] != "":
		delta += 0.03
	if a.get("religion", -1) >= 0 and b.get("religion", -1) >= 0:
		delta += SHARED_FAITH if a["religion"] == b["religion"] else -SHARED_FAITH
	if d <= Covet.REACH and (not Covet.reason(state, a, b).is_empty() or not Covet.reason(state, b, a).is_empty()):
		delta -= Covet.TENSION
	rel["score"] = clamp(rel["score"] * DECAY + delta + (rng.next() - 0.5) * 0.3, -100.0, 100.0)


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var civs := Civs.alive(state)
	for i in civs.size():
		for j in range(i + 1, civs.size()):
			var a: Dictionary = civs[i]
			var b: Dictionary = civs[j]
			var rel := Civs.relation(state, a, b)
			var d := _distance(state, a, b)
			_drift(state, rng, a, b, rel, d)
			var war = Civs.war_between(state, a, b)
			if war != null:
				_try_peace(state, rng, war, rel, a, b)
				continue
			var reach: int = NAVAL_BORDER if _naval(state, a) and _naval(state, b) else BORDER + 6
			if rel["score"] < WAR_THRESHOLD and state["day"] >= rel["truce_until"] and d < reach and rng.chance(WAR_CHANCE):
				rel["pact"] = ""
				_declare(state, a, b, d)
				continue
			_pact(state, rng, a, b, rel)
			if rel["pact"] != "" and rng.chance(TRADE_TECH_CHANCE):
				_trade_knowledge(state, rng, census, a, b)


static func _declare(state: Dictionary, a: Dictionary, b: Dictionary, d: int) -> void:
	var pair := [b, a] if _chef_trait(state, b, "agressif") and not _chef_trait(state, a, "agressif") else [a, b]
	var attacker: Dictionary = pair[0]
	var defender: Dictionary = pair[1]
	var capital = Settlements.by_id(state, attacker["capital"])
	var faith = Religions.by_id(state, attacker.get("religion", -1))
	var why := "pour des terres frontalières" if d < CLOSE_BORDER else "après des années de méfiance"
	var covet := Covet.reason(state, attacker, defender)
	if faith != null and defender.get("religion", -1) >= 0 and defender["religion"] != faith["id"]:
		why = "au nom %s" % FaithData.of_name(faith["deity"])
	elif not covet.is_empty():
		why = Covet.why(covet)
	elif _chef_trait(state, attacker, "agressif"):
		why = "sous l'impulsion %s" % Names.of_place(Governance.chef_of(state, capital)["name"])
	state["next_id"] += 1
	state["wars"].append({"id": state["next_id"], "a": attacker["id"], "b": defender["id"], "start": state["day"], "deaths": 0, "battles": 0})
	Journal.log_event(state, "guerre", "⚔️ %s déclare la guerre %s, %s !" % [Civs.title(attacker, true), Civs.to_title(defender), why], {"x": capital["x"], "y": capital["y"], "civ": attacker["id"], "highlight": true})


static func _try_peace(state: Dictionary, rng: Rng, war: Dictionary, rel: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var length: int = state["day"] - war["start"]
	if length < PEACE_MIN_DAYS or not rng.chance(0.003 + war["deaths"] * 0.0004 + (0.01 if length > 720 else 0.0)):
		return
	state["wars"].erase(war)
	rel["score"] = -10.0
	rel["truce_until"] = state["day"] + TRUCE_DAYS
	Journal.log_event(state, "paix", "🕊️ %s et %s signent la paix après %s de guerre et %s." % [Civs.title(a, true), Civs.title(b), Names.plural(length, "jour"), Names.plural(war["deaths"], "mort")], {"civ": a["id"], "highlight": true})


static func _pact(state: Dictionary, rng: Rng, a: Dictionary, b: Dictionary, rel: Dictionary) -> void:
	if rel["pact"] != "" and rel["score"] < BREAK_THRESHOLD:
		Journal.log_event(state, "rupture", "💔 %s entre %s et %s est rompue." % ["L'alliance" if rel["pact"] == "alliance" else "La route commerciale", Civs.title(a), Civs.title(b)], {"civ": a["id"]})
		rel["pact"] = ""
	elif rel["pact"] == "" and rel["score"] > TRADE_THRESHOLD and trades(state, a) and trades(state, b) and rng.chance(PACT_CHANCE):
		rel["pact"] = "commerce"
		Journal.log_event(state, "commerce", "🐪 %s et %s ouvrent une route commerciale." % [Civs.title(a, true), Civs.title(b)], {"civ": a["id"], "from": a["capital"], "to": b["capital"]})
	elif rel["pact"] == "commerce" and rel["score"] > ALLIANCE_THRESHOLD and rng.chance(ALLIANCE_CHANCE):
		rel["pact"] = "alliance"
		Journal.log_event(state, "alliance", "🤝 %s et %s scellent une alliance." % [Civs.title(a, true), Civs.title(b)], {"civ": a["id"], "highlight": true})


static func _trade_knowledge(state: Dictionary, rng: Rng, census: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var pair := [a, b] if rng.chance(0.5) else [b, a]
	var source = Settlements.by_id(state, pair[0]["capital"])
	var target = Settlements.by_id(state, pair[1]["capital"])
	if source == null or target == null or not census.has(target["id"]):
		return
	var pool: Array = source["techs"].filter(func(k): return Techs.can_learn(target, k))
	if pool.is_empty():
		return
	var key: String = rng.pick(pool)
	var learner = rng.pick(census[target["id"]]["people"])
	Ideas.discover(state, target, key, learner, source, "🐪 Par la route commerciale, %s apporte le secret %s à %s." % [Civs.title(pair[0]), Techs.DATA[key]["de"], target["name"]])


static func label(state: Dictionary, a: Dictionary, b: Dictionary) -> String:
	if Civs.war_between(state, a, b) != null:
		return "⚔️ en guerre"
	var rel := Civs.relation(state, a, b)
	if rel["pact"] == "alliance":
		return "🤝 allié"
	if rel["pact"] == "commerce":
		return "🐪 partenaire commercial"
	if rel["score"] <= -30:
		return "😠 hostile"
	return "🙂 cordial" if rel["score"] >= 30 else "😐 neutre"
