class_name MeshBuilder
extends RefCounted

var verts := PackedVector2Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()


func poly(points: PackedVector2Array, color: Color, uv: PackedVector2Array = PackedVector2Array()) -> void:
	for i in range(1, points.size() - 1):
		_vertex(points[0], color, uv[0] if not uv.is_empty() else Vector2.ZERO)
		_vertex(points[i], color, uv[i] if not uv.is_empty() else Vector2.ZERO)
		_vertex(points[i + 1], color, uv[i + 1] if not uv.is_empty() else Vector2.ZERO)


func shaded(points: PackedVector2Array, point_colors: PackedColorArray, uv: PackedVector2Array) -> void:
	for i in range(1, points.size() - 1):
		_vertex(points[0], point_colors[0], uv[0])
		_vertex(points[i], point_colors[i], uv[i])
		_vertex(points[i + 1], point_colors[i + 1], uv[i + 1])


func rect(r: Rect2, color: Color) -> void:
	poly(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]), color)


func line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var n := (b - a).orthogonal().normalized() * width * 0.5
	poly(PackedVector2Array([a - n, b - n, b + n, a + n]), color)


func _vertex(p: Vector2, c: Color, uv: Vector2) -> void:
	verts.append(p)
	colors.append(c)
	uvs.append(uv)


func build() -> ArrayMesh:
	if verts.is_empty():
		return null
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh
