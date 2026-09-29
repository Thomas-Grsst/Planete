class_name Languages
extends RefCounted

const DRIFT_RANGE := 18
const DRIFT_CHANCE := 0.06
const SOUNDS := ["ar", "el", "ok", "yn", "is", "um", "ed", "ai", "or", "ya", "en", "ul"]
const MONUMENT_CULTURE := 40.0
const MONUMENTS := [["observatoire", "🔭 un observatoire qui scrute les étoiles", "electricite"], ["pyramide", "🔺 une grande pyramide", "architecture"]]


static func ensure(state: Dictionary, rng: Rng) -> void:
	if not state.has("languages"):
		state["languages"] = []
	for s in state["settlements"]:
		if s.get("lang", -1) < 0 and s["abandoned"] < 0:
			var parent = Settlements.by_id(state, s.get("parent", -1))
			s["lang"] = parent.get("lang", -1) if parent != null else -1
			if s["lang"] < 0:
				s["lang"] = _new(state, rng, s, "")["id"]


static func by_id(state: Dictionary, id: int) -> Variant:
	for l in state.get("languages", []):
		if l["id"] == id:
			return l
	return null


static func _new(state: Dictionary, rng: Rng, s: Dictionary, parent_name: String) -> Dictionary:
	state["next_id"] += 1
	var root: String = s["name"].substr(0, min(4, s["name"].length()))
	var lang := {"id": state["next_id"], "name": "le %s%s" % [root.to_lower(), "ien" if parent_name == "" else rng.pick(["ois", "ien", "ais", "ique"])], "sound": rng.pick(SOUNDS), "home": s["id"], "home_name": s["name"], "parent": parent_name}
	state["languages"].append(lang)
	return lang


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	if state["day"] % 360 != 0:
		return
	ensure(state, rng)
	for id in census:
		var s: Dictionary = census[id]["s"]
		var lang = by_id(state, s["lang"])
		var home = Settlements.by_id(state, lang["home"]) if lang != null else null
		if lang == null or home == null or home["id"] == s["id"]:
			continue
		var far: bool = absi(home["x"] - s["x"]) + absi(home["y"] - s["y"]) > DRIFT_RANGE or not Regions.same_landmass(state["world"], home["x"], home["y"], s["x"], s["y"])
		var linked: bool = s.get("civ", -1) >= 0 and s.get("civ", -1) == home.get("civ", -1) and Techs.has_tech(s, "ecriture")
		if far and not linked and rng.chance(DRIFT_CHANCE):
			var fresh := _new(state, rng, s, lang["name"])
			s["lang"] = fresh["id"]
			Journal.log_event(state, "langue", "🗣️ À %s, on ne parle plus tout à fait comme à %s : %s devient %s." % [s["name"], lang["home_name"], lang["name"], fresh["name"]], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})
	_monuments(state)


static func accent(state: Dictionary, s: Dictionary, name: String) -> String:
	var lang = by_id(state, s.get("lang", -1))
	if lang == null or lang["parent"] == "":
		return name
	return name.substr(0, max(2, name.length() - 1)) + lang["sound"]


static func _monuments(state: Dictionary) -> void:
	for civ in Civs.alive(state):
		var capital = Settlements.by_id(state, civ["capital"])
		if capital == null or capital.has("monument") or civ["culture"] < MONUMENT_CULTURE:
			continue
		for m in MONUMENTS:
			if Techs.has_tech(capital, m[2]):
				capital["monument"] = m[0]
				Journal.log_event(state, "monument", "🏛️ %s élève %s à %s, visible de très loin." % [Civs.title(civ, true), m[1], capital["name"]], {"x": capital["x"], "y": capital["y"], "settlement": capital["id"], "highlight": true})
				break
