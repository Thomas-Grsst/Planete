class_name Social
extends RefCounted

const BOND_CHANCE := 0.02
const DUEL_CHANCE := 0.0015
const BETRAYAL_CHANCE := 0.0001
const DUEL_DEATH := 0.1
const FRIEND_JOY := 0.05


static func _link(p: Dictionary, key: String, other: int) -> void:
	if not p.has(key):
		p[key] = []
	if not p[key].has(other):
		p[key].append(other)


static func _unlink(p: Dictionary, key: String, other: int) -> void:
	if p.has(key):
		p[key].erase(other)


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p))
		if adults.size() < 4:
			continue
		if rng.chance(BOND_CHANCE):
			_bond(state, rng, adults)
		for p in adults:
			if not p.get("friends", []).is_empty():
				p["happiness"] = min(100.0, p["happiness"] + FRIEND_JOY)
		if rng.chance(BETRAYAL_CHANCE):
			_betray(state, rng, e, adults)
		if rng.chance(DUEL_CHANCE):
			_duel(state, rng, e["s"], adults)


static func _bond(state: Dictionary, rng: Rng, adults: Array) -> void:
	var a: Dictionary = rng.pick(adults)
	var b: Dictionary = rng.pick(adults)
	if a["id"] == b["id"] or a["partner"] == b["id"]:
		return
	var hostile: bool = a["traits"].has("agressif") or b["traits"].has("agressif") or (a["traits"].has("prudent") and b["traits"].has("aventurier"))
	var warm: bool = a["traits"].has("sociable") or b["traits"].has("sociable") or a["traits"].any(func(t): return b["traits"].has(t))
	if hostile and rng.chance(0.6):
		_link(a, "rivals", b["id"])
		_link(b, "rivals", a["id"])
		Journal.remember(state, a, "😠 %s et %s deviennent rivaux." % [a["name"], b["name"]])
		Journal.remember(state, b, "😠 %s et %s deviennent rivaux." % [b["name"], a["name"]])
	elif warm:
		_link(a, "friends", b["id"])
		_link(b, "friends", a["id"])
		Journal.remember(state, a, "🤝 %s et %s deviennent amis." % [a["name"], b["name"]])
		Journal.remember(state, b, "🤝 %s et %s deviennent amis." % [b["name"], a["name"]])


static func _betray(state: Dictionary, rng: Rng, e: Dictionary, adults: Array) -> void:
	var traitors: Array = adults.filter(func(p): return not p.get("friends", []).is_empty() and (p["traits"].has("agressif") or p["traits"].has("aventurier")))
	if traitors.is_empty():
		return
	var t: Dictionary = rng.pick(traitors)
	var victim = People.by_id(state, rng.pick(t["friends"]))
	if victim == null or not victim["alive"]:
		return
	_unlink(t, "friends", victim["id"])
	_unlink(victim, "friends", t["id"])
	_link(victim, "rivals", t["id"])
	_link(t, "rivals", victim["id"])
	var s: Dictionary = e["s"]
	Journal.log_event(state, "trahison", "🗡️ À %s, %s trahit la confiance de %s, son ami de toujours." % [s["name"], t["name"], victim["name"]], {"x": s["x"], "y": s["y"], "person": t["id"], "other": victim["id"]})


static func _duel(state: Dictionary, rng: Rng, s: Dictionary, adults: Array) -> void:
	var angry: Array = adults.filter(func(p): return not p.get("rivals", []).is_empty())
	if angry.is_empty():
		return
	var a: Dictionary = rng.pick(angry)
	var b = People.by_id(state, rng.pick(a["rivals"]))
	if b == null or not b["alive"] or b["home"] != a["home"]:
		return
	var sa := 1.0 + (1.0 if a["traits"].has("courageux") else 0.0) + (0.5 if a["job"] == "gardien" else 0.0) + rng.next()
	var sb := 1.0 + (1.0 if b["traits"].has("courageux") else 0.0) + (0.5 if b["job"] == "gardien" else 0.0) + rng.next()
	var winner: Dictionary = a if sa >= sb else b
	var loser: Dictionary = b if sa >= sb else a
	loser["health"] -= 35.0
	if rng.chance(DUEL_DEATH) or loser["health"] <= 0:
		People.kill(state, loser, "en duel face à %s" % winner["name"])
		Fame.add(winner, 1)
		return
	Journal.log_event(state, "duel", "⚔️ Duel à %s : %s l'emporte sur %s, son rival." % [s["name"], winner["name"], loser["name"]], {"x": s["x"], "y": s["y"], "person": winner["id"], "other": loser["id"]})
