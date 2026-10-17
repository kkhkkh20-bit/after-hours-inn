extends Node
## Drives the clock, the day phases and the day-start/day-end bookkeeping.
##
## The whole game loop hangs off this: prep -> open -> service -> close ->
## summary -> next day. Scenes listen to `phase_changed` rather than polling.

signal time_changed(minutes: int)
signal phase_changed(phase: int)
signal daypart_changed(part: String)

enum Phase { PREP, OPEN, CLOSING, SUMMARY }

## One in-game minute per this many real seconds. A full service is ~6 real
## minutes, which playtests as long enough to feel like a shift and short
## enough to want another one.
const SECONDS_PER_MINUTE := 0.143
const OPEN_MINUTES := 8 * 60      ## 08:00
const CLOSE_MINUTES := 22 * 60    ## 22:00

var minutes: int = OPEN_MINUTES
var phase: int = Phase.PREP
var running: bool = false
var _accum: float = 0.0
var _daypart: String = "morning"


func _process(delta: float) -> void:
	if not running or phase != Phase.OPEN:
		return
	_accum += delta
	while _accum >= SECONDS_PER_MINUTE:
		_accum -= SECONDS_PER_MINUTE
		minutes += 1
		time_changed.emit(minutes)
		var part := daypart()
		if part != _daypart:
			_daypart = part
			daypart_changed.emit(part)
			Audio.play_music(part)
		if minutes >= CLOSE_MINUTES:
			set_phase(Phase.CLOSING)
			return


func start_day() -> void:
	minutes = OPEN_MINUTES
	_accum = 0.0
	_daypart = daypart()
	Game.reset_day_stats()
	set_phase(Phase.PREP)
	running = true
	Game.day_started.emit(Game.day)


func open_restaurant() -> void:
	if phase == Phase.PREP:
		set_phase(Phase.OPEN)
		Audio.play_sfx("bell")
		Audio.play_music(daypart())


func set_phase(p: int) -> void:
	if phase == p:
		return
	phase = p
	phase_changed.emit(p)
	if p == Phase.CLOSING:
		_close()


func _close() -> void:
	running = false
	var summary := {
		"day": Game.day,
		"gold": Game.day_gold,
		"served": Game.day_served,
		"perfect": Game.day_perfect,
		"failed": Game.day_failed,
		"walkouts": Game.day_walkouts,
		"mean_satisfaction": (Game.day_satisfaction / float(Game.day_served)) if Game.day_served > 0 else 0.0,
		"reputation": Game.reputation,
	}
	Game.stats["days"] = int(Game.stats.get("days", 0)) + 1
	# Reputation drifts from the day's service rather than from single dishes,
	# so one bad plate never tanks the restaurant but a bad shift does. It
	# follows MEAN SATISFACTION, not the share of flawless dishes.
	# Keying it on perfect-count meant a day where every customer left happy on
	# merely good food still cost -0.18, and three competent days sank the
	# restaurant from 1.0 to 0.46. Competence should hold; excellence should
	# climb. Found by tests/playthrough.gd.
	var rep_delta := 0.0
	if Game.day_served > 0:
		var mean_sat := Game.day_satisfaction / float(Game.day_served)
		rep_delta = lerpf(-0.25, 0.30, mean_sat)
		# a perfect service is worth a little more than a merely happy one
		rep_delta += 0.06 * (float(Game.day_perfect) / float(Game.day_served))
		rep_delta -= 0.08 * float(Game.day_walkouts)
	else:
		rep_delta = -0.10
	Game.add_reputation(rep_delta)
	summary["rep_delta"] = rep_delta
	set_phase(Phase.SUMMARY)
	Game.day_ended.emit(summary)


func next_day() -> void:
	Game.day += 1
	start_day()


func daypart() -> String:
	if minutes < 11 * 60:
		return "morning"
	if minutes < 17 * 60:
		return "day"
	if minutes < 20 * 60:
		return "evening"
	return "night"


func is_night() -> bool:
	return daypart() == "night"


## Normalised progress through the service, 0 at open and 1 at close.
func service_progress() -> float:
	return clampf(float(minutes - OPEN_MINUTES)
			/ float(CLOSE_MINUTES - OPEN_MINUTES), 0.0, 1.0)


func time_string() -> String:
	var h := (minutes / 60) % 24
	var m := minutes % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
