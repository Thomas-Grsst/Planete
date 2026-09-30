extends SceneTree

const WATCH := ["route", "guerre", "bataille", "bataille_navale", "siege", "siege_fin", "blocus", "murailles", "conquete", "paix", "exploration", "port", "civilisation", "independance", "filon", "surpeche", "sol_epuise"]


func _init() -> void:
	var worlds := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 3
	for w in worlds:
		var sim = load("res://scripts/sim/sim.gd").new()
		sim.start_new("W%d" % w, "war-%d" % w)
		var t0 := Time.get_ticks_msec()
		var counts := {}
		var shown := {}
		for d in 36000:
			sim.tick(false)
			for e in Journal.take_fresh():
				if not WATCH.has(e["type"]):
					continue
				counts[e["type"]] = counts.get(e["type"], 0) + 1
				if shown.get(e["type"], 0) < 2:
					shown[e["type"]] = shown.get(e["type"], 0) + 1
					print("  an %d: %s" % [e["day"] / 360, e["text"]])
		var st: Dictionary = sim.state
		print("W%d: %d s, pop %d, colonies %d, civs %d, chunks %d, routes %d, ports %d, techs %d, events %s" % [w, (Time.get_ticks_msec() - t0) / 1000, People.alive_count(st), st["settlements"].filter(func(s): return s["abandoned"] < 0).size(), Civs.alive(st).size(), st["world"]["chunks"].size(), st.get("routes", []).size(), st["settlements"].filter(func(s): return s["abandoned"] < 0 and Ports.has_port(s)).size(), st["discoveries"].size(), str(counts)])
		sim.free()
	quit()
