extends Node2D

const FILL_ALPHA := 0.16
const EDGE_ALPHA := 0.85
const EDGE_WIDTH := 1.6
const REFRESH_DAYS := 10
const HALF_W := Iso.TILE_W * 0.5
const HALF_H := Iso.TILE_H * 0.5
const EDGES := [[Vector2i(-1, 0), 3, 0], [Vector2i(0, -1), 0, 1], [Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 2, 3]]

var _built: ArrayMesh
var _last := -99999


func _ready() -> void:
	Sim.day_passed.connect(func(day): if day - _last >= REFRESH_DAYS: queue_redraw())
	Sim.world_loaded.connect(queue_redraw)
	Sim.event_logged.connect(func(e): if e["type"] in ["civilisation", "conquete", "independance", "chute", "ralliement"]: queue_redraw())


func _draw() -> void:
	if Sim.state.is_empty() or Sim.state.get("civs", []).is_empty():
		return
	_last = Sim.state["day"]
	var map := Territory.map_of(Sim.state)
	var colors := {}
	for c in Civs.alive(Sim.state):
		colors[c["id"]] = c["color"]
	var mesh := MeshBuilder.new()
	var world: Dictionary = Sim.state["world"]
	var sides: Array = EDGES.map(func(edge): return [edge[0], _corners_for(Iso.screen_dir(edge[0]))])
	for pos in map:
		var id: int = map[pos]
		if not colors.has(id):
			continue
		var c := Iso.project(pos.x, pos.y, Iso.tile_lift(world, pos.x, pos.y))
		var corners := [c + Vector2(0, -HALF_H), c + Vector2(HALF_W, 0), c + Vector2(0, HALF_H), c + Vector2(-HALF_W, 0)]
		mesh.poly(PackedVector2Array(corners), Color(colors[id], FILL_ALPHA))
		for side in sides:
			if map.get(pos + side[0], -1) != id:
				mesh.line(corners[side[1][0]], corners[side[1][1]], Color(colors[id], EDGE_ALPHA), EDGE_WIDTH)
	_built = mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _corners_for(screen: Vector2i) -> Array:
	for edge in EDGES:
		if edge[0] == screen:
			return [edge[1], edge[2]]
	return [0, 1]
