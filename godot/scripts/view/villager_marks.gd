class_name VillagerMarks
extends RefCounted

const GOLD := Color("f2c14e")
const STEEL := Color("b0bec5")
const WOOD := Color("7a5a3a")
const SICK_TINT := Color("9ccc65")
const BITTEN_TINT := Color("7cb342")


static func skin(base: Color, st: Dictionary) -> Color:
	if st.get("bitten", false):
		return base.lerp(BITTEN_TINT, 0.6)
	if st.get("sick", false):
		return base.lerp(SICK_TINT, 0.35)
	return base


static func draw(node: Node2D, st: Dictionary, crouch: float, t: float) -> void:
	var a: float = st["alpha"]
	var f: float = st["facing"]
	var head := Vector2(0, -13.2 + crouch)
	match st["job"]:
		"chef":
			var c := Color(GOLD, a)
			node.draw_colored_polygon(PackedVector2Array([head + Vector2(-2.4, -1.6), head + Vector2(2.4, -1.6), head + Vector2(2.6, -4.2), head + Vector2(1.2, -2.8), head + Vector2(0, -4.6), head + Vector2(-1.2, -2.8), head + Vector2(-2.6, -4.2)]), c)
		"gardien":
			if st["activity"] in ["guard", "patrol", "idle"] or st["walking"]:
				var hand := Vector2(-3.2 * f, -8.0 + crouch)
				node.draw_line(hand + Vector2(0, 5), hand + Vector2(0.6 * f, -8), Color(WOOD, a), 1.0)
				node.draw_colored_polygon(PackedVector2Array([hand + Vector2(0.6 * f, -8), hand + Vector2(-0.5 + 0.6 * f, -6), hand + Vector2(0.5 + 0.6 * f, -6)]), Color(STEEL, a))
				node.draw_circle(Vector2(2.6 * f, -7.5 + crouch), 2.2, Color(0.55, 0.35, 0.2, a))
				node.draw_circle(Vector2(2.6 * f, -7.5 + crouch), 0.8, Color(STEEL, a))
		"guérisseur":
			node.draw_circle(Vector2(-2.6 * f, -5.5 + crouch), 1.3, Color(0.45, 0.75, 0.35, a))
	if st.get("sick", false) and int(t * 2.0 + node.person_id) % 4 == 0:
		node.draw_circle(head + Vector2(2.8 * f, -1.0), 0.7, Color(0.7, 0.85, 1.0, a))
	if st.get("famous", false):
		node.draw_circle(head + Vector2(0, -6.5), 0.9, Color(1.0, 0.95, 0.6, a * (0.5 + 0.5 * sin(t * 3.0))))
	if st["activity"] == "forge" and not st["walking"]:
		var spark := Vector2(4.5 * f, -4.0 + crouch)
		for i in 3:
			var k := fmod(t * 3.0 + i * 0.33, 1.0)
			node.draw_circle(spark + Vector2((i - 1) * 2.0 * k, -3.0 * k), 0.6, Color(1.0, 0.75, 0.3, a * (1.0 - k)))
