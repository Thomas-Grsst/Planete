extends Node

const SETTINGS := "user://settings.cfg"
const LOOPS := ["ambient_day", "ambient_night", "rain", "fire"]
const CUES := {
	"decouverte": "chime", "religion": "bell", "temple": "bell", "miracle": "miracle", "statue": "bell",
	"guerre": "horn", "bataille": "horn", "raid": "horn", "apocalypse": "zombie", "zombie": "zombie", "naissance": "birth",
	"cataclysme": "thunder", "exode": "miracle", "succes": "chime",
}
const CUE_GAP := 1.5
const FADE := 1.5

var loops := {}
var cues := {}
var muted := false
var last_cue := -99.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		muted = cfg.get_value("audio", "muted", false)
	for key in LOOPS:
		var player := AudioStreamPlayer.new()
		player.stream = _load(key)
		player.volume_db = -60.0
		add_child(player)
		player.play()
		loops[key] = player
	for key in CUES.values():
		if not cues.has(key):
			var player := AudioStreamPlayer.new()
			player.stream = _load(key)
			player.volume_db = -6.0
			add_child(player)
			cues[key] = player
	Sim.event_logged.connect(_on_event)
	Sim.power_used.connect(func(name, answered): cue("miracle" if not answered.is_empty() else ("zombie" if name == "zombie" else "")))


func _load(key: String) -> AudioStream:
	return load("res://audio/%s.wav" % key)


func toggle() -> bool:
	muted = not muted
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS)
	return muted


func _target_levels() -> Dictionary:
	var night := Daylight.night
	var w: String = Sim.state.get("weather", "sun")
	var wet := 1.0 if w in ["rain", "storm"] else 0.0
	return {
		"ambient_day": (1.0 - night) * (1.0 - 0.7 * wet),
		"ambient_night": night * (1.0 - 0.6 * wet),
		"rain": wet,
		"fire": 0.35 + 0.4 * night,
	}


func _process(delta: float) -> void:
	if Sim.state.is_empty():
		return
	var levels := _target_levels()
	for key in loops:
		var level: float = 0.0 if muted else levels[key]
		var db := linear_to_db(max(level, 0.001)) - 8.0
		loops[key].volume_db = move_toward(loops[key].volume_db, db, delta * 60.0 / FADE)


func cue(key: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if muted or key == "" or not cues.has(key) or now - last_cue < CUE_GAP:
		return
	last_cue = now
	cues[key].play()


func _on_event(entry: Dictionary) -> void:
	var type: String = entry["type"]
	if type == "naissance" and Sim.speed > 1.0:
		return
	if type == "decouverte" and not entry.get("highlight", false):
		return
	cue(CUES.get(type, ""))
