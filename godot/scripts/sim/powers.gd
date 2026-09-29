class_name Powers
extends RefCounted

const FORCED_DAYS := 10
const SKIP_DAYS := 30
const MIRACLES := ["rain", "sun", "grow", "zombie"]
const ZOMBIE_MIN_POP := 6
const LIST := [
	["rain", "🌧️ Pluie", "10 jours de pluie"],
	["sun", "☀️ Soleil", "10 jours de soleil"],
	["grow", "🌱 Végétation", "la nature explose"],
	["skip", "⏩ Avancer", "30 jours passent"],
	["zombie", "☣️ Réveiller les morts", "irréversible : des habitants mourront"],
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


static func wake_dead(state: Dictionary, rng: Rng) -> String:
	if Zombies.active(state):
		return "🧟 Les morts marchent déjà."
	var left := Zombies.cooldown_left(state)
	if left > 0:
		return "🧟 La terre est encore fraîche… (dans %d j)" % left
	var census := Census.build(state)
	var options: Array = census.values().filter(func(e): return e["pop"] >= ZOMBIE_MIN_POP).map(func(e): return e["s"])
	if options.is_empty():
		return "🧟 Personne à réveiller."
	var s: Dictionary = rng.pick(options)
	if not Zombies.start(state, rng, s, "pouvoir"):
		return "🧟 Personne à réveiller."
	state["zombies"]["power_day"] = state["day"]
	state["zombies"]["powers"] = state["zombies"].get("powers", 0) + 1
	return "☣️ Une brume verte descend sur %s…" % s["name"]


static func _grow(state: Dictionary) -> void:
	for t in state["world"]["tiles"]:
		if t["fertility"] <= 0.3:
			continue
		t["food"] = max(t["food"], t["fertility"] * 12.0)
		if t["biome"] == "forest" and t["trees"] < 9:
			t["trees"] += 2
