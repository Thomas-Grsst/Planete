extends Node2D

const COLORS := {"deer": Color("a0693a"), "sheep": Color("eeeae0"), "wolf": Color("7d8189")}
const SPEED := 0.35

var herd_view
var species := "deer"
var index := 0
var tile := Vector2.ZERO
var goal := Vector2.ZERO
var pause := 0.0
var step := 0.0
var facing := 1.0
var lift := 0.0


func setup(hv, kind: String, i: int) -> void:
	herd_view = hv
	species = kind
	index = i
	tile = hv.roam_target(i)
	goal = tile
	pause = randf() * 4.0



func _process(delta: float) -> void:
	if Sim.state.is_empty():
		return
	var ts: float = clamp(Sim.speed, 0.0, 20.0)
	if ts > 0.0:
		var to_goal := goal - tile
		if to_goal.length() < 0.03:
			pause -= delta * ts
			if pause <= 0.0:
				goal = herd_view.roam_target(index)
				pause = 2.0 + randf() * 6.0
		else:
			var stride: float = min(to_goal.length(), SPEED * pow(max(ts, 1.0), 0.7) * delta * (2.0 if species == "wolf" else 1.0))
			tile += to_goal.normalized() * stride
			step += stride * 18.0
			if absf(to_goal.x - to_goal.y) > 0.01:
				facing = sign(to_goal.x - to_goal.y)
	position = Iso.project(tile.x, tile.y)
	lift = Iso.lift_at(Sim.state["world"], tile.x, tile.y)
	queue_redraw()


func _draw() -> void:
	var c: Color = COLORS[species]
	var moving := (goal - tile).length() >= 0.03
	var f := facing
	var up := Vector2(0, -lift)
	draw_set_transform(up, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.2))
	draw_set_transform(up, 0.0, Vector2.ONE)
	var legs := sin(step) * 1.5 if moving else 0.0
	var leg := c.darkened(0.45)
	for x in [-3.0, 2.5]:
		draw_line(Vector2(x * f, -3), Vector2(x * f + legs, 0), leg, 1.0)
		draw_line(Vector2((x + 1.0) * f, -3), Vector2((x + 1.0) * f - legs, 0), leg, 1.0)
	if species == "sheep":
		for p in [Vector2(-2, -5), Vector2(1, -5.5), Vector2(-0.5, -6.5), Vector2(2.5, -4.5)]:
			draw_circle(Vector2(p.x * f, p.y), 2.3, c)
	else:
		draw_set_transform(up + Vector2(0, -4.5), 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, 4.2, c)
		draw_set_transform(up, 0.0, Vector2.ONE)
	var grazing := not moving and int(pause * 2.0) % 3 != 0
	var head := Vector2(4.8 * f, -3.2 if grazing else -7.0)
	draw_line(Vector2(3.0 * f, -5.0), head, c, 2.0)
	draw_circle(head, 1.6, c.darkened(0.1) if species != "sheep" else Color("4a4540"))
	if species == "deer":
		draw_line(head, head + Vector2(-0.5 * f, -3.5), Color("6b4a2a"), 0.8)
		draw_line(head + Vector2(-0.3 * f, -2.0), head + Vector2(1.2 * f, -3.8), Color("6b4a2a"), 0.8)
	elif species == "wolf":
		draw_line(head, head + Vector2(0.6 * f, -2.0), c.darkened(0.3), 1.0)
		draw_line(Vector2(-3.8 * f, -5.0), Vector2(-6.5 * f, -3.5 + sin(step * 0.5)), c, 1.4)
