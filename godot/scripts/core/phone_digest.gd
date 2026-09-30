class_name PhoneDigest
extends RefCounted

const SIM := preload("res://scripts/sim/sim.gd")
const QUIET_START := 22
const QUIET_END := 8
const GAP_SECONDS := 4 * 3600
const MIN_DELAY_SECONDS := 120
const MAX_NOTIFICATIONS := 6
const MIN_SCORE := 40
const MAX_WIDGET_EVENTS := 120
const SCORES := {
	"extinction": 100, "apocalypse": 90, "guerre": 80, "chute": 75, "conquete": 70, "exode": 70, "epidemie": 65, "cataclysme": 65,
	"grande_famine": 60, "civilisation": 60, "apocalypse_fin": 55, "religion": 55, "decouverte": 50, "paix": 50, "revolution": 50,
	"independance": 50, "contact": 50, "mutant": 45, "savoir_perdu": 45, "climat": 45, "alliance": 40, "monument": 40, "schisme": 40,
	"trahison": 40, "raid": 35, "dynastie": 35, "religion_etat": 35, "religion_fin": 35, "archeologie": 35,
}


static func score(e: Dictionary) -> int:
	var s: int = SCORES.get(e["type"], 0)
	return maxi(s, MIN_SCORE) if e.get("highlight", false) else s


static func seconds_until(state: Dictionary, now_day: int, day: int) -> float:
	return ((day - now_day) * SIM.MS_PER_DAY - float(state["acc_ms"])) / 1000.0


static func notifications(state: Dictionary, forecast: Forecast, now: float, now_day: int) -> Array:
	var candidates: Array = []
	for e in forecast.events:
		var s := score(e)
		var wait := seconds_until(state, now_day, e["day"])
		if e["day"] <= now_day or s < MIN_SCORE or wait < MIN_DELAY_SECONDS:
			continue
		candidates.append({"at": _awake_time(now + wait), "score": s, "e": e})
	candidates.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["at"] < b["at"]))
	var picks: Array = []
	for c in candidates:
		if picks.size() >= MAX_NOTIFICATIONS:
			break
		if not picks.any(func(p): return absf(p["at"] - c["at"]) < GAP_SECONDS):
			picks.append(c)
	picks.sort_custom(func(a, b): return a["at"] < b["at"])
	return picks.map(func(c): return {"at": int(c["at"] * 1000.0), "title": "🌍 %s · %s" % [state["name"], Journal.format_day(c["e"]["day"])], "text": c["e"]["text"]})


static func widget(state: Dictionary, forecast: Forecast, now: float, now_day: int) -> Dictionary:
	var pops: Array = []
	var d := now_day
	while forecast.pops.has(d):
		pops.append(forecast.pops[d])
		d += 1
	if pops.is_empty():
		pops.append(People.alive_count(state))
	var events: Array = []
	var last = _last_highlight(state)
	if last != null:
		events.append({"d": last["day"], "x": last["text"]})
	for e in forecast.events:
		if e["day"] > now_day and events.size() < MAX_WIDGET_EVENTS:
			events.append({"d": e["day"], "x": e["text"]})
	return {"name": state["name"], "t0": int(now * 1000.0 - float(state["acc_ms"])), "day0": now_day, "max": SIM.MAX_OFFLINE_DAYS, "pops": pops, "events": events}


static func _last_highlight(state: Dictionary):
	var journal: Array = state["journal"]
	for i in range(journal.size() - 1, -1, -1):
		if Journal.is_rare(journal[i]):
			return journal[i]
	return null


static func _awake_time(unix: float) -> float:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var local := int(unix) + bias * 60
	var t := Time.get_datetime_dict_from_unix_time(local)
	var hour: int = t["hour"]
	if hour >= QUIET_END and hour < QUIET_START:
		return unix
	var midnight: int = local - hour * 3600 - int(t["minute"]) * 60 - int(t["second"])
	var wake: int = midnight + QUIET_END * 3600 + (86400 if hour >= QUIET_START else 0)
	return float(wake - bias * 60)
