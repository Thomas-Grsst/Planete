class_name Daylight
extends CanvasModulate

const DAY := Color(1, 1, 1)
const DUSK := Color(1.0, 0.72, 0.55)
const NIGHT := Color(0.22, 0.27, 0.5)
const STORM := Color(0.62, 0.66, 0.75)
const DROUGHT := Color(1.0, 0.9, 0.75)

static var night := 0.0
static var _glow: GradientTexture2D


static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


static func light(color: Color, radius: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = glow_texture()
	l.color = color
	l.texture_scale = radius / 64.0
	l.energy = energy
	return l


static func glow_sprite(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.scale = Vector2.ONE * radius / 64.0
	s.modulate = Color(color, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	s.z_as_relative = false
	s.z_index = 15
	s.visible = false
	return s


static func darkness(hour: float) -> float:
	if hour >= 7.0 and hour < 17.5:
		return 0.0
	if hour >= 17.5 and hour < 20.0:
		return (hour - 17.5) / 2.5
	if hour >= 5.0 and hour < 7.0:
		return 1.0 - (hour - 5.0) / 2.0
	return 1.0


func _process(_delta: float) -> void:
	if Sim.state.is_empty():
		return
	var hour := Sim.hour()
	night = darkness(hour)
	var base := DAY
	var w: String = Sim.state["weather"]
	if w == "storm" or w == "rain":
		base = STORM if w == "storm" else DAY.lerp(STORM, 0.5)
	elif w == "drought":
		base = DROUGHT
	var dusk := 1.0 - absf(night - 0.45) / 0.45 if night > 0.0 and night < 0.9 else 0.0
	if Zombies.active(Sim.state):
		base = base.lerp(Color(0.75, 0.9, 0.6), 0.35)
	color = base.lerp(DUSK, clamp(dusk, 0.0, 1.0) * 0.6).lerp(NIGHT, night)
