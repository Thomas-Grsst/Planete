class_name HudActions
extends RefCounted

const REPLAY := preload("res://scripts/ui/replay.gd")
const SEED_DIALOG := preload("res://scripts/ui/seed_dialog.gd")
const CONFIRM := preload("res://scripts/ui/confirm_dialog.gd")


static func run(hud, parts: PackedStringArray) -> bool:
	if parts[0] != "action":
		return false
	match parts[1]:
		"power":
			if parts[2] == "zombie":
				var ask := PanelContainer.new()
				ask.set_script(CONFIRM)
				ask.title = "☣️ Réveiller les morts ?"
				ask.message = "Des habitants mourront. Cela pourrait détruire ta planète."
				hud.root.add_child(ask)
				ask.confirmed.connect(func(): _power(hud, "zombie"))
			else:
				_power(hud, parts[2])
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
		"sound":
			var mute: bool = hud.get_tree().root.find_child("Soundscape", true, false).toggle()
			hud.toast("🔇 Son coupé." if mute else "🔊 Son activé.")
			hud.refresh_panel()
		"replay":
			hud.close_panel()
			var replay := Node.new()
			replay.set_script(REPLAY)
			hud.add_child(replay)
			replay.start(hud)
	return true


static func _power(hud, name: String) -> void:
	var msg: String = Sim.use_power(name)
	if msg != "":
		hud.toast(msg)
	hud.refresh_panel()


static func _new_world(hud, seed_text: String) -> void:
	Sim.save_now()
	hud.close_panel()
	var name := Names.place_name(Rng.new(Time.get_ticks_usec()), {})
	Sim.start_new(name, seed_text)
	Sim.save_now()
	var from_seed := " (graine « %s »)" % seed_text if seed_text != "" else ""
	hud.toast("🌱 Un nouveau monde vient de naître : %s%s." % [Sim.state["name"], from_seed])
