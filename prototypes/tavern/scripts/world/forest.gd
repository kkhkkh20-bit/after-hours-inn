class_name Forest
extends Node2D
## The gathering area.
##
## Deliberately lightweight (GDD 26): walk up to a node, press SPACE, get an
## ingredient. No combat, no dungeon, no stamina bar. Its job is to make night
## feel different and to be the only source of the rare ingredients, which is
## what gives the day/night cycle teeth.

signal leave_to(place: String)
signal gathered(ingredient_id: String)

const W := 1280
const H := 720
const GROUND := 240
const NODE_COUNT := 9

var player: Player
var _world: Node2D
var _lighting: CanvasModulate
var _nodes: Array = []          ## [{node: Node2D, id: String, taken: bool}]
var _exit_point := Vector2(70, 640)


func _ready() -> void:
	y_sort_enabled = true
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_build()
	_lighting = CanvasModulate.new()
	add_child(_lighting)
	DayCycle.daypart_changed.connect(_on_daypart)
	_on_daypart(DayCycle.daypart())
	Audio.play_ambience("forest")


func _tile(name: String, x: int, y: int, parent: Node2D) -> void:
	var s := Sprite2D.new()
	s.texture = DB.env_texture(name)
	s.centered = false
	s.position = Vector2(x, y)
	parent.add_child(s)


