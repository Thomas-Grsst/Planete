extends Node2D

const WOOD := Color("7b5a36")
const WOOD_TOP := Color("a07a4a")
const STONE := Color("8f8a84")
const STONE_TOP := Color("b7b1a9")
const POSTS := 28
const TENTS := 5
const CAMP_GAP := 1.6
const TENT_CLOTH := Color("e9dfc8")

var village
var front := true
var radius := 1.0


func setup(v, front_half: bool) -> void:
	village = v
	front = front_half
	refresh()


func refresh() -> void:
	radius = Settlements.clear_radius(village.settlement) + 0.9
	var c: Vector2 = village.center()
	global_position = Iso.project(c.x, c.y) + Vector2(0, radius * Iso.TILE_H * (0.5 if front else -0.5))
	queue_redraw()


func _point(k: float, r: float) -> Vector2:
	var a := TAU * k
	var c: Vector2 = village.center()
	var tile := c + Vector2(cos(a), sin(a)) * r
	return Iso.ground(Sim.state["world"], tile.x, tile.y) - global_position


func _on_side(p: Vector2) -> bool:
	var c: Vector2 = village.center()
	var mid := Iso.project(c.x, c.y) - global_position
	return (p.y >= mid.y) == front


func _draw() -> void:
	var s: Dictionary = village.settlement
	if not village.alive():
		return
	if s.get("walls", -1) >= 0:
		_walls(s.get("stone_walls", false))
	if Sieges.besieged(s) and front:
		_camp(s)


func _walls(stone: bool) -> void:
	var height := 9.0 if stone else 8.0
	for i in POSTS:
		var p := _point(float(i) / POSTS, radius)
		var q := _point(float(i + 1) / POSTS, radius)
		if not _on_side(p.lerp(q, 0.5)):
			continue
		if stone:
			draw_colored_polygon(PackedVector2Array([p, q, q + Vector2(0, -height), p + Vector2(0, -height)]), STONE)
			draw_line(p + Vector2(0, -height), q + Vector2(0, -height), STONE_TOP, 1.4)
			if i % 2 == 0:
				draw_rect(Rect2(p + Vector2(-1, -height - 2), Vector2(2, 2)), STONE_TOP)
		else:
			draw_line(p, p + Vector2(0, -height), WOOD, 2.6)
			draw_line(p + Vector2(0, -height), p + Vector2(0.4, -height - 1.2), WOOD_TOP, 1.2)
			draw_line(p + Vector2(0, -height * 0.35), q + Vector2(0, -height * 0.35), WOOD, 1.6)
			draw_line(p + Vector2(0, -height * 0.75), q + Vector2(0, -height * 0.75), WOOD, 1.6)


func _camp(s: Dictionary) -> void:
	var civ = Civs.by_id(Sim.state, s["siege"]["by"])
	var flag: Color = civ["color"] if civ != null else Color("ef5350")
	for i in TENTS:
		var p := _point(0.1 + float(i) / TENTS, radius + CAMP_GAP)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(6, 0), p + Vector2(0, -9)]), TENT_CLOTH)
		draw_line(p + Vector2(0, -9), p + Vector2(0, -14), Color(0.35, 0.25, 0.15), 0.8)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(5, -12.5), p + Vector2(0, -11)]), flag)
