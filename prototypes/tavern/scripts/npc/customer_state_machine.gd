class_name CustomerStateMachine
extends RefCounted
## One state machine, every monster.
##
## GDD 16 requires that different personalities NOT mean different AI. The
## graph below is fixed; what varies per character is data pulled from
## characters.json - patience, tempo, tip multiplier, chaos, quality floor.
## A new monster is a JSON entry, never a new class.
##
##   ENTER -> FIND_TABLE -> SIT -> ORDER -> WAIT -> RECEIVE -> EAT -> REACT
##         -> PAY -> LEAVE
##
## Interrupts (IMPATIENT / ANGRY / EXCITED / CONFUSED / PANIC / TALKING /
## SPECIAL) layer on top of WAIT rather than replacing the graph, so a customer
## can get impatient and still be served without the flow breaking.

signal state_changed(from: int, to: int)
signal mood_changed(mood: String)
signal wants_line(situation: String)

enum S { ENTER, FIND_TABLE, SIT, ORDER, WAIT, RECEIVE, EAT, REACT, PAY, LEAVE, GONE }
enum Mood { CALM, IMPATIENT, ANGRY, EXCITED, CONFUSED, PANIC, TALKING }

const STATE_NAMES := ["ENTER", "FIND_TABLE", "SIT", "ORDER", "WAIT", "RECEIVE",
		"EAT", "REACT", "PAY", "LEAVE", "GONE"]

var state: int = S.ENTER
var mood: int = Mood.CALM
var char_id: String = ""
var data: Dictionary = {}

var patience_max: float = 30.0
var patience: float = 30.0
var tempo: float = 1.0
var chaos: float = 0.0

var wanted_recipe: String = ""
var served_quality: String = ""
var satisfaction: float = 0.0
var timer: float = 0.0
var table_index: int = -1
var walked_out: bool = false

## Fractions of remaining patience at which the mood escalates.
const IMPATIENT_AT := 0.45
const ANGRY_AT := 0.18


func setup(id: String) -> void:
	char_id = id
	data = DB.character(id)
	patience_max = float(data.get("patience", 30.0))
	# Friendlier customers wait longer - the relationship is mechanical, not
	# just flavour text.
	patience_max *= 1.0 + 0.10 * float(Game.friendship_level(id))
	patience = patience_max
	tempo = float(data.get("tempo", 1.0))
	chaos = float(data.get("chaos", 0.0))


func set_state(s: int) -> void:
	if state == s:
		return
	var from := state
	state = s
	timer = 0.0
	state_changed.emit(from, s)


func set_mood(m: int) -> void:
	if mood == m:
		return
	mood = m
	mood_changed.emit(mood_name())


func mood_name() -> String:
	match mood:
		Mood.IMPATIENT: return "impatient"
		Mood.ANGRY: return "angry"
		Mood.EXCITED: return "excited"
		Mood.CONFUSED: return "confused"
		Mood.PANIC: return "panic"
		Mood.TALKING: return "talking"
	return "calm"


func state_name() -> String:
	return STATE_NAMES[state] if state < STATE_NAMES.size() else "?"


## The facial expression this customer should currently wear. Maps the state
## machine onto the 12 expressions every character sprite provides.
func expression() -> String:
	match state:
		S.ENTER, S.FIND_TABLE:
			return "neutral"
		S.SIT, S.ORDER:
			return "hungry"
		S.WAIT:
			match mood:
				Mood.ANGRY: return "angry"
				Mood.IMPATIENT: return "confused"
				_: return "hungry"
		S.RECEIVE:
			return "surprised"
		S.EAT:
			return "happy" if satisfaction > 0.5 else "neutral"
		S.REACT:
			if satisfaction >= 0.85:
				return "excited"
			if satisfaction >= 0.6:
				return "happy"
			if satisfaction >= 0.35:
				return "confused"
			return "angry"
		S.PAY:
			return "satisfied" if satisfaction > 0.55 else "neutral"
		S.LEAVE:
			return "happy" if satisfaction > 0.55 else "sad"
	return "neutral"


func tick(delta: float) -> void:
	timer += delta
	match state:
		S.ENTER:
			if timer > 1.2 / tempo:
				set_state(S.FIND_TABLE)
		S.FIND_TABLE:
			pass                       # controller assigns a table then advances
		S.SIT:
			if timer > 0.8 / tempo:
				set_state(S.ORDER)
		S.ORDER:
			if timer > 0.4:
				wants_line.emit("order")
				set_state(S.WAIT)
		S.WAIT:
			_tick_wait(delta)
		S.RECEIVE:
			if timer > 0.7:
				set_state(S.EAT)
		S.EAT:
			if timer > 2.6 / tempo:
				set_state(S.REACT)
		S.REACT:
			if timer < 0.05:
				wants_line.emit(_reaction_situation())
			if timer > 2.2:
				set_state(S.PAY)
		S.PAY:
			if timer > 0.6:
				set_state(S.LEAVE)
		S.LEAVE:
			if timer < 0.05:
				wants_line.emit("leave_happy" if satisfaction > 0.5 else "leave_angry")
			pass # Fork: the visual controller completes departure at the door.


