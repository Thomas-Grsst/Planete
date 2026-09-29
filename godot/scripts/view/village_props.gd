extends Node2D

const STONE := Color("8a8480")
const LOG := Color("7b4f2a")
const FLAME := Color("ff9d2e")
const FLAME_CORE := Color("ffe27a")
const SOIL := Color("7a5a36")
const CROP := Color("d9c25a")
const SPROUT := Color("8fc25a")
const SCAFFOLD := Color("a07a4a")
const MAX_LOGS := 8
const MAX_BASKETS := 6

var village
var fire_light: PointLight2D
var embers: CPUParticles2D
var ground: Node2D
var label: Node2D
var bumps := {"wood": 0.0, "food": 0.0}
var lift := 0.0


func setup(v) -> void:
	village = v
	lift = Iso.lift_at(Sim.state["world"], v.settlement["x"], v.settlement["y"])
	fire_light = Daylight.light(Color(1.0, 0.62, 0.3), 90.0, 0.0)
	fire_light.position = Vector2(0, -4 - lift)
	add_child(fire_light)
	embers = CPUParticles2D.new()
	embers.amount = 14
	embers.lifetime = 1.4
	embers.position = Vector2(0, -4 - lift)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 14.0
	embers.scale_amount_min = 0.8
	embers.scale_amount_max = 1.6
	embers.color = Color(1.0, 0.7, 0.3, 0.9)
	add_child(embers)
	ground = Node2D.new()
	ground.z_as_relative = false
	ground.z_index = -5
	ground.draw.connect(_draw_ground)
	add_child(ground)
	label = Node2D.new()
	label.z_as_relative = false
	label.z_index = 28
	label.draw.connect(_draw_label)
	add_child(label)


func has_fire() -> bool:
	return village.alive() and Techs.has_tech(village.settlement, "feu")


func refresh() -> void:
	queue_redraw()
	ground.queue_redraw()
	label.queue_redraw()


func bump(item: String) -> void:
	bumps["wood" if item == "wood" else "food"] = 1.0


func _process(delta: float) -> void:
	if village.praying():
		label.queue_redraw()
	var fire := has_fire()
	embers.emitting = fire
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.013) * sin(Time.get_ticks_msec() * 0.007)
	fire_light.energy = lerp(fire_light.energy, (1.3 * flicker * Daylight.night) if fire else 0.0, delta * 3.0)
	fire_light.enabled = fire_light.energy > 0.02
	for k in bumps:
		bumps[k] = max(0.0, bumps[k] - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, -lift))
	var s: Dictionary = village.settlement
	for i in 7:
		var a := TAU * i / 7.0
		draw_circle(Vector2(cos(a) * 5.0, sin(a) * 2.4), 1.3, STONE)
	if has_fire():
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var sway := sin(t * 9.0 + i * 2.1) * 1.2
			var hgt := 6.0 + sin(t * 11.0 + i) * 1.5
			var x := (i - 1) * 1.8
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -1), Vector2(x + 2, -1), Vector2(x + sway, -1 - hgt)]), FLAME)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 1, -1), Vector2(x + 1, -1), Vector2(x + sway * 0.6, -1 - hgt * 0.55)]), FLAME_CORE)
	_draw_pile(s)
	if s["construction"] >= 0.0 and village.alive():
		_draw_site(s["construction"])


func _to_local_tile(tile: Vector2) -> Vector2:
	return Iso.ground(Sim.state["world"], tile.x, tile.y) - global_position + Vector2(0, lift)


func _draw_pile(s: Dictionary) -> void:
	var base := _to_local_tile(village.storage_spot(0))
	var logs: int = min(MAX_LOGS, int(s["wood"] / 6.0))
	var lift_wood: float = bumps["wood"] * 2.0
	for i in logs:
		var p := base + Vector2(-5 + (i % 4) * 3.0, -(i / 4) * 2.2 - lift_wood * (1 if i == logs - 1 else 0))
		draw_rect(Rect2(p, Vector2(6, 2)), LOG.lightened(0.08 * (i % 2)))
	var baskets: int = min(MAX_BASKETS, int(s["food"] / 25.0))
	for i in baskets:
		var p := base + Vector2(9 + (i % 3) * 4.0, 2 - (i / 3) * 3.0 - bumps["food"] * 1.5)
		draw_rect(Rect2(p, Vector2(3.5, 2.5)), Color("8a6134"))
		draw_circle(p + Vector2(1.7, 0), 1.3, Color("c0392b") if i % 2 == 0 else CROP)


func _draw_site(progress: float) -> void:
	var p := _to_local_tile(village.slot_tile(village.houses.size()))
	var h := 3.0 + 10.0 * progress
	var wall := PackedVector2Array([p + Vector2(-7, -h * 0.6), p + Vector2(0, -h * 0.6 + 3.5), p + Vector2(0, 3.5), p + Vector2(-7, 0)])
	draw_colored_polygon(wall, Color("d8c3a0", 0.4 + 0.6 * progress))
	for x in [-7.0, 0.0, 7.0]:
		draw_line(p + Vector2(x, 2), p + Vector2(x, -h - 2), SCAFFOLD, 1.0)
	draw_line(p + Vector2(-7, -h * 0.5), p + Vector2(7, -h * 0.5), SCAFFOLD, 1.0)


func _draw_ground() -> void:
	for tile in village.fields:
		var c: Vector2 = Iso.ground(Sim.state["world"], tile.x, tile.y) - global_position
		var ripe: bool = Weather.season(Sim.state["day"]) in [1, 2]
		var hw := Iso.TILE_W * 0.42
		var hh := Iso.TILE_H * 0.42
		ground.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)]), SOIL)
		for r in 5:
			var f := (r + 0.5) / 5.0
			var a := c + Vector2(-hw * (1.0 - f), -hh * f)
			var b := c + Vector2(hw * f, hh * (1.0 - f))
			ground.draw_line(a.lerp(b, 0.08), a.lerp(b, 0.92), CROP if ripe else SPROUT, 1.6)


func _draw_label() -> void:
	var s: Dictionary = village.settlement
	var font := ThemeDB.fallback_font
	var text: String = s["name"] if village.alive() else "%s (abandonné)" % s["name"]
	var rel = Religions.of(Sim.state, s)
	if rel != null and village.alive():
		text = "%s %s" % [rel["emoji"], text]
	var y := -30.0 - lift
	label.draw_string_outline(font, Vector2(-60, y), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 3, Color(0, 0, 0, 0.6))
	label.draw_string(font, Vector2(-60, y), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 1, 1, 0.95))
	if village.alive() and village.praying():
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
		label.draw_string(font, Vector2(-10, y - 14), "🙏", HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(1, 1, 1, pulse))
