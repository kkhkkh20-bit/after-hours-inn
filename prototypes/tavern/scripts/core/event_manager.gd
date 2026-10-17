extends Node
## Random restaurant events.
##
## The point of this system (GDD 25) is to generate stories out of mechanics
## that already exist. Every effect below pokes a system that was already
## there - gold, atmosphere, the pantry, the cooking heat. No event needs
## bespoke gameplay code, which is why adding one is a JSON entry.

signal event_fired(id: String, data: Dictionary)
signal event_effect(effect: String, value: Variant)

const RARITY_CHANCE := {
	"common": 1.0, "uncommon": 0.55, "rare": 0.22, "very_rare": 0.06,
}
## Mean seconds between event rolls during service.
const ROLL_INTERVAL := 26.0

var enabled: bool = true
var _t: float = 0.0
var _fired_today: Array[String] = []
var context: Dictionary = {}      ## filled by the restaurant each frame


func _process(delta: float) -> void:
	if not enabled or DayCycle.phase != DayCycle.Phase.OPEN:
		return
	_t += delta
	if _t >= ROLL_INTERVAL:
		_t = 0.0
		roll()


func reset_day() -> void:
	_fired_today.clear()
	_t = 0.0


## Pick and fire one eligible event, or nothing. Public so tests can drive it.
func roll(force_id: String = "") -> String:
	if force_id != "":
		_fire(force_id)
		return force_id
	var pool: Array = []
	var weights: Array = []
	for id in DB.events:
		if id in _fired_today:
			continue
		var ev: Dictionary = DB.events[id]
		if not _requirements_met(ev.get("requires", {})):
			continue
		var w := float(ev.get("weight", 1))
		w *= float(RARITY_CHANCE.get(str(ev.get("rarity", "common")), 1.0))
		if w <= 0.0:
			continue
		pool.append(id)
		weights.append(w)
	if pool.is_empty():
		return ""
	# Most rolls should produce nothing at all; constant incident is exhausting.
	if randf() > 0.42:
		return ""
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := randf() * total
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			_fire(str(pool[i]))
			return str(pool[i])
	return ""


func _requirements_met(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("min_day") and Game.day < int(req["min_day"]):
		return false
	if req.has("min_reputation") and Game.reputation < float(req["min_reputation"]):
		return false
	if req.has("min_customers") \
			and int(context.get("customer_count", 0)) < int(req["min_customers"]):
		return false
	if req.has("customer_present"):
		var present: Array = context.get("present", [])
		if not (str(req["customer_present"]) in present):
			return false
	return true


func _fire(id: String) -> void:
	var ev: Dictionary = DB.events.get(id, {})
	if ev.is_empty():
		return
	_fired_today.append(id)
	var sfx := str(ev.get("sfx", ""))
	if sfx != "":
		Audio.play_sfx(sfx)
	event_fired.emit(id, ev)
	_apply(ev.get("effect", {}))


## Effects are applied against existing systems. Anything the restaurant scene
## has to do visually (spawn a group, ruin the current cook) is relayed as an
## `event_effect` signal rather than reached into from here.
func _apply(effect: Dictionary) -> void:
	for key in effect:
		var value: Variant = effect[key]
		match key:
			"gold":
				Game.add_gold(int(value))
			"atmosphere":
				Game.add_atmosphere(float(value))
			"reputation":
				Game.add_reputation(float(value))
			"unlock_recipe":
				Game.unlock_recipe(str(value))
			"steal_ingredient":
				_steal(int(value))
			_:
				# ruin_cooking, spawn_group, patience_all, heat_penalty,
				# free_perfect, inspection, next_order_multiplier,
				# gold_multiplier, spawn_pause, duration, reputation_stake
				event_effect.emit(str(key), value)


func _steal(count: int) -> void:
	var ids := Game.inventory.keys()
	if ids.is_empty():
		return
	for i in count:
		if ids.is_empty():
			return
		var pick := str(ids[randi() % ids.size()])
		Game.remove_item(pick, 1)
		if Game.item_count(pick) <= 0:
			ids.erase(pick)


func event_text(id: String) -> String:
	return str(DB.events.get(id, {}).get("text", ""))


func event_name(id: String) -> String:
	return str(DB.events.get(id, {}).get("name", id))
