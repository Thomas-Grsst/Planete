extends Node

const TOTAL_SECONDS := 30.0
const MIN_STEP := 0.25
const MAX_STEP := 1.2

var hud
var entries: Array = []
var index := 0
var step := 0.5
var timer := 0.0
var banner: Label
var saved_speed := 1.0


func start(owner_hud) -> void:
	hud = owner_hud
	entries = Sim.state.get("chronicle", []).filter(func(e): return e.has("x"))
	if entries.is_empty():
		hud.toast("📖 Il n'y a encore rien à rejouer.")
		queue_free()
		return
	step = clamp(TOTAL_SECONDS / entries.size(), MIN_STEP, MAX_STEP)
	saved_speed = Sim.speed
	Sim.speed = 0.0
	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 120
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.root.add_child(banner)


func _process(delta: float) -> void:
	if entries.is_empty():
		return
	timer -= delta
	if timer > 0.0:
		return
	if index >= entries.size():
		_finish()
		return
	var e: Dictionary = entries[index]
	index += 1
	timer = step
	banner.text = "⏪ An %d" % (e["day"] / 360 + 1)
	hud.focus_requested.emit(Iso.ground(Sim.state["world"], e["x"], e["y"]))
	hud.toast(e["text"])


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_finish()


func _finish() -> void:
	Sim.speed = saved_speed
	if banner != null:
		banner.queue_free()
	hud.toast("📖 Fin du voyage dans le temps. Retour au présent.")
	queue_free()
