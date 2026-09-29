class_name Governance
extends RefCounted

const CHEF_MIN_POP := 25
const CHEF_MIN_AGE_DAYS := 360
const COUNCIL_MIN_POP := 50
const REVOLT_MIN_DAYS := 720
const REVOLT_UNHAPPY := 35.0
const REVOLT_CHANCE := 0.004


static func chef_of(state: Dictionary, s: Dictionary) -> Variant:
	var p = People.by_id(state, s.get("chef", -1))
	return p if p != null and p["alive"] and p["home"] == s["id"] else null


static func mods(state: Dictionary, s: Dictionary, e: Dictionary) -> void:
	var m: Dictionary = e["mods"]
	var council: bool = s.get("council", []).size() >= 3
	if council:
		m["research"] *= 1.2
		m["outbreak"] *= 0.9
	var chef = chef_of(state, s)
	if chef == null:
		if e["pop"] >= CHEF_MIN_POP:
			m["happiness"] -= 0.03
		return
	var t: Array = chef["traits"]
	m["happiness"] += 0.05 + (0.05 if t.has("sociable") else 0.0) - (0.05 if t.has("agressif") else 0.0)
	m["build"] *= 1.6 if t.has("travailleur") else 1.3
	m["defense"] *= 1.3 if t.has("agressif") else (1.15 if t.has("courageux") else 1.0)


static func _weight(p: Dictionary) -> float:
	var t: Array = p["traits"]
	return 1.0 + (2.0 if t.has("sociable") else 0.0) + (1.5 if t.has("courageux") else 0.0) + (0.5 if t.has("travailleur") else 0.0)


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if e["pop"] <= 0:
			continue
		var chef = chef_of(state, s)
		if s.get("chef", -1) >= 0 and chef == null:
			_lose_chef(state, rng, s)
		elif chef != null:
			_maybe_revolt(state, rng, s, e, chef)
		var can_elect: bool = state["day"] >= s.get("chef_vacant_until", 0) or Techs.has_tech(s, "lois")
		if s.get("chef", -1) < 0 and e["pop"] >= CHEF_MIN_POP and state["day"] - s["founded_day"] >= CHEF_MIN_AGE_DAYS and can_elect:
			_elect(state, rng, s, e)
		_council(state, rng, s, e)


static func _elect(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> void:
	var heir = Dynasties.heir(state, rng, s, e)
	var p = heir
	if p == null:
		var pool: Array = e["people"].filter(func(q): return q["job"] != "enfant" and q["job"] != "chef" and People.age_of(state, q) >= 20)
		if pool.is_empty():
			return
		var weights: Array = pool.map(func(q): return _weight(q))
		var r: float = rng.next() * weights.reduce(func(a, b): return a + b, 0.0)
		p = pool[-1]
		for i in pool.size():
			r -= weights[i]
			if r <= 0:
				p = pool[i]
				break
	p["job"] = "chef"
	s["chef"] = p["id"]
	s["chef_since"] = state["day"]
	s["council"] = s.get("council", []).filter(func(id): return id != p["id"])
	if heir != null:
		Dynasties.announce(state, s, p)
		return
	Dynasties.found(state, s, p)
	var female: bool = p["sex"] == "F"
	var title := "cheffe" if female else "chef"
	var text := "👑 %s devient %s %s." % [p["name"], title, Names.of_place(s["name"])]
	if p["traits"].has("sociable"):
		text = "👑 %s, %s de tous, devient %s %s." % [p["name"], "aimée" if female else "aimé", title, Names.of_place(s["name"])]
	elif p["traits"].has("agressif"):
		text = "👑 %s prend le pouvoir à %s." % [p["name"], s["name"]]
	Journal.log_event(state, "chef", text, {"x": s["x"], "y": s["y"], "person": p["id"], "settlement": s["id"]})


static func _lose_chef(state: Dictionary, rng: Rng, s: Dictionary) -> void:
	var p = People.by_id(state, s["chef"])
	if p != null and p["alive"]:
		if p["job"] == "chef":
			p["job"] = "cueilleur"
		Journal.log_event(state, "chef", "👑 %s quitte %s ; la colonie n'a plus de chef." % [p["name"], s["name"]], {"x": s["x"], "y": s["y"], "person": p["id"]})
	else:
		var title := "sa cheffe" if p != null and p["sex"] == "F" else "son chef"
		Journal.log_event(state, "chef", "👑 %s pleure %s%s." % [s["name"], title, " " + p["name"] if p != null else ""], {"x": s["x"], "y": s["y"]})
	s["chef"] = -1
	s["chef_vacant_until"] = state["day"] + rng.range_int(10, 30)


static func _maybe_revolt(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, chef: Dictionary) -> void:
	if state["day"] - s.get("chef_since", 0) < REVOLT_MIN_DAYS or not rng.chance(REVOLT_CHANCE):
		return
	var mood := 0.0
	for p in e["people"]:
		mood += p["happiness"]
	if mood / max(1, e["pop"]) >= REVOLT_UNHAPPY:
		return
	chef["job"] = "cueilleur"
	chef["happiness"] = 10.0
	s["chef"] = -1
	s["chef_vacant_until"] = state["day"] + rng.range_int(20, 60)
	var bloody: bool = chef["traits"].has("agressif") and rng.chance(0.5)
	if bloody:
		People.kill(state, chef, "lors de la révolte")
	var fate := "est tué%s par la foule" % ("e" if chef["sex"] == "F" else "") if bloody else "est %s du pouvoir" % ("chassée" if chef["sex"] == "F" else "chassé")
	Journal.log_event(state, "revolution", "✊ Révolte à %s ! Lassés de la misère, les habitants se soulèvent : %s %s." % [s["name"], chef["name"], fate], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})


static func _council(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> void:
	var ids := {}
	for p in e["people"]:
		ids[p["id"]] = true
	s["council"] = s.get("council", []).filter(func(id): return ids.has(id))
	if e["pop"] < COUNCIL_MIN_POP:
		return
	var seats := 5 if Techs.has_tech(s, "lois") else 3
	if s["council"].size() < seats and rng.chance(0.03):
		var pool: Array = e["people"].filter(func(p): return p["id"] != s.get("chef", -1) and not s["council"].has(p["id"]) and People.age_of(state, p) >= 25)
		if not pool.is_empty():
			s["council"].append(rng.pick(pool)["id"])
	if s["council"].size() >= 3 and s.get("council_day", -1) < 0:
		s["council_day"] = state["day"]
		var names: Array = s["council"].map(func(id): return People.by_id(state, id)["name"])
		Journal.log_event(state, "conseil", "🏛️ Un conseil de sages se forme à %s : %s." % [s["name"], Miracles.list_names(names)], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