func _tick_wait(delta: float) -> void:
	patience -= delta * tempo
	var frac: float = patience / maxf(1.0, patience_max)
	if frac <= 0.0:
		walked_out = true
		satisfaction = 0.0
		set_mood(Mood.ANGRY)
		set_state(S.LEAVE)
		return
	if frac < ANGRY_AT:
		set_mood(Mood.ANGRY)
	elif frac < IMPATIENT_AT:
		if mood != Mood.IMPATIENT:
			set_mood(Mood.IMPATIENT)
			wants_line.emit("wait")
	else:
		set_mood(Mood.CALM)


func patience_fraction() -> float:
	return clampf(patience / maxf(1.0, patience_max), 0.0, 1.0)


func _reaction_situation() -> String:
	if satisfaction >= 0.85:
		return "perfect"
	if satisfaction >= 0.55:
		return "good"
	return "bad"


## Called when a dish reaches the table.
func serve(recipe_id: String, quality: String) -> float:
	served_quality = quality
	satisfaction = score_satisfaction(char_id, recipe_id, quality,
			patience_fraction(), Game.atmosphere,
			Game.friendship_level(char_id), wanted_recipe)
	set_mood(Mood.EXCITED if satisfaction > 0.75 else Mood.CALM)
	set_state(S.RECEIVE)
	return satisfaction


## Multi-factor satisfaction (GDD 22). Deliberately static and pure so the test
## suite can pin the curve. The player never sees these numbers - they only see
## the face and the tip.
static func score_satisfaction(character_id: String, recipe_id: String,
		quality: String, patience_frac: float, atmosphere: float,
		friend_level: int, wanted: String = "") -> float:
	var ch := DB.character(character_id)
	var rec := DB.recipe(recipe_id)

	# 1. food quality
	var q := float(DB.QUALITY_SCORE.get(quality, 0.5))

	# 2. preference match against the dish's tags
	var prefers: Dictionary = ch.get("prefers", {})
	var dislikes: Dictionary = ch.get("dislikes", {})
	var tag_score := 0.0
	var tag_weight := 0.0
	for t in rec.get("tags", []):
		if prefers.has(t):
			tag_score += float(prefers[t])
			tag_weight += 1.0
		if dislikes.has(t):
			tag_score += float(dislikes[t])
			tag_weight += 1.0
	var pref := 0.5
	if tag_weight > 0.0:
		pref = clampf(0.5 + (tag_score / tag_weight) * 0.5, 0.0, 1.0)

	# 3..6: everything that is not the food itself - the trimmings.
	var context := pref * 0.24
	if wanted != "" and wanted == recipe_id:
		context += 0.10
	elif wanted != "":
		context -= 0.06
	if str(ch.get("favourite", "")) == recipe_id:
		context += 0.06
	context += clampf(patience_frac, 0.0, 1.0) * 0.13     # service speed
	context += clampf(atmosphere, 0.0, 1.0) * 0.07        # the room
	context += clampf(float(friend_level) / 4.0, 0.0, 1.0) * 0.09   # goodwill

	# Quality GATES the trimmings rather than merely outweighing them. When the
	# terms were all additive, a burnt favourite served instantly still scored
	# 0.51 because speed and preference carried it - a customer being delighted
	# by charcoal. Fast, friendly service cannot rescue food nobody can eat.
	var score := q * 0.52 + context * (0.15 + 0.85 * q)

	# A customer with a quality floor rejects anything below it outright,
	# regardless of how much they like you. This is what makes Vex feel like
	# Vex rather than a vampire-coloured Blaze.
	var floor_q := str(ch.get("quality_floor", ""))
	if floor_q != "" and q < float(DB.QUALITY_SCORE.get(floor_q, 0.0)):
		score = minf(score, 0.30)

	return clampf(score, 0.0, 1.0)


## Gold paid, including tip. Bad service can mean paying almost nothing.
func payment() -> int:
	if walked_out:
		return 0
	var base := CookingSystem.dish_value(wanted_recipe if served_quality == "" \
			else wanted_recipe, served_quality)
	var tip_mult := float(data.get("tip", 1.0))
	var mult := lerpf(0.25, tip_mult, satisfaction)
	mult *= 1.0 + 0.05 * float(Game.friendship_level(char_id))
	return int(round(float(base) * mult))


## Friendship earned from this visit.
func friendship_delta() -> float:
	if walked_out:
		return -2.0
	if satisfaction >= 0.85:
		return 3.0
	if satisfaction >= 0.6:
		return 1.5
	if satisfaction >= 0.35:
		return 0.25
	return -1.5
