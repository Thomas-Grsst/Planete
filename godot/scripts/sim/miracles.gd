class_name Miracles
extends RefCounted

const ANSWERED_DEVOTION := 40.0
const WITNESS_DEVOTION := 12.0
const MATCHING_DEVOTION := 10.0
const DOUBT_DEVOTION := 15.0


static func _legend_name(state: Dictionary, rng: Rng, kind: String) -> String:
	var year: int = state["day"] / 360 + 1
	var taken := {}
	for l in state["legends"]:
		taken[l["name"]] = true
	var names: Array = FaithData.SOURCES[kind]["legends"].map(func(n): return "%s de l'An %d" % [n, year])
	var free: Array = names.filter(func(n): return not taken.has(n))
	return rng.pick(free) if not free.is_empty() else "%s (bis)" % rng.pick(names)


static func list_names(names: Array) -> String:
	if names.size() > 3:
		return "%s, %s et %d autres colonies" % [names[0], names[1], names.size() - 2]
	if names.size() > 1:
		return "%s et %s" % [", ".join(names.slice(0, -1)), names[-1]]
	return names[0] if not names.is_empty() else ""


static func record(state: Dictionary, rng: Rng, kind: String) -> Dictionary:
	Religions.ensure(state)
	state["next_id"] += 1
	var legend := {"id": state["next_id"], "kind": kind, "day": state["day"], "name": _legend_name(state, rng, kind), "answered": []}
	Religions.remember_legend(state, legend)
	var groups := {}
	var answered_ids: Array = []
	for s in state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		var rel = Religions.of(state, s)
		var need: String = s["prayer"].get("need", "")
		if need != "" and FaithData.PRAYERS[need]["answers"].has(kind):
			_answer(state, s, rel, kind, legend, need, groups)
			legend["answered"].append(s["name"])
			answered_ids.append(s["id"])
		else:
			_witness(state, s, rel, kind, legend)
	_tell(state, kind, legend, groups)
	var verb := "entrent" if legend["name"].begins_with("les ") else "entre"
	Journal.log_event(state, "legende", "📖 %s %s dans les récits des anciens." % [FaithData.capitalize(legend["name"]), verb])
	var names: Array = legend["answered"]
	var echo := "" if names.is_empty() else "✨ %s %s au miracle !" % [list_names(names), "crient" if names.size() > 1 else "crie"]
	return {"echo": echo, "answered": answered_ids, "legend": legend}


static func _answer(state: Dictionary, s: Dictionary, rel, kind: String, legend: Dictionary, need: String, groups: Dictionary) -> void:
	s["prayer"] = {}
	var faithful := Religions.is_player(rel)
	if faithful:
		s["devotion"] = min(100.0, s["devotion"] + ANSWERED_DEVOTION)
	else:
		s["awe"] = {"kind": kind, "day": state["day"], "legend": legend["id"], "answered": true}
	if rel != null and not faithful:
		s["devotion"] = max(0.0, s["devotion"] - DOUBT_DEVOTION)
	var key := "%d|%s" % [rel["id"] if rel != null else -1, need]
	if not groups.has(key):
		groups[key] = {"rel": rel, "need": need, "places": []}
	groups[key]["places"].append(s)


static func _witness(state: Dictionary, s: Dictionary, rel, kind: String, legend: Dictionary) -> void:
	if Religions.is_player(rel):
		s["devotion"] = min(100.0, s["devotion"] + WITNESS_DEVOTION + (MATCHING_DEVOTION if rel["source"] == kind else 0.0))
	elif rel == null and not s["awe"].get("answered", false):
		s["awe"] = {"kind": kind, "day": state["day"], "legend": legend["id"], "answered": false}


static func _tell(state: Dictionary, kind: String, legend: Dictionary, groups: Dictionary) -> void:
	var sign: String = FaithData.SOURCES[kind]["sign"]
	for g in groups.values():
		var places: Array = g["places"]
		var names := list_names(places.map(func(s): return s["name"]))
		var plural := places.size() > 1
		var wish: String = FaithData.PRAYERS[g["need"]]["wish"]
		var rel = g["rel"]
		var text := "✨ %s %s le ciel pour %s, et %s. Personne n'oubliera %s." % [names, "imploraient" if plural else "implorait", wish, sign, legend["name"]]
		if Religions.is_player(rel):
			text = "✨ %s %s %s pour %s, et %s ! Les fidèles crient au miracle." % [names, "priaient" if plural else "priait", rel["deity"], wish, sign]
		elif rel != null:
			text = "✨ %s %s %s pour %s, et %s… mais qui a répondu ? Le doute gagne les fidèles %s." % [names, "priaient" if plural else "priait", rel["deity"], wish, sign, FaithData.of_name(rel["name"])]
		var ids: Array = places.map(func(s): return s["id"])
		Journal.log_event(state, "miracle", text, {"x": places[0]["x"], "y": places[0]["y"], "settlements": ids, "highlight": true})
