class_name Restaurant
extends Node2D
## The restaurant interior - the game's centrepiece scene.
##
## Composed for 1280x720: kitchen along the left wall, dining room to the
## right, door bottom-right. The camera does not move; the whole room is the
## frame, which is what lets the player read the state of every table at once.

const W := 1280
const H := 720
const FLOOR_TOP := 236          ## where the wall ends and the floor begins

signal request_cook(recipe_id: String)
signal request_panel(id: String)
signal leave_to(place: String)

var system: RestaurantSystem
var player: Player
var customers: Dictionary = {}      ## char_id -> Customer node
var orders: Dictionary = {}         ## char_id -> recipe_id
var ready_dish: Dictionary = {}     ## {recipe, quality} waiting on the pass

var _world: Node2D
var _lighting: CanvasModulate
var _pass_point: Vector2 = Vector2(300, 300)
var _door_point: Vector2 = Vector2(1180, 640)
var _table_points: Array = []
var _seat_points: Array = []
var _prompt_cb: Callable
var _dust: Sprite2D
var _pass_marker: Sprite2D
var _stove_marker: Node2D
var _heat_penalty_t: float = 0.0
var _windows: Array[Sprite2D] = []


func _ready() -> void:
	y_sort_enabled = true
	system = RestaurantSystem.new()
	add_child(system)
	system.customer_arrived.connect(_on_customer_arrived)

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_build_room()
	_build_player()

	_lighting = CanvasModulate.new()
	add_child(_lighting)
	DayCycle.daypart_changed.connect(_on_daypart)
	_on_daypart(DayCycle.daypart())

	Events.event_effect.connect(_on_event_effect)
	Audio.play_ambience("restaurant")


# ------------------------------------------------------------- room build --
func _tile(name: String, x: int, y: int, parent: Node2D) -> void:
	var s := Sprite2D.new()
	s.texture = DB.env_texture(name)
	s.centered = false
	s.position = Vector2(x, y)
	parent.add_child(s)


