class_name Voyages
extends RefCounted

# Ce que les routes transportent en plus des marchandises : idées, croyances, maladies et gens.

const IDEA_CHANCE := 0.025
const FAITH_CHANCE := 0.03
const DISEASE_CHANCE := 0.12
const MARRIAGE_CHANCE := 0.012
const MIN_DEVOTION := 20.0
const CONVERT_DEVOTION := 25.0
const MARRY_MIN_AGE := 16
const MARRY_MAX_AGE := 40


static func travel(state: Dictionary, rng: Rng, census: Dictionary, r: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var pair := [a, b] if rng.chance(0.5) else [b, a]
	var from: Dictionary = pair[0]
	var to: Dictionary = pair[1]
	var sea: bool = r["kind"] == "sea"
	_disease(state, rng, census, from, to, sea)
	if rng.chance(IDEA_CHANCE):
		_idea(state, rng, census, from, to, sea)
	if rng.chance(FAITH_CHANCE):
		_faith(state, rng, census, from, to, sea)
	if rng.chance(MARRIAGE_CHANCE):
		_marriage(state, rng, census, from, to, sea)


static func _trip(from: Dictionary, to: Dictionary, sea: bool, icon: String) -> Dictionary:
	return {"voyage": {"from": from["id"], "to": to["id"], "sea": sea, "icon": icon}}


static func _by(sea: bool) -> String:
	return "par la mer" if sea else "par la route"


static func _idea(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary, sea: bool) -> void:
	var pool: Array = from["techs"].filter(func(k): return Techs.can_learn(to, k))
	if pool.is_empty():
		return
	var key: String = rng.pick(pool)
	var adults: Array = census[to["id"]]["people"].filter(func(p): return People.is_adult(state, p))
	var learner = rng.pick(adults) if not adults.is_empty() else null
	var who := "Un marin" if sea else "Un marchand"
	var story := "%s %s %s rapporte le secret %s à %s." % ["⛵" if sea else "🐪", who, Names.of_place(from["name"]), Techs.DATA[key]["de"], to["name"]]
	Ideas.discover(state, to, key, learner, from, story, _trip(from, to, sea, Techs.DATA[key]["emoji"]))


static func _faith(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary, sea: bool) -> void:
	var rel = Religions.of(state, from)
	if rel == null or to.get("faith", -1) == rel["id"] or from["devotion"] < MIN_DEVOTION or Wars.at_war(state, from, to):
		return
	if not rng.chance(from["devotion"] / 100.0) or not FaithSpread.persuades(state, rng, from, to):
		return
	var old = Religions.of(state, to)
	Religions.adopt(state, to, rel, CONVERT_DEVOTION)
	var extra := {"x": to["x"], "y": to["y"], "settlement": to["id"], "religion": rel["id"]}
	extra.merge(_trip(from, to, sea, rel["emoji"]))
	var missionary = FaithSpread.missionary(state, rng, census[from["id"]])
	var who := "Des voyageurs %s arrivés %s convertissent" % [Names.of_place(from["name"]), _by(sea)]
	if missionary != null:
		who = "%s %s %s, %s convertit" % ["Venue" if missionary["sex"] == "F" else "Venu", Names.of_place(from["name"]), _by(sea), missionary["name"]]
		extra["person"] = missionary["id"]
	var text := "%s %s %s %s%s." % ["⛵" if sea else "🕯️", who, to["name"], FaithData.to_name(rel["name"]), ", qui abandonne %s" % old["name"] if old != null else ""]
	Journal.log_event(state, "conversion", text, extra)


static func _disease(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary, sea: bool) -> void:
	var outbreak: Dictionary = from.get("outbreak", {})
	if outbreak.is_empty() or not to.get("outbreak", {}).is_empty() or census[to["id"]]["pop"] < Epidemics.MIN_POP:
		return
	if state["day"] - to.get("last_outbreak", -9999) <= Epidemics.COOLDOWN_DAYS or not rng.chance(DISEASE_CHANCE):
		return
	var d: Dictionary = Diseases.DATA[outbreak["key"]]
	var source := "%s %s" % ["un navire" if sea else "une caravane", Names.of_place(from["name"])]
	Epidemics.start(state, rng, to, census[to["id"]], outbreak["key"], from["name"], _trip(from, to, sea, d["emoji"]), source)


static func _single(state: Dictionary, p: Dictionary) -> bool:
	var age := People.age_of(state, p)
	return p["alive"] and p["partner"] < 0 and age >= MARRY_MIN_AGE and age <= MARRY_MAX_AGE and not Diseases.is_sick(p) and p.get("bitten", -1) < 0


static func _marriage(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary, sea: bool) -> void:
	if census[from["id"]]["pop"] <= Trade.MIN_POP or Wars.at_war(state, from, to):
		return
	var travellers: Array = census[from["id"]]["people"].filter(func(p): return _single(state, p) and not state["followed"].has(p["id"]))
	if travellers.is_empty():
		return
	var p: Dictionary = rng.pick(travellers)
	var hosts: Array = census[to["id"]]["people"].filter(func(q): return _single(state, q) and q["sex"] != p["sex"])
	if hosts.is_empty():
		return
	var q: Dictionary = rng.pick(hosts)
	p["home"] = to["id"]
	p["partner"] = q["id"]
	q["partner"] = p["id"]
	p["happiness"] = min(100.0, p["happiness"] + 15)
	q["happiness"] = min(100.0, q["happiness"] + 15)
	var text := "💞 %s %s %s, %s s'installe à %s pour vivre avec %s." % ["Venue" if p["sex"] == "F" else "Venu", Names.of_place(from["name"]), _by(sea), p["name"], to["name"], q["name"]]
	var extra := {"x": to["x"], "y": to["y"], "settlement": to["id"], "person": p["id"], "other": q["id"]}
	extra.merge(_trip(from, to, sea, "💞"))
	Journal.log_event(state, "couple", text, extra)
	Journal.remember(state, q, "💞 %s épouse %s, %s %s." % [q["name"], p["name"], "venue" if p["sex"] == "F" else "venu", Names.of_place(from["name"])])