func _prop(name: String, pos: Vector2, parent: Node2D = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = DB.env_texture(name)
	s.centered = false
	if s.texture != null:
		s.position = pos - Vector2(s.texture.get_width() / 2.0,
				s.texture.get_height())
	(parent if parent != null else _world).add_child(s)
	return s


func _build() -> void:
	var bg := Node2D.new()
	bg.z_index = -20
	add_child(bg)
	# Grass only. Two attempts at worn dirt patches both failed the same way:
	# a tile-grid distance test produces axis-aligned blocks, and any tone that
	# reads as "bare earth" against this green reads as a hole in the ground.
	# The trees, bushes, rocks and gather nodes carry the visual interest; the
	# floor's job is to stay quiet underneath them.
	for x in range(0, W, 32):
		for y in range(0, H, 32):
			var gx := x / 32
			var gy := y / 32
			_tile("grass_%d" % ((gx * 3 + gy * 5) % 4), x, y, bg)
	# a winding path back toward town
	for x in range(0, 400, 32):
		_tile("path_%d" % ((x / 32) % 4), x, 620, bg)
	# a pond
	var pond := AnimatedSprite2D.new()
	pond.sprite_frames = DB.sprite_frames("environment", "water", "flow", 5.0, true)
	pond.centered = false
	pond.position = Vector2(900, 300)
	pond.scale = Vector2(7, 4)
	pond.z_index = -18
	bg.add_child(pond)
	pond.play("flow")

	# a dense treeline at the top so the area feels enclosed, and scattered
	# trees below for depth
	for i in range(0, 15):
		_prop("tree_%d" % (i % 4), Vector2(40 + i * 92, GROUND - 30 + (i % 3) * 14))
	for spec in [[210, 470], [520, 520], [1150, 430], [700, 660]]:
		_prop("tree_%d" % (int(spec[0]) % 4), Vector2(spec[0], spec[1]))
	for spec in [[300, 560], [640, 420], [1040, 610], [420, 660], [860, 560]]:
		_prop("bush_%d" % (int(spec[0]) % 4), Vector2(spec[0], spec[1]))
	for spec in [[380, 430], [760, 520], [1100, 660]]:
		_prop("rock_%d" % (int(spec[0]) % 4), Vector2(spec[0], spec[1]))
	_prop("log", Vector2(560, 610))

	_spawn_nodes()

	var l := UIKit.label("TOWN", 14, UIKit.PAPER)
	l.position = Vector2(50, 590)
	l.z_index = 50
	add_child(l)

	player = Player.new()
	_world.add_child(player)
	player.position = Vector2(160, 620)
	player.bounds = Rect2(50, GROUND + 60, W - 100, H - GROUND - 90)
	player.interacted.connect(func(_t): interact_here())


## Gatherable nodes are re-rolled every visit, honouring night-only gating.
## That is the whole "Ghost Mushroom appears only at night" rule from the GDD -
## it lives in the ingredient data, not in a special case here.
func _spawn_nodes() -> void:
	for entry in _nodes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_nodes.clear()
	var pool := DB.ingredients_from("forest", DayCycle.is_night())
	if pool.is_empty():
		return
	var spots := [Vector2(300, 500), Vector2(470, 580), Vector2(620, 470),
			Vector2(800, 620), Vector2(950, 500), Vector2(1120, 570),
			Vector2(380, 660), Vector2(700, 540), Vector2(1030, 660)]
	for i in mini(NODE_COUNT, spots.size()):
		var id := str(pool[randi() % pool.size()])
		var holder := Node2D.new()
		holder.position = spots[i]
		_world.add_child(holder)
		var art := _node_art(id)
		var s := Sprite2D.new()
		s.texture = DB.env_texture(art)
		if s.texture == null:
			s.texture = DB.ingredient_texture(id)
		s.centered = false
		if s.texture != null:
			s.position = -Vector2(s.texture.get_width() / 2.0,
					s.texture.get_height())
		holder.add_child(s)
		if DB.ingredient(id).get("rarity", "common") == "rare":
			var glow := AnimatedSprite2D.new()
			glow.sprite_frames = DB.sprite_frames("vfx", "magic", "shine", 9.0, true)
			glow.position = Vector2(0, -14)
			glow.modulate.a = 0.75
			holder.add_child(glow)
			glow.play("shine")
		_nodes.append({"node": holder, "id": id, "taken": false})


## Pick forest scenery art that matches the ingredient, so a gather node reads
## as a thing growing rather than a floating inventory icon.
func _node_art(id: String) -> String:
	match id:
		"ghost_mushroom": return "mushroom_ghost"
		"gold_mushroom": return "mushroom_gold"
		"cave_mushroom": return "mushroom_red"
		"moon_berry": return "bush_1"
		"crimson_sap": return "bush_3"
		"shadow_herb": return "flower_2"
		"swamp_greens": return "bush_0"
		"ember_pepper": return "flower_3"
		"frost_root": return "flower_0"
		"thunder_egg": return "rock_1"
	return "mushroom_blue"


func _on_daypart(part: String) -> void:
	var tint := Color(1, 1, 1)
	match part:
		"morning": tint = Color(0.96, 0.94, 0.86)
		"day": tint = Color(1, 1, 1)
		"evening": tint = Color(0.86, 0.70, 0.66)
		"night": tint = Color(0.38, 0.44, 0.74)
	var tw := create_tween()
	tw.tween_property(_lighting, "color", tint, 1.5)
	_spawn_nodes()


func interact_here() -> void:
	var p := player.position
	if p.distance_to(_exit_point) < 110.0:
		leave_to.emit("town")
		return
	for entry in _nodes:
		if entry["taken"] or not is_instance_valid(entry["node"]):
			continue
		if p.distance_to(entry["node"].position) < 62.0:
			entry["taken"] = true
			var id := str(entry["id"])
			Game.add_item(id, 1)
			Audio.play_sfx("magic" if DB.ingredient(id).get("rarity", "") == "rare"
					else "ui_confirm")
			_pop(entry["node"].position, id)
			entry["node"].queue_free()
			gathered.emit(id)
			return


func _pop(pos: Vector2, id: String) -> void:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = DB.sprite_frames("vfx", "sparkle", "play", 14.0, false)
	fx.position = pos + Vector2(0, -16)
	add_child(fx)
	fx.play("play")
	fx.animation_finished.connect(fx.queue_free)
	var l := UIKit.label("+ %s" % str(DB.ingredient(id).get("name", id)), 14,
			UIKit.GOLD)
	l.position = pos + Vector2(-30, -60)
	l.z_index = 60
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -26), 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


func prompt_text() -> String:
	var p := player.position
	if p.distance_to(_exit_point) < 110.0:
		return "SPACE  back to town"
	for entry in _nodes:
		if entry["taken"] or not is_instance_valid(entry["node"]):
			continue
		if p.distance_to(entry["node"].position) < 62.0:
			return "SPACE  gather %s" % str(
				DB.ingredient(str(entry["id"])).get("name", entry["id"]))
	return ""
