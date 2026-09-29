extends Node2D

signal shake(amount: float)
signal map_changed

const WALKER := preload("res://scripts/view/walker.gd")
const SKY_OBJECT := preload("res://scripts/view/sky_object.gd")
const CARAVAN_DAYS := 12
const LABEL_LIFT := Vector2(0, -34)

var life
var effects


func setup(manager, fx) -> void:
	life = manager
	effects = fx
	Sim.day_passed.connect(_on_day)


func _tile_of(id: int) -> Variant:
	var s = Settlements.by_id(Sim.state, id)
	return Vector2(s["x"], s["y"]) if s != null else null


func _at(entry: Dictionary) -> Vector2:
	return Iso.ground(Sim.state["world"], entry.get("x", 0), entry.get("y", 0))


func _civ_color(entry: Dictionary) -> Color:
	var civ = Civs.by_id(Sim.state, entry.get("civ", -1))
	return civ["color"] if civ != null else Color("b0bec5")


func _walk(from, to, kind: String, color: Color, size: int, on_arrive: Callable = Callable()) -> void:
	if from == null or to == null:
		return
	var w := Node2D.new()
	w.set_script(WALKER)
	life.entities.add_child(w)
	w.setup(from, to, kind, color, size)
	if on_arrive.is_valid():
		w.arrived.connect(on_arrive)


func _sky(kind: String, at: Vector2) -> void:
	var o := Node2D.new()
	o.set_script(SKY_OBJECT)
	add_child(o)
	o.setup(kind, at)


func on_event(entry: Dictionary) -> void:
	var at := _at(entry)
	match entry["type"]:
		"bataille":
			var target = _tile_of(entry["settlement"])
			_walk(_tile_of(entry["from"]), target, "soldiers", _civ_color(entry), 5, func(): _clash(Iso.ground(Sim.state["world"], target.x, target.y)))
		"commerce":
			_walk(_tile_of(entry["from"]), _tile_of(entry["to"]), "caravan", _civ_color(entry), 1)
		"migration":
			if entry.get("boat", false):
				_walk(_tile_of(entry["from"]), _tile_of(entry["to"]), "boat", Color("ffffff"), 1)
		"cataclysme":
			if entry.get("meteor", false):
				_sky("meteor", at)
				get_tree().create_timer(1.5).timeout.connect(func(): _impact(at, 14.0))
			elif entry.get("volcano", false):
				_impact(at, 10.0)
				effects.plume(at)
			else:
				_impact(at, 8.0)
		"catastrophe":
			if entry.get("fire", false) or entry.get("flood", false):
				effects.burst(at + LABEL_LIFT * 0.5, Color("ff7043") if entry.get("fire", false) else Color("64b5f6"))
		"contact":
			_sky("ufo", at)
		"exode":
			if entry.has("settlement"):
				_sky("rocket", at)
				shake.emit(4.0)
		"guerre", "conquete", "revolution", "independance", "civilisation", "raid", "apocalypse", "statue", "savoir_perdu":
			effects.burst(at + LABEL_LIFT * 0.6, _color_for(entry))
			effects.float_text(at + LABEL_LIFT, _icon_for(entry["type"]), _color_for(entry), true)
	if entry.get("map", false):
		map_changed.emit()


func _color_for(entry: Dictionary) -> Color:
	match entry["type"]:
		"apocalypse": return Color("9ccc65")
		"raid", "guerre", "conquete": return Color("ef5350")
		"savoir_perdu": return Color("b0bec5")
		"statue": return Color("fff3c4")
	return _civ_color(entry)


func _icon_for(type: String) -> String:
	return {"guerre": "⚔️", "conquete": "🏴", "revolution": "✊", "independance": "✊", "civilisation": "🏰", "raid": "🔥", "apocalypse": "🧟", "statue": "🗿", "savoir_perdu": "🕯️"}.get(type, "")


func _clash(pos: Vector2) -> void:
	effects.burst(pos + Vector2(0, -10), Color("ffcc80"))
	effects.puff(pos)
	effects.float_text(pos + LABEL_LIFT, "⚔️", Color("ffcc80"), true)
	shake.emit(2.0)


func _impact(pos: Vector2, amount: float) -> void:
	effects.burst(pos + Vector2(0, -8), Color("ff8a65"))
	effects.puff(pos)
	shake.emit(amount)


func _on_day(day: int) -> void:
	if day % CARAVAN_DAYS != 0:
		return
	for key in Sim.state.get("relations", {}):
		var rel: Dictionary = Sim.state["relations"][key]
		if rel["pact"] == "":
			continue
		var ids: PackedStringArray = key.split("-")
		var a = Civs.by_id(Sim.state, int(ids[0]))
		var b = Civs.by_id(Sim.state, int(ids[1]))
		if a != null and b != null and a["alive"] and b["alive"]:
			_walk(_tile_of(a["capital"]), _tile_of(b["capital"]), "caravan", a["color"], 1)
