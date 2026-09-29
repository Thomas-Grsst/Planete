extends SceneTree

const ANSWERS := {"drought": "rain", "hunger": "grow", "storm": "sun", "cold": "sun"}


func _init() -> void:
	var sim = load("res://scripts/sim/sim.gd").new()
	sim.start_new("F", "bench-2")
	var seen := 0
	for d in 9000:
		sim.tick(false)
		var st: Dictionary = sim.state
		if d % 400 == 0 and d > 0:
			for s in st["settlements"]:
				var need: String = s.get("prayer", {}).get("need", "")
				if s["abandoned"] < 0 and ANSWERS.has(need):
					print("[power %s d%d] %s" % [ANSWERS[need], st["day"], sim.use_power(ANSWERS[need])])
					break
		for e in st["journal"].slice(seen):
			if e["type"] in ["religion", "schisme", "miracle", "conversion", "temple", "religion_fin", "religion_vie"]:
				print("%d %s" % [e["day"], e["text"]])
		seen = st["journal"].size()
	var st: Dictionary = sim.state
	print("religions: ", st["religions"].map(func(r): return "%s (%s)" % [r["name"], "vivante" if r["alive"] else "éteinte"]))
	print("faithful colonies: %d / %d" % [st["settlements"].filter(func(s): return s["abandoned"] < 0 and s["faith"] >= 0).size(), st["settlements"].filter(func(s): return s["abandoned"] < 0).size()])
	sim.free()
	quit()
