class_name Exodus
extends RefCounted


static func step(state: Dictionary) -> void:
	var exodus: Dictionary = state.get("exodus", {})
	if exodus.is_empty() or exodus.get("done", false) or state["day"] < exodus["launch_day"]:
		return
	var departing: Array = state["settlements"].filter(func(s): return s["abandoned"] < 0 and Techs.has_tech(s, "espace"))
	var homes := {}
	for s in departing:
		homes[s["id"]] = true
	var names: Array = []
	var crew: Array = []
	var remaining := 0
	for p in state["people"]:
		if not p["alive"]:
			continue
		if not homes.has(p["home"]):
			remaining += 1
			continue
		p["alive"] = false
		p["departed"] = true
		p["death_day"] = state["day"]
		Journal.remember(state, p, "🚀 S'envole vers les étoiles.")
		if names.size() < 2:
			names.append(p["name"])
		crew.append({"name": p["name"], "sex": p["sex"], "traits": p["traits"], "age": People.age_of(state, p)})
	if crew.is_empty():
		state["exodus"] = {}
		return
	var origin = Settlements.by_id(state, exodus["settlement"])
	if origin == null or origin["abandoned"] >= 0 and not homes.has(origin["id"]):
		origin = departing[0]
	for s in departing:
		s["departed"] = state["day"]
		s["abandoned"] = state["day"]
	var who: String = "%s et %s" % names if names.size() == 2 else names[0]
	Journal.log_event(state, "exode", "🚀 Le grand départ : %s quittent la planète depuis %s. %s s'envolent vers les étoiles." % [Names.plural(crew.size(), "habitant"), origin["name"], who], {"x": origin["x"], "y": origin["y"], "settlement": origin["id"], "highlight": true})
	var after := "🌍 %s restent sur %s et regardent le ciel." % [Names.plural(remaining, "habitant"), state["name"]] if remaining > 0 else "🌍 La planète est désormais silencieuse."
	Journal.log_event(state, "exode", after)
	state["ended"] = {"day": state["day"], "departed": crew.size(), "remaining": remaining, "crew": crew, "techs": origin["techs"].duplicate()}
	exodus["done"] = true
