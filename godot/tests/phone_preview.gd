extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var warm := int(args[0]) if args.size() > 0 else 3600
	var sim = load("res://scripts/sim/sim.gd").new()
	sim.persist = false
	sim.start_new("Noria", args[1] if args.size() > 1 else "phone-preview")
	for d in warm:
		sim.tick(false)
	Journal.take_fresh()
	var forecast := Forecast.new()
	var t0 := Time.get_ticks_msec()
	forecast.advance(sim.state, sim.state["day"], 600000)
	print("prévision de %d jours en %d ms, %d événements marquants" % [Forecast.HORIZON_DAYS, Time.get_ticks_msec() - t0, forecast.events.size()])
	var now := Time.get_unix_time_from_system()
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	for n in PhoneDigest.notifications(sim.state, forecast, now, sim.state["day"]):
		print("  🔔 %s  %s — %s" % [Time.get_datetime_string_from_unix_time(n["at"] / 1000 + bias * 60, true), n["title"], n["text"]])
	var widget := PhoneDigest.widget(sim.state, forecast, now, sim.state["day"])
	print("widget : %s, %d jours de population, %d événements, %d octets" % [widget["name"], widget["pops"].size(), widget["events"].size(), JSON.stringify(widget).length()])
	var gaps := 0
	for k in Forecast.HORIZON_DAYS:
		sim.tick(false)
		if forecast.marks.get(sim.state["day"]) != sim.state["rng_state"] or forecast.pops.get(sim.state["day"]) != People.alive_count(sim.state):
			gaps += 1
	Journal.take_fresh()
	print("✅ prévision fidèle au vrai déroulement" if gaps == 0 else "❌ %d jours diffèrent de la prévision" % gaps)
	forecast.reset()
	sim.free()
	quit(1 if gaps > 0 else 0)
