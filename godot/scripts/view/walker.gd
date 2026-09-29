extends Node2D

signal arrived

const SPEEDS := {"soldiers": 1.0, "caravan": 0.6, "boat": 1.1}
const MAX_TIME_SCALE := 20.0

var tile := Vector2.ZERO
var goal := Vector2.ZERO
var kind := "soldiers"
var color := Color.WHITE
var count := 3
var alpha := 0.0
var done := false
var step := 0.0
var facing := 1.0


func setup(from: Vector2, to: Vector2, walker_kind: String, tint: Color, size: int = 3) -> void:
	tile = from
	goal = to
	kind = walker_kind
	color = tint
	count = clampi(size, 1, 6)
	position = Iso.project(tile.x, tile.y)


func _process(delta: float) -> void:
	if done:
		alpha -= delta
		if alpha <= 0.0:
			queue_free()
		queue_redraw()
		return
	alpha = min(1.0, alpha + delta)
	var ts: float = clamp(Sim.speed, 0.0, MAX_TIME_SCALE)
	var to_goal := goal - tile
	if to_goal.length() < 0.05:
		done = true
		arrived.emit()
		return
	var stride: float = min(to_goal.length(), SPEEDS[kind] * pow(max(ts, 1.0), 0.7) * delta * (1.0 if ts > 0.0 else 0.0))
	tile += to_goal.normalized() * stride
	step += stride * 14.0
	if absf(to_goal.x - to_goal.y) > 0.01:
		facing = sign(to_goal.x - to_goal.y)
	position = Iso.project(tile.x, tile.y)
	queue_redraw()


func _draw() -> void:
	var lift := 0.0 if kind == "boat" else Iso.lift_at(Sim.state["world"], tile.x, tile.y)
	draw_set_transform(Vector2(0, -lift))
	match kind:
		"soldiers": _soldiers()
		"caravan": _caravan()
		"boat": _boat()


func _soldiers() -> void:
	var a := alpha
	for i in count:
		var o := Vector2((i % 3 - 1) * 5.0, (i / 3) * 3.0)
		var swing := sin(step + i) * 1.5
		draw_line(o + Vector2(-1, -4), o + Vector2(-1 + swing, 0), Color(0.3, 0.25, 0.2, a), 1.2)
		draw_line(o + Vector2(1, -4), o + Vector2(1 - swing, 0), Color(0.3, 0.25, 0.2, a), 1.2)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-2, -10), o + Vector2(2, -10), o + Vector2(2.4, -4), o + Vector2(-2.4, -4)]), Color(color, a))
		draw_circle(o + Vector2(0, -12.4), 2.1, Color(0.85, 0.7, 0.55, a))
		draw_arc(o + Vector2(0, -12.8), 2.4, PI, TAU, 6, Color(0.7, 0.72, 0.75, a), 1.4)
		draw_line(o + Vector2(3 * facing, -4), o + Vector2(3.5 * facing, -17), Color(0.45, 0.35, 0.25, a), 0.9)
	draw_line(Vector2(-6, -15), Vector2(-6, -26), Color(0.4, 0.3, 0.2, a), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -26), Vector2(2, -24), Vector2(-6, -21)]), Color(color, a))


func _caravan() -> void:
	var a := alpha
	var f := facing
	var bob := absf(sin(step)) * 0.8
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * f, -9 - bob), Vector2(2 * f, -9 - bob), Vector2(3 * f, -4), Vector2(-7 * f, -4)]), Color(0.55, 0.42, 0.28, a))
	draw_line(Vector2(3 * f, -8 - bob), Vector2(6 * f, -12 - bob), Color(0.55, 0.42, 0.28, a), 1.6)
	for x in [-5.0, 1.0]:
		draw_line(Vector2(x * f, -4), Vector2(x * f + sin(step) * 1.2, 0), Color(0.4, 0.3, 0.2, a), 1.0)
	draw_rect(Rect2(Vector2(-14 * f if f > 0 else 6, -9), Vector2(8, 5)), Color(0.45, 0.3, 0.18, a))
	draw_circle(Vector2(-12 * f, -3), 2.0, Color(0.3, 0.22, 0.15, a))
	draw_circle(Vector2(-8 * f, -3), 2.0, Color(0.3, 0.22, 0.15, a))
	draw_rect(Rect2(Vector2(-13 * f if f > 0 else 7, -12), Vector2(6, 3)), Color(color, a))


func _boat() -> void:
	var a := alpha
	var bob := sin(step * 0.3) * 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -1 + bob), Vector2(9, -1 + bob), Vector2(6, 3 + bob), Vector2(-6, 3 + bob)]), Color(0.45, 0.3, 0.2, a))
	draw_line(Vector2(0, -1 + bob), Vector2(0, -17 + bob), Color(0.35, 0.25, 0.15, a), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(1, -16 + bob), Vector2(8 * facing + 1, -5 + bob), Vector2(1, -4 + bob)]), Color(0.95, 0.93, 0.85, a))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -17 + bob), Vector2(5, -15.5 + bob), Vector2(0, -14 + bob)]), Color(color, a))
