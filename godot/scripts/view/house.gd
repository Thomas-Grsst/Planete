extends Node2D

const FLOOR := 6.0
const DOOR := Color("5a3b24")
const WINDOW_DARK := Color("3b3326")
const WINDOW_LIT := Color("ffd76a")

var village
var index := 0
var smoke: CPUParticles2D
var lamp: Sprite2D
var grow := 1.0
var style: Dictionary = {}
var lift := 0.0
var _was_lit := false


func setup(v, i: int, animate: bool, ground_lift: float) -> void:
	village = v
	lift = ground_lift
	index = i
	grow = 0.0 if animate else 1.0
	smoke = CPUParticles2D.new()
	smoke.amount = 10
	smoke.lifetime = 3.0
	smoke.position = Vector2(4, -17 - lift)
	smoke.direction = Vector2(0.3, -1)
	smoke.spread = 12.0
	smoke.gravity = Vector2(4, -6)
	smoke.initial_velocity_min = 4.0
	smoke.initial_velocity_max = 7.0
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.85, 0.85, 0.5))
	ramp.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	smoke.color_ramp = ramp
	smoke.emitting = false
	add_child(smoke)
	lamp = Daylight.glow_sprite(Color(1.0, 0.78, 0.4), 34.0)
	lamp.position = Vector2(2, -6 - lift)
	add_child(lamp)
	refresh()


func refresh() -> void:
	style = HouseStyle.of(village.settlement, index)
	var tall: float = (style["floors"] - 1) * FLOOR
	smoke.position = Vector2(4, -17 - lift - tall)
	queue_redraw()


func _process(delta: float) -> void:
	if grow < 1.0:
		grow = min(1.0, grow + delta * 1.5)
		scale = Vector2.ONE * (0.4 + 0.6 * _ease(grow))
		queue_redraw()
	var h := Sim.hour() if not Sim.state.is_empty() else 12.0
	var occupied: bool = village.alive()
	var hearth: bool = (h >= 5.5 and h < 9.0) or (h >= 17.0 and h < 22.5) or Sim.state.get("weather", "") == "snow"
	smoke.emitting = occupied and hearth and index % 3 != 2
	var lit: bool = occupied and Daylight.night > 0.3 and (h < 23.0 and h > 12.0 or h < 6.5 and h > 5.0)
	lamp.modulate.a = lerp(lamp.modulate.a, 0.55 if lit else 0.0, delta * 2.0)
	lamp.visible = lamp.modulate.a > 0.02
	if lit != _was_lit:
		_was_lit = lit
		queue_redraw()



func collapse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.1), 0.6)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0) + sin(t * PI) * 0.15


func _draw() -> void:
	draw_set_transform(Vector2(0, -lift))
	var abandoned: bool = not village.alive()
	var dim := 0.35 if abandoned else 0.0
	var wall: Color = style["wall"].darkened(dim)
	var shade: Color = style["shade"].darkened(dim)
	var roof: Color = style["roof"].darkened(dim)
	var window := WINDOW_LIT if _was_lit else WINDOW_DARK
	if style["era"] == "tent":
		_tent(wall, shade)
		return
	var w := 7.0
	var h: float = 7.0 + (style["floors"] - 1) * FLOOR
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(0, -h + 3.5), Vector2(0, 3.5), Vector2(-w, 0)]), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -h + 3.5), Vector2(w, -h), Vector2(w, 0), Vector2(0, 3.5)]), shade)
	if style["era"] == "stone":
		for f in int(style["floors"]):
			var y: float = -f * FLOOR
			draw_line(Vector2(-w, y - 1.0), Vector2(0, y + 2.5), shade, 0.6)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.62, -3.5), Vector2(-w * 0.32, -2.0), Vector2(-w * 0.32, 2.5), Vector2(-w * 0.62, 1.0)]), DOOR)
	for f in int(style["floors"]):
		var up: float = -f * FLOOR
		_window(Vector2(w * 0.3, -7.0 + 5.5 + up), window)
		if f > 0:
			_window(Vector2(-w * 0.65, -7.0 + 5.5 + up + 0.2), window, true)
			_window(Vector2(-w * 0.35, -7.0 + 5.5 + up + 1.9), window, true)
	if style["era"] == "brick":
		_flat_roof(w, h, roof)
		return
	var peak := Vector2(0, -h - 8.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 1.5, -h + 0.5), peak + Vector2(-0.5, 0), Vector2(-0.5, -h + 4.5)]), roof.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([peak, Vector2(w + 1.5, -h + 0.5), Vector2(0, -h + 4.5)]), roof.darkened(0.12))
	draw_rect(Rect2(Vector2(3, -h - 6), Vector2(2, 4)), Color("7a6a5a"))


func _window(at: Vector2, color: Color, left_face: bool = false) -> void:
	var dy := 1.7 if left_face else -1.7
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(2.45, dy), at + Vector2(2.45, dy + 3.0), at + Vector2(0, 3.0)]), color)


func _flat_roof(w: float, h: float, roof: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(0, -h - 3.5), Vector2(w, -h), Vector2(0, -h + 3.5)]), roof)
	draw_line(Vector2(-w, -h), Vector2(0, -h + 3.5), roof.darkened(0.3), 1.0)
	draw_line(Vector2(0, -h + 3.5), Vector2(w, -h), roof.darkened(0.3), 1.0)
	draw_rect(Rect2(Vector2(3, -h - 7), Vector2(2.2, 6)), Color("6d4c41"))


func _tent(hide: Color, hide_shade: Color) -> void:
	var peak := Vector2(0, -15)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), peak, Vector2(0, 3.5)]), hide)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 3.5), peak, Vector2(8, 0)]), hide_shade)
	draw_colored_polygon(PackedVector2Array([Vector2(-3.2, 1.6), Vector2(-1.2, -5), Vector2(0.4, 2.8)]), DOOR)
	for dx in [-1.5, 0.0, 1.5]:
		draw_line(peak, peak + Vector2(dx, -3), Color("6d4c2a"), 0.8)
