extends Node2D

const FLOAT_TIME := 3.2
const RISE := 26.0
const SHOWN := {
	"naissance": ["👶", Color("ffd1e6")], "deces": ["🕯️", Color("c9c9d6")], "couple": ["💞", Color("ff9ecb")],
	"decouverte": ["💡", Color("ffe27a")], "diffusion": ["🧳", Color("bfe3ff")], "construction": ["🏠", Color("ffffff")],
	"fondation": ["🏕️", Color("b9f6ca")], "croissance": ["📈", Color("b9f6ca")], "migration": ["🧭", Color("ffffff")],
}

var floaters: Array = []
var font: Font


func _ready() -> void:
	z_as_relative = false
	z_index = 30
	font = ThemeDB.fallback_font


func on_event(entry: Dictionary, life) -> void:
	if not SHOWN.has(entry["type"]):
		return
	var pos = _where(entry, life)
	if pos == null:
		return
	var style: Array = SHOWN[entry["type"]]
	var text: String = style[0]
	if entry["type"] == "decouverte" or entry["type"] == "diffusion":
		text = "%s %s" % [Techs.DATA[entry["tech"]]["emoji"], Techs.DATA[entry["tech"]]["name"]]
		burst(pos, Color("ffe27a"))
	elif entry["type"] == "croissance" or entry["type"] == "fondation":
		burst(pos, Color("b9f6ca"))
	float_text(pos, text, style[1], entry["type"] in ["decouverte", "fondation", "croissance"])


func float_text(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	floaters.append({"pos": pos, "text": text, "color": color, "age": 0.0, "big": big})


func _where(entry: Dictionary, life) -> Variant:
	if entry.has("person"):
		var v = life.villager(entry["person"])
		if v != null and v.visible:
			return v.position + Vector2(0, -22 - v.lift)
	if entry.has("x"):
		return Iso.ground(Sim.state["world"], entry["x"], entry["y"]) + Vector2(0, -34)
	return null


func burst(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 26
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, 18)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = color
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func plume(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -10)
	p.amount = 80
	p.lifetime = 6.0
	p.one_shot = false
	p.direction = Vector2(0.2, -1)
	p.spread = 14.0
	p.gravity = Vector2(6, -10)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.35, 0.33, 0.32, 0.55)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(40.0).timeout.connect(p.queue_free)


func puff(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 16
	p.lifetime = 1.2
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.85, 0.78, 0.65, 0.6)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	if floaters.is_empty():
		return
	for f in floaters:
		f["age"] += delta
	floaters = floaters.filter(func(f): return f["age"] < FLOAT_TIME)
	queue_redraw()


func _draw() -> void:
	for f in floaters:
		var t: float = f["age"] / FLOAT_TIME
		var a: float = clamp(1.0 - pow(t, 2.0), 0.0, 1.0) * clamp(f["age"] * 4.0, 0.0, 1.0)
		var size := 13 if f["big"] else 10
		var p: Vector2 = f["pos"] + Vector2(-70, -RISE * t)
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 140, size, 3, Color(0, 0, 0, 0.55 * a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 140, size, Color(f["color"], a))
