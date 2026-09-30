class_name RouteLayer
extends Node2D

const ROAD := Color(0.55, 0.4, 0.25, 0.75)
const SEA_LANE := Color(1, 1, 1, 0.45)
const ROAD_WIDTH := 2.2
const LANE_WIDTH := 1.6
const DASH := 0.45
const GAP := 0.3
const REDRAW_DAYS := 30

var _built: ArrayMesh


func _ready() -> void:
	Sim.world_loaded.connect(queue_redraw)
	Sim.event_logged.connect(func(e): if e["type"] in ["route", "conquete", "independance", "chute", "paix", "guerre", "rupture"]: queue_redraw())
	Sim.day_passed.connect(func(day): if day % REDRAW_DAYS == 0: queue_redraw())


static func ends(s: Dictionary, sea: bool) -> Vector2:
	if sea and Ports.has_port(s):
		return Vector2(Ports.tile(s))
	return Vector2(s["x"], s["y"])


func _draw() -> void:
	if Sim.state.is_empty():
		return
	var world: Dictionary = Sim.state["world"]
	var mesh := MeshBuilder.new()
	for r in Sim.state.get("routes", []):
		var a = Settlements.by_id(Sim.state, r["a"])
		var b = Settlements.by_id(Sim.state, r["b"])
		if a == null or b == null:
			continue
		var sea: bool = r["kind"] == "sea"
		var from := ends(a, sea)
		var to := ends(b, sea)
		var length := from.distance_to(to)
		var t := 0.8
		while t < length - 0.8:
			var p := from.lerp(to, t / length)
			var q := from.lerp(to, min(t + DASH, length) / length)
			var pa := Iso.project(p.x, p.y) if sea else Iso.ground(world, p.x, p.y)
			var qa := Iso.project(q.x, q.y) if sea else Iso.ground(world, q.x, q.y)
			mesh.line(pa, qa, SEA_LANE if sea else ROAD, LANE_WIDTH if sea else ROAD_WIDTH)
			t += DASH + GAP
	_built = mesh.build()
	if _built != null:
		draw_mesh(_built, null)
