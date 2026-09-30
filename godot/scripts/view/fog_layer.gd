extends Node2D

const HALF_W := Iso.TILE_W * 0.5
const HALF_H := Iso.TILE_H * 0.5
const DEPTH := 4
const MIST := Color(0.78, 0.84, 0.9)
const STRENGTH := 0.5
const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var chunks := Rect2i()
var _mesh: MeshBuilder
var _built: ArrayMesh


func show_range(r: Rect2i) -> void:
	chunks = r
	queue_redraw()


func _draw() -> void:
	if Sim.state.is_empty() or chunks.size == Vector2i.ZERO:
		return
	var known: Dictionary = Sim.state["world"]["chunks"]
	_mesh = MeshBuilder.new()
	for cy in range(chunks.position.y, chunks.end.y):
		for cx in range(chunks.position.x, chunks.end.x):
			var key := Vector2i(cx, cy)
			if known.has(key):
				continue
			var near: Array = []
			for o in AROUND:
				if known.has(key + o):
					near.append(Rect2i(WorldGen.origin(key + o), Vector2i.ONE * WorldGen.CHUNK))
			if not near.is_empty():
				_edge(key, near)
	_built = _mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _edge(key: Vector2i, near: Array) -> void:
	var o := WorldGen.origin(key)
	for ly in WorldGen.CHUNK:
		for lx in WorldGen.CHUNK:
			var x := o.x + lx
			var y := o.y + ly
			var d := DEPTH + 1
			for r in near:
				var dx: int = max(0, max(r.position.x - x, x - (r.end.x - 1)))
				var dy: int = max(0, max(r.position.y - y, y - (r.end.y - 1)))
				d = min(d, dx + dy)
			if d <= DEPTH:
				_mist(x, y, STRENGTH * (1.0 - float(d - 1) / DEPTH))


func _mist(x: int, y: int, alpha: float) -> void:
	var c := Iso.project(x, y)
	_mesh.poly(PackedVector2Array([c + Vector2(0, -HALF_H), c + Vector2(HALF_W, 0), c + Vector2(0, HALF_H), c + Vector2(-HALF_W, 0)]), Color(MIST, alpha))
