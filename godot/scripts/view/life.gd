extends Node2D

signal selected(kind: String, id: int)

const VILLAGER := preload("res://scripts/view/villager.gd")
const VILLAGE := preload("res://scripts/view/village_view.gd")
const HERD := preload("res://scripts/view/herd_view.gd")
const EFFECTS := preload("res://scripts/view/effects.gd")
const FAITH_FX := preload("res://scripts/view/faith_fx.gd")
const WORLD_FX := preload("res://scripts/view/world_fx.gd")
const TROOP := preload("res://scripts/view/troop_view.gd")
const PICK_VILLAGER := 16.0
const PICK_VILLAGE := 46.0

var entities: Node2D
var effects: Node2D
var faith_fx: Node2D
var villagers := {}
var villages := {}
var herds := {}
var troops := {}
var world_fx: Node2D
var selection_id := -1


func setup(entity_root: Node2D) -> void:
	entities = entity_root
	effects = Node2D.new()
	effects.set_script(EFFECTS)
	add_child(effects)
	faith_fx = Node2D.new()
	faith_fx.set_script(FAITH_FX)
	add_child(faith_fx)
	faith_fx.setup(self, effects)
	world_fx = Node2D.new()
	world_fx.set_script(WORLD_FX)
	add_child(world_fx)
	world_fx.setup(self, effects)
	Sim.day_passed.connect(func(_d): sync())
	Sim.world_loaded.connect(_reset)
	Sim.event_logged.connect(_on_event)
	_reset()


func relayout() -> void:
	_reset()


func _reset() -> void:
	for group in [villagers, villages, herds, troops]:
		for n in group.values():
			n.queue_free()
		group.clear()
	if not Sim.state.is_empty():
		sync()


func sync() -> void:
	var state: Dictionary = Sim.state
	var opts := DebugOptions.parse()
	if not opts.has("no-villages"):
		_sync_villages(state)
	if not opts.has("no-villagers"):
		_sync_villagers(state)
	if not opts.has("no-animals"):
		_sync_herds(state)
	_sync_troops(state)


func _sync_villages(state: Dictionary) -> void:
	for s in state["settlements"]:
		var id: int = s["id"]
		if not villages.has(id):
			var v := Node2D.new()
			v.set_script(VILLAGE)
			entities.add_child(v)
			v.setup(s, entities, effects)
			villages[id] = v
		villages[id].refresh()


func _sync_villagers(state: Dictionary) -> void:
	var seen := {}
	for p in state["people"]:
		if not p["alive"]:
			continue
		var id: int = p["id"]
		seen[id] = true
		if not villagers.has(id) and villages.has(p["home"]):
			var v := Node2D.new()
			v.set_script(VILLAGER)
			entities.add_child(v)
			v.setup(p, self)
			villagers[id] = v
	for id in villagers.keys():
		if not seen.has(id):
			villagers[id].leave()
			villagers.erase(id)


func _sync_troops(state: Dictionary) -> void:
	var seen := {}
	var groups := [["z", state.get("zombies", {}).get("hordes", [])], ["r", state.get("raiders", [])]]
	for g in groups:
		for r in g[1]:
			var key: String = "%s%d" % [g[0], r["id"]]
			seen[key] = true
			if not troops.has(key):
				var v := Node2D.new()
				v.set_script(TROOP)
				entities.add_child(v)
				v.setup(r, "zombie" if g[0] == "z" else r["kind"])
				troops[key] = v
			troops[key].record = r
	for key in troops.keys():
		if not seen.has(key):
			troops[key].queue_free()
			troops.erase(key)


func _sync_herds(state: Dictionary) -> void:
	for h in state["herds"]:
		if not herds.has(h["id"]):
			var v := Node2D.new()
			v.set_script(HERD)
			entities.add_child(v)
			v.setup(h)
			herds[h["id"]] = v
		herds[h["id"]].refresh()


func village_of(settlement_id: int):
	return villages.get(settlement_id)


func herd_near(tile: Vector2):
	var best = null
	var best_d := 9999.0
	for h in Sim.state["herds"]:
		var d := tile.distance_to(Vector2(h["x"], h["y"]))
		if h["species"] != "wolf" and d < best_d:
			best_d = d
			best = herds.get(h["id"])
	return best if best_d < 8.0 else null


func _on_event(entry: Dictionary) -> void:
	if entry.has("voyage"):
		world_fx.voyage(entry, func():
			effects.on_event(entry, self)
			faith_fx.on_event(entry))
		return
	effects.on_event(entry, self)
	faith_fx.on_event(entry)
	world_fx.on_event(entry)
	if entry["type"] in ["apocalypse", "raid", "zombie"]:
		_sync_troops(Sim.state)


func villager(id: int):
	return villagers.get(id)


func tap(world_pos: Vector2) -> void:
	var best = null
	var best_d := PICK_VILLAGER
	for v in villagers.values():
		if v.visible:
			var d: float = (v.position - Vector2(0, v.lift)).distance_to(world_pos + Vector2(0, 8))
			if d < best_d:
				best_d = d
				best = v
	if best != null:
		_select("person", best.person_id)
		return
	for v in villages.values():
		if v.alive() and v.position.distance_to(world_pos) < PICK_VILLAGE:
			_select("settlement", v.settlement_id)
			return
	_select("", -1)


func _select(kind: String, id: int) -> void:
	if villagers.has(selection_id):
		villagers[selection_id].selected = false
	selection_id = id if kind == "person" else -1
	if villagers.has(selection_id):
		villagers[selection_id].selected = true
	selected.emit(kind, id)
