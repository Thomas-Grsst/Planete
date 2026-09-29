class_name Hordes
extends RefCounted

const CAP := 40.0
const MAX_HORDES := 12
const TARGET_RANGE := 15
const FLEE_RANGE := 20
const KILL_PER_DEFENSE := 0.2
const MAX_KILL_SHARE := 0.4
const BITE_PER_ZOMBIE := 0.12
const DEFENSE_BITE_WEIGHT := 0.5
const DEVOURED_CHANCE := 0.3


static func spawn(state: Dictionary, x: int, y: int, count: float) -> Dictionary:
	state["next_id"] += 1
	var h := {"id": state["next_id"], "x": x, "y": y, "count": count, "target": -1, "met": []}
	state["zombies"]["hordes"].append(h)
	return h


static func spawn_spot(state: Dictionary, rng: Rng, s: Dictionary) -> Vector2i:
	for tries in 30:
		var x: int = s["x"] + rng.range_int(-10, 10)
		var y: int = s["y"] + rng.range_int(-10, 10)
		var d: int = absi(x - s["x"]) + absi(y - s["y"])
		if d >= 6 and WorldGen.is_walkable(state["world"], x, y) and Regions.same_landmass(state["world"], s["x"], s["y"], x, y):
			return Vector2i(x, y)
	return Vector2i(s["x"] + 3, s["y"])


static func _stochastic(rng: Rng, x: float) -> int:
	return int(floor(x)) + (1 if rng.chance(x - floor(x)) else 0)


static func target(state: Dictionary, census: Dictionary, h: Dictionary) -> Variant:
	var best = null
	var best_d := 9999
	for id in census:
		var s: Dictionary = census[id]["s"]
		var d: int = absi(h["x"] - s["x"]) + absi(h["y"] - s["y"])
		if census[id]["pop"] > 0 and d <= TARGET_RANGE and d < best_d and Regions.same_landmass(state["world"], h["x"], h["y"], s["x"], s["y"]):
			best_d = d
			best = s
	h["target"] = best["id"] if best != null else -1
	return best


static func move(state: Dictionary, rng: Rng, h: Dictionary, t) -> void:
	if state["weather"] == "snow" or (t == null and not rng.chance(0.5)):
		return
	var steps: Array = [Vector2i(rng.range_int(-1, 1), rng.range_int(-1, 1))]
	if t != null:
		var dx: int = sign(t["x"] - h["x"])
		var dy: int = sign(t["y"] - h["y"])
		steps = [Vector2i(dx, 0), Vector2i(0, dy), Vector2i(dx, dy)] if absi(t["x"] - h["x"]) >= absi(t["y"] - h["y"]) else [Vector2i(0, dy), Vector2i(dx, 0), Vector2i(dx, dy)]
	for st in steps:
		if st != Vector2i.ZERO and WorldGen.is_walkable(state["world"], h["x"] + st.x, h["y"] + st.y):
			h["x"] += st.x
			h["y"] += st.y
			return


static func rot(state: Dictionary, h: Dictionary) -> void:
	h["count"] = max(0.0, h["count"] - h["count"] * 0.015 - (0.2 if state["weather"] == "snow" else 0.05))


