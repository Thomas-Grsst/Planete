extends PanelContainer

signal chosen(seed_text: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "🔑 Graine du monde"
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Écris la graine qu'un ami t'a donnée :\nvous aurez la même planète."
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(hint)
	var field := LineEdit.new()
	field.placeholder_text = "ex : noria-1234"
	field.max_length = 40
	box.add_child(field)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(queue_free)
	row.add_child(cancel)
	var create := Button.new()
	create.text = "🌱 Créer"
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.pressed.connect(func(): _confirm(field.text))
	field.text_submitted.connect(_confirm)
	row.add_child(create)
	position -= size * 0.5
	field.grab_focus()


func _confirm(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	chosen.emit(clean)
	queue_free()
