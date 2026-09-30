extends Node

const PLUGIN := "PetitePlanete"
const FRAME_BUDGET_MS := 3
const PAUSE_BUDGET_MS := 400

var forecast := Forecast.new()
var plugin = null


func _ready() -> void:
	if not Engine.has_singleton(PLUGIN):
		return
	plugin = Engine.get_singleton(PLUGIN)
	plugin.requestNotificationPermission()
	plugin.clearNotifications()
	Sim.world_loaded.connect(forecast.reset)
	Sim.power_used.connect(func(_name, _answered): forecast.reset())
	Sim.day_passed.connect(func(_day): forecast.check(Sim.state))


func _exit_tree() -> void:
	forecast.reset()


func _now_day() -> int:
	return Sim.state["day"] + Sim.pending_days


func _process(_delta: float) -> void:
	if plugin == null or not Sim.persist or Sim.state.is_empty() or Sim.pending_days > 0:
		return
	forecast.advance(Sim.state, _now_day(), FRAME_BUDGET_MS)


func _notification(what: int) -> void:
	if plugin == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_publish()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		plugin.clearNotifications()


func _publish() -> void:
	if not Sim.persist or Sim.state.is_empty():
		return
	var now_day := _now_day()
	forecast.advance(Sim.state, now_day, PAUSE_BUDGET_MS)
	forecast.prune(now_day)
	var now := Time.get_unix_time_from_system()
	var widget := PhoneDigest.widget(Sim.state, forecast, now, now_day)
	var notes := PhoneDigest.notifications(Sim.state, forecast, now, now_day)
	plugin.publish(JSON.stringify(widget), JSON.stringify(notes))
