class_name Chronicle
extends RefCounted

const CAP := 800
const ERA_YEARS := 10
const THEMES := [
	[["guerre", "bataille", "conquete", "raid"], "Le temps des épées"],
	[["epidemie", "apocalypse", "zombie", "grande_famine", "cataclysme"], "Les années noires"],
	[["religion", "schisme", "miracle", "temple"], "L'âge des prophètes"],
	[["decouverte"], "L'ère des découvertes"],
	[["civilisation", "independance", "dynastie", "alliance"], "Le temps des royaumes"],
	[["fondation", "croissance", "migration"], "L'essor des villages"],
]


static func record(state: Dictionary, entry: Dictionary) -> void:
	if not state.has("chronicle"):
		state["chronicle"] = []
	var keep := {"day": entry["day"], "type": entry["type"], "text": entry["text"]}
	for k in ["x", "y", "person"]:
		if entry.has(k):
			keep[k] = entry[k]
	state["chronicle"].append(keep)
	if state["chronicle"].size() > CAP:
		state["chronicle"].pop_front()


static func eras(state: Dictionary) -> Array:
	var out: Array = []
	var current := {}
	for e in state.get("chronicle", []):
		var era: int = e["day"] / (360 * ERA_YEARS)
		if current.is_empty() or current["era"] != era:
			current = {"era": era, "entries": []}
			out.append(current)
		current["entries"].append(e)
	for era in out:
		era["title"] = _title(era["entries"])
	return out


static func _title(entries: Array) -> String:
	var best := "Des jours paisibles"
	var best_score := 0
	for theme in THEMES:
		var score := 0
		for e in entries:
			if theme[0].has(e["type"]):
				score += 1
		if score > best_score:
			best_score = score
			best = theme[1]
	return best
