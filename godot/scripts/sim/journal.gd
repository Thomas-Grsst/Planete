class_name Journal
extends RefCounted

const CAP := 1500
const HISTORY_CAP := 30
const RARE := ["fondation", "decouverte", "croissance", "grande_famine", "disparition", "extinction", "catastrophe", "chef"]
const PRIORITY := {"extinction": 95, "decouverte": 60, "fondation": 40, "croissance": 30, "grande_famine": 30, "disparition": 25, "catastrophe": 20, "chef": 30}

static var fresh: Array = []


static func log_event(state: Dictionary, type: String, text: String, extra: Dictionary = {}) -> Dictionary:
	state["journal_seq"] += 1
	var entry := {"seq": state["journal_seq"], "day": state["day"], "type": type, "text": text}
	entry.merge(extra)
	state["journal"].append(entry)
	if state["journal"].size() > CAP:
		state["journal"] = state["journal"].slice(state["journal"].size() - CAP)
	var counts: Dictionary = state["pending_summary"]
	counts[type] = counts.get(type, 0) + 1
	if extra.has("person"):
		var p = People.by_id(state, extra["person"])
		if p != null:
			remember(state, p, text)
	if is_rare(entry):
		state["pending_highlights"].append(entry)
		if state["pending_highlights"].size() > 12:
			state["pending_highlights"].pop_front()
	fresh.append(entry)
	return entry


static func remember(state: Dictionary, p: Dictionary, text: String) -> void:
	p["history"].append({"day": state["day"], "text": text})
	if p["history"].size() > HISTORY_CAP:
		p["history"].pop_front()


static func is_rare(entry: Dictionary) -> bool:
	return RARE.has(entry["type"]) or entry.get("highlight", false)


static func format_day(day: int) -> String:
	return "An %d, jour %d" % [day / 360 + 1, day % 360 + 1]


static func take_fresh() -> Array:
	var out := fresh
	fresh = []
	return out
