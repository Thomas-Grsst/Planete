class_name Famine
extends RefCounted

# Quand un village a faim : ses voisins envoient des vivres, et les plus affamés partent se réfugier chez eux.

const CHECK_DAYS := 5
const STARVING_SHARE := 0.25
const RANGE := 18
const AID_GAP_DAYS := 20
const AID_MIN_RATIO := 0.4
const AID_KEEP_RATIO := 0.3
const AID_LOAD := 30.0
const REFUGE_CHANCE := 0.25
const REFUGE_GAP_DAYS := 60
const REFUGE_MIN_RATIO := 0.3
const REFUGE_SHARE := 0.3


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	if state["day"] % CHECK_DAYS != 0:
		return
	for id in census:
		var e: Dictionary = census[id]
		if e["pop"] <= 0 or e["hungry"] < max(2, e["pop"] * STARVING_SHARE):
			continue
		var s: Dictionary = e["s"]
		if state["day"] - s.get("aid_day", -9999) >= AID_GAP_DAYS:
			_aid(state, census, s, e)
		if state["day"] - s.get("refuge_day", -9999) >= REFUGE_GAP_DAYS and rng.chance(REFUGE_CHANCE):
			_refuge(state, census, s, e)


static func _reachable(state: Dictionary, from: Dictionary, o: Dictionary) -> String:
	if absi(from["x"] - o["x"]) + absi(from["y"] - o["y"]) > RANGE or Wars.at_war(state, from, o) or Sieges.besieged(o) or Sieges.besieged(from):
		return ""
	if Regions.same_landmass(state["world"], from["x"], from["y"], o["x"], o["y"]):
		return "land"
	if from.get("partners", []).has(o["id"]) and not Sieges.blockaded(from) and not Sieges.blockaded(o):
		return "sea"
	return ""


static func _ratio(census: Dictionary, o: Dictionary) -> float:
	return o["food"] / max(1.0, Trade.food_cap(census[o["id"]]))


# Le voisin le mieux pourvu qui peut aider, ou null.
static func _helper(state: Dictionary, census: Dictionary, s: Dictionary, min_ratio: float) -> Variant:
	var best = null
	var best_ratio := min_ratio
	for id in census:
		var o: Dictionary = census[id]["s"]
		if o["id"] == s["id"] or census[id]["hungry"] > census[id]["pop"] * 0.1 or _reachable(state, s, o) == "":
			continue
		var ratio := _ratio(census, o)
		if ratio > best_ratio:
			best_ratio = ratio
			best = o
	return best


static func _trip(from: Dictionary, to: Dictionary, sea: bool, icon: String) -> Dictionary:
	return {"voyage": {"from": from["id"], "to": to["id"], "sea": sea, "icon": icon}}


static func _aid(state: Dictionary, census: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var o = _helper(state, census, s, AID_MIN_RATIO)
	if o == null:
		return
	var spare: float = o["food"] - Trade.food_cap(census[o["id"]]) * AID_KEEP_RATIO
	var amount: float = min(AID_LOAD, spare)
	if amount < 5.0:
		return
	o["food"] -= amount
	s["food"] += amount
	s["aid_day"] = state["day"]
	var sea := _reachable(state, s, o) == "sea"
	var extra := {"x": s["x"], "y": s["y"], "settlement": s["id"], "from": o["id"], "to": s["id"]}
	extra.merge(_trip(o, s, sea, "🌾"))
	Journal.log_event(state, "entraide", "🌾 %s envoie des vivres %s à %s, qui a faim." % [o["name"], "par la mer" if sea else "par la route", s["name"]], extra)
	var ca = Civs.of(state, o)
	var cb = Civs.of(state, s)
	if ca != null and cb != null and ca["id"] != cb["id"]:
		var rel := Civs.relation(state, ca, cb)
		rel["score"] = min(100.0, rel["score"] + 3.0)


static func _refuge(state: Dictionary, census: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var o = _helper(state, census, s, REFUGE_MIN_RATIO)
	if o == null:
		return
	var hungry: Array = e["people"].filter(func(p): return p["hunger"] > Census.HUNGRY_ABOVE and People.is_adult(state, p))
	if hungry.is_empty():
		return
	hungry.sort_custom(func(a, b): return a["hunger"] > b["hunger"] or (a["hunger"] == b["hunger"] and a["id"] < b["id"]))
	var room: int = max(1, int(e["pop"] * REFUGE_SHARE))
	var moved: Array = []
	for p in hungry:
		if moved.size() >= room:
			break
		for q in [p, People.by_id(state, p["partner"]) if p["partner"] >= 0 else null]:
			if q != null and q["alive"] and q["home"] == s["id"] and not moved.has(q):
				moved.append(q)
		for cid in p["children"]:
			var c = People.by_id(state, cid)
			if c != null and c["alive"] and c["home"] == s["id"] and not People.is_adult(state, c) and not moved.has(c):
				moved.append(c)
	if moved.size() >= e["pop"]:
		moved = moved.slice(0, e["pop"] - 1)
	if moved.is_empty():
		return
	for p in moved:
		p["home"] = o["id"]
	s["refuge_day"] = state["day"]
	var lead: Dictionary = moved[0]
	var sea := _reachable(state, s, o) == "sea"
	var company := "" if moved.size() == 1 else " et %s" % Names.plural(moved.size() - 1, "proche")
	var extra := {"x": o["x"], "y": o["y"], "settlement": o["id"], "person": lead["id"], "from": s["id"], "to": o["id"]}
	extra.merge(_trip(s, o, sea, "🥣"))
	Journal.log_event(state, "refuge", "🥣 Fuyant la famine %s, %s%s %s refuge à %s." % [Names.of_place(s["name"]), lead["name"], company, "trouvent" if moved.size() > 1 else "trouve", o["name"]], extra)
