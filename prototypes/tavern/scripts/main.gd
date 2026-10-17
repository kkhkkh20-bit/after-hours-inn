extends Node
## Root node: owns the current place, the HUD, the panels and the cooking
## screen, and routes between them.
##
## Scenes are built in code rather than as .tscn files. For a game whose whole
## world is generated from a manifest, hand-authored scene files would be a
## second source of truth that could silently drift from the art pipeline.

const W := 1280
const H := 720

var hud: HUD
var panels: Panels
var cooking: CookingPanel
var menu: MainMenu
var place: Node = null
var place_name: String = ""

var _world_root: Node2D
var _transition: ColorRect
var _busy: bool = false


func _ready() -> void:
	randomize()
	_world_root = Node2D.new()
	add_child(_world_root)

	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_transition = ColorRect.new()
	_transition.color = Color(0.05, 0.03, 0.09, 1.0)
	_transition.size = Vector2(W, H)
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_transition)

	hud = HUD.new()
	add_child(hud)
	hud.visible = false
	hud.action_pressed.connect(_on_hud_action)

	panels = Panels.new()
	add_child(panels)
	panels.cook_requested.connect(_on_cook_requested)
	panels.next_day_requested.connect(_on_next_day)
	panels.quit_to_menu.connect(_to_menu)
	# Loading mid-run has to rebuild the room: table count and the day both
	# come from the save.
	panels.save_loaded.connect(func():
		DayCycle.start_day()
		Events.reset_day()
		go_to("restaurant"))

	cooking = CookingPanel.new()
	add_child(cooking)
	cooking.completed.connect(_on_cooked)

	Game.day_ended.connect(_on_day_ended)
	Game.recipe_unlocked.connect(_on_recipe_unlocked)

	_to_menu()


func _to_menu() -> void:
	_clear_place()
	hud.visible = false
	Audio.stop_ambience()
	if menu != null:
		menu.queue_free()
	menu = MainMenu.new()
	add_child(menu)
	menu.start_new.connect(_new_game)
	menu.continue_game.connect(_continue)
	menu.settings_requested.connect(panels.open_settings)
	_fade_in()


func _new_game() -> void:
	Game.reset()
	_start_run()
	_maybe_story()


func _continue() -> void:
	if not SaveManager.load_game(0):
		_new_game()
		return
	_start_run()


func _start_run() -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	hud.visible = true
	DayCycle.start_day()
	Events.reset_day()
	go_to("restaurant")


# --------------------------------------------------------------- routing --
func go_to(name: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_out()
	_clear_place()
	place_name = name
	match name:
		"restaurant":
			var r := Restaurant.new()
			r.request_panel.connect(_on_place_panel)
			r.leave_to.connect(go_to)
			place = r
		"town":
			var t := Town.new()
			t.request_panel.connect(_on_place_panel)
			t.leave_to.connect(go_to)
			place = t
		"forest":
			var f := Forest.new()
			f.leave_to.connect(go_to)
			place = f
	if place != null:
		_world_root.add_child(place)
	await _fade_in()
	_busy = false


func _clear_place() -> void:
	if place != null and is_instance_valid(place):
		place.queue_free()
	place = null
	place_name = ""


func _fade_out(t: float = 0.28) -> void:
	_transition.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_transition, "color:a", 1.0, t)
	await tw.finished


func _fade_in(t: float = 0.32) -> void:
	_transition.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_transition, "color:a", 0.0, t)
	await tw.finished


# ------------------------------------------------------------ per-frame ---
func _process(_delta: float) -> void:
	if place == null or not hud.visible:
		return
	if place.has_method("prompt_text"):
		hud.set_prompt(place.call("prompt_text"))
	if place is Restaurant:
		var r := place as Restaurant
		hud.set_orders(r.order_list())
		# The restaurant opens as soon as the player is ready; PREP exists so
		# they can stock up and cook ahead without the clock running.
		if DayCycle.phase == DayCycle.Phase.PREP and Input.is_action_just_pressed("open_orders"):
			DayCycle.open_restaurant()


func _unhandled_input(event: InputEvent) -> void:
	if menu != null:
		return
	if event.is_action_pressed("cancel") and not panels.visible and not cooking.visible:
		panels.open_pause()
		get_viewport().set_input_as_handled()
		return
	if panels.visible or cooking.visible:
		return
	if event.is_action_pressed("open_inventory"):
		panels.open_inventory()
	elif event.is_action_pressed("open_recipes"):
		panels.open_recipes()
	elif event.is_action_pressed("open_restaurant"):
		panels.open_upgrades()


func _on_hud_action(action: String) -> void:
	match action:
		"open_inventory": panels.open_inventory()
		"open_recipes": panels.open_recipes()
		"open_orders":
			if DayCycle.phase == DayCycle.Phase.PREP:
				DayCycle.open_restaurant()
				hud.show_banner("The restaurant is open.")
			else:
				panels.open_relationships()
		"open_restaurant": panels.open_upgrades()


func _on_place_panel(id: String) -> void:
	match id:
		"recipes": panels.open_recipes()
		"shop_market": panels.open_shop("market")
		"shop_witch": panels.open_shop("witch")
		"inventory": panels.open_inventory()


func _on_cook_requested(recipe_id: String) -> void:
	if not Game.has_ingredients_for(recipe_id):
		hud.show_banner("Not enough ingredients for that.")
		return
	if place is Restaurant and not (place as Restaurant).ready_dish.is_empty():
		hud.show_banner("The pass is full - serve that dish first.")
		return
	Game.consume_ingredients_for(recipe_id)
	if place is Restaurant:
		cooking.cooking.heat_penalty = (place as Restaurant).heat_penalty()
	cooking.begin(recipe_id)


func _on_cooked(result: Dictionary) -> void:
	if place is Restaurant:
		(place as Restaurant).dish_ready(result)
		hud.show_banner("%s: %s. Take it to the pass."
				% [str(DB.recipe(str(result.get("recipe", ""))).get("name", "Dish")),
				str(result.get("quality", "")).to_upper()])


func _on_recipe_unlocked(id: String) -> void:
	hud.show_banner("New recipe: %s" % str(DB.recipe(id).get("name", id)))


func _on_day_ended(summary: Dictionary) -> void:
	if place is Restaurant:
		(place as Restaurant).clear_customers()
	panels.open_summary(summary)


func _on_next_day() -> void:
	SaveManager.save_game(0)
	DayCycle.next_day()
	Events.reset_day()
	if place is Restaurant:
		(place as Restaurant).rebuild_tables()
	else:
		go_to("restaurant")
	_maybe_story()


## Story beats are keyed off the day number and shown once.
func _maybe_story() -> void:
	var key := "day_%d" % Game.day
	if DB.story.has(key) and not (key in Game.seen_story):
		Game.seen_story.append(key)
		await get_tree().create_timer(0.5).timeout
		panels.open_story(key)
