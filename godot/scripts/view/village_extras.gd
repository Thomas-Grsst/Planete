extends Node2D

const STONE := Color("9e9a94")
const STATUE := Color("cfc8bb")
const ANVIL := Color("3d3f44")
const LAMP_POST := Color("4a4a4a")
const ROCKET := Color("eceff1")
const MAX_STATUES := 3
const WELL_SPOT := Vector2(0.45, 0.62)
const MARKET_SPOT := Vector2(-0.4, 0.75)
const BELFRY_SPOT := Vector2(-1.5, -0.1)
const AWNINGS := [Color("e57373"), Color("fff176"), Color("64b5f6"), Color("81c784")]
const LAMPS := [Vector2(1.2, 0.2), Vector2(-1.1, 0.4), Vector2(0.2, -1.3), Vector2(-0.3, 1.4)]

var village
var lift := 0.0
var lamps: Array = []


func setup(v) -> void:
	village = v
	lift = Iso.lift_at(Sim.state["world"], v.settlement["x"], v.settlement["y"])
	for i in LAMPS.size():
		var g := Daylight.glow_sprite(Color(1.0, 0.95, 0.75), 30.0)
		add_child(g)
		lamps.append(g)
	refresh()


func refresh() -> void:
	for i in lamps.size():
		lamps[i].position = _local(village.center() + LAMPS[i]) + Vector2(0, -9)
	queue_redraw()


func _local(tile: Vector2) -> Vector2:
	return Iso.ground(Sim.state["world"], tile.x, tile.y) - global_position


func _electric() -> bool:
	return village.alive() and Techs.has_tech(village.settlement, "electricite")


func _process(delta: float) -> void:
	var on := _electric() and Daylight.night > 0.3
	for g in lamps:
		g.modulate.a = lerp(g.modulate.a, 0.6 if on else 0.0, delta * 2.0)
		g.visible = g.modulate.a > 0.02


func _draw() -> void:
	var s: Dictionary = village.settlement
	if not village.alive():
		return
	if s["level"] >= 2:
		_well(_local(village.center() + WELL_SPOT))
	if s["level"] >= HouseStyle.TOWN_LEVEL:
		_market(_local(village.center() + MARKET_SPOT), s["id"])
	if s["level"] >= HouseStyle.CITY_LEVEL:
		_belfry(_local(village.center() + BELFRY_SPOT), HouseStyle.of(s, 0))
	if Techs.METALS.any(func(k): return Techs.has_tech(s, k)):
		_anvil(_local(village.forge_spot(0)) + Vector2(4, 1))
	var statues: Array = s.get("statues", []).slice(-MAX_STATUES)
	for i in statues.size():
		_statue(_local(village.center() + Vector2(0.9 - i * 0.35, 0.9 + i * 0.2)))
	if _electric():
		for spot in LAMPS:
			var p := _local(village.center() + spot)
			draw_line(p, p + Vector2(0, -9), LAMP_POST, 1.0)
			draw_circle(p + Vector2(0, -9.5), 1.3, Color(1.0, 0.95, 0.7))
	match s.get("monument", ""):
		"pyramide": _pyramid(_local(village.center() + Vector2(-1.9, 1.2)))
		"observatoire": _observatory(_local(village.center() + Vector2(-1.9, 1.2)))
	if Techs.has_tech(s, "fusee") and not s.has("departed"):
		_rocket(_local(village.center() + Vector2(1.6, -1.2)))


func _pyramid(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-22, 0), p + Vector2(0, 11), p + Vector2(0, -34)]), Color("d9c38a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 11), p + Vector2(22, 0), p + Vector2(0, -34)]), Color("b89d62"))
	draw_circle(p + Vector2(0, -34), 1.6, Color("fff3c4"))


func _observatory(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-8, -16), Vector2(16, 16)), Color("cfd8dc"))
	draw_circle(p + Vector2(0, -16), 9.0, Color("eceff1"))
	draw_line(p + Vector2(0, -18), p + Vector2(10, -28), Color("455a64"), 2.0)
	draw_rect(Rect2(p + Vector2(-2, -8), Vector2(4, 8)), Color("546e7a"))


