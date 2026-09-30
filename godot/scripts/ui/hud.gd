extends CanvasLayer

signal focus_requested(world_pos: Vector2)
signal rotate_requested

const SPEEDS := [[0.0, "⏸"], [1.0, "▶"], [10.0, "▶▶"], [100.0, "▶▶▶"]]
const QUIET := ["couple", "meteo", "migration"]

var root: Control
var clock: Label
var weather_icon: Label
var pop_button: Button
var speed_buttons: Array = []
var feed
var panel: PanelContainer
var panel_text: RichTextLabel
var current := {"kind": "", "id": -1}


func _ready() -> void:
	root = Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	HudActions.rotate_button(self, root)
	_build_bottom()
	_build_feed()
	_build_panel()
	Sim.event_logged.connect(_on_event)
	Sim.day_passed.connect(func(_d): _refresh_panel())
	Sim.world_loaded.connect(func(): _set_speed(Sim.speed))


func _build_top() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = 14
	root.add_child(bar)
	clock = Label.new()
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.add_theme_font_size_override("font_size", 22)
	clock.add_theme_constant_override("outline_size", 6)
	clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	bar.add_child(clock)
	weather_icon = Label.new()
	weather_icon.add_theme_font_size_override("font_size", 34)
	bar.add_child(weather_icon)
	for s in SPEEDS:
		var b := Button.new()
		b.text = s[1]
		b.custom_minimum_size = Vector2(62, 52)
		b.pressed.connect(_set_speed.bind(s[0]))
		bar.add_child(b)
		speed_buttons.append(b)
	_set_speed(Sim.speed)


func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -86
	bar.offset_bottom = -18
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	for spec in [["📜 Journal", _show.bind("journal", -1)], ["👥 0", _show.bind("stats", -1)], ["✨ Pouvoirs", _show.bind("powers", -1)], ["🌍", _show.bind("world", -1)]]:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		bar.add_child(b)
		if spec[0].begins_with("👥"):
			pop_button = b


func _build_feed() -> void:
	feed = VBoxContainer.new()
	feed.set_script(load("res://scripts/ui/feed.gd"))
	root.add_child(feed)
	feed.focus_requested.connect(func(pos): focus_requested.emit(pos))


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -620
	panel.offset_bottom = -96
	panel.offset_left = 10
	panel.offset_right = -10
	panel.visible = false
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var close := Button.new()
	close.text = "✕"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): panel.visible = false; current = {"kind": "", "id": -1})
	box.add_child(close)
	panel_text = RichTextLabel.new()
	panel_text.bbcode_enabled = true
	panel_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_text.meta_clicked.connect(_on_meta)
	box.add_child(panel_text)


func _process(_delta: float) -> void:
	if Sim.state.is_empty():
		return
	var st: Dictionary = Sim.state
	var h := Sim.hour()
	var night := h >= 19.0 or h < 6.0
	clock.text = "An %d · jour %d · %02dh %s\n%s" % [st["day"] / 360 + 1, st["day"] % 360 + 1, int(h), "🌙" if night else "☀️", st["name"]]
	weather_icon.text = Weather.ICONS.get(st["weather"], "☀️")
	pop_button.text = "👥 %d" % People.alive_count(st)


func _set_speed(value: float) -> void:
	Sim.speed = value
	for i in speed_buttons.size():
		UiTheme.active(speed_buttons[i], is_equal_approx(SPEEDS[i][0], value))


func _on_event(entry: Dictionary) -> void:
	if entry["type"] in QUIET and Sim.speed > 1.0:
		return
	if entry["type"] in ["naissance", "deces"] and Sim.speed >= 100.0:
		return
	toast(entry["text"], entry)


func toast(text: String, entry: Dictionary = {}) -> void:
	feed.add(text, entry)


func show_info(kind: String, id: int) -> void:
	if kind == "":
		return
	_show(kind, id)


func _show(kind: String, id: int) -> void:
	current = {"kind": kind, "id": id}
	panel_text.text = ""
	panel.visible = true
	_refresh_panel()


func refresh_panel() -> void:
	_refresh_panel()


func close_panel() -> void:
	panel.visible = false
	current = {"kind": "", "id": -1}


func _refresh_panel() -> void:
	if current["kind"] == "welcome" and panel_text.text != "":
		return
	if panel.visible:
		panel_text.text = InfoPanels.render(current["kind"], current["id"])


func _on_meta(meta) -> void:
	var parts: PackedStringArray = str(meta).split(":")
	if HudActions.run(self, parts):
		return
	if parts[0] == "tile":
		focus_requested.emit(Iso.ground(Sim.state["world"], int(parts[1]), int(parts[2])))
	else:
		_show(parts[0], int(parts[1]))


func start_catch_up() -> void:
	feed.show_catch_up()


func welcome(days: int) -> void:
	if days > 0:
		_show("welcome", days)
	else:
		toast("🌍 %s vit sa vie. Touche un habitant ou un village pour le découvrir." % Sim.state["name"])
