extends Node

signal day_passed(day: int)
signal event_logged(entry: Dictionary)
signal world_loaded
signal catch_up_progress(done: int, total: int)
signal caught_up(days: int)
signal power_used(name: String, answered: Array)
signal resumed(days: int)

const MS_PER_DAY := 300000.0
const MAX_OFFLINE_DAYS := 8640
const MAX_TICKS_PER_FRAME := 30
const AUTOSAVE_SECONDS := 20.0
const CATCH_UP_BUDGET_MS := 14
const MAX_FRAME_SECONDS := 0.5

var state: Dictionary = {}
var speed := 1.0
var persist := true
var rng := Rng.new()
var _save_timer := 0.0
var pending_days := 0
var _catch_total := 0


func start_new(world_name: String, seed_text: String = "", colony: Dictionary = {}) -> void:
	state = WorldState.create(world_name, seed_text, colony)
	_bind()


func load_existing(data: Dictionary) -> int:
	state = data
	state["pending_summary"] = {}
	state["pending_highlights"] = []
	_bind()
	return catch_up()


func _bind() -> void:
	rng = Rng.new()
	rng.state = state["rng_state"]
	Journal.take_fresh()
	world_loaded.emit()


func catch_up() -> int:
	var elapsed_ms: float = max(0.0, Time.get_unix_time_from_system() - state["last_sim_time"]) * 1000.0
	var total: float = state["acc_ms"] + elapsed_ms
	var days: int = min(MAX_OFFLINE_DAYS, int(total / MS_PER_DAY))
	state["acc_ms"] = fmod(total, MS_PER_DAY)
	state["last_sim_time"] = Time.get_unix_time_from_system()
	pending_days = days
	_catch_total = days
	return days


func _step_catch_up() -> void:
	var start := Time.get_ticks_msec()
	while pending_days > 0 and Time.get_ticks_msec() - start < CATCH_UP_BUDGET_MS:
		tick(false)
		pending_days -= 1
	catch_up_progress.emit(_catch_total - pending_days, _catch_total)
	if pending_days > 0:
		return
	Journal.take_fresh()
	world_loaded.emit()
	caught_up.emit(_catch_total)


func _process(delta: float) -> void:
	if state.is_empty():
		return
	if pending_days > 0:
		_step_catch_up()
		return
	_save_timer += delta
	if _save_timer >= AUTOSAVE_SECONDS:
		_save_timer = 0.0
		save_now()
	if speed <= 0.0:
		return
	state["acc_ms"] += minf(delta, MAX_FRAME_SECONDS) * 1000.0 * speed
	var ticks := 0
	while state["acc_ms"] >= MS_PER_DAY and ticks < MAX_TICKS_PER_FRAME:
		state["acc_ms"] -= MS_PER_DAY
		tick(true)
		ticks += 1


func tick(announce: bool = true) -> void:
	state["day"] += 1
	rng.state = state["rng_state"]
	Weather.step(state, rng)
	Work.regrow(state)
	var census := Census.build(state)
	Work.step(state, rng, census)
	People.step(state, rng, census)
	Epidemics.step(state, rng, census)
	Zombies.step(state, rng, census)
	Herds.step(state, rng)
	Settlements.step(state, rng, census)
	Wolves.step(state, rng, census)
	Jobs.step(state, rng, census)
	Governance.step(state, rng, census)
	Faith.step(state, rng, census)
	CivFormation.step(state, rng, census)
	Diplomacy.step(state, rng, census)
	Wars.step(state, rng, census)
	Lore.step(state, rng, census)
	Ideas.step(state, rng, census)
	World.step(state, rng, census)
	Exodus.step(state)
	Fame.yearly(state)
	Achievements.daily(state)
	Housekeeping.step(state)
	_check_extinction()
	state["rng_state"] = rng.state
	if not announce:
		return
	for entry in Journal.take_fresh():
		event_logged.emit(entry)
	day_passed.emit(state["day"])


func use_power(name: String) -> String:
	if state.is_empty():
		return ""
	if name == "skip":
		for i in Powers.SKIP_DAYS:
			tick(true)
		return "⏩ %d jours passent." % Powers.SKIP_DAYS
	rng.state = state["rng_state"]
	var msg := Powers.wake_dead(state, rng) if name == "zombie" else Powers.apply(state, name)
	if name == "zombie" and not msg.begins_with("☣️"):
		state["rng_state"] = rng.state
		return msg
	var miracle := Miracles.record(state, rng, name)
	state["rng_state"] = rng.state
	for entry in Journal.take_fresh():
		event_logged.emit(entry)
	power_used.emit(name, miracle["answered"])
	return msg if miracle["echo"] == "" else "%s %s" % [msg, miracle["echo"]]


func _check_extinction() -> void:
	if state["extinct"] or People.alive_count(state) > 0:
		return
	state["extinct"] = true
	Journal.log_event(state, "extinction", "🪦 Plus personne ne respire sur %s. Le silence est total." % state["name"])


func day_phase() -> float:
	return clamp(state.get("acc_ms", 0.0) / MS_PER_DAY, 0.0, 0.9999)


func hour() -> float:
	return fmod(6.0 + day_phase() * 24.0, 24.0)


func save_now() -> void:
	if persist and not state.is_empty():
		SaveStore.save(state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_resume()


func _resume() -> void:
	if not persist or state.is_empty() or pending_days > 0:
		return
	state["pending_summary"] = {}
	state["pending_highlights"] = []
	if catch_up() > 0:
		resumed.emit(pending_days)
