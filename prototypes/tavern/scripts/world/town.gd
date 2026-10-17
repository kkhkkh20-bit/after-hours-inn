class_name Town
extends Node2D
## The town square. A small hub: market, witch shop, fountain, the way back to
## the restaurant and the path to the forest.
##
## Deliberately one screen. GDD 50 says make the restaurant better rather than
## making the world bigger, so the town exists to serve shopping and errands,
## not to be explored.

signal request_panel(id: String)
signal leave_to(place: String)

const W := 1280
const H := 720
const GROUND := 300

var player: Player
var _world: Node2D
var _lighting: CanvasModulate
var _points: Dictionary = {}


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
	# sky band above the horizon, then grass, then a cobbled square
	# Graded sky rather than a flat slab, with a distant treeline breaking the
	# horizon. A hard colour edge across the top of the frame is the fastest
	# way to make a scene look unfinished.
	# One GradientTexture2D, not 260 stacked ColorRects - the naive version
	# works but puts a few hundred pointless nodes in the tree every frame.
	var grad := Gradient.new()
	grad.set_color(0, Color("#5f93c4"))
	grad.set_color(1, Color("#bcd9e8"))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 8
	gtex.height = 64
	var sky := TextureRect.new()
	sky.texture = gtex
	sky.size = Vector2(W, GROUND - 40)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	bg.add_child(sky)
	for i in 22:
		var far := Sprite2D.new()
		far.texture = DB.env_texture("tree_%d" % (i % 4))
		far.centered = false
		if far.texture != null:
			far.position = Vector2(i * 62 - 20,
					GROUND - 74 - (i % 3) * 8)
		far.modulate = Color(0.62, 0.72, 0.78)      # atmospheric haze
		far.scale = Vector2(0.7, 0.7)
		bg.add_child(far)
	for x in range(0, W, 32):
		for y in range(GROUND - 60, H, 32):
			_tile("grass_%d" % ((x / 32 + y / 32) % 4), x, y, bg)
	for x in range(320, 1000, 32):
		for y in range(420, 660, 32):
			_tile("cobble_%d" % ((x / 32 + y / 32) % 4), x, y, bg)
	for y in range(GROUND, H, 32):
		_tile("path_%d" % ((y / 32) % 4), 96, y, bg)
	for x in range(1000, W, 32):
		_tile("path_%d" % ((x / 32) % 4), x, 560, bg)

	# --- buildings --------------------------------------------------------
	_prop("house_0", Vector2(200, GROUND + 60))
	_prop("house_1", Vector2(420, GROUND + 20))
	_prop("house_3", Vector2(1120, GROUND + 40))
	var shop := _prop("witch_shop", Vector2(880, GROUND + 60))
	_points["witch"] = Vector2(880, GROUND + 70)

	# market stalls
	for i in 3:
		_prop("stall_%d" % i, Vector2(560 + i * 130, 640))
	_points["market"] = Vector2(690, 660)

	_prop("fountain", Vector2(660, 470))
	for p in [Vector2(320, 400), Vector2(1010, 400)]:
		_prop("tree_%d" % (int(p.x) % 4), p)
	_prop("bush_1", Vector2(500, 690))
	_prop("bush_2", Vector2(980, 690))

	# --- signage / exits --------------------------------------------------
	_points["restaurant"] = Vector2(120, 690)
	_points["forest"] = Vector2(1210, 560)
	_marker("RESTAURANT", Vector2(120, 640))
	_marker("FOREST", Vector2(1200, 520))

	player = Player.new()
	_world.add_child(player)
	player.position = Vector2(200, 660)
	player.bounds = Rect2(60, GROUND + 40, W - 120, H - GROUND - 80)
	player.interacted.connect(func(_t): interact_here())


func _marker(text: String, pos: Vector2) -> void:
	var l := UIKit.label(text, 14, UIKit.PAPER)
	l.position = pos
	l.z_index = 50
	add_child(l)


func _on_daypart(part: String) -> void:
	var tint := Color(1, 1, 1)
	match part:
		"morning": tint = Color(1.0, 0.94, 0.84)
		"day": tint = Color(1, 1, 1)
		"evening": tint = Color(0.92, 0.72, 0.62)
		"night": tint = Color(0.46, 0.50, 0.80)
	var tw := create_tween()
	tw.tween_property(_lighting, "color", tint, 1.5)


func interact_here() -> void:
	var p := player.position
	for key in _points:
		if p.distance_to(_points[key]) < 96.0:
			match key:
				"market":
					request_panel.emit("shop_market")
				"witch":
					request_panel.emit("shop_witch")
				"restaurant":
					leave_to.emit("restaurant")
				"forest":
					leave_to.emit("forest")
			return


func prompt_text() -> String:
	var p := player.position
	for key in _points:
		if p.distance_to(_points[key]) < 96.0:
			match key:
				"market": return "SPACE  browse the market"
				"witch": return "SPACE  visit Marrow's shop"
				"restaurant": return "SPACE  back to the restaurant"
				"forest": return "SPACE  head into the forest"
	return ""
