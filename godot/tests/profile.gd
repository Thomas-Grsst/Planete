extends SceneTree


func _init() -> void:
	var sim = load("res://scripts/sim/sim.gd").new()
	sim.start_new("P", "bench-1")
	for d in 5000:
		sim.tick(false)
	var st: Dictionary = sim.state
	var rng: Rng = sim.rng
	var totals := {}
	for d in 1000:
		st["day"] += 1
		var t := Time.get_ticks_usec()
		Weather.step(st, rng); t = _mark(totals, "weather", t)
		Work.regrow(st); t = _mark(totals, "regrow", t)
		var census := Census.build(st); t = _mark(totals, "census", t)
		Work.step(st, rng, census); t = _mark(totals, "work", t)
		People.step(st, rng, census); t = _mark(totals, "people", t)
		Jobs.step(st, rng, census); t = _mark(totals, "jobs", t)
		Settlements.step(st, rng, census); t = _mark(totals, "settlements", t)
		Herds.step(st, rng); t = _mark(totals, "herds", t)
		Ideas.step(st, rng, census); t = _mark(totals, "ideas", t)
	for k in totals:
		print("%s: %.3f ms/tick" % [k, totals[k] / 1000.0 / 1000.0])
	print("people records: %d, alive %d" % [st["people"].size(), People.alive_count(st)])
	quit()


func _mark(totals: Dictionary, key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	totals[key] = totals.get(key, 0) + now - since
	return now
