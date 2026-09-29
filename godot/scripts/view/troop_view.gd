extends Node2D

const LOOKS := {
	"zombie": {"body": Color("5d7a3a"), "skin": Color("9ccc65"), "gait": 0.35},
	"barbare": {"body": Color("6d4c41"), "skin": Color("d7a67a"), "gait": 0.8},
	"pirate": {"body": Color("263238"), "skin": Color("e0b08a"), "gait": 0.7},
	"machine": {"body": Color("78909c"), "skin": Color("b0bec5"), "gait": 0.6},
}
const MAX_FIGURES := 8
const SPEED := 0.6

var record: Dictionary
var kind := "zombie"
var tile := Vector2.ZERO
var t0 := 0.0


func setup(r: Dictionary, k: String) -> void:
	record = r
	kind = k
	tile = Vector2(r["x"], r["y"])
	t0 = randf() * 10.0
	_place()


func _place() -> void:
	position = Iso.project(tile.x, tile.y)


func _process(delta: float) -> void:
	var goal := Vector2(record["x"], record["y"])
	var ts: float = clamp(Sim.speed, 0.0, 20.0)
	if ts > 0.0:
		tile = tile.move_toward(goal, SPEED * LOOKS[kind]["gait"] * pow(max(ts, 1.0), 0.7) * delta)
	_place()
	queue_redraw()


func _on_water() -> bool:
	var t = WorldGen.tile_at(Sim.state["world"], int(round(tile.x)), int(round(tile.y)))
	return t != null and Biomes.is_water(t["biome"])


func _draw() -> void:
	var lift := Iso.lift_at(Sim.state["world"], tile.x, tile.y)
	draw_set_transform(Vector2(0, -lift))
	var n: int = clampi(int(ceil(record["count"])), 1, MAX_FIGURES)
	var t := Time.get_ticks_msec() / 1000.0 + t0
	if kind == "pirate" and _on_water():
		_ship(t)
		return
	for i in n:
		var o := Vector2(((i * 37) % 17 - 8) * 1.1, ((i * 23) % 9 - 4) * 0.8)
		_figure(o, t + i * 0.7)
	var font := ThemeDB.fallback_font
	if record["count"] > MAX_FIGURES:
		draw_string(font, Vector2(8, -18), "×%d" % int(record["count"]), HORIZONTAL_ALIGNMENT_LEFT, 40, 9, Color(1, 1, 1, 0.9))


func _figure(o: Vector2, t: float) -> void:
	var look: Dictionary = LOOKS[kind]
	var sway := sin(t * (2.0 if kind == "zombie" else 5.0))
	var lean := 1.5 if kind == "zombie" else 0.0
	draw_line(o + Vector2(-1, -4), o + Vector2(-1 + sway, 0), look["body"].darkened(0.3), 1.2)
	draw_line(o + Vector2(1, -4), o + Vector2(1 - sway, 0), look["body"].darkened(0.3), 1.2)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-2 + lean, -10), o + Vector2(2 + lean, -10), o + Vector2(2.4, -4), o + Vector2(-2.4, -4)]), look["body"])
	if kind == "machine":
		draw_rect(Rect2(o + Vector2(-2.2 + lean, -14.5), Vector2(4.4, 4)), look["skin"])
		draw_circle(o + Vector2(0.9 + lean, -12.8), 0.7, Color(1, 0.2, 0.2))
		return
	draw_circle(o + Vector2(lean, -12.5), 2.2, look["skin"])
	if kind == "zombie":
		draw_line(o + Vector2(1 + lean, -9), o + Vector2(5 + lean, -9.5 + sway * 0.5), look["skin"], 1.1)
	elif kind == "barbare":
		draw_line(o + Vector2(2.5, -8), o + Vector2(5, -12), Color("5d4037"), 1.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(4.5, -13), o + Vector2(6.5, -12), o + Vector2(5, -10.5)]), Color("b0bec5"))
	elif kind == "pirate":
		draw_line(o + Vector2(-2.2, -13.8), o + Vector2(2.2, -13.8), Color("c62828"), 1.4)


func _ship(t: float) -> void:
	var bob := sin(t * 1.6) * 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -2 + bob), Vector2(12, -2 + bob), Vector2(8, 3 + bob), Vector2(-8, 3 + bob)]), Color("4e342e"))
	draw_line(Vector2(0, -2 + bob), Vector2(0, -22 + bob), Color("3e2723"), 1.2)
	draw_colored_polygon(PackedVector2Array([Vector2(1, -21 + bob), Vector2(10, -8 + bob), Vector2(1, -6 + bob)]), Color("212121"))
	draw_string(ThemeDB.fallback_font, Vector2(-6, -16 + bob), "☠", HORIZONTAL_ALIGNMENT_LEFT, 20, 8, Color.WHITE)
