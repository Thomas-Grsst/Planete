extends Node2D

const HALF_W := Iso.TILE_W * 0.5
const HALF_H := Iso.TILE_H * 0.5
const AUTUMN := Color("c9772e")
const DRY := Color("c9a54a")
const SNOW := Color("eef3ff")
const SPRING := Color("7ed957")

@export var band_start := 0
@export var band_end := 95

var _season := -1
var _weather := ""
var _mesh: MeshBuilder
var _built: ArrayMesh


func _ready() -> void:
	Sim.day_passed.connect(_on_day)
	Sim.world_loaded.connect(queue_redraw)


func _on_day(day: int) -> void:
	var season := Weather.season(day)
	if season != _season or Sim.state["weather"] != _weather or day % 5 == 0:
		queue_redraw()


func _draw() -> void:
	if Sim.state.is_empty():
		return
	var world: Dictionary = Sim.state["world"]
	_season = Weather.season(Sim.state["day"])
	_weather = Sim.state["weather"]
	var size := WorldGen.SIZE
	_mesh = MeshBuilder.new()
	for diag in range(band_start, min(band_end, size * 2 - 1)):
		for x in range(max(0, diag - size + 1), min(diag, size - 1) + 1):
			var y := diag - x
			var t: Dictionary = world["tiles"][y * size + x]
			if not Biomes.is_water(t["biome"]):
				_draw_tile(x, y, t)
	_built = _mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _draw_tile(x: int, y: int, t: Dictionary) -> void:
	var lift := Iso.lift(t["height"], t["biome"])
	var c := Iso.project(x, y, lift)
	var top := _top_color(x, y, t)
	var n := c + Vector2(0, -HALF_H)
	var e := c + Vector2(HALF_W, 0)
	var s := c + Vector2(0, HALF_H)
	var w := c + Vector2(-HALF_W, 0)
	var down := Vector2(0, lift)
	_mesh.poly(PackedVector2Array([w, s, s + down, w + down]), top.darkened(0.38))
	_mesh.poly(PackedVector2Array([s, e, e + down, s + down]), top.darkened(0.22))
	_mesh.poly(PackedVector2Array([n, e, s, w]), top)
	_mesh.line(w, n, top.lightened(0.12), 1.0)
	_mesh.line(n, e, top.lightened(0.12), 1.0)


func _top_color(x: int, y: int, t: Dictionary) -> Color:
	var biome: String = t["biome"]
	var base: Color = Biomes.DATA[biome]["color"]
	var jitter := (float((x * 73856093) ^ (y * 19349663)) / 2147483647.0)
	base = base.lightened(0.04 * fmod(absf(jitter) * 10.0, 1.0)).darkened(0.03 * fmod(absf(jitter) * 7.0, 1.0))
	base = base.lightened(clamp((t["height"] - 0.5) * 0.35, 0.0, 0.2))
	if biome == "plain" or biome == "forest":
		var cap: float = t["fertility"] * 12.0
		var depletion: float = 1.0 - t["food"] / cap if cap > 0 else 0.0
		base = base.lerp(DRY, clamp(depletion, 0.0, 1.0) * 0.35)
		if _season == 2:
			base = base.lerp(AUTUMN, 0.22 if biome == "plain" else 0.12)
		elif _season == 0:
			base = base.lerp(SPRING, 0.12)
	if _weather == "snow" and biome != "river":
		base = base.lerp(SNOW, 0.7)
	elif _season == 3 and (biome == "tundra" or biome == "mountain"):
		base = base.lerp(SNOW, 0.55)
	elif biome == "mountain" and t["height"] > 0.86:
		base = base.lerp(SNOW, 0.6)
	return base
