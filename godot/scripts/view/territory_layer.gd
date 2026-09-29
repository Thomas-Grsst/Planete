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
	for y in WorldGen.SIZE:
		for x in WorldGen.SIZE:
			var id: int = map[y * WorldGen.SIZE + x]
			if not colors.has(id):
				continue
			var c := Iso.project(x, y, Iso.tile_lift(world, x, y))
			var corners := [c + Vector2(0, -HALF_H), c + Vector2(HALF_W, 0), c + Vector2(0, HALF_H), c + Vector2(-HALF_W, 0)]
			mesh.poly(PackedVector2Array(corners), Color(colors[id], FILL_ALPHA))
			for edge in EDGES:
				var n: Vector2i = Vector2i(x, y) + edge[0]
				var other: int = map[n.y * WorldGen.SIZE + n.x] if n.x >= 0 and n.y >= 0 and n.x < WorldGen.SIZE and n.y < WorldGen.SIZE else -1
				if other != id:
					mesh.line(corners[edge[1]], corners[edge[2]], Color(colors[id], EDGE_ALPHA), EDGE_WIDTH)
	_built = mesh.build()
	if _built != null:
		draw_mesh(_built, null)
