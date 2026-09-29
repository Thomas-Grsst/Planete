class_name Lore
extends RefCounted

const ROOT_KEEPERS := 8
const ROOT_SHARE := 0.25
const APPRENTICE_CHANCE := 0.008
const MAX_APPRENTICE_CHANCE := 0.3
const APPRENTICE_AGE := 10


static func _ensure(s: Dictionary) -> void:
	if not s.has("rooted"):
		s["rooted"] = s["techs"].duplicate()
	if not s.has("keeper_name"):
		s["keeper_name"] = {}


static func teach(p: Dictionary, key: String) -> void:
	if not p.has("knows"):
		p["knows"] = []
	if not p["knows"].has(key):
		p["knows"].append(key)


static func learned(s: Dictionary, key: String, who) -> void:
	_ensure(s)
	if who != null:
		teach(who, key)
	elif not s["rooted"].has(key):
		s["rooted"].append(key)
	_root_if_written(s, key)


static func _root_if_written(s: Dictionary, key: String) -> void:
	if not s["rooted"].has("ecriture") and key != "ecriture":
		return
	if not s["rooted"].has(key):
		s["rooted"].append(key)
	if key == "ecriture":
		for k in s["techs"]:
			if not s["rooted"].has(k):
				s["rooted"].append(k)


static func is_fragile(s: Dictionary, key: String) -> bool:
	return s.has("rooted") and not s["rooted"].has(key)


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		if e["pop"] <= 0:
			continue
		var s: Dictionary = e["s"]
		_ensure(s)
		var counts := {}
		var keeper := {}
		for p in e["people"]:
			for k in p.get("knows", []):
				counts[k] = counts.get(k, 0) + 1
				keeper[k] = p
		_refresh(state, s, counts, e["pop"])
		_apprentice(state, rng, s, e["people"], counts, keeper)


static func _refresh(state: Dictionary, s: Dictionary, counts: Dictionary, pop: int) -> void:
	var writing: bool = s["rooted"].has("ecriture")
	for k in counts:
		if not s["rooted"].has(k) and (writing or counts[k] >= max(ROOT_KEEPERS, pop * ROOT_SHARE)):
			s["rooted"].append(k)
	var next: Array = Techs.ORDER.filter(func(k): return s["rooted"].has(k) or counts.get(k, 0) > 0)
	for k in s["techs"]:
		if Techs.DATA.has(k) and not next.has(k):
			var who: String = s["keeper_name"].get(k, "")
			var since := " depuis que %s n'est plus là" % who if who != "" else ""
			Journal.log_event(state, "savoir_perdu", "🕯️ Plus personne à %s ne connaît le secret %s%s." % [s["name"], Techs.DATA[k]["de"], since], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})
			s["lost_lore_day"] = state["day"]
	s["techs"] = next


static func _apprentice(state: Dictionary, rng: Rng, s: Dictionary, people: Array, counts: Dictionary, keeper: Dictionary) -> void:
	for k in counts:
		if s["rooted"].has(k) or not Techs.DATA.has(k):
			continue
		var master: Dictionary = keeper[k]
		s["keeper_name"][k] = master["name"]
		if not rng.chance(min(MAX_APPRENTICE_CHANCE, APPRENTICE_CHANCE * counts[k])):
			continue
		var pool: Array = people.filter(func(p): return not p.get("knows", []).has(k) and People.age_of(state, p) >= APPRENTICE_AGE)
		if pool.is_empty():
			continue
		var kin: Array = pool.filter(func(p): return p["parents"].has(master["id"]))
		var learner: Dictionary = rng.pick(kin) if not kin.is_empty() and rng.chance(0.5) else rng.pick(pool)
		teach(learner, k)
		Journal.remember(state, learner, "📖 %s apprend le secret %s auprès de %s." % [learner["name"], Techs.DATA[k]["de"], master["name"]])
