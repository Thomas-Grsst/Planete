class_name UiTheme
extends RefCounted

const PANEL := Color(0.07, 0.11, 0.15, 0.9)
const BUTTON := Color(1, 1, 1, 0.1)
const BUTTON_HOVER := Color(1, 1, 1, 0.18)
const ACCENT := Color("4caf50")
const TEXT := Color("e8eef2")
const MUTED := Color("8fa3b3")
const BORDER := Color(1, 1, 1, 0.08)


static func box(color: Color, radius: int = 14, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.border_color = BORDER
	s.set_border_width_all(1)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, 16))
	t.set_stylebox("normal", "Button", box(BUTTON, 12, 10))
	t.set_stylebox("hover", "Button", box(BUTTON_HOVER, 12, 10))
	t.set_stylebox("pressed", "Button", box(ACCENT, 12, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 21)
	t.set_font_size("bold_font_size", "RichTextLabel", 23)
	t.set_constant("line_separation", "RichTextLabel", 6)
	return t


static func active(button: Button, on: bool) -> void:
	button.add_theme_stylebox_override("normal", box(ACCENT if on else BUTTON, 12, 10))
