extends Node2D

const HOUSE := preload("res://scripts/view/house.gd")
const PROPS := preload("res://scripts/view/village_props.gd")
const RINGS := [[0.95, 6, 0.3], [1.65, 10, 0.1], [2.35, 14, 0.5], [3.0, 18, 0.2]]
const FIELD_MIN_FERTILITY := 0.5
const TEMPLE := preload("res://scripts/view/temple.gd")
const EXTRAS := preload("res://scripts/view/village_extras.gd")
const HARBOR := preload("res://scripts/view/harbor.gd")
const WALLS := preload("res://scripts/view/walls.gd")
const TEMPLE_OFFSET := Vector2(-0.95, -0.95)
const TEMPLE_CLEARANCE := 0.75

var settlement: Dictionary
var settlement_id := -1
var entities: Node2D
var effects: Node2D
var houses: Array = []
var fields: Array = []
var props
var temple
var extras
var harbor
var walls: Array = []
var slots: Array = []


func setup(s: Dictionary, entity_root: Node2D, fx: Node2D) -> void:
	settlement = s
	settlement_id = s["id"]
	entities = entity_root
	effects = fx
	y_sort_enabled = true
	position = Iso.project(s["x"], s["y"])
	var world: Dictionary = Sim.state["world"]
	for ring in RINGS:
		for i in ring[1]:
			var a: float = TAU * i / ring[1] + ring[2]
			var offset: Vector2 = Vector2(cos(a), sin(a)) * ring[0]
			if _dry(world, center() + offset) and offset.distance_to(TEMPLE_OFFSET) >= TEMPLE_CLEARANCE:
				slots.append(offset)
	if slots.is_empty():
		slots.append(Vector2(0.6, 0.0))
	props = Node2D.new()
	props.set_script(PROPS)
	add_child(props)
	props.setup(self)
	temple = Node2D.new()
	temple.set_script(TEMPLE)
	add_child(temple)
	var spot := _land(center() + TEMPLE_OFFSET)
	temple.global_position = Iso.project(spot.x, spot.y)
	temple.setup(self, Iso.lift_at(world, spot.x, spot.y))
	extras = Node2D.new()
	extras.set_script(EXTRAS)
	add_child(extras)
	extras.setup(self)
	for front in [false, true]:
		var w := Node2D.new()
		w.set_script(WALLS)
		add_child(w)
		w.setup(self, front)
		walls.append(w)


func _dry(world: Dictionary, tile: Vector2) -> bool:
	for corner in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		var t = WorldGen.tile_at(world, int(round(tile.x + corner.x)), int(round(tile.y + corner.y)))
		if t == null or not Biomes.walkable(t["biome"]) or t["biome"] == "river":
			return false
	return true


func _land(point: Vector2) -> Vector2:
	var world: Dictionary = Sim.state["world"]
	for k in 6:
		if WorldGen.is_walkable(world, int(round(point.x)), int(round(point.y))):
			return point
		point = point.lerp(center(), 0.4)
	return center()


func praying() -> bool:
	return not settlement.get("prayer", {}).is_empty()


func alive() -> bool:
	return settlement["abandoned"] < 0


func center() -> Vector2:
	return Vector2(settlement["x"], settlement["y"])


func _ground(tile: Vector2) -> Vector2:
	return Iso.ground(Sim.state["world"], tile.x, tile.y)


func refresh() -> void:
	var wanted: int = settlement["houses"] if alive() else 0
	while houses.size() < min(wanted, slots.size()):
		var h := Node2D.new()
		h.set_script(HOUSE)
		var tile: Vector2 = center() + slots[houses.size()]
		add_child(h)
		h.global_position = Iso.project(tile.x, tile.y)
		h.setup(self, houses.size(), Sim.state["day"] - settlement["founded_day"] > 1, Iso.lift_at(Sim.state["world"], tile.x, tile.y))
		houses.append(h)
		if Sim.state["day"] - settlement["founded_day"] > 1:
			effects.puff(_ground(tile))
	while houses.size() > max(0, wanted) and not houses.is_empty():
		var gone = houses.pop_back()
		effects.puff(gone.global_position + Vector2(0, -gone.lift))
		gone.collapse()
	for h in houses:
		h.refresh()
	_refresh_fields()
	props.refresh()
	temple.refresh()
	extras.refresh()
	_refresh_harbor()
	for w in walls:
		w.refresh()


func _refresh_fields() -> void:
	fields.clear()
	if not Techs.has_tech(settlement, "agriculture") or not alive():
		props.queue_redraw()
		return
	var world: Dictionary = Sim.state["world"]
	var wanted: int = clampi(2 + settlement["houses"] / 2, 2, 9)
	for o in Work.offsets():
		var d: int = absi(o.x) + absi(o.y)
		if d < 2 or fields.size() >= wanted:
			continue
		var t = WorldGen.tile_at(world, settlement["x"] + o.x, settlement["y"] + o.y)
		if t != null and Biomes.walkable(t["biome"]) and t["biome"] != "river" and t["fertility"] >= FIELD_MIN_FERTILITY:
			fields.append(center() + Vector2(o))


func slot_tile(index: int) -> Vector2:
	return center() + slots[index % slots.size()]


func door(person_id: int) -> Vector2:
	var count: int = max(1, min(houses.size(), slots.size()))
	var tile := slot_tile(person_id % count)
	return tile + (center() - tile) * 0.22


func sit_spot(person_id: int) -> Vector2:
	var a := float(person_id % 12) / 12.0 * TAU
	var r := 0.42 + 0.12 * float(person_id % 3)
	return _land(center() + Vector2(cos(a), sin(a)) * r)


func play_spot(seed_value: int) -> Vector2:
	var a := float(absi(seed_value * 7919) % 360) * PI / 180.0
	var r := 0.3 + float(absi(seed_value * 104729) % 100) / 100.0 * 0.9
	return _land(center() + Vector2(cos(a), sin(a)) * r)


func storage_spot(person_id: int) -> Vector2:
	return _land(center() + Vector2(0.55, -0.35) + Vector2(float(person_id % 3) * 0.06, 0))


func construction_spot(seed_value: int) -> Vector2:
	var tile := slot_tile(houses.size())
	return tile + Vector2(0.28 * (1 if seed_value % 2 == 0 else -1), 0.2)


func patrol_spot(seed_value: int) -> Vector2:
	var a := float(absi(seed_value * 2654435) % 628) / 100.0
	var r: float = 1.4 + 0.25 * houses.size() / 6.0
	return _land(center() + Vector2(cos(a), sin(a)) * min(r, 3.2))


func forge_spot(person_id: int) -> Vector2:
	return _land(center() + Vector2(-0.55, 0.45) + Vector2(0.08 * (person_id % 2), 0))


func receive(item: String) -> void:
	if item != "":
		props.bump(item)


func _refresh_harbor() -> void:
	if harbor != null or not Ports.has_port(settlement):
		return
	harbor = Node2D.new()
	harbor.set_script(HARBOR)
	add_child(harbor)
	harbor.setup(self, Ports.tile(settlement))
