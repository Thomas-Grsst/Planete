extends Node2D

const LOOK := preload("res://scripts/view/villager_look.gd")
const WALK_SPEED := 0.75
const MAX_TIME_SCALE := 20.0
const ARRIVE := 0.04
const WAKE_HOUR := 6.0
const EVENING_HOUR := 17.5

var person_id := -1
var person: Dictionary
var life
var look
var tile := Vector2.ZERO
var goal := Vector2.ZERO
var walking := false
var activity := "idle"
var next_activity := ""
var timer := 0.0
var carrying := ""
var pending_carry := ""
var facing := 1.0
var step := 0.0
var selected := false
var home_id := -1
var chores := 0
var alpha := 0.0
var leaving := false
var bedtime := 21.0
var wake := 6.0
var lift := 0.0


func setup(p: Dictionary, manager) -> void:
	person = p
	person_id = p["id"]
	life = manager
	home_id = p["home"]
	look = LOOK.new(p)
	bedtime = 20.2 + (person_id % 9) * 0.2
	wake = WAKE_HOUR + (person_id % 5) * 0.15
	var village = _village()
	tile = village.door(person_id) if village != null else Vector2.ZERO
	if _is_night(Sim.hour()):
		activity = "sleep"
	else:
		tile = village.sit_spot(person_id) if village != null else tile
		alpha = 1.0
	_place()


func _place() -> void:
	position = Iso.project(tile.x, tile.y)
	lift = Iso.lift_at(Sim.state["world"], tile.x, tile.y)


func leave() -> void:
	leaving = true


func _village():
	return life.village_of(person["home"])


func _is_night(h: float) -> bool:
	return h >= bedtime or h < wake


func time_scale() -> float:
	return clamp(Sim.speed, 0.0, MAX_TIME_SCALE)


func _process(delta: float) -> void:
	if leaving:
		alpha -= delta * 0.8
		queue_redraw()
		if alpha <= 0.0:
			queue_free()
		return
	var ts := time_scale()
	if ts > 0.0:
		_think()
		_move(delta, ts)
		if not walking:
			timer -= delta * ts
	var target_alpha := 0.0 if activity == "sleep" and not walking else 1.0
	alpha = move_toward(alpha, target_alpha, delta * 1.5)
	visible = alpha > 0.01
	if visible:
		_place()
		queue_redraw()


func _think() -> void:
	var village = _village()
	if village == null:
		return
	if person["home"] != home_id:
		home_id = person["home"]
		carrying = ""
		activity = "travel"
		_walk(village.door(person_id), "idle")
		return
	if walking:
		return
	var h := Sim.hour()
	if _is_night(h):
		if activity != "sleep":
			_walk(village.door(person_id), "sleep")
		return
	if activity == "sleep":
		activity = "idle"
		timer = 0.0
	if h >= EVENING_HOUR and activity not in ["sit", "drop"]:
		if carrying != "":
			_walk(village.storage_spot(person_id), "drop")
		else:
			_walk(village.sit_spot(person_id), "sit")
		return
	if timer > 0.0 or (activity == "sit" and h >= EVENING_HOUR):
		return
	_finish(village)


func _finish(village) -> void:
	if activity == "drop":
		village.receive(carrying)
		carrying = ""
	elif pending_carry != "" and activity not in ["idle", "sit", "play", "travel"]:
		carrying = pending_carry
		pending_carry = ""
		_walk(village.storage_spot(person_id), "drop")
		return
	chores += 1
	var task: Dictionary = VillagerTasks.choose(self, village)
	pending_carry = task["carry"]
	_walk(task["goal"], task["activity"], task["duration"])


func _walk(to: Vector2, then: String, duration: float = 1.5) -> void:
	goal = to
	walking = true
	next_activity = then
	timer = duration
	if then != "sleep" and activity == "sleep":
		activity = "idle"


func _move(delta: float, ts: float) -> void:
	if not walking:
		return
	var speed := WALK_SPEED * pow(max(ts, 1.0), 0.7) * (1.3 if activity == "play" else 1.0)
	var to_goal := goal - tile
	var dist := to_goal.length()
	if dist <= ARRIVE:
		walking = false
		activity = next_activity
		timer = timer if timer > 0.0 else 1.0
		return
	var stride: float = min(dist, speed * delta)
	tile += to_goal / dist * stride
	var screen_dir := to_goal.x - to_goal.y
	if absf(screen_dir) > 0.01:
		facing = sign(screen_dir)
	step += stride * 14.0


func _draw() -> void:
	look.draw_on(self, {
		"alpha": alpha, "lift": lift, "walking": walking, "activity": activity, "step": step, "facing": facing,
		"carrying": carrying, "selected": selected, "child": not People.is_adult(Sim.state, person),
		"time": Time.get_ticks_msec() / 1000.0, "job": person["job"], "name": person["name"],
	})
