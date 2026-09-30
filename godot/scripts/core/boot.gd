class_name Boot
extends RefCounted

const DEFAULT_NAME := "Noria"


static func _answer_prayers() -> void:
	var answers := {"drought": "rain", "hunger": "grow", "storm": "sun", "cold": "sun"}
	for s in Sim.state["settlements"]:
		var need: String = s.get("prayer", {}).get("need", "")
		if s["abandoned"] < 0 and answers.has(need):
			Sim.use_power(answers[need])
			return


static func start(options: Dictionary) -> int:
	if options.has("fresh"):
		Sim.persist = false
		Sim.start_new(options.get("name", DEFAULT_NAME), options.get("seed", ""))
		for i in int(options.get("days", "0")):
			Sim.tick(false)
			if options.has("auto-pray") and i % 400 == 399:
				_answer_prayers()
		Journal.take_fresh()
		if options.has("hour"):
			Sim.state["acc_ms"] = fposmod(float(options["hour"]) - 6.0, 24.0) / 24.0 * Sim.MS_PER_DAY
		if options.has("speed"):
			Sim.speed = float(options["speed"])
		if options.has("era"):
			DebugOptions.apply_era(options)
			Sim.tick(false)
			Journal.take_fresh()
			if options.has("fete"):
				var s: Dictionary = Sim.state["settlements"][0]
				s["fete"] = {"kind": options["fete"], "day": Sim.state["day"]}
				s["burials"] = 14
				s["graves"] = [{"name": "Aster", "day": 0, "person": -1}, {"name": "Nilo", "day": 0, "person": -1}]
				Festivals.cemetery(Sim.state, s)
		Sim.world_loaded.emit()
		return 0
	var id := SaveStore.current_id()
	var saved := SaveStore.load_world(id) if id != "" else {}
	if saved.is_empty():
		Sim.start_new(DEFAULT_NAME)
		Sim.save_now()
		return 0
	if options.has("absent"):
		saved["last_sim_time"] -= float(options["absent"]) * 3600.0
	return Sim.load_existing(saved)
