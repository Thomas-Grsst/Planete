extends RefCounted

const SKINS := [Color("f1c7a1"), Color("d9a47a"), Color("b07a52"), Color("8a5a3b"), Color("f6d6b8")]
const HAIRS := [Color("2b1d14"), Color("5a3a22"), Color("a0662f"), Color("d8b05a"), Color("1b1b1b"), Color("7a2e1f")]
const CLOTHES := {
	"cueilleur": Color("5d9b4a"), "fermier": Color("d8b64a"), "chasseur": Color("8a5a36"), "pêcheur": Color("3f7fbf"),
	"bâtisseur": Color("d9803a"), "enfant": Color("e8a0bf"), "chef": Color("8e5cc7"),
	"bûcheron": Color("a33b2b"), "mineur": Color("6d6258"), "explorateur": Color("b08d57"), "forgeron": Color("4e4a47"),
	"gardien": Color("607d8b"), "guérisseur": Color("f2f2f2"),
}
const CARRY := {"wood": Color("8b5a2b"), "berries": Color("c0392b"), "fish": Color("b8c7d6"), "meat": Color("9b3b2e"), "grain": Color("e3c565"), "herbs": Color("66bb6a"), "ore": Color("7e7870"), "water": Color("64b5f6")}
const SHADOW := Color(0, 0, 0, 0.22)
const TOOL := Color("5b4636")
const LINE := Color(1, 1, 1, 0.55)

var skin: Color
var hair: Color
var female := false
var _skin := Color.WHITE


func _init(p: Dictionary) -> void:
	var id: int = p["id"]
	skin = SKINS[id % SKINS.size()]
	hair = HAIRS[(id / 3) % HAIRS.size()]
	female = p["sex"] == "F"


