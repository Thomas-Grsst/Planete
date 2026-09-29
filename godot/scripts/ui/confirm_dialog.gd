extends PanelContainer

signal confirmed

var title := ""
var message := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var head := Label.new()
	head.text = title
	box.add_child(head)
	var body := Label.new()
	body.text = message
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(queue_free)
	row.add_child(cancel)
	var ok := Button.new()
	ok.text = "Oui"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func(): confirmed.emit(); queue_free())
	row.add_child(ok)
	position -= size * 0.5
