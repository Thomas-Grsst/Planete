extends Node2D

const LIFETIMES := {"ufo": 14.0, "rocket": 7.0, "meteor": 1.6}

var kind := "ufo"
var age := 0.0
var base := Vector2.ZERO
var trail: CPUParticles2D


func setup(what: String, at: Vector2) -> void:
	kind = what
	base = at
	position = at
	z_as_relative = false
	z_index = 32
	if kind != "ufo":
		trail = CPUParticles2D.new()
		trail.amount = 60
		trail.lifetime = 1.2
		trail.direction = Vector2(0, 1) if kind == "rocket" else Vector2(-1, -1)
		trail.spread = 18.0
		trail.gravity = Vector2(0, 20) if kind == "rocket" else Vector2.ZERO
		trail.initial_velocity_min = 20.0
		trail.initial_velocity_max = 50.0
		trail.scale_amount_min = 1.5
		trail.scale_amount_max = 4.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
		ramp.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
		trail.color_ramp = ramp
		add_child(trail)


func _process(delta: float) -> void:
	age += delta
	var life: float = LIFETIMES[kind]
	match kind:
		"ufo":
			position = base + Vector2(sin(age * 0.8) * 20.0, -60.0 - sin(age * 1.3) * 6.0 - max(0.0, age - life + 3.0) * 120.0)
		"rocket":
			position = base + Vector2(0, -pow(age, 2.2) * 18.0)
		"meteor":
			position = base + Vector2(1, 1) * (1.0 - age / life) * -260.0
	if age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	match kind:
		"ufo":
			draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(10, 5), Vector2(-10, 5)]), Color("b0bec5"))
			draw_circle(Vector2(0, -2), 7.0, Color(0.6, 0.95, 1.0, 0.8))
			for i in 5:
				var on := int(age * 6.0 + i) % 2 == 0
				draw_circle(Vector2(-12 + i * 6, 2), 1.2, Color(1, 1, 0.5) if on else Color(0.4, 1, 0.6))
			if age > 2.0 and age < LIFETIMES["ufo"] - 3.0:
				draw_colored_polygon(PackedVector2Array([Vector2(-6, 5), Vector2(6, 5), Vector2(22, 70), Vector2(-22, 70)]), Color(0.7, 1.0, 0.9, 0.18 + 0.08 * sin(age * 5.0)))
		"rocket":
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -18), Vector2(0, -25), Vector2(-3, -18)]), Color("eceff1"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(-6, 4), Vector2(-3, -6)]), Color("e53935"))
			draw_colored_polygon(PackedVector2Array([Vector2(3, 0), Vector2(6, 4), Vector2(3, -6)]), Color("e53935"))
		"meteor":
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.5))
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 0.9))
