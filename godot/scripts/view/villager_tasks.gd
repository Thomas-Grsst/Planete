class_name VillagerTasks
extends RefCounted

const RADIUS := 4
const ELDER_AGE := 58


static func choose(v, village) -> Dictionary:
	var p: Dictionary = v.person
	var s: Dictionary = village.settlement
	var world: Dictionary = Sim.state["world"]
	var age := People.age_of(Sim.state, p)
	var seed_value: int = v.person_id * 31 + Sim.state["day"] * 7 + v.chores
	if not People.is_adult(Sim.state, p):
		return _task(village.play_spot(seed_value), "play", 5.0, "")
	if not p.get("sick", {}).is_empty() or p.get("bitten", -1) >= 0:
		return _task(village.door(v.person_id), "rest", 12.0, "")
	if age >= ELDER_AGE:
		return _task(village.sit_spot(v.person_id), "sit", 14.0, "")
	match p["job"]:
		"chef":
			return _task(village.play_spot(seed_value), "idle", 10.0, "")
		"gardien":
			return _task(village.patrol_spot(seed_value), "guard", 8.0, "")
		"forgeron":
			return _task(village.forge_spot(v.person_id), "forge", 14.0, "")
		"guérisseur":
			if not s.get("outbreak", {}).is_empty():
				return _task(village.door(seed_value), "heal", 8.0, "")
			return _tile_task(world, s, seed_value, func(t): return t["biome"] in ["forest", "swamp", "plain"], "gather", 10.0, "herbs", village)
		"bâtisseur":
			if s["construction"] >= 0.0:
				return _task(village.construction_spot(seed_value), "build", 10.0, "")
			return _tile_task(world, s, seed_value, func(t): return t["trees"] > 0, "chop", 9.0, "wood", village)
		"bûcheron":
			return _tile_task(world, s, seed_value, func(t): return t["trees"] > 0, "chop", 11.0, "wood", village)
		"mineur":
			var mine = village.mine_tile()
			if mine != null:
				return _task(mine + _jitter(seed_value, 0.25), "mine", 14.0, "ore")
		"explorateur":
			return _task(_far_spot(world, s, seed_value, village), "scout", 9.0, "")
		"pêcheur":
			var shore = _shore(world, s, seed_value)
			if shore != null:
				return _task(shore, "fish", 16.0, "fish")
		"chasseur":
			var herd = v.life.herd_near(Vector2(s["x"], s["y"]))
			if herd != null:
				return _task(herd.hunt_spot(seed_value), "hunt", 10.0, "meat")
		"fermier":
			if not village.fields.is_empty():
				return _task(village.fields[seed_value % village.fields.size()] + _jitter(seed_value, 0.3), "farm", 12.0, "grain")
	if seed_value % 5 == 0:
		var water = _shore(world, s, seed_value)
		if water != null:
			return _task(water, "gather", 4.0, "water")
	return _tile_task(world, s, seed_value, func(t): return t["food"] > 1.0, "gather", 10.0, "berries", village)


# Un point loin du village, au-delà des champs, pour l'explorateur qui guette l'horizon.
static func _far_spot(world: Dictionary, s: Dictionary, seed_value: int, village) -> Vector2:
	for k in 8:
		var a := float(absi(seed_value * 2654435 + k * 977) % 628) / 100.0
		var r := 5.5 + float(absi(seed_value * 31 + k) % 30) / 10.0
		var p := Vector2(s["x"], s["y"]) + Vector2(cos(a), sin(a)) * r
		if WorldGen.is_walkable(world, int(round(p.x)), int(round(p.y))):
			return p
	return village.patrol_spot(seed_value)


static func _task(goal: Vector2, activity: String, duration: float, carry: String) -> Dictionary:
	return {"goal": goal, "activity": activity, "duration": duration, "carry": carry}


static func _jitter(seed_value: int, amount: float) -> Vector2:
	var a := float((seed_value * 1103515245 + 12345) % 1000) / 1000.0
	var b := float((seed_value * 214013 + 2531011) % 1000) / 1000.0
	return Vector2((a - 0.5) * 2.0 * amount, (b - 0.5) * 2.0 * amount)


static func _tile_task(world: Dictionary, s: Dictionary, seed_value: int, ok: Callable, activity: String, duration: float, carry: String, village) -> Dictionary:
	var options: Array = []
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var t = WorldGen.tile_at(world, s["x"] + dx, s["y"] + dy)
			if t != null and Biomes.walkable(t["biome"]) and t["biome"] != "river" and (absi(dx) + absi(dy)) > 0 and ok.call(t):
				options.append(Vector2(s["x"] + dx, s["y"] + dy))
	if options.is_empty():
		return _task(village.play_spot(seed_value), "gather", duration, carry)
	return _task(options[absi(seed_value) % options.size()] + _jitter(seed_value, 0.45), activity, duration, carry)


static func _shore(world: Dictionary, s: Dictionary, seed_value: int):
	var spots: Array = []
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var x: int = s["x"] + dx
			var y: int = s["y"] + dy
			if not WorldGen.is_walkable(world, x, y):
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n = WorldGen.tile_at(world, x + o.x, y + o.y)
				if n != null and (Biomes.is_water(n["biome"]) or n["biome"] == "river"):
					spots.append(Vector2(x, y) + Vector2(o) * 0.38)
					break
	if spots.is_empty():
		return null
	return spots[absi(seed_value) % spots.size()]
