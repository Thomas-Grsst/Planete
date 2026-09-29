extends Node2D

const ANIMAL := preload("res://scripts/view/animal.gd")
const MAX_ANIMALS := 6
const ROAM := 0.9

var herd: Dictionary
var animals: Array = []


func setup(h: Dictionary) -> void:
	herd = h
	y_sort_enabled = true
	refresh()


func center() -> Vector2:
	return Vector2(herd["x"], herd["y"])


func refresh() -> void:
	var wanted: int = clampi(int(round(herd["count"] / 3.0)), 1, MAX_ANIMALS) if herd["count"] >= 1.0 else 0
	while animals.size() < wanted:
		var a := Node2D.new()
		a.set_script(ANIMAL)
		add_child(a)
		a.setup(self, herd["species"], animals.size())
		animals.append(a)
	while animals.size() > wanted:
		animals.pop_back().queue_free()


func roam_target(index: int) -> Vector2:
	var angle := randf() * TAU
	return center() + Vector2(cos(angle), sin(angle)) * ROAM * randf() + Vector2(0.15 * (index % 3), 0)


func hunt_spot(seed_value: int) -> Vector2:
	var a := float(absi(seed_value) % 360) * PI / 180.0
	return center() + Vector2(cos(a), sin(a)) * 1.3
