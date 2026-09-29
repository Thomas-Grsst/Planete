class_name FaithSpread
extends RefCounted

const SPREAD_CHANCE := 0.004
const MIN_POP := 8
const MIN_DEVOTION := 25.0
const LAND_RANGE := 14
const CONVERT_DEVOTION := 30.0
const BASE_ODDS := 0.6
const TEMPLE_RESIST := 1.5
const HOLY_RESIST := 0.25
const RECENT_CONVERT_DAYS := 720
const RECENT_CONVERT_RESIST := 0.3
const MAX_ODDS := 0.95


static func _target(state: Dictionary, rng: Rng, s: Dictionary, rel: Dictionary) -> Variant:
	var options: Array = state["settlements"].filter(func(o): return o["abandoned"] < 0 and o["id"] != s["id"] and o.get("faith", -1) != rel["id"] \
		and absi(o["x"] - s["x"]) + absi(o["y"] - s["y"]) <= LAND_RANGE and Regions.same_landmass(state["world"], s["x"], s["y"], o["x"], o["y"]))
	return rng.pick(options) if not options.is_empty() else null


static func _persuades(state: Dictionary, rng: Rng, s: Dictionary, target: Dictionary) -> bool:
	var odds := BASE_ODDS
	var old = Religions.of(state, target)
	if old != null:
		odds *= s["devotion"] / (s["devotion"] + target["devotion"] * (TEMPLE_RESIST if target["temple"] > 0 else 1.0))
		if old["holy"] == target["id"]:
			odds *= HOLY_RESIST
	if state["day"] - target["converted_day"] < RECENT_CONVERT_DAYS:
		odds *= RECENT_CONVERT_RESIST
	return rng.chance(min(MAX_ODDS, odds))


static func _missionary(state: Dictionary, rng: Rng, e: Dictionary) -> Variant:
	var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p))
	var eager: Array = adults.filter(func(p): return p["traits"].has("sociable") or p["traits"].has("aventurier"))
	if not eager.is_empty():
		return rng.pick(eager)
	return rng.pick(adults) if not adults.is_empty() else null


static func spread(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary, rel: Dictionary) -> void:
	if e["pop"] < MIN_POP or s["devotion"] < MIN_DEVOTION:
		return
	if not rng.chance(SPREAD_CHANCE * (s["devotion"] / 100.0) * (1.0 + 0.5 * s["temple"])):
		return
	var target = _target(state, rng, s, rel)
	if target == null or not _persuades(state, rng, s, target):
		return
	var missionary = _missionary(state, rng, e)
	var old = Religions.of(state, target)
	Religions.adopt(state, target, rel, CONVERT_DEVOTION)
	var who := "Des pèlerins %s convertissent %s" % [Names.of_place(s["name"]), target["name"]]
	if missionary != null:
		who = "%s %s, %s convertit %s" % ["Venue" if missionary["sex"] == "F" else "Venu", Names.of_place(s["name"]), missionary["name"], target["name"]]
	var extra := {"x": target["x"], "y": target["y"], "settlement": target["id"], "from": s["id"], "religion": rel["id"]}
	if missionary != null:
		extra["person"] = missionary["id"]
	Journal.log_event(state, "conversion", "🕯️ %s %s%s." % [who, FaithData.to_name(rel["name"]), ", qui abandonne %s" % old["name"] if old != null else ""], extra)
