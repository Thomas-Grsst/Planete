class_name Fame
extends RefCounted

const STATUE_FAME := 8
const REASONS := {"decouverte": "inventeur", "religion": "prophète", "civilisation": "fondateur", "chef": "chef", "hero": "héros", "fondation": "pionnier"}
const REASON_FEM := {"inventeur": "inventrice", "prophète": "prophétesse", "fondateur": "fondatrice", "chef": "cheffe", "héros": "héroïne", "pionnier": "pionnière"}
const POINTS := {"decouverte": 5, "religion": 5, "schisme": 4, "civilisation": 5, "independance": 3, "fondation": 1}


static func add(p: Dictionary, points: int, reason: String = "hero") -> void:
	p["fame"] = p.get("fame", 0) + points
	var best: Dictionary = p.get("fame_reasons", {})
	best[reason] = best.get(reason, 0) + points
	p["fame_reasons"] = best


static func title(p: Dictionary) -> String:
	var reasons: Dictionary = p.get("fame_reasons", {})
	var top := ""
	for r in reasons:
		if top == "" or reasons[r] > reasons[top]:
			top = r
	var word: String = REASONS.get(top, "héros")
	return REASON_FEM.get(word, word) if p["sex"] == "F" else word


static func on_event(state: Dictionary, entry: Dictionary) -> void:
	if not entry.has("person") or not POINTS.has(entry["type"]):
		return
	var p = People.by_id(state, entry["person"])
	if p != null and (entry["type"] != "decouverte" or entry.get("highlight", false)):
		add(p, POINTS[entry["type"]], "religion" if entry["type"] == "schisme" else ("civilisation" if entry["type"] == "independance" else entry["type"]))


static func yearly(state: Dictionary) -> void:
	for s in state["settlements"]:
		if s["abandoned"] < 0 and s.get("chef", -1) >= 0 and (state["day"] - s.get("chef_since", 0)) % 360 == 0:
			var chef = People.by_id(state, s["chef"])
			if chef != null:
				add(chef, 1, "chef")


static func on_death(state: Dictionary, p: Dictionary, home) -> void:
	if p.get("fame", 0) < STATUE_FAME or home == null:
		return
	var what := title(p)
	if not home.has("statues"):
		home["statues"] = []
	home["statues"].append({"name": p["name"], "title": what, "day": state["day"], "person": p["id"]})
	if not state.has("pantheon"):
		state["pantheon"] = []
	state["pantheon"].append({"name": p["name"], "title": what, "place": home["name"], "day": state["day"], "person": p["id"]})
	Journal.log_event(state, "statue", "🗿 %s élève une statue à %s, %s dont on se souviendra longtemps." % [home["name"], p["name"], what], {"x": home["x"], "y": home["y"], "person": p["id"], "settlement": home["id"], "highlight": true})
