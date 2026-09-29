class_name Powers
extends RefCounted

const FORCED_DAYS := 10
const SKIP_DAYS := 30
const MIRACLES := ["rain", "sun", "grow"]
const LIST := [
	["rain", "🌧️ Pluie", "10 jours de pluie"],
	["sun", "☀️ Soleil", "10 jours de soleil"],
	["grow", "🌱 Végétation", "la nature explose"],
	["skip", "⏩ Avancer", "30 jours passent"],
]


static func apply(state: Dictionary, name: String) -> String:
	match name:
		"rain":
			state["powers"]["rain"] = FORCED_DAYS
			state["powers"]["sun"] = 0
			state["weather"] = "rain"
			Journal.log_event(state, "meteo", "🌧️ Une pluie providentielle tombe du ciel.")
			return "🌧️ Une pluie providentielle tombe du ciel."
		"sun":
			state["powers"]["sun"] = FORCED_DAYS
			state["powers"]["rain"] = 0
			state["weather"] = "sun"
			Journal.log_event(state, "meteo", "☀️ Le ciel se dégage soudainement.")
			return "☀️ Le ciel se dégage."
		"grow":
			_grow(state)
			Journal.log_event(state, "meteo", "🌱 La végétation explose partout dans le monde.")
			return "🌱 La végétation explose."
	return ""


static func _grow(state: Dictionary) -> void:
	for t in state["world"]["tiles"]:
		if t["fertility"] <= 0.3:
			continue
		t["food"] = max(t["food"], t["fertility"] * 12.0)
		if t["biome"] == "forest" and t["trees"] < 9:
			t["trees"] += 2
