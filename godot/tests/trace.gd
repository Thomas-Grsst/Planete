extends SceneTree


func _init() -> void:
	var sim = load("res://scripts/sim/sim.gd").new()
	var seed_text: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "bench-0"
	sim.start_new("T", seed_text)
	for d in 14400:
		sim.tick(false)
		if d % 720 == 0:
			var st: Dictionary = sim.state
			var census := Census.build(st)
			var line := "y%d pop %d:" % [d / 360, People.alive_count(st)]
			for id in census:
				var e: Dictionary = census[id]
				line += " [%s p%d h%d food%d gain%.0f hungry%d techs%d %s]" % [e["s"]["name"], e["pop"], e["s"]["houses"], e["s"]["food"], e["s"]["last_gain"], e["hungry"], e["s"]["techs"].size(), str(e["jobs"])]
			print(line)
	sim.free()
	quit()
