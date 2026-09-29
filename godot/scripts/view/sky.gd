extends CanvasLayer

const LIGHTNING_CHANCE := 0.004

var rain: CPUParticles2D
var snow: CPUParticles2D
var flash: ColorRect
var flash_alpha := 0.0
var flash_color := Color(0.95, 0.97, 1.0)


func _ready() -> void:
	rain = _particles(420, 1.6, Vector2(-40, 900), Color(0.75, 0.82, 1.0, 0.55), Vector2(0.6, 2.8))
	snow = _particles(160, 7.0, Vector2(8, 55), Color(1, 1, 1, 0.85), Vector2(1.2, 2.4))
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	get_viewport().size_changed.connect(_fit)
	Sim.power_used.connect(_on_power)
	_fit()


func _particles(amount: int, lifetime: float, gravity: Vector2, color: Color, scale_range: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = gravity.normalized()
	p.spread = 4.0
	p.gravity = gravity
	p.initial_velocity_min = gravity.length() * 0.2
	p.initial_velocity_max = gravity.length() * 0.3
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	p.color = color
	p.emitting = false
	p.preprocess = lifetime
	add_child(p)
	return p


func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	for p in [rain, snow]:
		p.position = Vector2(size.x * 0.5, -20)
		p.emission_rect_extents = Vector2(size.x * 0.7, 10)


func _process(delta: float) -> void:
	if Sim.state.is_empty():
		return
	var w: String = Sim.state["weather"]
	rain.emitting = w == "rain" or w == "storm"
	snow.emitting = w == "snow"
	if w == "storm" and Sim.speed > 0.0 and randf() < LIGHTNING_CHANCE * min(Sim.speed, 5.0):
		flash_alpha = 0.55
		flash_color = Color(0.95, 0.97, 1.0)
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.8)
	flash.color = Color(flash_color, flash_alpha)


func _on_power(name: String, _answered: Array) -> void:
	flash_color = {"sun": Color(1.0, 0.9, 0.55), "grow": Color(0.6, 1.0, 0.55), "rain": Color(0.6, 0.75, 1.0)}.get(name, Color.WHITE)
	flash_alpha = 0.45
