extends Node
## The single source of truth for player progression state.
##
## Everything here is saved. Everything not here is either derived or scene
## local. If you find yourself adding a second manager that also owns gold or
## day count, stop - it belongs in this file.

signal gold_changed(amount: int, delta: int)
signal reputation_changed(value: float)
signal friendship_changed(char_id: String, points: float, level: int)
signal recipe_unlocked(recipe_id: String)
signal inventory_changed()
signal day_started(day: int)
signal day_ended(summary: Dictionary)

const STARTING_GOLD := 220
const MAX_REPUTATION := 5.0

var day: int = 1
var gold: int = STARTING_GOLD
var reputation: float = 1.0
## Atmosphere drifts with events and furnishing; it feeds satisfaction.
var atmosphere: float = 0.5

var inventory: Dictionary = {}        ## ingredient_id -> count
var known_recipes: Array[String] = []
var friendship: Dictionary = {}       ## char_id -> float points
var upgrades: Dictionary = {}         ## upgrade_id -> level
var seen_story: Array[String] = []
var stats: Dictionary = {}            ## lifetime counters, for the summary screen

## Per-day accumulators, reset by DayManager.
var day_gold: int = 0
var day_served: int = 0
var day_perfect: int = 0
var day_failed: int = 0
var day_walkouts: int = 0
var day_satisfaction: float = 0.0   ## summed over served customers


func _ready() -> void:
	reset()


func reset() -> void:
	day = 1
	gold = STARTING_GOLD
	reputation = 1.0
	atmosphere = 0.5
	inventory = {}
	known_recipes = []
	friendship = {}
	upgrades = {"tables": 2, "stove": 1, "decor": 0}
	seen_story = []
	stats = {"served": 0, "perfect": 0, "burnt": 0, "gold_earned": 0,
			"days": 0, "walkouts": 0}
	for id in DB.recipe_ids():
		if DB.recipe(id).get("unlocked", false):
			known_recipes.append(id)
	# A starting pantry, so day one is playable without a shopping trip.
	for pair in [["dragon_beef", 4], ["ember_pepper", 4], ["cave_mushroom", 5],
			["shadow_herb", 4], ["witch_salt", 3], ["wheat_flour", 5],
			["swamp_greens", 4]]:
		add_item(str(pair[0]), int(pair[1]), false)
	reset_day_stats()
	inventory_changed.emit()


func reset_day_stats() -> void:
	day_gold = 0
	day_served = 0
	day_perfect = 0
	day_failed = 0
	day_walkouts = 0
	day_satisfaction = 0.0


# ------------------------------------------------------------------ money --
func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	if amount > 0:
		day_gold += amount
		stats["gold_earned"] = int(stats.get("gold_earned", 0)) + amount
	gold_changed.emit(gold, amount)


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	add_gold(-cost)
	return true


# -------------------------------------------------------------- inventory --
func add_item(id: String, count: int = 1, notify: bool = true) -> void:
	if count <= 0:
		return
	inventory[id] = int(inventory.get(id, 0)) + count
	if notify:
		inventory_changed.emit()


func remove_item(id: String, count: int = 1) -> bool:
	var have := int(inventory.get(id, 0))
	if have < count:
		return false
	if have == count:
		inventory.erase(id)
	else:
		inventory[id] = have - count
	inventory_changed.emit()
	return true


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func total_items() -> int:
	var n := 0
	for id in inventory:
		n += int(inventory[id])
	return n


## Can we currently cook this recipe? Checks the pantry, not the recipe book.
func has_ingredients_for(recipe_id: String) -> bool:
	var need := {}
	for ing in DB.recipe(recipe_id).get("ingredients", []):
		need[ing] = int(need.get(ing, 0)) + 1
	for ing in need:
		if item_count(str(ing)) < int(need[ing]):
			return false
	return true


func consume_ingredients_for(recipe_id: String) -> bool:
	if not has_ingredients_for(recipe_id):
		return false
	for ing in DB.recipe(recipe_id).get("ingredients", []):
		remove_item(str(ing), 1)
	return true


# ------------------------------------------------------------- reputation --
func add_reputation(delta: float) -> void:
	reputation = clampf(reputation + delta, 0.0, MAX_REPUTATION)
	reputation_changed.emit(reputation)
	_check_unlocks()


func add_atmosphere(delta: float) -> void:
	atmosphere = clampf(atmosphere + delta, 0.0, 1.0)


# ------------------------------------------------------------- friendship --
func add_friendship(char_id: String, points: float) -> void:
	var before := DB.level_for(float(friendship.get(char_id, 0.0)))
	friendship[char_id] = maxf(0.0, float(friendship.get(char_id, 0.0)) + points)
	var after := DB.level_for(float(friendship[char_id]))
	friendship_changed.emit(char_id, float(friendship[char_id]), after)
	if after > before:
		Audio.play_sfx("levelup")
		_check_unlocks()


func friendship_points(char_id: String) -> float:
	return float(friendship.get(char_id, 0.0))


func friendship_level(char_id: String) -> int:
	return DB.level_for(friendship_points(char_id))


# ---------------------------------------------------------------- recipes --
func knows_recipe(id: String) -> bool:
	return id in known_recipes


func unlock_recipe(id: String) -> bool:
	if id in known_recipes or not DB.recipes.has(id):
		return false
	known_recipes.append(id)
	recipe_unlocked.emit(id)
	Audio.play_sfx("levelup")
	return true


## Re-evaluates every locked recipe's unlock condition. Cheap, and calling it
## after any progression change means unlock rules stay declarative in JSON.
func _check_unlocks() -> void:
	for id in DB.recipe_ids():
		if id in known_recipes:
			continue
		var cond: Dictionary = DB.recipe(id).get("unlock", {})
		if cond.is_empty():
			continue
		if cond.has("reputation") and reputation >= float(cond["reputation"]):
			unlock_recipe(id)
		elif cond.has("friendship"):
			var pair: Array = cond["friendship"]
			if pair.size() == 2 and friendship_level(str(pair[0])) >= int(pair[1]):
				unlock_recipe(id)


# --------------------------------------------------------------- upgrades --
func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func apply_upgrade(id: String) -> void:
	upgrades[id] = upgrade_level(id) + 1
	if id == "decor":
		add_atmosphere(0.12)


func table_count() -> int:
	return clampi(upgrade_level("tables"), 1, 6)


# ------------------------------------------------------------------ save ---
func to_dict() -> Dictionary:
	return {
		"day": day, "gold": gold, "reputation": reputation,
		"atmosphere": atmosphere, "inventory": inventory.duplicate(),
		"known_recipes": known_recipes.duplicate(),
		"friendship": friendship.duplicate(), "upgrades": upgrades.duplicate(),
		"seen_story": seen_story.duplicate(), "stats": stats.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	gold = int(d.get("gold", STARTING_GOLD))
	reputation = float(d.get("reputation", 1.0))
	atmosphere = float(d.get("atmosphere", 0.5))
	inventory = (d.get("inventory", {}) as Dictionary).duplicate()
	known_recipes.clear()
	for r in d.get("known_recipes", []):
		known_recipes.append(str(r))
	friendship = (d.get("friendship", {}) as Dictionary).duplicate()
	upgrades = (d.get("upgrades", {}) as Dictionary).duplicate()
	seen_story.clear()
	for s in d.get("seen_story", []):
		seen_story.append(str(s))
	stats = (d.get("stats", {}) as Dictionary).duplicate()
	reset_day_stats()
	gold_changed.emit(gold, 0)
	reputation_changed.emit(reputation)
	inventory_changed.emit()
