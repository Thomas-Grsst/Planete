extends SceneTree

# Compte ce que les routes transportent (idées, croyances, maladies, mariages) sur plusieurs mondes.

func _init() -> void:
	var worlds := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 3
	var years := int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 60
	for w in worlds:
		var sim = load("res://scripts/sim/sim.gd").new()
		sim.start_new("V%d" % w, "voyage-%d" % w)
		var t0 := Time.get_ticks_msec()
		var counts := {}
		var shown := {}
		for d in years * 360:
			sim.tick(false)
			for e in Journal.take_fresh():
				if not e.has("voyage"):
					continue
				var key: String = ("mer " if e["voyage"]["sea"] else "terre ") + e["type"]
				counts[key] = counts.get(key, 0) + 1
				if shown.get(key, 0) < 2:
					shown[key] = shown.get(key, 0) + 1
					print("  an %d: %s" % [e["day"] / 360, e["text"]])
		var st: Dictionary = sim.state
		print("V%d: %d s, pop %d, routes %d (mer %d), %s" % [w, (Time.get_ticks_msec() - t0) / 1000, People.alive_count(st), st.get("routes", []).size(), st.get("routes", []).filter(func(r): return r["kind"] == "sea").size(), str(counts)])
		sim.free()
	quit()
