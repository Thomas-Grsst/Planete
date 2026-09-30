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
	var stride: int = maxi(1, water.size() / MAX_SPOTS)
	for j in range(water.size() - 1, -1, -stride):
		if spots.size() < MAX_SPOTS:
			spots.append(water[j])


func _process(_delta: float) -> void:
	queue_redraw()


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
