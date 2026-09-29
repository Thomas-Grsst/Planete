class_name Raiders
extends RefCounted

const KINDS := {
	"barbare": {"emoji": "🪓", "name": "barbares", "min_day": 7200, "chance": 0.0003, "size": [5, 12]},
	"pirate": {"emoji": "🏴‍☠️", "name": "pirates", "min_day": 10800, "chance": 0.00025, "size": [4, 9]},
	"machine": {"emoji": "🤖", "name": "machines rebelles", "min_day": 0, "chance": 0.0, "size": [8, 16]},
}
const MAX_BANDS := 4
const RAID_REACH := 1
const LOOT_SHARE := 0.4
const SPY_CHANCE := 0.0015


static func spawn(state: Dictionary, kind: String, x: int, y: int, size: int, target: int) -> void:
	if not state.has("raiders"):
		state["raiders"] = []
	state["next_id"] += 1
	state["raiders"].append({"id": state["next_id"], "kind": kind, "x": x, "y": y, "count": float(size), "target": target, "days": 0})


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	if not state.has("raiders"):
		state["raiders"] = []
	if census.size() >= 3 and state["raiders"].size() < MAX_BANDS:
		_maybe_spawn(state, rng, census)
	for band in state["raiders"].duplicate():
		_advance(state, rng, census, band)
	state["raiders"] = state["raiders"].filter(func(b): return b["count"] >= 1 and b["days"] < 400)
	_spies(state, rng)


static func _maybe_spawn(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for kind in ["barbare", "pirate"]:
		var k: Dictionary = KINDS[kind]
		if state["day"] < k["min_day"] or not rng.chance(k["chance"]):
			continue
		var targets: Array = census.values().map(func(e): return e["s"]).filter(func(s): return kind != "pirate" or s["geo"]["coast"])
		if targets.is_empty():
			continue
		var target: Dictionary = rng.pick(targets)
		var spot := Hordes.spawn_spot(state, rng, target)
		var size := rng.range_int(k["size"][0], k["size"][1])
		spawn(state, kind, spot.x, spot.y, size, target["id"])
		var from := "surgissent des terres sauvages" if kind == "barbare" else "jettent l'ancre au large"
		Journal.log_event(state, "raid", "%s Des %s %s et marchent sur %s !" % [k["emoji"], k["name"], from, target["name"]], {"x": spot.x, "y": spot.y, "settlement": target["id"], "highlight": true})


static func _advance(state: Dictionary, rng: Rng, census: Dictionary, band: Dictionary) -> void:
	band["days"] += 1
	var target = Settlements.by_id(state, band["target"])
	if target == null or not census.has(target["id"]):
		band["count"] = 0.0
		return
	var d: int = absi(band["x"] - target["x"]) + absi(band["y"] - target["y"])
	if d > RAID_REACH:
		var step := Vector2i(sign(target["x"] - band["x"]), sign(target["y"] - band["y"]))
		if band["kind"] == "pirate" or WorldGen.is_walkable(state["world"], band["x"] + step.x, band["y"] + step.y):
			band["x"] += step.x
			band["y"] += step.y
		else:
			band["x"] += step.x
		return
	_raid(state, rng, band, target, census[target["id"]])


static func _raid(state: Dictionary, rng: Rng, band: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var k: Dictionary = KINDS[band["kind"]]
	var defense := Threats.defense(state, e) * (0.7 + rng.next() * 0.6)
	var strength: float = band["count"] * 0.35
	if defense >= strength:
		var guards: Array = e["people"].filter(func(p): return p["job"] == "gardien")
		var hero = rng.pick(guards) if not guards.is_empty() else null
		if hero != null:
			Fame.add(hero, 2)
		band["count"] = 0.0
		var who := " %s mène la défense." % hero["name"] if hero != null else ""
		Journal.log_event(state, "raid", "🛡️ %s repousse les %s !%s" % [s["name"], k["name"], who], {"x": s["x"], "y": s["y"], "settlement": s["id"], "person": hero["id"] if hero != null else -1, "highlight": true})
		return
	var dead := 0
	for i in rng.range_int(1, 3):
		var v = rng.pick(e["people"])
		if v != null and v["alive"]:
			People.kill(state, v, "lors du pillage")
			dead += 1
	s["food"] *= 1.0 - LOOT_SHARE
	s["wood"] *= 1.0 - LOOT_SHARE
	if band["kind"] == "machine" and s["houses"] > 1:
		s["houses"] -= 1
	band["count"] = 0.0
	Journal.log_event(state, "raid", "%s Les %s pillent %s et repartent chargés de butin. %s." % [k["emoji"], k["name"], s["name"], Names.plural(dead, "mort")], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})


static func _spies(state: Dictionary, rng: Rng) -> void:
	for war in state.get("wars", []):
		if not rng.chance(SPY_CHANCE):
			continue
		var a = Civs.by_id(state, war["a"])
		var b = Civs.by_id(state, war["b"])
		if a == null or b == null:
			continue
		var thief = Settlements.by_id(state, a["capital"])
		var victim = Settlements.by_id(state, b["capital"])
		if thief == null or victim == null:
			continue
		var pool: Array = victim["techs"].filter(func(t): return Techs.can_learn(thief, t))
		if not pool.is_empty():
			var key: String = rng.pick(pool)
			Ideas.discover(state, thief, key, null, victim, "🕵️ Un espion %s dérobe le secret %s à %s." % [Civs.of_title(a), Techs.DATA[key]["de"], victim["name"]])
