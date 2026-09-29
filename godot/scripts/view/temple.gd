extends Node2D

const STONE := Color("e6e0d4")
const STONE_SHADE := Color("bdb4a3")
const COLUMN := Color("f4efe6")
const GOLD := Color("f2c14e")

var village
var level := 0
var lift := 0.0
var glow: Sprite2D
var grow := 1.0


func setup(v, ground_lift: float) -> void:
	village = v
	lift = ground_lift
	glow = Daylight.glow_sprite(Color(1.0, 0.9, 0.6), 60.0)
	glow.position = Vector2(0, -10 - lift)
	add_child(glow)
	refresh(false)


func refresh(animate: bool = true) -> void:
	var wanted: int = village.settlement.get("temple", 0)
	if wanted == level:
		return
	level = wanted
	visible = level > 0
	if animate:
		grow = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if grow < 1.0:
		grow = min(1.0, grow + delta * 0.8)
		scale = Vector2.ONE * (0.3 + 0.7 * grow)
	var lit: bool = level > 0 and village.alive() and Daylight.night > 0.3
	glow.modulate.a = lerp(glow.modulate.a, 0.45 if lit else 0.0, delta * 2.0)
	glow.visible = glow.modulate.a > 0.02
	var rel = Religions.of(Sim.state, village.settlement)
	if rel != null:
		glow.modulate = Color(rel["color"].lightened(0.4), glow.modulate.a)


func _draw() -> void:
	if level <= 0:
		return
	draw_set_transform(Vector2(0, -lift))
	var great := level > 1
	var w := 13.0 if great else 9.0
	var h := 12.0 if great else 8.0
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 2, 0), Vector2(0, 5), Vector2(w + 2, 0), Vector2(0, -5)]), STONE_SHADE)
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 2, 0), Vector2(0, 5), Vector2(0, 7), Vector2(-w - 2, 2)]), STONE_SHADE.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(w + 2, 0), Vector2(w + 2, 2), Vector2(0, 7)]), STONE_SHADE.darkened(0.3))
	var columns := 5 if great else 4
	for i in columns:
		var x := -w + i * (2.0 * w) / (columns - 1)
		var base_y := 2.0 - absf(x) * 0.25
		draw_rect(Rect2(Vector2(x - 1.2, base_y - h), Vector2(2.4, h)), COLUMN)
		draw_rect(Rect2(Vector2(x - 0.4, base_y - h), Vector2(0.8, h)), STONE_SHADE)
	var top := -h - 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 2.5, top + 1), Vector2(w + 2.5, top + 1), Vector2(w + 2.5, top - 1.5), Vector2(-w - 2.5, top - 1.5)]), STONE)
	var roof := GOLD if great else STONE.darkened(0.08)
	draw_colored_polygon(PackedVector2Array([Vector2(-w - 3, top - 1.5), Vector2(w + 3, top - 1.5), Vector2(0, top - (10.0 if great else 7.0))]), roof)
	var rel = Religions.of(Sim.state, village.settlement)
	if rel != null:
		draw_circle(Vector2(0, top - (5.5 if great else 3.8)), 1.6, rel["color"])
