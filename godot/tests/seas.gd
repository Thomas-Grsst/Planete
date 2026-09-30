extends SceneTree

# Vie des ports sur plusieurs mondes : chantiers, phares, naufrages et épaves fouillées.

const WATCH := ["port", "route", "chantier", "phare", "naufrage", "epave", "entraide", "refuge", "fete"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 0
	var count := int(args[1]) if args.size() > 1 else 2
	var years := int(args[2]) if args.size() > 2 else 100
	for w in range(first, first + count):
		var sim = load("res://scripts/sim/sim.gd").new()
		sim.start_new("M%d" % w, "mers-%d" % w)
		var counts := {}
		var shown := {}
		for d in years * 360:
			sim.tick(false)
			for e in Journal.take_fresh():
				if not WATCH.has(e["type"]):
					continue
				counts[e["type"]] = counts.get(e["type"], 0) + 1
				if shown.get(e["type"], 0) < 2:
					shown[e["type"]] = shown.get(e["type"], 0) + 1
					print("  M%d an %d: %s" % [w, e["day"] / 360, e["text"]])
		var st: Dictionary = sim.state
		print("M%d pop %d routes mer %d %s" % [w, People.alive_count(st), st.get("routes", []).filter(func(r): return r["kind"] == "sea").size(), str(counts)])
		sim.free()
	quit()
