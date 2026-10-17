class_name CookingSystem
extends Node
## The cooking minigame.
##
## Design rule (GDD 17): cooking is never "click recipe, wait, food appears".
## A dish is a sequence of STAGES read from the recipe data. Each stage is a
## small timing or control act the player performs:
##
##   chop    - rhythmic taps, each scored on how close to the beat
##   mix     - hold within a moving band
##   fry     - hold the heat needle in the recipe's window, and flip on cue
##   boil    - same, slower window, punishes over-attention
##   bake    - set heat then leave it; punishes fiddling
##   season  - one precise tap in a narrow window
##   plate   - one final placement tap
##
## Every stage produces a 0..1 score. The dish quality is the weighted mean,
## with a hard penalty for any catastrophically failed stage - so a player who
## nails three stages and forgets the pan still gets burnt food, which is the
## honest outcome.

signal stage_started(stage: String, index: int, total: int)
signal stage_scored(stage: String, score: float)
signal beat(index: int)              ## for chop rhythm cues
signal flip_cue()                    ## fry/boil "flip now" prompt
signal finished(result: Dictionary)
signal heat_changed(value: float)
signal progress_changed(value: float)

const STAGE_DURATION := {
	"chop": 4.0, "mix": 3.5, "fry": 6.0, "boil": 6.5,
	"bake": 5.5, "season": 2.5, "plate": 2.0,
}
## Quality thresholds on the final 0..1 score.
const T_PERFECT := 0.88
const T_GOOD := 0.62
const T_UNDER := 0.34

var recipe_id: String = ""
var recipe: Dictionary = {}
var stages: Array = []
var stage_index: int = -1
var stage: String = ""
var active: bool = false

## Player-controlled heat, 0..1. Shared across stages so the player is always
## tending one dial rather than learning a new control per stage.
var heat: float = 0.35
var heat_penalty: float = 0.0       ## set by the stove-trouble event

var _t: float = 0.0
var _stage_len: float = 1.0
var _scores: Array[float] = []
var _stage_accum: float = 0.0
var _stage_samples: int = 0
var _beat_i: int = 0
var _beat_next: float = 0.0
var _chop_hits: Array[float] = []
var _flip_time: float = -1.0
var _flipped: bool = false
var _seasoned: bool = false
var _mix_band: float = 0.5
var _bake_set: bool = false
var _bake_locked_heat: float = 0.0
var _bake_fiddle: float = 0.0
## Score captured by a one-shot stage (season/plate) when the player taps.
## -1 means "not tapped yet"; _score_stage applies the miss penalty instead.
var _manual_score: float = -1.0

const BEAT_INTERVAL := 0.62


func start(id: String) -> bool:
	if not DB.recipes.has(id):
		return false
	recipe_id = id
	recipe = DB.recipe(id)
	stages = recipe.get("prep", ["fry"]).duplicate()
	if stages.is_empty():
		stages = ["fry"]
	stage_index = -1
	_scores.clear()
	heat = 0.35
	active = true
	_advance()
	return true


func cancel() -> void:
	active = false
	stage = ""
	stage_index = -1


func _advance() -> void:
	stage_index += 1
	if stage_index >= stages.size():
		_complete()
		return
	stage = str(stages[stage_index])
	_stage_len = float(STAGE_DURATION.get(stage, 4.0))
	# Harder recipes give less time, which is the main difficulty lever.
	_stage_len *= 1.0 - 0.06 * float(int(recipe.get("difficulty", 1)) - 1)
	_t = 0.0
	_stage_accum = 0.0
	_stage_samples = 0
	_beat_i = 0
	_beat_next = 0.5
	_chop_hits.clear()
	_flipped = false
	_seasoned = false
	_bake_set = false
	_bake_fiddle = 0.0
	_manual_score = -1.0
	_flip_time = _stage_len * randf_range(0.42, 0.62) if stage in ["fry", "boil"] else -1.0
	stage_started.emit(stage, stage_index, stages.size())


func _process(delta: float) -> void:
	if not active or stage == "":
		return
	_t += delta
	progress_changed.emit(clampf(_t / _stage_len, 0.0, 1.0))

	match stage:
		"chop":
			_tick_chop()
		"mix":
			_tick_mix(delta)
		"fry", "boil":
			_tick_heat(delta)
		"bake":
			_tick_bake(delta)
		"season", "plate":
			pass   # scored purely on the player's single input

	if _t >= _stage_len:
		_score_stage()


# ---------------------------------------------------------------- stages ---
func _tick_chop() -> void:
	if _t >= _beat_next:
		_beat_i += 1
		_beat_next += BEAT_INTERVAL
		beat.emit(_beat_i)


func _tick_mix(delta: float) -> void:
	# The target band drifts; the player holds heat near it.
	_mix_band = 0.5 + 0.32 * sin(_t * 1.9)
	var err: float = absf(heat - _mix_band)
	_stage_accum += clampf(1.0 - err / 0.30, 0.0, 1.0)
	_stage_samples += 1


func _tick_heat(delta: float) -> void:
	var target := float(recipe.get("heat", 0.6))
	var tol := float(recipe.get("heat_tolerance", 0.12))
	var err: float = absf(heat - target)
	_stage_accum += clampf(1.0 - err / maxf(tol, 0.02), 0.0, 1.0)
	_stage_samples += 1
	if _flip_time > 0.0 and not _flipped and _t >= _flip_time:
		flip_cue.emit()
		# Missing the flip entirely is a hard fail for this stage, not a nudge.
		if _t > _flip_time + 1.4:
			_flipped = true
			_stage_accum *= 0.45


