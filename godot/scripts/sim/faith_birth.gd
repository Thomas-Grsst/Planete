class_name FaithBirth
extends RefCounted

const MAX_RELIGIONS := 6
const MAX_WITH_SCHISMS := 8
const AWE_DAYS := 360
const ANSWERED_CHANCE := 0.04
const WITNESS_CHANCE := 0.0004
const ECHO_FACTOR := 0.15
const STORM_CHANCE := 0.0003
const GRIEF_CHANCE := 0.002
const GRIEF_DEATHS := 3
const ANCESTORS_CHANCE := 0.0001
const ANCESTORS_AGE_DAYS := 3600
const BIRTH_MIN_POP := 10
const NATURAL_MIN_POP := 20
const PROPHET_MIN_AGE := 20
const CONVERT_CHANCE := 0.03
const JOIN_DEVOTION := 55.0
const SCHISM_MIN_AGE_DAYS := 3600
const SCHISM_RANGE := 16
const SCHISM_CHANCE := 0.00008
const SCHISM_MIN_POP := 20
const SCHISM_MIN_DEVOTION := 30.0


static func _prophet(state: Dictionary, rng: Rng, e: Dictionary) -> Variant:
	var adults: Array = e["people"].filter(func(p): return p.get("prophet_of", -1) < 0 and People.age_of(state, p) >= PROPHET_MIN_AGE)
	if adults.is_empty():
		return null
	var weights: Array = adults.map(func(p): return 1.0 + (3.0 if p["traits"].has("sociable") else 0.0) + (2.0 if p["traits"].has("curieux") else 0.0) + (1.0 if p["traits"].has("prudent") else 0.0))
	var r: float = rng.next() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in adults.size():
		r -= weights[i]
		if r <= 0:
			return adults[i]
	return adults[-1]


static func _awe_origin(state: Dictionary, s: Dictionary) -> Dictionary:
	var awe: Dictionary = s["awe"]
	if awe.is_empty() or state["day"] - awe["day"] > AWE_DAYS:
		return {}
	if awe["answered"]:
		return {"source": awe["kind"], "chance": ANSWERED_CHANCE}
	var echoed: bool = Religions.alive(state).any(func(r): return r["legends"].has(awe["legend"]))
	return {"source": awe["kind"], "chance": WITNESS_CHANCE * (ECHO_FACTOR if echoed else 1.0)}


static func _natural_origin(state: Dictionary, s: Dictionary, e: Dictionary) -> Dictionary:
	if e["pop"] < NATURAL_MIN_POP or not Techs.has_tech(s, "feu"):
		return {}
	if Faith.mourning(state, s, 60) >= GRIEF_DEATHS:
		return {"source": "ancestors", "chance": GRIEF_CHANCE}
	if state["weather"] == "storm":
		return {"source": "storm", "chance": STORM_CHANCE}
	if state["day"] - s["founded_day"] >= ANCESTORS_AGE_DAYS:
		return {"source": "ancestors", "chance": ANCESTORS_CHANCE}
	return {}


static func _found(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, source: String, intro: String = "") -> Variant:
	var prophet = _prophet(state, rng, e)
	if prophet == null:
		return null
	var legend = Religions.legend_by_id(state, s["awe"].get("legend", -1))
	var rel := Religions.create(state, rng, s, prophet, source)
	var fields := {"religion": rel["name"], "deity": rel["deity"]}
	if legend != null:
		fields["legend"] = legend["name"]
	var story := FaithData.tell(FaithData.SOURCES[source]["founding"], prophet, s, fields)
	Journal.log_event(state, "religion", intro + story, {"x": s["x"], "y": s["y"], "person": prophet["id"], "settlement": s["id"], "religion": rel["id"]})
	return rel


static func _join_sibling(state: Dictionary, s: Dictionary, old) -> bool:
	var legend_id: int = s["awe"].get("legend", -1)
	if legend_id < 0:
		return false
	var siblings: Array = Religions.alive(state).filter(func(r): return r["origin_legend"] == legend_id)
	if siblings.is_empty():
		return false
	var sibling: Dictionary = siblings[0]
	var legend = Religions.legend_by_id(state, legend_id)
	Religions.adopt(state, s, sibling, JOIN_DEVOTION)
	s["awe"] = {}
	var leaving := ", abandonnant %s" % old["name"] if old != null else ""
	Journal.log_event(state, "conversion", "✨ Après %s, %s rejoint %s%s." % [legend["name"] if legend != null else "le miracle", s["name"], sibling["name"], leaving], {"x": s["x"], "y": s["y"], "settlement": s["id"], "religion": sibling["id"]})
	return true


static func try_birth(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> void:
	if e["pop"] < BIRTH_MIN_POP:
		return
	var origin := _awe_origin(state, s)
	if origin.is_empty():
		origin = _natural_origin(state, s, e)
	if origin.is_empty() or not rng.chance(origin["chance"]):
		return
	if not s["awe"].is_empty() and _join_sibling(state, s, null):
		return
	if Religions.alive(state).size() < MAX_RELIGIONS:
		_found(state, rng, s, e, origin["source"])


static func try_conversion(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, rel: Dictionary) -> bool:
	var awe: Dictionary = s["awe"]
	if awe.is_empty() or not awe["answered"] or state["day"] - awe["day"] > AWE_DAYS or not rng.chance(CONVERT_CHANCE):
		return false
	if _join_sibling(state, s, rel):
		return true
	if Religions.alive(state).size() >= MAX_WITH_SCHISMS:
		return false
	return _found(state, rng, s, e, awe["kind"], "✨ Après le miracle, %s abandonne %s. " % [s["name"], rel["name"]]) != null


static func try_schism(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, rel: Dictionary) -> void:
	if s["id"] == rel["holy"] or e["pop"] < SCHISM_MIN_POP or s["devotion"] < SCHISM_MIN_DEVOTION:
		return
	if state["day"] - rel["founded_day"] < SCHISM_MIN_AGE_DAYS or not rng.chance(SCHISM_CHANCE):
		return
	var holy = Settlements.by_id(state, rel["holy"])
	if holy != null and absi(holy["x"] - s["x"]) + absi(holy["y"] - s["y"]) <= SCHISM_RANGE:
		return
	if Religions.alive(state).size() >= MAX_WITH_SCHISMS or Religions.members(state, rel).size() < 3:
		return
	var prophet = _prophet(state, rng, e)
	if prophet == null:
		return
	var schism := Religions.create(state, rng, s, prophet, rel["source"], rel)
	var text := "⚡ Schisme ! À %s, %s rejette l'autorité %s : %s se séparent %s." % [s["name"], prophet["name"], Names.of_place(rel["holy_name"]), schism["name"], FaithData.of_name(rel["name"])]
	Journal.log_event(state, "schisme", text, {"x": s["x"], "y": s["y"], "person": prophet["id"], "settlement": s["id"], "religion": schism["id"]})
