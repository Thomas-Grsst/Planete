class_name Housekeeping
extends RefCounted

const KEEP_DEAD_DAYS := 10800
const HISTORY_KEPT := 3


static func step(state: Dictionary) -> void:
	if state["day"] % 360 != 180:
		return
	var keep := {}
	for p in state["people"]:
		if p["alive"]:
			for id in p["parents"]:
				keep[id] = true
			if p["partner"] >= 0:
				keep[p["partner"]] = true
	for id in state["followed"]:
		keep[id] = true
	for r in state.get("religions", []):
		keep[r["founder"]] = true
	for c in state.get("civs", []):
		keep[c["founder"]] = true
	for d in state["discoveries"].values():
		keep[d["person"]] = true
	var kept: Array = []
	var removed := 0
	for p in state["people"]:
		var old: bool = not p["alive"] and state["day"] - p["death_day"] > KEEP_DEAD_DAYS
		if not old or keep.has(p["id"]) or p.get("fame", 0) >= Fame.STATUE_FAME:
			if old:
				p["history"] = p["history"].slice(-HISTORY_KEPT)
			kept.append(p)
		else:
			removed += 1
	if removed > 0:
		state["people"] = kept
		state["removed_dead"] = state.get("removed_dead", 0) + removed
