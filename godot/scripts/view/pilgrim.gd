extends Node2D

signal arrived

const SPEED := 0.8
const MAX_TIME_SCALE := 20.0
const SKIN := Color("e0b08a")
const STAFF := Color("7a5a3a")

var tile := Vector2.ZERO
var goal := Vector2.ZERO
var robe := Color.WHITE
var step := 0.0
var facing := 1.0
var lift := 0.0
var alpha := 0.0
var done := false


func setup(from: Vector2, to: Vector2, color: Color) -> void:
	tile = from
	goal = to
	robe = color
	_place()


func _place() -> void:
	position = Iso.project(tile.x, tile.y)
	lift = Iso.lift_at(Sim.state["world"], tile.x, tile.y)


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
	var dist := to_goal.length()
	if dist < 0.05:
		done = true
		arrived.emit()
		return
	var stride: float = min(dist, SPEED * pow(max(ts, 1.0), 0.7) * delta * (1.0 if ts > 0.0 else 0.0))
	tile += to_goal / dist * stride
	step += stride * 14.0
	if absf(Iso.project(to_goal.x, to_goal.y).x) > 0.3:
		facing = sign(Iso.project(to_goal.x, to_goal.y).x)
	_place()
	queue_redraw()


func _draw() -> void:
	var up := Vector2(0, -lift - absf(sin(step)) * 1.0)
	var a := alpha
	var f := facing
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.5, Color(0, 0, 0, 0.22 * a))
	draw_set_transform(up)
	var swing := sin(step) * 1.5
	draw_colored_polygon(PackedVector2Array([Vector2(-2.0, -11), Vector2(2.0, -11), Vector2(3.5 + swing * 0.3, 0), Vector2(-3.5 - swing * 0.3, 0)]), Color(robe, a))
	draw_circle(Vector2(0, -13), 2.3, Color(SKIN, a))
	draw_arc(Vector2(0, -13.2), 2.7, PI, TAU, 8, Color(robe.darkened(0.3), a), 1.8)
	draw_line(Vector2(3.0 * f, -12), Vector2(3.8 * f + swing * 0.5, 1), Color(STAFF, a), 1.1)
	draw_circle(Vector2(3.0 * f, -12.5), 1.0, Color(1.0, 0.9, 0.5, a))
