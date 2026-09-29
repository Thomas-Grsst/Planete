extends Node2D

const MAX_TREES := 4
const OFFSETS := [Vector2(-9, -2), Vector2(8, 1), Vector2(-1, 5), Vector2(3, -6)]
const PINE := Color("2e6b34")
const LEAF := Color("4f9e3a")
const AUTUMN_LEAF := Color("d9822b")
const WINTER_LEAF := Color("7d8f74")
const TRUNK := Color("6d4c33")

static var sway_material: ShaderMaterial

var tiles: Array = []
var counts: Dictionary = {}
var conifers: Dictionary = {}
var offsets: Dictionary = {}
var season := -1
var _mesh: MeshBuilder
var _built: ArrayMesh


func setup(diagonal_tiles: Array) -> void:
	tiles = diagonal_tiles
	if sway_material == null:
		sway_material = ShaderMaterial.new()
		sway_material.shader = load("res://shaders/sway.gdshader")
	material = sway_material
	var world: Dictionary = Sim.state["world"]
	for i in tiles:
		var t: Dictionary = world["tiles"][i]
		conifers[i] = t["biome"] == "forest" and (i * 2654435761) % 3 != 0 or t["biome"] == "tundra" or t["biome"] == "mountain"
		offsets[i] = Iso.ground(world, i % WorldGen.SIZE, i / WorldGen.SIZE) - position
	refresh()


func refresh() -> void:
	var world: Dictionary = Sim.state["world"]
	var now := Weather.season(Sim.state["day"])
	var changed := now != season
	for i in tiles:
		var n: int = min(MAX_TREES, world["tiles"][i]["trees"])
		if counts.get(i, -1) != n:
			counts[i] = n
			changed = true
	season = now
	if changed:
		queue_redraw()


func _draw() -> void:
	_mesh = MeshBuilder.new()
	for i in tiles:
		var base: Vector2 = offsets[i]
		for k in counts[i]:
			var scale_k: float = 0.62 + 0.08 * ((i + k * 7) % 4)
			if conifers[i]:
				_pine(base + OFFSETS[k], 7.0 * scale_k)
			else:
				_leafy(base + OFFSETS[k], 6.5 * scale_k, i)
	_built = _mesh.build()
	if _built != null:
		draw_mesh(_built, null)


func _pine(o: Vector2, r: float) -> void:
	_mesh.rect(Rect2(o + Vector2(-r * 0.14, -r * 0.5), Vector2(r * 0.28, r * 0.7)), TRUNK)
	for layer in 3:
		var base := o + Vector2(0, -r * (0.35 + layer * 0.55))
		var w := r * (1.0 - layer * 0.22)
		var tip := base + Vector2(0, -r * 1.05)
		var shade := PINE.lightened(0.08 * layer)
		var sway := 0.3 + layer * 0.25
		_mesh.shaded(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(w, 0), tip]), PackedColorArray([shade.darkened(0.15), shade, shade]), PackedVector2Array([Vector2(0, sway), Vector2(1, sway), Vector2(0.5, sway + 0.25)]))


func _leafy(o: Vector2, r: float, tile_index: int) -> void:
	_mesh.rect(Rect2(o + Vector2(-r * 0.15, -r * 0.9), Vector2(r * 0.3, r * 1.1)), TRUNK)
	var leaf := LEAF
	if season == 2:
		leaf = AUTUMN_LEAF.lerp(LEAF, 0.15 * ((tile_index + int(o.x)) % 3))
	elif season == 3:
		leaf = WINTER_LEAF
	var center := o + Vector2(0, -r * 1.55)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for k in 10:
		var a := TAU * k / 10.0
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.85))
		uvs.append(Vector2(0, clamp(0.55 - sin(a) * 0.45, 0.0, 1.0)))
		cols.append(leaf.darkened(0.12) if sin(a) > 0.2 else leaf.lightened(0.06))
	_mesh.shaded(pts, cols, uvs)
