class_name Threats
extends RefCounted

const RAID_REACH := 6


static func pressing(state: Dictionary, s: Dictionary) -> bool:
	if state.get("zombies", {}).get("active", false):
		return true
	if IdeaFlags.check(state, {"s": s}, "wolves") or Wars.at_war_any(state, s):
		return true
	for r in state.get("raiders", []):
		if absi(r["x"] - s["x"]) + absi(r["y"] - s["y"]) <= RAID_REACH:
			return true
	return false


static func defense(state: Dictionary, e: Dictionary) -> float:
	var guards: int = e["jobs"].get("gardien", 0)
	var brave: int = e["traits"].get("courageux", 0)
	return (guards * 1.0 + brave * 0.4 + e["adults"] * 0.08) * e["mods"]["defense"]
