extends SceneTree

# Rythme des découvertes : l'année où chaque savoir apparaît, la population et les morts de faim.
# godot --headless -s tests/pace.gd -- <monde> <années>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 0
	var years := int(args[1]) if args.size() > 1 else 40
	var sim = load("res://scripts/sim/sim.gd").new()
	sim.start_new("P%d" % w, "survie-%d" % w)
	var starved := 0
	var mines := 0
	var finds := []
	for d in years * 360:
		sim.tick(false)
		for e in Journal.take_fresh():
			if e["type"] == "deces" and e["text"].contains("de faim"):
				starved += 1
			elif e["type"] == "mine":
				mines += 1
			elif e["type"] == "minerai":
				finds.append("%s an%d" % [e["ore"], e["day"] / 360])
	var st: Dictionary = sim.state
	var line := []
	for k in Techs.ORDER:
		if st["discoveries"].has(k):
			line.append("%s:%d" % [k, st["discoveries"][k]["day"] / 360])
	var jobs := {}
	for p in st["people"]:
		if p["alive"]:
			jobs[p["job"]] = jobs.get(p["job"], 0) + 1
	print("P%d pop %d faim %d mines %d | %s" % [w, People.alive_count(st), starved, mines, " ".join(line)])
	print("P%d minerais %s" % [w, str(finds.slice(0, 8))])
	print("P%d métiers %s" % [w, str(jobs)])
	quit()
