extends Node2D

const WALL := Color("d8c3a0")
const WALL_SHADE := Color("b59a74")
const THATCH := Color("b8913f")
const TILES := Color("b5452f")
const DOOR := Color("5a3b24")
const WINDOW_DARK := Color("3b3326")
const WINDOW_LIT := Color("ffd76a")

var village
var index := 0
var smoke: CPUParticles2D
var lamp: Sprite2D
var grow := 1.0
var tiled := false
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
	tiled = Techs.has_tech(village.settlement, "poterie")
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
	var w := 7.0
	var h := 7.0
	var abandoned: bool = not village.alive()
	var wall := WALL.darkened(0.35) if abandoned else WALL
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(0, -h + 3.5), Vector2(0, 3.5), Vector2(-w, 0)]), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -h + 3.5), Vector2(w, -h), Vector2(w, 0), Vector2(0, 3.5)]), WALL_SHADE.darkened(0.35) if abandoned else WALL_SHADE)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.62, -3.5), Vector2(-w * 0.32, -2.0), Vector2(-w * 0.32, 2.5), Vector2(-w * 0.62, 1.0)]), DOOR)
	var window := WINDOW_LIT if _was_lit else WINDOW_DARK
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, -h + 5.5), Vector2(w * 0.65, -h + 3.8), Vector2(w * 0.65, -h + 6.8), Vector2(w * 0.3, -h + 8.5)]), window)
	var roof := (TILES if tiled else THATCH).darkened(0.3 if abandoned else 0.0)
	var peak := Vector2(0, -h - 8.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 1.5, -h + 0.5), peak + Vector2(-0.5, 0), Vector2(-0.5, -h + 4.5)]), roof.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([peak, Vector2(w + 1.5, -h + 0.5), Vector2(0, -h + 4.5)]), roof.darkened(0.12))
	draw_rect(Rect2(Vector2(3, -h - 6), Vector2(2, 4)), Color("7a6a5a"))
