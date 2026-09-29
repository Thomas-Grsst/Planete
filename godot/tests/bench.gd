extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var worlds := int(args[0]) if args.size() > 0 else 3
	var days := int(args[1]) if args.size() > 1 else 7200
	for w in worlds:
		var sim = load("res://scripts/sim/sim.gd").new()
		sim.start_new("W%d" % w, "bench-%d" % w)
		var t0 := Time.get_ticks_msec()
		for d in days:
			sim.tick(false)
			if d % 1800 == 0:
				var st: Dictionary = sim.state
				var alive: Array = st["settlements"].filter(func(s): return s["abandoned"] < 0)
				print("  w%d day %d pop %d colonies %d techs %s food %s" % [w, st["day"], People.alive_count(st), alive.size(), str(st["discoveries"].keys()), str(alive.map(func(s): return int(s["food"])))])
		var st: Dictionary = sim.state
		var counts := {}
		for e in st["journal"]:
			counts[e["type"]] = counts.get(e["type"], 0) + 1
			if e["type"] == "deces":
				var cause: String = e["text"].split(" meurt ")[1].split(" à ")[0]
				counts[cause] = counts.get(cause, 0) + 1
		print("w%d: pop %d, %d ms, events %s" % [w, People.alive_count(st), Time.get_ticks_msec() - t0, str(counts)])
		sim.free()
	quit()
