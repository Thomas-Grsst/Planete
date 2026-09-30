extends Node2D

const PLANK := Color("9a7048")
const PLANK_DARK := Color("6d4c33")
const HULL := Color(0.45, 0.3, 0.2)
const SAIL := Color(0.95, 0.93, 0.85)
const MAX_BOATS := 3
const MAX_SPOTS := 6
const LEAVE := 6.5
const ARRIVE := 8.5
const TURN_BACK := 15.5
const HOME := 17.5

var village
var port := Vector2.ZERO
var shore := Vector2.ZERO
var spots: Array = []
var beacon: Sprite2D


func setup(v, port_tile: Vector2i) -> void:
	village = v
	port = Vector2(port_tile)
	global_position = Iso.project(port.x, port.y)
	var world: Dictionary = Sim.state["world"]
	shore = port
	for n in WorldGen.neighbors(port_tile.x, port_tile.y):
		if WorldGen.is_walkable(world, n.x, n.y):
			shore = Vector2(n)
			break
	var s: Dictionary = v.settlement
	var water: Array = []
	for o in Geography.offsets(Harvest.fish_radius(s)):
		var t = WorldGen.tile_at(world, s["x"] + o.x, s["y"] + o.y)
		var p := Vector2(s["x"] + o.x, s["y"] + o.y)
		if t != null and t["biome"] == "ocean" and p.distance_to(port) >= 2.0:
			water.append(p)
	beacon = Daylight.glow_sprite(Color(1.0, 0.9, 0.55), 60.0)
	beacon.position = _lighthouse_at() + Vector2(0, -27 - Iso.lift_at(world, shore.x, shore.y))
	beacon.visible = false
	add_child(beacon)
	var stride: int = maxi(1, water.size() / MAX_SPOTS)
	for j in range(water.size() - 1, -1, -stride):
		if spots.size() < MAX_SPOTS:
			spots.append(water[j])


func _process(delta: float) -> void:
	var lit: bool = village.alive() and Seafaring.has_lighthouse(village.settlement) and Daylight.night > 0.25
	beacon.modulate.a = lerp(beacon.modulate.a, 0.8 if lit else 0.0, delta * 2.0)
	beacon.visible = beacon.modulate.a > 0.02
	queue_redraw()


func _side() -> Vector2:
	var along := (port - shore).normalized()
	return Vector2(-along.y, along.x)


func _lighthouse_at() -> Vector2:
	return _local(shore - _side() * 1.1)


func _shipyard_at() -> Vector2:
	return _local(shore + _side() * 1.3)


func _local(tile: Vector2) -> Vector2:
	return Iso.project(tile.x, tile.y) - global_position


func _draw() -> void:
	if not village.alive():
		return
	var a := _local(shore.lerp(port, 0.45))
	var b := _local(port + (port - shore) * 0.25)
	var side := (b - a).orthogonal().normalized() * 3.2
	draw_colored_polygon(PackedVector2Array([a - side, b - side, b + side, a + side]), PLANK)
	for k in 5:
		var p := a.lerp(b, k / 4.0)
		draw_line(p - side, p + side, PLANK_DARK, 0.8)
		draw_line(p + side, p + side + Vector2(0, 3), PLANK_DARK, 1.0)
	var count: int = mini(MAX_BOATS, 1 + village.settlement["houses"] / 6)
	for i in count:
		_boat(_boat_at(i), i)
	if Seafaring.has_shipyard(village.settlement):
		_shipyard(_shipyard_at())
	if Seafaring.has_lighthouse(village.settlement):
		_lighthouse(_lighthouse_at())
	if Sieges.blockaded(village.settlement):
		_blockade()


func _boat_at(i: int) -> Vector2:
	var along := (port - shore).normalized()
	var moored := port + along * 0.1 + Vector2(-along.y, along.x) * (0.45 + 0.4 * i)
	if spots.is_empty():
		return moored
	var spot: Vector2 = spots[i % spots.size()]
	var h: float = Sim.hour() - i * 0.4
	if h < LEAVE or h >= HOME:
		return moored
	if h < ARRIVE:
		return moored.lerp(spot, smoothstep(LEAVE, ARRIVE, h))
	if h >= TURN_BACK:
		return spot.lerp(moored, smoothstep(TURN_BACK, HOME, h))
	return spot + Vector2(sin(h * 3.0 + i) * 0.25, cos(h * 2.0 + i) * 0.2)


