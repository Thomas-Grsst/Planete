class_name Civs
extends RefCounted

const COLORS := [Color("e57373"), Color("64b5f6"), Color("ffd54f"), Color("81c784"), Color("ba68c8"), Color("4db6ac"), Color("ff8a65"), Color("f06292"), Color("aed581"), Color("90a4ae")]
const REGIMES := {
	"agressif": ["Empire", "l'"], "courageux": ["Royaume", "le"], "sociable": ["Confédération", "la"], "travailleur": ["République", "la"],
	"inventif": ["Principauté", "la"], "prudent": ["Ligue", "la"], "curieux": ["Cité-État", "la"], "aventurier": ["Clan", "le"],
}


static func ensure(state: Dictionary) -> void:
	for key in ["civs", "wars"]:
		if not state.has(key):
			state[key] = []
	if not state.has("relations"):
		state["relations"] = {}


static func by_id(state: Dictionary, id: int) -> Variant:
	if id < 0:
		return null
	for c in state.get("civs", []):
		if c["id"] == id:
			return c
	return null


static func of(state: Dictionary, s: Dictionary) -> Variant:
	var c = by_id(state, s.get("civ", -1))
	return c if c != null and c["alive"] else null


static func alive(state: Dictionary) -> Array:
	return state.get("civs", []).filter(func(c): return c["alive"])


static func members(state: Dictionary, civ: Dictionary) -> Array:
	return state["settlements"].filter(func(s): return s["abandoned"] < 0 and s.get("civ", -1) == civ["id"])


static func title(civ: Dictionary, start: bool = false) -> String:
	var article: String = civ["article"] if civ["article"] == "l'" else civ["article"] + " "
	var text := "%s%s %s" % [article, civ["regime"], Names.of_place(civ["name"])]
	return FaithData.capitalize(text) if start else text


static func of_title(civ: Dictionary) -> String:
	return "du %s %s" % [civ["regime"], Names.of_place(civ["name"])] if civ["article"] == "le" else "de " + title(civ)


static func to_title(civ: Dictionary) -> String:
	return "au %s %s" % [civ["regime"], Names.of_place(civ["name"])] if civ["article"] == "le" else "à " + title(civ)


static func create(state: Dictionary, capital: Dictionary, chef) -> Dictionary:
	var regime: Array = ["Royaume", "le"]
	if chef != null:
		for t in chef["traits"]:
			if REGIMES.has(t):
				regime = REGIMES[t]
				break
	state["next_id"] += 1
	var civ := {
		"id": state["next_id"], "name": capital["name"], "regime": regime[0], "article": regime[1], "color": COLORS[state["civs"].size() % COLORS.size()],
		"capital": capital["id"], "founded_day": state["day"], "founder": chef["id"] if chef != null else -1, "founder_name": chef["name"] if chef != null else "",
		"culture": 0.0, "alive": true, "fall_day": -1, "conquests": 0, "religion": capital.get("faith", -1),
	}
	state["civs"].append(civ)
	capital["civ"] = civ["id"]
	capital["conquered_day"] = -1
	return civ


static func population(state: Dictionary, civ: Dictionary) -> int:
	var ids := {}
	for s in members(state, civ):
		ids[s["id"]] = true
	var n := 0
	for p in state["people"]:
		if p["alive"] and ids.has(p["home"]):
			n += 1
	return n


static func relation(state: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var key := "%d-%d" % [min(a["id"], b["id"]), max(a["id"], b["id"])]
	if not state["relations"].has(key):
		state["relations"][key] = {"score": 0.0, "pact": "", "truce_until": 0}
	return state["relations"][key]


static func war_between(state: Dictionary, a: Dictionary, b: Dictionary) -> Variant:
	for w in state.get("wars", []):
		if (w["a"] == a["id"] and w["b"] == b["id"]) or (w["a"] == b["id"] and w["b"] == a["id"]):
			return w
	return null


static func tech_share(state: Dictionary, civ: Dictionary) -> int:
	var known := {}
	for s in members(state, civ):
		for k in s["techs"]:
			known[k] = true
	return int(round(100.0 * known.size() / Techs.ORDER.size()))
