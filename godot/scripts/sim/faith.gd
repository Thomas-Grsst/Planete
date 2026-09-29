class_name Faith
extends RefCounted

const DEVOTION_PULL := 0.001
const BASE_DEVOTION := 35.0
const TEMPLE_DEVOTION := 15.0
const HOLY_DEVOTION := 10.0
const PROPHET_DEVOTION := 10.0
const DOUBT_AFTER_DAYS := 60
const DOUBT_RATE := 0.05
const APOSTASY_BELOW := 5.0
const PRAYER_LOG_GAP := 120
const MOURNING_DAYS := 30
const MOURNING_DEATHS := 2
const TEMPLE_POP := 25
const TEMPLE_MIN_DEVOTION := 45.0
const TEMPLE_WOOD := 25.0
const TEMPLE_CHANCE := 0.01
const GREAT_TEMPLE_POP := 50
const GREAT_TEMPLE_WOOD := 40.0
const GREAT_TEMPLE_CHANCE := 0.004


static func mourning(state: Dictionary, s: Dictionary, days: int) -> int:
	var m: Dictionary = s.get("mourning", {})
	return m.get("count", 0) if state["day"] - m.get("day", -99999) <= days else 0


static func note_death(state: Dictionary, s: Dictionary) -> void:
	var fresh: bool = state["day"] - s.get("mourning", {}).get("day", -99999) <= MOURNING_DAYS * 2
	s["mourning"] = {"day": state["day"], "count": (s["mourning"]["count"] + 1) if fresh else 1}


static func _need(state: Dictionary, s: Dictionary, e: Dictionary) -> String:
	if state["weather"] == "drought":
		return "drought"
	if e["hungry"] >= max(2, e["pop"] * 0.25):
		return "hunger"
	if mourning(state, s, MOURNING_DAYS) >= MOURNING_DEATHS:
		return "mourning"
	if state["weather"] == "storm":
		return "storm"
	if state["weather"] == "snow":
		return "cold"
	return ""


static func _pray(state: Dictionary, s: Dictionary, e: Dictionary, rel) -> void:
	var need := _need(state, s, e)
	if need == "":
		s["prayer"] = {}
		return
	if s["prayer"].get("need", "") == need:
		return
	s["prayer"] = {"need": need, "since": state["day"]}
	if rel == null or e["pop"] < 5 or state["day"] - s.get("prayer_log", -99999) < PRAYER_LOG_GAP:
		return
	s["prayer_log"] = state["day"]
	Journal.log_event(state, "priere", "🙏 À %s, on prie %s pour %s." % [s["name"], rel["deity"], FaithData.PRAYERS[need]["wish"]], {"x": s["x"], "y": s["y"], "settlement": s["id"]})


static func _tend(state: Dictionary, s: Dictionary, e: Dictionary, rel: Dictionary) -> void:
	var prophet: bool = e["people"].any(func(p): return p.get("prophet_of", -1) == rel["id"])
	var target: float = BASE_DEVOTION + TEMPLE_DEVOTION * s["temple"] + (HOLY_DEVOTION if s["id"] == rel["holy"] else 0.0) + (PROPHET_DEVOTION if prophet else 0.0)
	s["devotion"] += (target - s["devotion"]) * DEVOTION_PULL
	if not s["prayer"].is_empty() and state["day"] - s["prayer"]["since"] > DOUBT_AFTER_DAYS:
		s["devotion"] -= DOUBT_RATE
	if s["devotion"] >= APOSTASY_BELOW:
		return
	Journal.log_event(state, "conversion", "🕯️ À %s, on a trop prié en vain : la colonie se détourne %s." % [s["name"], FaithData.of_name(rel["name"])], {"x": s["x"], "y": s["y"]})
	Religions.leave(s)


static func _build_temple(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, rel: Dictionary) -> void:
	if s["temple"] == 0:
		if e["pop"] < TEMPLE_POP or s["devotion"] < TEMPLE_MIN_DEVOTION or s["wood"] < TEMPLE_WOOD or not rng.chance(TEMPLE_CHANCE):
			return
		s["temple"] = 1
		s["wood"] -= TEMPLE_WOOD
		Journal.log_event(state, "temple", "🛕 %s élève un temple %s." % [s["name"], FaithData.to_name(rel["deity"])], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
		return
	if s["temple"] > 1 or s["id"] != rel["holy"] or e["pop"] < GREAT_TEMPLE_POP or s["wood"] < GREAT_TEMPLE_WOOD or not rng.chance(GREAT_TEMPLE_CHANCE):
		return
	s["temple"] = 2
	s["wood"] -= GREAT_TEMPLE_WOOD
	Journal.log_event(state, "temple", "🛕 Un grand temple dédié %s domine désormais %s, ville sainte %s." % [FaithData.to_name(rel["deity"]), s["name"], FaithData.of_name(rel["name"])], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})


static func _life(state: Dictionary, census: Dictionary) -> void:
	for rel in Religions.alive(state):
		var members := Religions.members(state, rel)
		if members.is_empty():
			rel["alive"] = false
			rel["fall_day"] = state["day"]
			var years: int = (state["day"] - rel["founded_day"]) / 360
			Journal.log_event(state, "religion_fin", "🕯️ Plus aucune colonie ne suit %s, %s après sa fondation." % [rel["name"], Names.plural(years, "an") if years > 0 else "moins d'un an"])
			continue
		if not members.any(func(s): return s["id"] == rel["holy"]):
			var next: Dictionary = members[0]
			for s in members:
				if census.get(s["id"], {}).get("pop", 0) > census.get(next["id"], {}).get("pop", 0):
					next = s
			rel["holy"] = next["id"]
			rel["holy_name"] = next["name"]
			Journal.log_event(state, "religion_vie", "🛕 %s devient la ville sainte %s." % [next["name"], FaithData.of_name(rel["name"])], {"x": next["x"], "y": next["y"]})
		if rel["prophet_gone"] < 0:
			var p = People.by_id(state, rel["founder"])
			if p == null or not p["alive"]:
				rel["prophet_gone"] = state["day"]
				var title := "la prophétesse" if p != null and p["sex"] == "F" else "le prophète"
				Journal.log_event(state, "religion_vie", "🕯️ %s, %s %s, s'éteint. Ses paroles lui survivent." % [rel["founder_name"], title, FaithData.of_name(rel["name"])])


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	Religions.ensure(state)
	for id in census:
		var e: Dictionary = census[id]
		var s: Dictionary = e["s"]
		if e["pop"] <= 0:
			continue
		var rel = Religions.of(state, s)
		if rel == null and s["faith"] >= 0:
			Religions.leave(s)
		_pray(state, s, e, rel)
		if rel == null:
			FaithBirth.try_birth(state, rng, s, e)
			continue
		if not Religions.is_player(rel) and FaithBirth.try_conversion(state, rng, s, e, rel):
			continue
		_tend(state, s, e, rel)
		if s["faith"] < 0:
			continue
		_build_temple(state, rng, s, e, rel)
		FaithSpread.spread(state, rng, s, e, rel)
		FaithBirth.try_schism(state, rng, s, e, rel)
	_life(state, census)