func _boat(tile: Vector2, i: int) -> void:
	var c := _local(tile)
	var bob := sin(Time.get_ticks_msec() * 0.003 + i) * 0.8
	var o := c + Vector2(0, bob)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-6, -1), o + Vector2(6, -1), o + Vector2(4, 2), o + Vector2(-4, 2)]), HULL)
	draw_line(o + Vector2(0, -1), o + Vector2(0, -11), Color(0.35, 0.25, 0.15), 0.9)
	draw_colored_polygon(PackedVector2Array([o + Vector2(0.8, -10.5), o + Vector2(5.5, -3), o + Vector2(0.8, -2.5)]), SAIL)


func _blockade() -> void:
	var civ = Civs.by_id(Sim.state, village.settlement["blockade"]["by"])
	var flag: Color = civ["color"] if civ != null else Color("ef5350")
	var along := (port - shore).normalized()
	for k in [-1.0, 1.0]:
		var o := _local(port + along * 2.6 + Vector2(-along.y, along.x) * k * 1.1)
		var bob := sin(Time.get_ticks_msec() * 0.002 + k) * 0.8
		o += Vector2(0, bob)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-9, -1), o + Vector2(9, -1), o + Vector2(6, 3), o + Vector2(-6, 3)]), Color(0.3, 0.2, 0.14))
		draw_line(o + Vector2(0, -1), o + Vector2(0, -17), Color(0.3, 0.22, 0.14), 1.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(1, -16), o + Vector2(8, -6), o + Vector2(1, -5)]), flag.lightened(0.45))
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -17), o + Vector2(5, -15.5), o + Vector2(0, -14)]), flag)


func _lighthouse(p: Vector2) -> void:
	var lift := Iso.lift_at(Sim.state["world"], shore.x, shore.y)
	p += Vector2(0, -lift)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(-2.5, -24), p + Vector2(0, -23), p + Vector2(0, 2)]), Color("eceff1"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -23), p + Vector2(2.5, -24), p + Vector2(4, 0), p + Vector2(0, 2)]), Color("b0bec5"))
	for y in [-6.0, -15.0]:
		draw_line(p + Vector2(-3.6, y), p + Vector2(3.6, y), Color("e53935"), 2.2)
	draw_rect(Rect2(p + Vector2(-3, -29), Vector2(6, 5)), Color("fff3c4") if Daylight.night > 0.25 else Color("90a4ae"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -29), p + Vector2(0, -33), p + Vector2(4, -29)]), Color("c62828"))
	if Daylight.night > 0.25:
		var a := Time.get_ticks_msec() * 0.0012
		var tip := p + Vector2(0, -27)
		var dir := Vector2(cos(a), sin(a) * 0.5)
		var side := dir.orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([tip, tip + dir * 60.0 + side, tip + dir * 60.0 - side]), Color(1.0, 0.95, 0.7, 0.18 * Daylight.night))


func _shipyard(p: Vector2) -> void:
	var lift := Iso.lift_at(Sim.state["world"], shore.x, shore.y)
	p += Vector2(0, -lift)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 1), p + Vector2(10, 1), p + Vector2(7, 5), p + Vector2(-7, 5)]), PLANK_DARK)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -2), p + Vector2(9, -2), p + Vector2(6, 2), p + Vector2(-6, 2)]), HULL)
	for k in 6:
		var x := -7.0 + k * 2.8
		draw_line(p + Vector2(x, -2), p + Vector2(x * 1.1, -7.5), PLANK, 1.0)
	draw_line(p + Vector2(-7.7, -7.5), p + Vector2(7.7, -7.5), PLANK, 0.8)
	draw_line(p + Vector2(-11, 3), p + Vector2(-11, -12), PLANK_DARK, 1.0)
	draw_line(p + Vector2(-11, -12), p + Vector2(-2, -12), PLANK_DARK, 1.0)
	draw_line(p + Vector2(-3, -12), p + Vector2(-3, -8), Color("5d4037"), 0.6)