func _prop(name: String, pos: Vector2, parent: Node2D = null,
		anchor_bottom: bool = true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = DB.env_texture(name)
	s.centered = false
	var tex := s.texture
	if tex != null and anchor_bottom:
		s.position = pos - Vector2(tex.get_width() / 2.0, tex.get_height())
	else:
		s.position = pos
	# y_sort keys off node position, so props sort by their contact point
	if anchor_bottom and tex != null:
		s.position = pos - Vector2(tex.get_width() / 2.0, tex.get_height())
		s.z_index = 0
	(parent if parent != null else _world).add_child(s)
	return s


func _build_room() -> void:
	var bg := Node2D.new()
	bg.z_index = -20
	add_child(bg)

	# Wall band, then a two-course wainscot, then floor. The wall is kept to
	# ~1/4 of the frame: a taller one eats the play area and leaves a flat
	# cream slab across the top of every screenshot.
	for x in range(0, W, 32):
		for y in range(0, FLOOR_TOP - 64, 32):
			_tile("wall_%d" % ((x / 32 + y / 32) % 2), x, y, bg)
		_tile("wainscot", x, FLOOR_TOP - 64, bg)
		_tile("wainscot", x, FLOOR_TOP - 32, bg)
	for x in range(0, W, 32):
		for y in range(FLOOR_TOP, H, 32):
			# kitchen half gets tile, dining half gets boards
			if x < 420:
				_tile("floor_tile_%d" % ((x / 32 + y / 32) % 2), x, y, bg)
			else:
				_tile("floor_plank_%d" % ((x / 32 * 3 + y / 32) % 4), x, y, bg)
	# a visible seam between kitchen and dining room
	for y in range(FLOOR_TOP, H, 32):
		_tile("wainscot", 420 - 8, y, bg)

	# --- wall dressing ---------------------------------------------------
	_windows.append(_prop("window_day", Vector2(600, 44), bg, false))
	_windows.append(_prop("window_day", Vector2(700, 44), bg, false))
	_windows.append(_prop("window_day", Vector2(940, 44), bg, false))
	_prop("painting", Vector2(1080, 52), bg, false)
	_prop("painting", Vector2(820, 52), bg, false)
	_prop("sign", Vector2(452, 30), bg, false)
	_prop("shelf", Vector2(40, 60), bg, false)
	_prop("shelf", Vector2(180, 60), bg, false)
	_prop("shelf", Vector2(320, 60), bg, false)

	# --- kitchen ---------------------------------------------------------
	_stove_marker = _prop("stove", Vector2(120, 360))
	var fire := AnimatedSprite2D.new()
	fire.sprite_frames = DB.sprite_frames("vfx", "fire", "burn", 10.0, true)
	fire.position = Vector2(120, 330)
	fire.scale = Vector2(0.7, 0.7)
	fire.z_index = 1
	_world.add_child(fire)
	fire.play("burn")

	_prop("counter_long", Vector2(300, 320))
	_prop("fridge", Vector2(60, 500))
	_prop("barrel", Vector2(360, 520))
	_prop("crate", Vector2(300, 560))
	_prop("pot", Vector2(268, 300))
	_prop("pan", Vector2(330, 302))

	# the pass: where finished dishes are put down and picked up
	_pass_point = Vector2(390, 420)
	_prop("counter", Vector2(390, 440))
	_pass_marker = Sprite2D.new()
	_pass_marker.centered = true
	_pass_marker.position = _pass_point - Vector2(0, 34)
	_pass_marker.z_index = 2
	_world.add_child(_pass_marker)

	# --- dining room ------------------------------------------------------
	_prop("rug", Vector2(820, 600))
	_prop("plant", Vector2(500, 300))
	_prop("plant", Vector2(1230, 420))
	_prop("door", Vector2(1180, 700))

	_layout_tables()

	# hanging lamps, with real light so the room feels lit rather than tinted
	for x in [560, 800, 1040, 1210]:
		var lamp := _prop("lamp_on", Vector2(x, 200), null, false)
		lamp.z_index = 40
		var light := PointLight2D.new()
		light.texture = _radial_light()
		light.position = Vector2(x, 430)
		light.energy = 0.55
		light.color = Color("#ffcf6b")
		light.texture_scale = 3.2
		add_child(light)
	# one hard-working lamp over the kitchen pass
	var klamp := _prop("lamp_on", Vector2(300, 200), null, false)
	klamp.z_index = 40
	var klight := PointLight2D.new()
	klight.texture = _radial_light()
	klight.position = Vector2(280, 400)
	klight.energy = 0.5
	klight.color = Color("#ffdca0")
	klight.texture_scale = 2.6
	add_child(klight)

	# ambient dust motes drifting in the lamplight
	var dust_anim := AnimatedSprite2D.new()
	dust_anim.sprite_frames = DB.sprite_frames("vfx", "dust", "drift", 6.0, true)
	if dust_anim.sprite_frames.get_frame_count("drift") > 0:
		dust_anim.centered = false
		dust_anim.position = Vector2(520, 260)
		dust_anim.scale = Vector2(11, 6)     # tile the 64px sheet over the room
		dust_anim.z_index = 45
		dust_anim.modulate.a = 0.42
		add_child(dust_anim)
		dust_anim.play("drift")


## Tables are laid out on a grid that always fits inside the 16:9 dining half,
## for every table count from 1 to 5.
func _layout_tables() -> void:
	_table_points.clear()
	_seat_points.clear()
	var n := Game.table_count()
	var spots := [Vector2(600, 430), Vector2(830, 430), Vector2(1060, 430),
			Vector2(700, 620), Vector2(960, 620)]
	for i in n:
		var p: Vector2 = spots[i % spots.size()]
		_table_points.append(p)
		_seat_points.append(p + Vector2(0, -46))
		_prop("table", p)
		_prop("chair", p + Vector2(-44, 6))
		_prop("chair", p + Vector2(44, 6))
		var candle := _prop("candle", p + Vector2(0, -30))
		candle.z_index = 3


func _radial_light() -> Texture2D:
	# Built once at runtime rather than shipped as an asset: it is a pure
	# falloff mask, not art, and generating it keeps the asset folder honest.
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _build_player() -> void:
	player = Player.new()
	_world.add_child(player)
	player.position = Vector2(330, 480)
	player.bounds = Rect2(40, FLOOR_TOP + 40, W - 90, H - FLOOR_TOP - 70)
	player.interacted.connect(_on_player_interact)


# --------------------------------------------------------------- lighting --
func _on_daypart(part: String) -> void:
	var tint := Color(1, 1, 1)
	match part:
		"morning": tint = Color(1.0, 0.96, 0.88)
		"day": tint = Color(1, 1, 1)
		"evening": tint = Color(0.96, 0.82, 0.72)
		"night": tint = Color(0.72, 0.74, 0.95)
	var tw := create_tween()
	tw.tween_property(_lighting, "color", tint, 1.5)
	# swap the window art so the world outside actually changes with the hour
	var night := (part == "night")
	for w in _windows:
		if is_instance_valid(w):
			w.texture = DB.env_texture("window_night" if night else "window_day")


# ------------------------------------------------------------- service ----
func _on_customer_arrived(char_id: String, table: int) -> void:
	var c := Customer.new()
	_world.add_child(c)
	c.setup_customer(char_id, _door_point, _seat_points[table % _seat_points.size()],
			table)
	c.ordered.connect(_on_customer_ordered)
	c.left.connect(_on_customer_left)
	c.reacted.connect(_on_customer_reacted)
	customers[char_id] = c
	Audio.play_sfx("bell")


func _on_customer_ordered(c: Customer) -> void:
	var recipe := system.choose_order(c.char_id)
	c.fsm.wanted_recipe = recipe
	orders[c.char_id] = recipe


func _on_customer_reacted(c: Customer, satisfaction: float) -> void:
	if satisfaction >= 0.85:
		Game.add_atmosphere(0.03)
	elif satisfaction < 0.35:
		Game.add_atmosphere(-0.04)


func _on_customer_left(c: Customer) -> void:
	system.complete_visit(c.char_id, c.fsm)
	customers.erase(c.char_id)
	orders.erase(c.char_id)


func _process(delta: float) -> void:
	system.tick(delta)
	Events.context = {
		"customer_count": customers.size(),
		"present": customers.keys(),
	}
	if _heat_penalty_t > 0.0:
		_heat_penalty_t -= delta
	_update_pass_marker()


func _update_pass_marker() -> void:
	if ready_dish.is_empty():
		_pass_marker.visible = false
		return
	_pass_marker.visible = true
	_pass_marker.texture = DB.dish_texture(str(ready_dish.get("recipe", "")),
			str(ready_dish.get("quality", "good")))


## Interaction is proximity-based rather than trigger-area based: at this
## sprite scale, walking "into" a hitbox is fiddly, and distance-to-point is
## both simpler and more forgiving.
func _on_player_interact(_t: Node) -> void:
	interact_here()


func interact_here() -> void:
	var p := player.position
	# 1. put down / pick up at the pass
	if p.distance_to(_pass_point) < 70.0:
		if player.is_carrying():
			ready_dish = player.drop_carry()
			Audio.play_sfx("plate")
		elif not ready_dish.is_empty():
			player.carry(str(ready_dish.get("recipe", "")),
					str(ready_dish.get("quality", "good")))
			ready_dish = {}
			Audio.play_sfx("plate")
		return
	# 2. cook at the stove
	if p.distance_to(_stove_marker.position + Vector2(0, -20)) < 90.0:
		request_panel.emit("recipes")
		return
	# 3. serve a waiting customer
	var target := _nearest_waiting(p)
	if target != null and player.is_carrying():
		var dish := player.drop_carry()
		var sat: float = target.serve_dish(str(dish.get("recipe", "")),
				str(dish.get("quality", "good")))
		if sat < 0.0:
			player.carry(str(dish.get("recipe", "")), str(dish.get("quality", "good")))
		return
	# 4. leave through the door
	if p.distance_to(_door_point) < 80.0:
		leave_to.emit("town")


func _nearest_waiting(p: Vector2) -> Customer:
	var best: Customer = null
	var best_d := 92.0 * 92.0
	for id in customers:
		var c: Customer = customers[id]
		if not is_instance_valid(c) or not c.is_waiting():
			continue
		var d := p.distance_squared_to(c.position)
		if d < best_d:
			best_d = d
			best = c
	return best


## Text for the HUD's context prompt.
func prompt_text() -> String:
	var p := player.position
	if p.distance_to(_pass_point) < 70.0:
		if player.is_carrying():
			return "SPACE  put dish on the pass"
		if not ready_dish.is_empty():
			return "SPACE  pick up dish"
		return ""
	if p.distance_to(_stove_marker.position + Vector2(0, -20)) < 90.0:
		return "SPACE  cook"
	var t := _nearest_waiting(p)
	if t != null and player.is_carrying():
		return "SPACE  serve %s" % t.display_name()
	if p.distance_to(_door_point) < 80.0:
		return "SPACE  go into town"
	return ""


## Live order tickets for the HUD.
func order_list() -> Array:
	var out: Array = []
	for id in customers:
		var c: Customer = customers[id]
		if not is_instance_valid(c) or not c.is_waiting():
			continue
		out.append({"name": c.display_name(),
				"recipe": orders.get(id, ""),
				"patience": c.fsm.patience_fraction()})
	return out


func dish_ready(result: Dictionary) -> void:
	ready_dish = {"recipe": str(result.get("recipe", "")),
			"quality": str(result.get("quality", "good"))}


func heat_penalty() -> float:
	return 0.25 if _heat_penalty_t > 0.0 else 0.0


func _on_event_effect(effect: String, value: Variant) -> void:
	match effect:
		"heat_penalty":
			_heat_penalty_t = 60.0
		"patience_all":
			for id in customers:
				var c: Customer = customers[id]
				if is_instance_valid(c):
					c.fsm.patience = maxf(1.0, c.fsm.patience * (1.0 + float(value)))
		"spawn_group":
			for i in int(value):
				system.request_spawn()
		"spawn_pause":
			system.spawn_pause = float(value)
		"gold_multiplier":
			system.gold_multiplier = float(value)
		"next_order_multiplier":
			system.next_order_multiplier = float(value)
		"free_perfect":
			if not ready_dish.is_empty():
				ready_dish["quality"] = "perfect"
		"ruin_cooking":
			if not ready_dish.is_empty():
				ready_dish["quality"] = "burnt"


## Called at closing. Anyone who was ALREADY SERVED gets settled before being
## cleared - otherwise a customer still chewing when the clock runs out is
## freed without ever paying, and both their gold and their friendship change
## vanish. Found by tests/playthrough.gd.
func clear_customers() -> void:
	for id in customers.keys():
		var c: Customer = customers[id]
		if not is_instance_valid(c):
			continue
		if c.fsm != null and c.fsm.served_quality != "":
			system.complete_visit(c.char_id, c.fsm)
		c.queue_free()
	customers.clear()
	orders.clear()
	ready_dish = {}
	system.clear_all()


func rebuild_tables() -> void:
	system.rebuild_tables()
