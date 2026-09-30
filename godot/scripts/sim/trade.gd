class_name Trade
extends RefCounted

const PLAN_DAYS := 30
const EXCHANGE_DAYS := 10
const LAND_RANGE := 40
const RAFT_RANGE := 30
const SHIP_RANGE := 70
const MIN_POP := 6
const LOAD := 12.0
const SURPLUS := 0.6
const SHORT := 0.3
const FRIENDSHIP := 0.4


static func routes(state: Dictionary) -> Array:
	return state.get_or_add("routes", [])


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	if state["day"] % PLAN_DAYS == 0:
		_plan(state, census)
	if state["day"] % EXCHANGE_DAYS == 0:
		_exchange(state, rng, census)


static func sea_range(s: Dictionary) -> int:
	if not Ports.has_port(s):
		return 0
	return SHIP_RANGE if Techs.has_tech(s, "navigation") else RAFT_RANGE


static func kind_between(state: Dictionary, a: Dictionary, b: Dictionary) -> String:
	var d: int = absi(a["x"] - b["x"]) + absi(a["y"] - b["y"])
	if Regions.same_landmass(state["world"], a["x"], a["y"], b["x"], b["y"]):
		return "land" if d <= LAND_RANGE else ""
	return "sea" if sea_range(a) > 0 and sea_range(b) > 0 and d <= max(sea_range(a), sea_range(b)) else ""


static func partners(state: Dictionary, s: Dictionary) -> Array:
	var out: Array = []
	for id in s.get("partners", []):
		var o = Settlements.by_id(state, id)
		if o != null:
			out.append(o)
	return out


static func _index(state: Dictionary) -> void:
	for s in state["settlements"]:
		s.erase("partners")
	for r in routes(state):
		var a = Settlements.by_id(state, r["a"])
		var b = Settlements.by_id(state, r["b"])
		if a != null and b != null:
			a.get_or_add("partners", []).append(b["id"])
			b.get_or_add("partners", []).append(a["id"])


static func _plan(state: Dictionary, census: Dictionary) -> void:
	var all := routes(state)
	for r in all.duplicate():
		if not _valid(state, census, r):
			all.erase(r)
	for civ in Civs.alive(state):
		var capital = Settlements.by_id(state, civ["capital"])
		if capital == null or not census.has(capital["id"]):
			continue
		for s in Civs.members(state, civ):
			if s["id"] != capital["id"] and census.has(s["id"]) and census[s["id"]]["pop"] >= MIN_POP:
				_link(state, capital, s)
	for key in state.get("relations", {}):
		if state["relations"][key]["pact"] == "":
			continue
		var ids: PackedStringArray = key.split("-")
		var pair = _closest(state, census, Civs.by_id(state, int(ids[0])), Civs.by_id(state, int(ids[1])))
		if pair != null:
			_link(state, pair[0], pair[1])
	_index(state)


static func _closest(state: Dictionary, census: Dictionary, a, b) -> Variant:
	if a == null or b == null or not a["alive"] or not b["alive"]:
		return null
	var best = null
	var best_d := 99999
	for s in Civs.members(state, a):
		for o in Civs.members(state, b):
			var d: int = absi(s["x"] - o["x"]) + absi(s["y"] - o["y"])
			if d < best_d and census.has(s["id"]) and census.has(o["id"]) and kind_between(state, s, o) != "":
				best_d = d
				best = [s, o]
	return best


static func _find(state: Dictionary, a: int, b: int) -> Variant:
	for r in routes(state):
		if (r["a"] == a and r["b"] == b) or (r["a"] == b and r["b"] == a):
			return r
	return null


static func _link(state: Dictionary, a: Dictionary, b: Dictionary) -> void:
	if _find(state, a["id"], b["id"]) != null:
		return
	var kind := kind_between(state, a, b)
	if kind == "":
		return
	state["next_id"] += 1
	routes(state).append({"id": state["next_id"], "a": a["id"], "b": b["id"], "kind": kind, "since": state["day"], "goods": 0.0})
	var text := "⛵ Une route maritime relie désormais %s et %s." if kind == "sea" else "🐪 Une route relie désormais %s à %s."
	Journal.log_event(state, "route", text % [a["name"], b["name"]], {"x": a["x"], "y": a["y"], "from": a["id"], "to": b["id"], "sea": kind == "sea"})


static func _valid(state: Dictionary, census: Dictionary, r: Dictionary) -> bool:
	var a = Settlements.by_id(state, r["a"])
	var b = Settlements.by_id(state, r["b"])
	if a == null or b == null or not census.has(a["id"]) or not census.has(b["id"]) or kind_between(state, a, b) != r["kind"]:
		return false
	var ca = Civs.of(state, a)
	var cb = Civs.of(state, b)
	if ca == null or cb == null:
		return false
	if ca["id"] == cb["id"]:
		return true
	return Civs.relation(state, ca, cb)["pact"] != "" and Civs.war_between(state, ca, cb) == null


static func _exchange(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for r in routes(state):
		var a = Settlements.by_id(state, r["a"])
		var b = Settlements.by_id(state, r["b"])
		if a == null or b == null or not census.has(a["id"]) or not census.has(b["id"]) or not Sieges.can_trade(a, r["kind"]) or not Sieges.can_trade(b, r["kind"]):
			continue
		var moved := _balance(a, b, "food", _food_cap(census[a["id"]]), _food_cap(census[b["id"]]))
		moved += _balance(a, b, "wood", _wood_cap(a), _wood_cap(b))
		moved += _balance(a, b, "metal", Mining.METAL_CAP, Mining.METAL_CAP)
		r["goods"] += moved
		Voyages.travel(state, rng, census, r, a, b)
		var ca = Civs.of(state, a)
		var cb = Civs.of(state, b)
		if moved > 0.0 and ca != null and cb != null and ca["id"] != cb["id"]:
			var rel := Civs.relation(state, ca, cb)
			rel["score"] = min(100.0, rel["score"] + FRIENDSHIP)


static func _food_cap(e: Dictionary) -> float:
	return (Work.STORE_BASE + e["s"]["houses"] * Work.STORE_PER_HOUSE) * e["mods"]["store"]


static func _wood_cap(s: Dictionary) -> float:
	return Work.WOOD_CAP_BASE + s["houses"] * Work.WOOD_PER_HOUSE


static func _balance(a: Dictionary, b: Dictionary, key: String, cap_a: float, cap_b: float) -> float:
	var ra: float = a.get(key, 0.0) / max(1.0, cap_a)
	var rb: float = b.get(key, 0.0) / max(1.0, cap_b)
	if ra > SURPLUS and rb < SHORT:
		return _move(a, b, key, min(LOAD, a.get(key, 0.0) - cap_a * SURPLUS))
	if rb > SURPLUS and ra < SHORT:
		return _move(b, a, key, min(LOAD, b.get(key, 0.0) - cap_b * SURPLUS))
	return 0.0


static func _move(from: Dictionary, to: Dictionary, key: String, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	from[key] = from.get(key, 0.0) - amount
	to[key] = to.get(key, 0.0) + amount
	return amount