func draw_on(node: Node2D, st: Dictionary) -> void:
	var a: float = st["alpha"]
	var k := 0.72 if st["child"] else 1.0
	var t: float = st["time"]
	var act: String = st["activity"]
	var f: float = st["facing"]
	var up := Vector2(0, -st["lift"])
	var bob := 0.0
	var crouch := 0.0
	if st["walking"]:
		bob = absf(sin(st["step"])) * 1.2
	elif act in ["gather", "farm"]:
		crouch = 2.5 + sin(t * 3.0) * 0.8
	elif act == "sit":
		crouch = 3.0
	elif act == "pray":
		crouch = 3.5 + sin(t * 1.5) * 0.4
	elif act == "rest":
		crouch = 4.5
	elif act == "play":
		bob = absf(sin(t * 7.0 + node.person_id)) * 3.0
	elif act == "dance" and not st["walking"]:
		bob = absf(sin(t * 6.0 + node.person_id)) * 2.5
	elif act == "mourn":
		crouch = 1.2
	if st["cheer"] > 0.0:
		bob = absf(sin(t * 9.0 + node.person_id)) * 4.0
	if st["selected"]:
		node.draw_arc(up, 7.0, 0.0, TAU, 20, Color(1, 0.84, 0.3, a), 1.6)
	node.draw_set_transform(up, 0.0, Vector2(1.0, 0.45))
	node.draw_circle(Vector2.ZERO, 4.5 * k, Color(0, 0, 0, SHADOW.a * a))
	node.draw_set_transform(up + Vector2(0, -bob), 0.0, Vector2(k, k))
	_legs(node, st, a, crouch)
	_body(node, st, a, crouch)
	_arms(node, st, a, crouch, t, f)
	_skin = VillagerMarks.skin(skin, st)
	_head(node, a, crouch, f)
	if st["prophet"]:
		node.draw_arc(Vector2(0, -17.5 + crouch), 2.6, 0.0, TAU, 12, Color(1.0, 0.85, 0.35, a), 1.0)
	VillagerMarks.draw(node, st, crouch, t)
	if st["carrying"] != "":
		_carry(node, st["carrying"], a, crouch)
	node.draw_set_transform(up, 0.0, Vector2.ONE)
	if st["selected"]:
		var font := ThemeDB.fallback_font
		node.draw_string(font, Vector2(-40, -24), st["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(1, 1, 1, a))


func _legs(node: Node2D, st: Dictionary, a: float, crouch: float) -> void:
	var swing := sin(st["step"]) * 2.2 if st["walking"] else 0.0
	var leg := Color(0.25, 0.2, 0.18, a)
	if st["activity"] in ["sit", "pray"] and not st["walking"]:
		node.draw_line(Vector2(-1.2, -3), Vector2(2.5 * st["facing"], -1.5), leg, 1.4)
		node.draw_line(Vector2(1.2, -3), Vector2(3.5 * st["facing"], -1.5), leg, 1.4)
		return
	node.draw_line(Vector2(-1.2, -5 + crouch), Vector2(-1.2 + swing, 0), leg, 1.4)
	node.draw_line(Vector2(1.2, -5 + crouch), Vector2(1.2 - swing, 0), leg, 1.4)


func _body(node: Node2D, st: Dictionary, a: float, crouch: float) -> void:
	var cloth: Color = CLOTHES.get(st["job"], CLOTHES["cueilleur"])
	cloth.a = a
	var top := -11.0 + crouch
	var bottom := -4.5 + crouch
	var hem := 3.2 if female else 2.3
	node.draw_colored_polygon(PackedVector2Array([Vector2(-2.2, top), Vector2(2.2, top), Vector2(hem, bottom), Vector2(-hem, bottom)]), cloth)


func _arms(node: Node2D, st: Dictionary, a: float, crouch: float, t: float, f: float) -> void:
	var shoulder := Vector2(1.8 * f, -9.5 + crouch)
	var arm := Color(skin, a)
	var act: String = st["activity"]
	if act == "dance" and not st["walking"]:
		var wave := sin(t * 6.0 + node.person_id)
		node.draw_line(shoulder, shoulder + Vector2(2.5 * f, -3.5 - wave * 1.5), arm, 1.2)
		node.draw_line(shoulder + Vector2(-3.6 * f, 0), shoulder + Vector2(-6.0 * f, -3.0 + wave * 1.5), arm, 1.2)
		return
	if st["cheer"] > 0.0 or act == "pray":
		var lift_arm := 5.5 if st["cheer"] > 0.0 else 4.0 + sin(t * 1.5) * 0.6
		node.draw_line(shoulder, shoulder + Vector2(1.5 * f, -lift_arm), arm, 1.2)
		node.draw_line(shoulder + Vector2(-3.6 * f, 0), shoulder + Vector2(-4.5 * f, -lift_arm), arm, 1.2)
		return
	if st["walking"]:
		var s := sin(st["step"]) * 2.0
		node.draw_line(shoulder, shoulder + Vector2(s * f, 4.5), arm, 1.2)
		return
	match act:
		"mine":
			var swing := sin(t * 6.0)
			var hand := shoulder + Vector2((2.2 + swing * 1.2) * f, -2.0 + swing * 3.5)
			node.draw_line(shoulder, hand, arm, 1.2)
			var head := hand + Vector2(3.0 * f, -3.0 + swing * 2.0)
			node.draw_line(hand, head, Color(TOOL, a), 1.2)
			node.draw_line(head + Vector2(-1.8, -1.0), head + Vector2(1.8, 1.0), Color(0.55, 0.55, 0.6, a), 1.1)
		"scout":
			var look := sin(t * 0.8)
			node.draw_line(shoulder, shoulder + Vector2(1.2 * f, -3.2), arm, 1.2)
			node.draw_line(shoulder + Vector2(1.2 * f, -3.2), shoulder + Vector2((2.6 + look) * f, -3.6), arm, 1.2)
		"chop", "build", "farm", "forge":
			var swing := sin(t * (7.0 if act != "farm" else 4.0))
			var hand := shoulder + Vector2((2.5 + swing * 1.5) * f, -1.0 + swing * 3.0)
			node.draw_line(shoulder, hand, arm, 1.2)
			node.draw_line(hand, hand + Vector2(3.5 * f, -2.5 + swing * 2.0), Color(TOOL, a), 1.3)
		"fish":
			var hand := shoulder + Vector2(3.0 * f, -1.0)
			node.draw_line(shoulder, hand, arm, 1.2)
			var tip := hand + Vector2(7.0 * f, -6.0)
			node.draw_line(hand, tip, Color(TOOL, a), 1.0)
			var bob_pos := tip + Vector2(4.0 * f, 12.0 + sin(t * 2.0) * 0.8)
			node.draw_line(tip, bob_pos, Color(LINE, LINE.a * a), 0.6)
			node.draw_circle(bob_pos, 0.9, Color(0.9, 0.2, 0.2, a))
		"hunt":
			node.draw_line(shoulder, shoulder + Vector2(3.0 * f, 1.0), arm, 1.2)
			node.draw_line(shoulder + Vector2(-2.0 * f, 4.0), shoulder + Vector2(7.0 * f, -5.0), Color(TOOL, a), 1.0)
		"gather":
			node.draw_line(shoulder, shoulder + Vector2(2.5 * f, 4.0 + sin(t * 5.0)), arm, 1.2)
		_:
			node.draw_line(shoulder, shoulder + Vector2(0.8 * f, 4.5), arm, 1.2)


func _head(node: Node2D, a: float, crouch: float, f: float) -> void:
	var c := Vector2(0, -13.2 + crouch)
	node.draw_circle(c, 2.4, Color(_skin, a))
	node.draw_arc(c + Vector2(0, -0.2), 2.5, PI * 1.05, PI * 1.95, 8, Color(hair, a), 1.6)
	if female:
		node.draw_line(c + Vector2(-2.2 * f, -0.5), c + Vector2(-2.6 * f, 3.0), Color(hair, a), 1.4)


func _carry(node: Node2D, item: String, a: float, crouch: float) -> void:
	var c: Color = CARRY.get(item, CARRY["berries"])
	c.a = a
	var p := Vector2(0, -17.5 + crouch)
	if item == "wood":
		node.draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 2.2)), c)
		node.draw_rect(Rect2(p + Vector2(-3.5, -3), Vector2(7, 2.0)), c.lightened(0.15))
	elif item == "fish":
		node.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(2, -1.5), p + Vector2(2, 1.5)]), c)
		node.draw_colored_polygon(PackedVector2Array([p + Vector2(2, 0), p + Vector2(4, -1.5), p + Vector2(4, 1.5)]), c)
	else:
		node.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 3)), Color(0.55, 0.38, 0.2, a))
		node.draw_circle(p + Vector2(-1, -1.2), 1.2, c)
		node.draw_circle(p + Vector2(1.2, -1.4), 1.2, c)
