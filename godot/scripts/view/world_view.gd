extends Node2D

const TERRAIN_REFRESH_DAYS := 5
const FLORA_REFRESH_DAYS := 30
const FLORA_NEAR := 1

var entities: Node2D
var life: Node2D
var map: Node2D
var territory: Node2D
var routes: Node2D
var skip_flora := false
var _season := -1


func build() -> void:
	entities = Node2D.new()
	entities.y_sort_enabled = true
	map = Node2D.new()
	map.set_script(load("res://scripts/view/map_view.gd"))
	add_child(map)
	map.skip_flora = skip_flora
	map.setup(entities)
	territory = Node2D.new()
	territory.set_script(load("res://scripts/view/territory_layer.gd"))
	territory.z_index = -7
	add_child(territory)
	routes = Node2D.new()
	routes.set_script(load("res://scripts/view/route_layer.gd"))
	routes.z_index = -7
	add_child(routes)
	add_child(entities)
	life = Node2D.new()
	life.set_script(load("res://scripts/view/life.gd"))
	add_child(life)
	life.setup(entities)
	life.world_fx.map_changed.connect(_on_map_changed)
	Sim.day_passed.connect(_on_day)
	Sim.power_used.connect(func(name, _answered): if name == "grow": map.refresh_flora())
	Sim.world_loaded.connect(spawn_flora)


func _on_map_changed() -> void:
	map.rebuild()
	territory.queue_redraw()


func spawn_flora() -> void:
	map.rebuild()


func rotate_view() -> void:
	map.rebuild()
	territory.queue_redraw()
	routes.queue_redraw()
	life.relayout()


func _on_day(day: int) -> void:
	var season := Weather.season(day)
	map.refresh_terrain(day % TERRAIN_REFRESH_DAYS == 0)
	if season != _season:
		_season = season
		map.refresh_rivers()
	if day % FLORA_REFRESH_DAYS == 0:
		map.refresh_flora()
		return
	for s in Sim.state["settlements"]:
		if s["abandoned"] < 0:
			var key := WorldGen.key_of(s["x"], s["y"])
			map.refresh_flora(Rect2i(key - Vector2i.ONE * FLORA_NEAR, Vector2i.ONE * (FLORA_NEAR * 2 + 1)))
