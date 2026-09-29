class_name Weather
extends RefCounted

const KINDS := ["sun", "sun", "cloud", "rain", "rain", "storm", "drought"]
const ICONS := {"sun": "☀️", "cloud": "☁️", "rain": "🌧️", "storm": "⛈️", "drought": "🔥", "snow": "❄️"}
const LABELS := {"sun": "soleil", "cloud": "nuageux", "rain": "pluie", "storm": "tempête", "drought": "sécheresse", "snow": "neige"}
const NEWS := {"storm": "⛈️ Une tempête éclate.", "drought": "🔥 Une sécheresse frappe la région.", "snow": "❄️ La neige recouvre le monde."}
const SEASONS := ["printemps", "été", "automne", "hiver"]


static func season(day: int) -> int:
	return (day % 360) / 90


static func step(state: Dictionary, rng: Rng) -> void:
	var forced: Dictionary = state["powers"]
	if forced.get("rain", 0) > 0:
		forced["rain"] -= 1
		state["weather"] = "rain"
		return
	if forced.get("sun", 0) > 0:
		forced["sun"] -= 1
		state["weather"] = "sun"
		return
	state["weather_days"] -= 1
	if state["weather_days"] > 0:
		return
	var next: String = rng.pick(KINDS)
	var s := season(state["day"])
	if s == 3 and rng.chance(0.4):
		next = "snow"
	if next == "drought" and s != 1:
		next = "sun"
	state["weather_days"] = rng.range_int(5, 18)
	if next == state["weather"]:
		return
	state["weather"] = next
	if NEWS.has(next):
		Journal.log_event(state, "meteo", NEWS[next])
