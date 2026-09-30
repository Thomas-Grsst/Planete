class_name Forecast
extends RefCounted

const HORIZON_DAYS := 432
const SIM_SCRIPT := "res://scripts/sim/sim.gd"

var runner = null
var pops := {}
var marks := {}
var events: Array = []


func reset() -> void:
	if runner != null:
		runner.free()
	runner = null
	pops = {}
	marks = {}
	events = []


func check(state: Dictionary) -> void:
	if runner != null and marks.has(state["day"]) and marks[state["day"]] != state["rng_state"]:
		reset()


func advance(state: Dictionary, now_day: int, budget_ms: int) -> void:
	var start := Time.get_ticks_msec()
	check(state)
	if runner == null or runner.state["day"] < now_day:
		_start(state)
	if runner.state["day"] >= now_day + HORIZON_DAYS:
		return
	var keep: Array = Journal.fresh
	Journal.fresh = []
	People._indexed_state = {}
	while runner.state["day"] < now_day + HORIZON_DAYS and Time.get_ticks_msec() - start < budget_ms:
		runner.tick(false)
		_collect(Journal.take_fresh())
	People._indexed_state = {}
	Journal.fresh = keep


func prune(now_day: int) -> void:
	for d in pops.keys():
		if d < now_day:
			pops.erase(d)
			marks.erase(d)
	events = events.filter(func(e): return e["day"] > now_day)


func _start(state: Dictionary) -> void:
	reset()
	runner = load(SIM_SCRIPT).new()
	runner.persist = false
	runner.state = state.duplicate(true)
	pops[state["day"]] = People.alive_count(state)
	marks[state["day"]] = state["rng_state"]


func _collect(fresh: Array) -> void:
	var st: Dictionary = runner.state
	pops[st["day"]] = People.alive_count(st)
	marks[st["day"]] = st["rng_state"]
	for e in fresh:
		if Journal.is_rare(e) or PhoneDigest.SCORES.has(e["type"]):
			events.append({"day": e["day"], "type": e["type"], "text": e["text"], "highlight": e.get("highlight", false)})
