class_name RestaurantSystem
extends Node
## Runs a service: who walks in, where they sit, what they want, who pays.
##
## Kept separate from the Restaurant scene so the whole service loop can be
## driven headlessly by the test suite without instantiating any art.

signal customer_arrived(customer_id: String, table: int)
signal customer_seated(customer_id: String, table: int)
signal order_placed(customer_id: String, recipe_id: String, table: int)
signal customer_served(customer_id: String, satisfaction: float, gold: int)
signal customer_left(customer_id: String, walked_out: bool)
signal tables_changed()

const BASE_SPAWN_INTERVAL := 13.0

var tables: Array = []            ## table_index -> customer_id or ""
var active: Dictionary = {}       ## customer_id -> node (or null when headless)
var spawn_pause: float = 0.0
var gold_multiplier: float = 1.0
var next_order_multiplier: float = 1.0

var _spawn_t: float = 0.0
var _served_today: Array[String] = []


func _ready() -> void:
	rebuild_tables()


func rebuild_tables() -> void:
	var n := Game.table_count()
	tables.resize(n)
	for i in n:
		if tables[i] == null:
			tables[i] = ""
	tables_changed.emit()


func free_table() -> int:
	for i in tables.size():
		if str(tables[i]) == "":
			return i
	return -1


func occupied_count() -> int:
	var n := 0
	for t in tables:
		if str(t) != "":
			n += 1
	return n


func tick(delta: float) -> void:
	if DayCycle.phase != DayCycle.Phase.OPEN:
		return
	if spawn_pause > 0.0:
		spawn_pause -= delta
		return
	_spawn_t += delta
	if _spawn_t >= _spawn_interval():
		_spawn_t = 0.0
		if free_table() >= 0:
			request_spawn()


## Spawn rate rises with reputation - a busy restaurant is the reward for a
## good one, and it is also the difficulty curve.
func _spawn_interval() -> float:
	var rep_factor: float = lerpf(1.25, 0.55, clampf(Game.reputation / 5.0, 0.0, 1.0))
	# Nobody arrives right at close; the tail of the day thins out naturally.
	var late: float = 1.0 + DayCycle.service_progress() * 0.8
	return BASE_SPAWN_INTERVAL * rep_factor * late


## Which monsters could walk in right now, weighted by their arrival weight.
func eligible_customers() -> Array:
	var out: Array = []
	for id in DB.character_ids():
		var ch := DB.character(id)
		if Game.day < int(ch.get("unlock_day", 1)):
			continue
		if id in active:
			continue
		out.append(id)
	return out


func pick_customer() -> String:
	var pool := eligible_customers()
	if pool.is_empty():
		return ""
	var total := 0.0
	for id in pool:
		total += float(DB.character(id).get("arrival_weight", 1.0))
	var roll := randf() * total
	for id in pool:
		roll -= float(DB.character(id).get("arrival_weight", 1.0))
		if roll <= 0.0:
			return str(id)
	return str(pool[0])


func request_spawn(force_id: String = "") -> String:
	var id := force_id if force_id != "" else pick_customer()
	if id == "":
		return ""
	# A forced spawn must respect this too, or an event that seats a named
	# customer can double-book someone who is already at a table.
	if id in active:
		return ""
	var t := free_table()
	if t < 0:
		return ""
	tables[t] = id
	active[id] = null
	tables_changed.emit()
	customer_arrived.emit(id, t)
	return id


## What this customer decides to order. Weighted toward dishes they like that
## the player can actually cook, so orders stay satisfiable.
func choose_order(char_id: String) -> String:
	var ch := DB.character(char_id)
	var fav := str(ch.get("favourite", ""))
	var options: Array = []
	for r in Game.known_recipes:
		if Game.has_ingredients_for(r):
			options.append(r)
	if options.is_empty():
		# Nothing cookable: still order the favourite so the player gets a
		# clear "you need to shop" signal rather than a silent empty order.
		return fav if fav != "" else (Game.known_recipes[0] if not Game.known_recipes.is_empty() else "")
	# Favourite gets a strong bias once they know you.
	if fav in options and randf() < 0.35 + 0.10 * float(Game.friendship_level(char_id)):
		return fav
	var best := ""
	var best_score := -99.0
	for r in options:
		var s := _preference_score(ch, str(r)) + randf() * 0.35
		if s > best_score:
			best_score = s
			best = str(r)
	return best


func _preference_score(ch: Dictionary, recipe_id: String) -> float:
	var prefers: Dictionary = ch.get("prefers", {})
	var dislikes: Dictionary = ch.get("dislikes", {})
	var s := 0.0
	for t in DB.recipe(recipe_id).get("tags", []):
		s += float(prefers.get(t, 0.0)) + float(dislikes.get(t, 0.0))
	return s


## Resolve a completed visit: pay out, move friendship, free the table.
func complete_visit(char_id: String, fsm: CustomerStateMachine) -> Dictionary:
	var gold := 0
	if not fsm.walked_out:
		gold = int(round(float(fsm.payment()) * gold_multiplier * next_order_multiplier))
		Game.add_gold(gold)
		Game.day_served += 1
		Game.day_satisfaction += fsm.satisfaction
		Game.stats["served"] = int(Game.stats.get("served", 0)) + 1
		if fsm.satisfaction >= 0.85:
			Game.day_perfect += 1
			Game.stats["perfect"] = int(Game.stats.get("perfect", 0)) + 1
		elif fsm.satisfaction < 0.35:
			Game.day_failed += 1
	else:
		Game.day_walkouts += 1
		Game.stats["walkouts"] = int(Game.stats.get("walkouts", 0)) + 1
	next_order_multiplier = 1.0
	Game.add_friendship(char_id, fsm.friendship_delta())
	release(char_id)
	customer_served.emit(char_id, fsm.satisfaction, gold)
	customer_left.emit(char_id, fsm.walked_out)
	return {"gold": gold, "satisfaction": fsm.satisfaction,
			"walked_out": fsm.walked_out}


func release(char_id: String) -> void:
	for i in tables.size():
		if str(tables[i]) == char_id:
			tables[i] = ""
	active.erase(char_id)
	tables_changed.emit()


func clear_all() -> void:
	for i in tables.size():
		tables[i] = ""
	active.clear()
	spawn_pause = 0.0
	gold_multiplier = 1.0
	next_order_multiplier = 1.0
	_spawn_t = 0.0
	tables_changed.emit()
