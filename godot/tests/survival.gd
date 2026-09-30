extends SceneTree

# Survie des mondes : population à 10, 25 et 50 ans, morts de faim, entraide et réfugiés.
# godot --headless -s tests/survival.gd -- <premier monde> <nombre> <années>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 0
	var count := int(args[1]) if args.size() > 1 else 4
	var years := int(args[2]) if args.size() > 2 else 50
	for w in range(first, first + count):
		var sim = load("res://scripts/sim/sim.gd").new()
		sim.start_new("S%d" % w, "survie-%d" % w)
		var marks := []
		var counts := {"faim": 0, "entraide": 0, "refuge": 0}
		for y in years:
			for d in 360:
				sim.tick(false)
				for e in Journal.take_fresh():
					if e["type"] == "deces" and e["text"].contains("de faim"):
						counts["faim"] += 1
					elif counts.has(e["type"]):
						counts[e["type"]] += 1
			if y + 1 in [10, 25, 50, 100]:
				marks.append("an%d:%d" % [y + 1, People.alive_count(sim.state)])
			if People.alive_count(sim.state) == 0:
				marks.append("éteint an %d" % (y + 1))
				break
		print("S%d %s %s" % [w, " ".join(marks), str(counts)])
		sim.free()
	quit()
