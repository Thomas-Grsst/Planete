extends SceneTree


func _init() -> void:
	var sim = load("res://scripts/sim/sim.gd").new()
	var args := OS.get_cmdline_user_args()
	sim.start_new("P", args[0] if args.size() > 0 else "war-0")
	for d in (int(args[1]) if args.size() > 1 else 28000):
		sim.tick(false)
	Journal.take_fresh()
	var st: Dictionary = sim.state
	var rng: Rng = sim.rng
	var totals := {}
	var steps := [
		["weather", func(c): Weather.step(st, rng)], ["regrow", func(c): Work.regrow(st)], ["work", func(c): Work.step(st, rng, c)],
		["people", func(c): People.step(st, rng, c)], ["epidemics", func(c): Epidemics.step(st, rng, c)], ["zombies", func(c): Zombies.step(st, rng, c)],
		["herds", func(c): Herds.step(st, rng)], ["settlements", func(c): Settlements.step(st, rng, c)], ["exploration", func(c): Exploration.step(st, rng, c)],
		["wolves", func(c): Wolves.step(st, rng, c)], ["jobs", func(c): Jobs.step(st, rng, c)], ["governance", func(c): Governance.step(st, rng, c)],
		["faith", func(c): Faith.step(st, rng, c)], ["civ_formation", func(c): CivFormation.step(st, rng, c)], ["diplomacy", func(c): Diplomacy.step(st, rng, c)],
		["wars", func(c): Wars.step(st, rng, c)], ["sieges", func(c): Sieges.step(st)], ["trade", func(c): Trade.step(st, rng, c)], ["lore", func(c): Lore.step(st, rng, c)],
		["ideas", func(c): Ideas.step(st, rng, c)], ["world", func(c): World.step(st, rng, c)], ["fame", func(c): Fame.yearly(st)], ["achievements", func(c): Achievements.daily(st)],
		["housekeeping", func(c): Housekeeping.step(st)],
	]
	var n := 400
	for d in n:
		st["day"] += 1
		var t := Time.get_ticks_usec()
		var census := Census.build(st)
		totals["census"] = totals.get("census", 0) + Time.get_ticks_usec() - t
		for s in steps:
			t = Time.get_ticks_usec()
			s[1].call(census)
			totals[s[0]] = totals.get(s[0], 0) + Time.get_ticks_usec() - t
		Journal.take_fresh()
	var keys := totals.keys()
	keys.sort_custom(func(a, b): return totals[a] > totals[b])
	var sum := 0
	for k in keys:
		sum += totals[k]
	for k in keys.slice(0, 12):
		print("%-14s %.2f ms/tick" % [k, totals[k] / 1000.0 / n])
	print("total %.2f ms/tick · pop %d · colonies %d · people records %d · herds %d · chunks %d" % [sum / 1000.0 / n, People.alive_count(st), st["settlements"].filter(func(s): return s["abandoned"] < 0).size(), st["people"].size(), st["herds"].size(), st["world"]["chunks"].size()])
	quit()
