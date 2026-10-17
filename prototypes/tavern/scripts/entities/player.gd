class_name Player
extends Actor
## The cook. Free 8-way movement inside the restaurant, with a carry slot and
## a proximity interaction target.
##
## Movement is deliberately snappy - no acceleration ramp. In a game where you
## are constantly crossing the room under time pressure, momentum reads as
## sluggishness, not weight.

signal interacted(target: Node)

const WALK_SPEED := 118.0

var bounds: Rect2 = Rect2(0, 0, 1280, 720)
var can_move: bool = true
var carrying: Dictionary = {}        ## {recipe, quality} or empty

var _carry_sprite: Sprite2D
var _nearby: Array[Node] = []
var _prompt: Sprite2D


func _ready() -> void:
	setup("cook")
	speed = WALK_SPEED
	_carry_sprite = Sprite2D.new()
	_carry_sprite.centered = true
	_carry_sprite.position = Vector2(9, -height() + 6)
	_carry_sprite.visible = false
	add_child(_carry_sprite)


func _process(delta: float) -> void:
	if not can_move:
		play("idle")
		return
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		var next := position + dir * speed * delta
		position.x = clampf(next.x, bounds.position.x, bounds.end.x)
		position.y = clampf(next.y, bounds.position.y, bounds.end.y)
		face(1 if dir.x > 0.1 else (-1 if dir.x < -0.1 else facing))
		play("walk")
		_step_t += delta
		if _step_t > 0.28:
			_step_t = 0.0
			Audio.play_sfx_varied("footstep", 0.18)
	else:
		play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event.is_action_pressed("interact"):
		var t := nearest_interactable()
		if t != null:
			interacted.emit(t)
			get_viewport().set_input_as_handled()


## Interaction targets register themselves; the player just picks the closest.
func register_interactable(n: Node) -> void:
	if not (n in _nearby):
		_nearby.append(n)


func unregister_interactable(n: Node) -> void:
	_nearby.erase(n)


func nearest_interactable(max_dist: float = 62.0) -> Node:
	var best: Node = null
	var best_d := max_dist * max_dist
	for n in _nearby:
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var d: float = position.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func carry(recipe_id: String, quality: String) -> void:
	carrying = {"recipe": recipe_id, "quality": quality}
	var tex := DB.dish_texture(recipe_id, quality)
	if tex != null:
		_carry_sprite.texture = tex
		_carry_sprite.visible = true


func drop_carry() -> Dictionary:
	var c := carrying.duplicate()
	carrying = {}
	_carry_sprite.visible = false
	return c


func is_carrying() -> bool:
	return not carrying.is_empty()
