class_name HudActions
extends RefCounted

const REPLAY := preload("res://scripts/ui/replay.gd")
const SEED_DIALOG := preload("res://scripts/ui/seed_dialog.gd")


static func run(hud, parts: PackedStringArray) -> bool:
	if parts[0] != "action":
		return false
	match parts[1]:
		"power":
			var msg: String = Sim.use_power(parts[2])
			if msg != "":
				hud.toast(msg)
			hud.refresh_panel()
		"new":
			_new_world(hud, "")
		"seed":
			var dialog := PanelContainer.new()
			dialog.set_script(SEED_DIALOG)
			hud.root.add_child(dialog)
			dialog.chosen.connect(func(text): _new_world(hud, text))
		"colony":
			var ended: Dictionary = Sim.state.get("ended", {})
			if ended.is_empty():
				return true
			var colony := {"crew": ended["crew"], "techs": ended["techs"], "origin": Sim.state["name"]}
			Sim.save_now()
			hud.close_panel()
			Sim.start_new(Names.place_name(Rng.new(Time.get_ticks_usec()), {}), "", colony)
			Sim.save_now()
			hud.toast("🚀 Le vaisseau se pose sur %s. Une nouvelle histoire commence." % Sim.state["name"])
		"replay":
			hud.close_panel()
			var replay := Node.new()
			replay.set_script(REPLAY)
			hud.add_child(replay)
			replay.start(hud)
	return true


static func _new_world(hud, seed_text: String) -> void:
	Sim.save_now()
	hud.close_panel()
	var name := Names.place_name(Rng.new(Time.get_ticks_usec()), {})
	Sim.start_new(name, seed_text)
	Sim.save_now()
	var from_seed := " (graine « %s »)" % seed_text if seed_text != "" else ""
	hud.toast("🌱 Un nouveau monde vient de naître : %s%s." % [Sim.state["name"], from_seed])
