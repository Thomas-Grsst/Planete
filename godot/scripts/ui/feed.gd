extends VBoxContainer

signal focus_requested(world_pos: Vector2)

const TOAST_SECONDS := 6.0
const MAX_TOASTS := 4


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 16
	offset_right = -16
	offset_top = -330
	offset_bottom = -100
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(text: String, entry: Dictionary = {}) -> void:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, 12, 10))
	if entry.has("x"):
		b.pressed.connect(func(): focus_requested.emit(Iso.ground(Sim.state["world"], entry["x"], entry["y"])))
	add_child(b)
	while get_child_count() > MAX_TOASTS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var tween := b.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(b, "modulate:a", 0.0, 0.8)
	tween.tween_callback(b.queue_free)


func show_catch_up() -> void:
	var veil := PanelContainer.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var label := Label.new()
	label.text = "⏳ Pendant ton absence…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	veil.add_child(label)
	get_parent().add_child(veil)
	veil.position -= veil.size * 0.5
	var progress := func(done, total): label.text = "⏳ Pendant ton absence…\n%s · %d %%" % [Journal.format_day(Sim.state["day"]), done * 100 / max(1, total)]
	var finish := func(_d):
		Sim.catch_up_progress.disconnect(progress)
		veil.queue_free()
	Sim.catch_up_progress.connect(progress)
	Sim.caught_up.connect(finish, CONNECT_ONE_SHOT)
