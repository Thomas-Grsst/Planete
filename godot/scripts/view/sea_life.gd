extends Node2D

# Au-dessus de l'eau : épaves des naufrages, baleines qui soufflent au large, dauphins qui sautent près des côtes.

const SPAWN_MIN := 4.0
const SPAWN_MAX := 9.0
const MAX_CREATURES := 4
const DEEP_RADIUS := 2
const WRECK_VIEW := 30.0
const HULL := Color(0.32, 0.22, 0.15)
const WHALE := Color("455a64")
const DOLPHIN := Color("78909c")
const FOAM := Color(1, 1, 1, 0.8)

var creatures: Array = []
var next_spawn := 3.0
var clock := 0.0
var _test_whale := DebugOptions.parse().has("whale")


func _process(delta: float) -> void:
	if Sim.state.is_empty():
		return
	clock += delta
	if _test_whale:
		_test_whale = false
		_force_whale()
	next_spawn -= delta
	if next_spawn <= 0.0:
		next_spawn = randf_range(SPAWN_MIN, SPAWN_MAX)
		if creatures.size() < MAX_CREATURES:
			_spawn()
	for c in creatures.duplicate():
		c["age"] += delta
		if c["age"] >= c["life"]:
			if c.get("loop", false):
				c["age"] = 0.0
			else:
				creatures.erase(c)
	queue_redraw()


func _view_tile() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	return Iso.unproject(cam.global_position) if cam != null else Vector2.ZERO


func _is_ocean(x: int, y: int) -> bool:
	var t = WorldGen.tile_at(Sim.state["world"], x, y)
	return t != null and t["biome"] == "ocean"


func _deep(x: int, y: int) -> bool:
	for dy in range(-DEEP_RADIUS, DEEP_RADIUS + 1):
		for dx in range(-DEEP_RADIUS, DEEP_RADIUS + 1):
			if not _is_ocean(x + dx, y + dy):
				return false
	return true


# Un point de mer pris dans ce que la caméra montre, pour qu'on voie vraiment la baleine.
func _spawn() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	for attempt in 16:
		var at: Vector2 = cam.get_screen_center_position() + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y)) * 0.85
		var tile := Iso.unproject(at)
		var x := int(round(tile.x))
		var y := int(round(tile.y))
		if not _is_ocean(x, y):
			continue
		var dir := 1.0 if randf() < 0.5 else -1.0
		if _deep(x, y):
			creatures.append({"kind": "whale", "tile": Vector2(x, y), "age": 0.0, "life": 8.0, "dir": dir})
		else:
			creatures.append({"kind": "dolphins", "tile": Vector2(x, y), "age": 0.0, "life": 3.6, "dir": dir})
		return


# --whale : une baleine qui souffle et un banc de dauphins tout près du centre de la vue.
func _force_whale() -> void:
	var c := _view_tile()
	for o in Geography.offsets(14):
		var x: int = int(round(c.x)) + o.x
		var y: int = int(round(c.y)) + o.y
		if _deep(x, y):
			creatures.append({"kind": "whale", "tile": Vector2(x, y), "age": 2.5, "life": 8.0, "dir": 1.0, "loop": true})
			creatures.append({"kind": "dolphins", "tile": Vector2(x + 1, y + 2), "age": 0.9, "life": 3.6, "dir": -1.0, "loop": true})
			get_viewport().get_camera_2d().jump(Iso.project(x, y))
			return


func _draw() -> void:
	if Sim.state.is_empty():
		return
	var center := _view_tile()
	for w in Sim.state.get("wrecks", []):
		var tile := Vector2(w["x"], w["y"])
		if tile.distance_to(center) <= WRECK_VIEW and _is_ocean(w["x"], w["y"]):
			_wreck(Iso.ground(Sim.state["world"], tile.x, tile.y), w["id"])
	for c in creatures:
		var p := Iso.ground(Sim.state["world"], c["tile"].x, c["tile"].y)
		if c["kind"] == "whale":
			_whale(p, c)
		else:
			_dolphins(p, c)


func _wreck(p: Vector2, id: int) -> void:
	var bob := sin(clock * 1.3 + id) * 0.6
	var o := p + Vector2(0, bob)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-6, 0), o + Vector2(3, -1.5), o + Vector2(5, 1), o + Vector2(-4, 2)]), HULL)
	draw_line(o + Vector2(-1, -0.5), o + Vector2(3, -12), HULL.darkened(0.2), 1.1)
	draw_line(o + Vector2(1.2, -6), o + Vector2(4.8, -7.5), HULL.darkened(0.2), 0.8)
	draw_colored_polygon(PackedVector2Array([o + Vector2(2.6, -11), o + Vector2(5.6, -8), o + Vector2(3.2, -7.8)]), Color(0.85, 0.83, 0.76, 0.8))
	var ring := fmod(clock * 0.5 + id * 0.37, 1.0)
	draw_arc(o + Vector2(0, 1.5), 5.0 + ring * 5.0, 0.0, TAU, 20, Color(1, 1, 1, 0.35 * (1.0 - ring)), 0.7)


func _whale(p: Vector2, c: Dictionary) -> void:
	var t: float = c["age"] / c["life"]
	var rise: float = sin(t * PI)
	var o := p + Vector2(c["dir"] * (t - 0.5) * 14.0, 0)
	var back := PackedVector2Array()
	for k in 9:
		var f := k / 8.0
		back.append(o + Vector2((f - 0.5) * 22.0 * c["dir"], -sin(f * PI) * 6.0 * rise))
	back.append(o + Vector2(11.0 * c["dir"], 0.8))
	back.append(o + Vector2(-11.0 * c["dir"], 0.8))
	if rise > 0.05:
		draw_colored_polygon(back, WHALE)
	if t > 0.2 and t < 0.55:
		var spout := sin((t - 0.2) / 0.35 * PI)
		var head := o + Vector2(7.0 * c["dir"], -5.0 * rise)
		for k in 5:
			var a := -PI / 2 + (k - 2) * 0.35
			draw_line(head, head + Vector2(cos(a), sin(a)) * 10.0 * spout, Color(1, 1, 1, 0.75 * spout), 1.2)
	if t > 0.75:
		var tail := o + Vector2(-11.0 * c["dir"], 0)
		var up := sin((t - 0.75) / 0.25 * PI) * 9.0
		draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-5.0, -up), tail + Vector2(0, -up * 0.6), tail + Vector2(5.0, -up)]), WHALE.darkened(0.15))
	draw_arc(o + Vector2(0, 1), 9.0 + t * 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3 * (1.0 - t)), 0.8)


func _dolphins(p: Vector2, c: Dictionary) -> void:
	for i in 3:
		var t: float = clamp((c["age"] - i * 0.35) / 1.4, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var base := p + Vector2(i * 4.0 - 4.0, i * 1.5)
		var x: float = (t - 0.5) * 10.0 * c["dir"]
		var y: float = -sin(t * PI) * 6.0
		var body := base + Vector2(x, y)
		var ahead := Vector2(c["dir"] * 2.2, -cos(t * PI) * 2.2)
		draw_line(body - ahead, body + ahead, DOLPHIN, 2.0)
		draw_circle(body + ahead, 1.0, DOLPHIN)
		if t > 0.85:
			draw_circle(base + Vector2(5.0 * c["dir"], 0), 1.5 * (1.0 - t) * 6.0, FOAM)