func _anvil(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-3, -3), Vector2(6, 1.6)), ANVIL)
	draw_rect(Rect2(p + Vector2(-1.2, -1.4), Vector2(2.4, 1.6)), ANVIL.darkened(0.2))
	draw_rect(Rect2(p + Vector2(-2.5, 0.2), Vector2(5, 1)), ANVIL.darkened(0.3))


func _statue(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-3, -2.5), Vector2(6, 3)), STONE)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-1.8, -2.5), p + Vector2(1.8, -2.5), p + Vector2(1.2, -10), p + Vector2(-1.2, -10)]), STATUE)
	draw_circle(p + Vector2(0, -11.6), 1.8, STATUE)
	draw_line(p + Vector2(1.2, -9), p + Vector2(3.2, -12.5), STATUE, 1.1)


func _rocket(p: Vector2) -> void:
	draw_line(p + Vector2(-4, 0), p + Vector2(-4, -16), LAMP_POST, 1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-1.8, -2), p + Vector2(1.8, -2), p + Vector2(1.8, -14), p + Vector2(0, -19), p + Vector2(-1.8, -14)]), ROCKET)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-1.8, -2), p + Vector2(-3.5, 0), p + Vector2(-1.8, -6)]), Color("e53935"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(1.8, -2), p + Vector2(3.5, 0), p + Vector2(1.8, -6)]), Color("e53935"))
	draw_circle(p + Vector2(0, -11), 0.9, Color("64b5f6"))


func _well(p: Vector2) -> void:
	draw_circle(p + Vector2(0, -1.5), 3.2, STONE)
	draw_circle(p + Vector2(0, -2.2), 2.1, Color("37474f"))
	draw_line(p + Vector2(-2.8, -1.5), p + Vector2(-2.8, -8), Color("6d4c41"), 1.0)
	draw_line(p + Vector2(2.8, -1.5), p + Vector2(2.8, -8), Color("6d4c41"), 1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -7.5), p + Vector2(0, -10.5), p + Vector2(4, -7.5)]), Color("8d6e63"))


func _market(p: Vector2, seed_value: int) -> void:
	for i in 3:
		var q := p + Vector2(i * 7.0 - 7.0, i * 1.5)
		var awning: Color = AWNINGS[(seed_value + i) % AWNINGS.size()]
		draw_rect(Rect2(q + Vector2(-3, -3), Vector2(6, 3)), Color("8d6e63"))
		draw_circle(q + Vector2(-1.2, -3.4), 0.9, Color("c0392b"))
		draw_circle(q + Vector2(1.2, -3.4), 0.9, Color("d9c25a"))
		draw_line(q + Vector2(-3, 0), q + Vector2(-3, -8), Color("5d4037"), 0.8)
		draw_line(q + Vector2(3, 0), q + Vector2(3, -8), Color("5d4037"), 0.8)
		draw_colored_polygon(PackedVector2Array([q + Vector2(-4, -7), q + Vector2(4, -7), q + Vector2(3.2, -9.5), q + Vector2(-3.2, -9.5)]), awning)


func _belfry(p: Vector2, style: Dictionary) -> void:
	var wall: Color = style["wall"]
	var shade: Color = style["shade"]
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -30), p + Vector2(0, -28), p + Vector2(0, 2), p + Vector2(-4, 0)]), wall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -28), p + Vector2(4, -30), p + Vector2(4, 0), p + Vector2(0, 2)]), shade)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-2.6, -25.5), p + Vector2(-1, -24.8), p + Vector2(-1, -21), p + Vector2(-2.6, -21.7)]), Color("3b3326"))
	draw_circle(p + Vector2(2, -24), 1.4, Color("fff3c4"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -29.5), p + Vector2(0, -40), p + Vector2(0, -27)]), style["roof"].lightened(0.1))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -27), p + Vector2(0, -40), p + Vector2(5, -29.5)]), style["roof"].darkened(0.12))