func _tick_bake(delta: float) -> void:
	# Bake wants the heat set early and then LEFT ALONE. Fiddling is punished,
	# which makes bake feel different from fry rather than being a reskin.
	if not _bake_set and _t > 1.2:
		_bake_set = true
		_bake_locked_heat = heat
	if _bake_set:
		_bake_fiddle += absf(heat - _bake_locked_heat) * delta


func _score_stage() -> void:
	var s := 0.5
	match stage:
		"chop":
			if _beat_i <= 0:
				s = 0.0
			else:
				var hit_ratio := float(_chop_hits.size()) / float(_beat_i)
				var accuracy := 0.0
				for h in _chop_hits:
					accuracy += h
				accuracy = accuracy / maxf(1.0, float(_chop_hits.size()))
				s = clampf(hit_ratio * 0.55 + accuracy * 0.45, 0.0, 1.0)
		"mix", "fry", "boil":
			s = _stage_accum / maxf(1.0, float(_stage_samples))
		"bake":
			var target := float(recipe.get("heat", 0.6))
			var tol := float(recipe.get("heat_tolerance", 0.12))
			var err: float = absf(_bake_locked_heat - target)
			s = clampf(1.0 - err / maxf(tol, 0.02), 0.0, 1.0)
			s *= clampf(1.0 - _bake_fiddle * 0.8, 0.25, 1.0)
		"season":
			s = _manual_score if _manual_score >= 0.0 else 0.15
		"plate":
			s = _manual_score if _manual_score >= 0.0 else 0.35
	_scores.append(clampf(s, 0.0, 1.0))
	stage_scored.emit(stage, s)
	Audio.play_sfx("ui_click" if s < T_GOOD else "ui_confirm")
	_advance()


# ------------------------------------------------------------ player input -
## Called on a chop tap. Scores proximity to the nearest beat.
func tap() -> float:
	if not active:
		return 0.0
	match stage:
		"chop":
			var nearest: float = round((_t - 0.5) / BEAT_INTERVAL) * BEAT_INTERVAL + 0.5
			var err: float = absf(_t - nearest)
			var acc: float = clampf(1.0 - err / 0.22, 0.0, 1.0)
			if acc > 0.05:
				_chop_hits.append(acc)
			Audio.play_sfx_varied("chop")
			return acc
		"fry", "boil":
			if not _flipped and _flip_time > 0.0:
				var err2: float = absf(_t - _flip_time)
				var acc2: float = clampf(1.0 - err2 / 0.7, 0.0, 1.0)
				_flipped = true
				# A good flip lifts the whole stage; a late one costs.
				_stage_accum *= lerpf(0.6, 1.25, acc2)
				Audio.play_sfx("sizzle")
				return acc2
			return 0.0
		"season":
			if _seasoned:
				return 0.0
			_seasoned = true
			var t_target := float(recipe.get("time", 0.65)) * _stage_len
			var tol := float(recipe.get("time_tolerance", 0.12)) * _stage_len
			var err3: float = absf(_t - t_target)
			var acc3: float = clampf(1.0 - err3 / maxf(tol, 0.05), 0.0, 1.0)
			_manual_score = acc3
			Audio.play_sfx("pour")
			_t = _stage_len   # end the stage; _score_stage records it once
			return acc3
		"plate":
			if _seasoned:
				return 0.0
			_seasoned = true
			var mid := _stage_len * 0.6
			var acc4: float = clampf(1.0 - absf(_t - mid) / 0.6, 0.0, 1.0)
			_manual_score = maxf(0.35, acc4)
			Audio.play_sfx("plate")
			_t = _stage_len
			return acc4
	return 0.0


func set_heat(v: float) -> void:
	heat = clampf(v - heat_penalty, 0.0, 1.0)
	heat_changed.emit(heat)


func nudge_heat(delta: float) -> void:
	set_heat(heat + delta)


## The band the UI should highlight right now.
func target_window() -> Vector2:
	match stage:
		"mix":
			return Vector2(_mix_band - 0.15, _mix_band + 0.15)
		"fry", "boil", "bake":
			var t := float(recipe.get("heat", 0.6))
			var tol := float(recipe.get("heat_tolerance", 0.12))
			return Vector2(t - tol, t + tol)
	return Vector2(-1, -1)


# -------------------------------------------------------------- resolution -
func _complete() -> void:
	active = false
	stage = ""
	var result := grade(_scores)
	result["recipe"] = recipe_id
	finished.emit(result)


## Pure function: stage scores in, quality out. Kept free of node state so the
## test suite can exercise the grading curve directly.
static func grade(scores: Array) -> Dictionary:
	if scores.is_empty():
		return {"quality": "raw", "score": 0.0, "value": 0}
	var total := 0.0
	var worst := 1.0
	for s in scores:
		total += float(s)
		worst = minf(worst, float(s))
	var mean: float = total / float(scores.size())
	# One catastrophic stage drags the dish down hard - a great sear cannot
	# rescue a raw middle, and pretending otherwise makes cooking feel fake.
	var score: float = mean * lerpf(0.55, 1.0, clampf(worst / 0.35, 0.0, 1.0))
	var quality := "good"
	if worst <= 0.08:
		quality = "burnt" if mean > 0.45 else "raw"
	elif score >= T_PERFECT:
		quality = "perfect"
	elif score >= T_GOOD:
		quality = "good"
	elif score >= T_UNDER:
		quality = "undercooked"
	else:
		quality = "overcooked" if mean > 0.30 else "raw"
	return {"quality": quality, "score": score, "mean": mean, "worst": worst}


## Gold value of a finished dish, before customer tip modifiers.
static func dish_value(recipe_id: String, quality: String) -> int:
	var base := float(DB.recipe(recipe_id).get("value", 40))
	var mult := float(DB.QUALITY_SCORE.get(quality, 0.5))
	return int(round(base * lerpf(0.15, 1.35, mult)))
