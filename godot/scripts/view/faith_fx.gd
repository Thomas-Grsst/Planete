extends Node2D

const PILGRIM := preload("res://scripts/view/pilgrim.gd")
const MIRACLE_GOLD := Color("ffe27a")
const CHEER_SECONDS := 6.0
const LABEL_LIFT := Vector2(0, -34)

var life
var effects


func setup(manager, fx) -> void:
	life = manager
	effects = fx
	Sim.power_used.connect(_on_power)


func _village_pos(id: int) -> Variant:
	var s = Settlements.by_id(Sim.state, id)
	return null if s == null else Iso.ground(Sim.state["world"], s["x"], s["y"]) + LABEL_LIFT


func _color(entry: Dictionary) -> Color:
	var rel = Religions.by_id(Sim.state, entry.get("religion", -1))
	return rel["color"] if rel != null else MIRACLE_GOLD


func on_event(entry: Dictionary) -> void:
	match entry["type"]:
		"religion", "schisme":
			_announce(entry, "🙏 " + FaithData.capitalize(Religions.by_id(Sim.state, entry["religion"])["name"]), true)
		"conversion":
			if entry.has("from"):
				_send_pilgrim(entry)
			else:
				_announce(entry, "🕯️", false)
		"temple":
			var pos = _village_pos(entry["settlement"])
			if pos != null:
				effects.puff(pos - LABEL_LIFT)
				effects.float_text(pos, "🛕", Color.WHITE, true)
		"priere":
			var pos = _village_pos(entry["settlement"])
			if pos != null:
				effects.float_text(pos, "🙏", Color("e8e4ff"))
		"miracle":
			for id in entry.get("settlements", []):
				_miracle_at(id)


func _announce(entry: Dictionary, text: String, big: bool) -> void:
	var pos = _village_pos(entry.get("settlement", -1))
	if pos == null:
		return
	effects.burst(pos - LABEL_LIFT * 0.6, _color(entry))
	effects.float_text(pos, text, _color(entry).lightened(0.3), big)


func _send_pilgrim(entry: Dictionary) -> void:
	var from = Settlements.by_id(Sim.state, entry["from"])
	var to = Settlements.by_id(Sim.state, entry["settlement"])
	if from == null or to == null:
		return
	var walker := Node2D.new()
	walker.set_script(PILGRIM)
	life.entities.add_child(walker)
	walker.setup(Vector2(from["x"], from["y"]), Vector2(to["x"], to["y"]), _color(entry))
	walker.arrived.connect(func(): _announce(entry, "🕯️ " + FaithData.capitalize(Religions.by_id(Sim.state, entry["religion"])["name"]), false))


func _miracle_at(id: int) -> void:
	var pos = _village_pos(id)
	if pos == null:
		return
	effects.burst(pos - LABEL_LIFT * 0.6, MIRACLE_GOLD)
	effects.burst(pos - LABEL_LIFT * 0.3, Color.WHITE)
	effects.float_text(pos, "✨ Miracle !", MIRACLE_GOLD, true)
	for v in life.villagers.values():
		if v.person["home"] == id:
			v.cheer_up(CHEER_SECONDS)


func _on_power(name: String, answered: Array) -> void:
	for s in Sim.state["settlements"]:
		if s["abandoned"] >= 0 or answered.has(s["id"]):
			continue
		var pos = _village_pos(s["id"])
		if pos == null:
			continue
		if name == "grow":
			effects.burst(pos - LABEL_LIFT * 0.5, Color("8fe36a"))
		elif Religions.is_player(Religions.of(Sim.state, s)):
			effects.float_text(pos, "🙏", Color("fff3c4"))
