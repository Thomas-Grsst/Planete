class_name Ideas
extends RefCounted

const MAX_DAILY_CHANCE := 0.5
const ADULTS_REF := 15.0
const NO_THINKER_FACTOR := 0.4
const APOCALYPSE_FACTOR := 0.3
const SPREAD_RANGE := 14
const KIN_SPREAD_RANGE := 30
const KIN_SPREAD_BONUS := 3.0
const SPREAD_BASE_CHANCE := 0.004
const SPREAD_MAX_CHANCE := 0.5
const EXODUS_DELAY := 60
# Rythme des découvertes : les savoirs lents sont accélérés davantage (feu ÷3, écriture ÷6), sans toucher à la durée du jour.
const PACE_MIN := 3.0
const PACE_MAX := 6.0
const PACE_DIVISOR := 10.0


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var colonies := 0
	for id in census:
		if census[id]["pop"] >= 3:
			colonies += 1
	var share := pow(max(1, colonies), -0.75)
	for id in census:
		var e: Dictionary = census[id]
		if e["pop"] < 3:
			continue
		_think(state, rng, e, share)
		_spread(state, rng, census, e)


static func _people_factor(e: Dictionary) -> float:
	var inventors: int = min(6, e["traits"].get("inventif", 0))
	var curious: int = min(8, e["traits"].get("curieux", 0))
	var f: float = min(2.0, 0.4 + 0.6 * sqrt(e["adults"] / ADULTS_REF))
	f *= 1.0 + 0.08 * inventors + 0.04 * curious
	if inventors == 0 and curious == 0:
		f *= NO_THINKER_FACTOR
	return min(4.0, f * e["mods"]["research"])


static func _think(state: Dictionary, rng: Rng, e: Dictionary, share: float) -> void:
	var s: Dictionary = e["s"]
	var pf := _people_factor(e)
	var apocalypse: bool = state.get("zombies", {}).get("active", false)
	for key in Techs.ORDER:
		if not Techs.can_learn(s, key):
			continue
		var idea: Dictionary = IdeasData.DATA[key]
		var best = null
		for trig in idea["triggers"]:
			if (best == null or trig[1] > best[1]) and IdeaFlags.check(state, e, trig[0]):
				best = trig
		if best == null:
			continue
		var need := 1.0
		for flag in idea["needs"]:
			if IdeaFlags.check(state, e, flag):
				need *= idea["needs"][flag]
		var factor := APOCALYPSE_FACTOR if apocalypse and key != "epee" else 1.0
		if not rng.chance(min(MAX_DAILY_CHANCE, best[1] * need * pf * share * factor / paced_mean(idea["mean"]))):
			continue
		var who = _thinker(state, rng, e, Techs.DATA[key]["job"])
		if who != null:
			discover(state, s, key, who, null, _tell(best[2], who, s))
		return


static func paced_mean(mean: float) -> float:
	return mean / clamp(sqrt(mean) / PACE_DIVISOR, PACE_MIN, PACE_MAX)


static func _thinker(state: Dictionary, rng: Rng, e: Dictionary, boost_job: String) -> Variant:
	var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p))
	if adults.is_empty():
		return null
	var weights: Array = adults.map(func(p): return 1.0 + (3.0 if p["traits"].has("inventif") else 0.0) + (2.0 if p["traits"].has("curieux") else 0.0) + (1.0 if p["job"] == boost_job else 0.0))
	var r: float = rng.next() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in adults.size():
		r -= weights[i]
		if r <= 0:
			return adults[i]
	return adults[-1]


static func _tell(story: String, p: Dictionary, s: Dictionary) -> String:
	var female: bool = p["sex"] == "F"
	return story.replace("{name}", p["name"]).replace("{place}", s["name"]).replace("{Il}", "Elle" if female else "Il").replace("{il}", "elle" if female else "il")


static func discover(state: Dictionary, s: Dictionary, key: String, who, source, story: String, more: Dictionary = {}) -> void:
	if Techs.has_tech(s, key):
		return
	s["techs"].append(key)
	Lore.learned(s, key, who)
	var first: bool = not state["discoveries"].has(key)
	if first and source == null and who != null:
		state["discoveries"][key] = {"day": state["day"], "person": who["id"], "name": who["name"], "place": s["name"]}
	var extra := {"x": s["x"], "y": s["y"], "settlement": s["id"], "tech": key, "highlight": first and source == null}
	if who != null:
		extra["person"] = who["id"]
	extra.merge(more)
	var type := "diffusion" if source != null else ("decouverte" if first else "decouverte_locale")
	Journal.log_event(state, type, story if first or source != null else "🔁 " + story, extra)
	if key == "espace" and state.get("exodus", {}).is_empty():
		state["exodus"] = {"settlement": s["id"], "launch_day": state["day"] + EXODUS_DELAY}


static func _spread(state: Dictionary, rng: Rng, census: Dictionary, e: Dictionary) -> void:
	var s: Dictionary = e["s"]
	var learnable := {}
	for k in Techs.ORDER:
		if Techs.can_learn(s, k):
			learnable[k] = true
	if learnable.is_empty():
		return
	var pool: Array = []
	var best := 0.0
	var sources := {}
	for id in census:
		var o: Dictionary = census[id]["s"]
		var kin: bool = s.get("civ", -1) >= 0 and o.get("civ", -1) == s.get("civ", -1)
		if o["id"] == s["id"] or absi(o["x"] - s["x"]) + absi(o["y"] - s["y"]) > (KIN_SPREAD_RANGE if kin else SPREAD_RANGE) or Wars.at_war(state, o, s):
			continue
		for k in o["techs"]:
			if learnable.has(k) and not pool.has(k):
				pool.append(k)
				sources[k] = o
		best = max(best, census[id]["mods"]["spread"] * (KIN_SPREAD_BONUS if kin else 1.0))
	if pool.is_empty() or not rng.chance(min(SPREAD_MAX_CHANCE, SPREAD_BASE_CHANCE * pool.size() * best)):
		return
	var key: String = rng.pick(pool)
	var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p))
	var learner = rng.pick(adults) if not adults.is_empty() else null
	var source: Dictionary = sources[key]
	var who := " à %s" % learner["name"] if learner != null else ""
	discover(state, s, key, learner, source, "🧳 Un voyageur venu %s enseigne le secret %s%s, à %s." % [Names.of_place(source["name"]), Techs.DATA[key]["de"], who, s["name"]])
