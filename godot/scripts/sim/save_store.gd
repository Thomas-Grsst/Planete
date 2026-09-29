class_name SaveStore
extends RefCounted

const DIR := "user://worlds"
const CURRENT := "user://current_world.txt"


static func _path(id: String) -> String:
	return "%s/%s.save" % [DIR, id]


static func save(state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	state["last_sim_time"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(_path(state["id"]), FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(state)
	file.close()
	var current := FileAccess.open(CURRENT, FileAccess.WRITE)
	if current != null:
		current.store_string(state["id"])
	return true


static func load_world(id: String) -> Dictionary:
	if not FileAccess.file_exists(_path(id)):
		return {}
	var file := FileAccess.open(_path(id), FileAccess.READ)
	var data = file.get_var()
	return data if data is Dictionary else {}


static func current_id() -> String:
	if not FileAccess.file_exists(CURRENT):
		return ""
	return FileAccess.get_file_as_string(CURRENT).strip_edges()


static func list_worlds() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".save"):
			out.append(f.trim_suffix(".save"))
	return out


static func delete_world(id: String) -> void:
	DirAccess.remove_absolute(_path(id))