static func attack(state: Dictionary, rng: Rng, h: Dictionary, s: Dictionary, e: Dictionary, census: Dictionary) -> void:
	var guards: Array = e["people"].filter(func(p): return p["alive"] and p["job"] == "gardien")
	if not h["met"].has(s["id"]):
		h["met"].append(s["id"])
		var n := int(round(h["count"]))
		var watch := "%s %s face." % [Names.plural(guards.size(), "gardien"), "font" if guards.size() > 1 else "fait"] if not guards.is_empty() else "Personne ne monte la garde."
		Journal.log_event(state, "zombie", "🧟 %s %s ! %s" % ["Une horde de %d zombies attaque" % n if n > 1 else "Un zombie attaque", s["name"], watch], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
	var defense := Threats.defense(state, e)
	var bites := _stochastic(rng, h["count"] * BITE_PER_ZOMBIE * h["count"] / (h["count"] + DEFENSE_BITE_WEIGHT * defense))
	for i in bites:
		var pool: Array = guards if not guards.is_empty() and rng.chance(0.4) else e["people"]
		var v = rng.pick(pool)
		if v == null or not v["alive"] or v.get("bitten", -1) >= 0:
			continue
		if rng.chance(DEVOURED_CHANCE):
			People.kill(state, v, "dévorée par les zombies" if v["sex"] == "F" else "dévoré par les zombies")
			state["zombies"]["dead"] += 1
			h["count"] = min(CAP, h["count"] + 1)
		else:
			v["bitten"] = state["day"]
			Journal.remember(state, v, "🧟 %s est %s par un zombie." % [v["name"], "mordue" if v["sex"] == "F" else "mordu"])
	var before: float = h["count"]
	h["count"] = max(0.0, h["count"] - _stochastic(rng, min(h["count"] * MAX_KILL_SHARE, defense * KILL_PER_DEFENSE)))
	if before >= 1 and h["count"] < 1:
		var hero = rng.pick(guards) if not guards.is_empty() else null
		var extra := {"x": s["x"], "y": s["y"], "settlement": s["id"]}
		if hero != null:
			extra["person"] = hero["id"]
			Fame.add(hero, 3)
		Journal.log_event(state, "zombie", "🛡️ %s repousse la horde.%s" % [s["name"], " %s a abattu le dernier zombie." % hero["name"] if hero != null else ""], extra)
	elif defense < h["count"] / 2:
		_flee(state, rng, census, s, e)


static func _flee(state: Dictionary, rng: Rng, census: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var z: Dictionary = state["zombies"]
	if z["fled"].has(s["id"]):
		return
	var dest = null
	var best := FLEE_RANGE + 1
	for id in census:
		var t: Dictionary = census[id]["s"]
		var d: int = absi(s["x"] - t["x"]) + absi(s["y"] - t["y"])
		if t["id"] != s["id"] and d < best and census[id]["pop"] > 0 and not z["hordes"].any(func(h): return absi(h["x"] - t["x"]) + absi(h["y"] - t["y"]) <= 3):
			best = d
			dest = t
	if dest == null:
		return
	var movers: Array = e["people"].filter(func(p): return p["alive"] and p.get("bitten", -1) < 0 and p["job"] not in ["gardien", "chef"] and People.age_of(state, p) >= People.MIGRANT_MIN_AGE and rng.chance(0.3))
	if movers.size() < 2:
		return
	for p in movers:
		p["home"] = dest["id"]
		for cid in p["children"]:
			var c = People.by_id(state, cid)
			if c != null and c["alive"] and People.age_of(state, c) < People.MIGRANT_MIN_AGE:
				c["home"] = dest["id"]
	z["fled"].append(s["id"])
	Journal.log_event(state, "zombie", "🧭 %s fuit %s avec %s vers %s." % [movers[0]["name"], s["name"], Names.plural(movers.size() - 1, "compagnon"), dest["name"]], {"x": s["x"], "y": s["y"], "person": movers[0]["id"]})


static func turn(state: Dictionary, x: int, y: int) -> void:
	var hordes: Array = state["zombies"]["hordes"]
	for h in hordes:
		if absi(h["x"] - x) + absi(h["y"] - y) <= 2:
			h["count"] = min(CAP, h["count"] + 1)
			return
	if hordes.size() < MAX_HORDES:
		spawn(state, x, y, 1.0)


static func merge(state: Dictionary) -> void:
	var by_tile := {}
	var kept: Array = []
	for h in state["zombies"]["hordes"]:
		if h["count"] < 1:
			continue
		var key: int = h["y"] * 1000 + h["x"]
		if by_tile.has(key):
			by_tile[key]["count"] = min(CAP, by_tile[key]["count"] + h["count"])
		else:
			by_tile[key] = h
			kept.append(h)
	state["zombies"]["hordes"] = kept
