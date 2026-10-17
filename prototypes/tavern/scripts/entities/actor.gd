class_name Actor
extends Node2D
## Shared visual body for the player and every customer.
##
## Owns the animated sprite, the expression overlay, the shadow and the
## walk-to-point movement. Both the player controller and the customer AI drive
## this rather than each reimplementing sprite handling.

const EXPRESSIONS := ["neutral", "happy", "excited", "hungry", "confused",
		"angry", "shocked", "embarrassed", "sad", "proud", "satisfied",
		"surprised"]

var sprite_id: String = "cook"
var speed: float = 68.0
var facing: int = 1

var _anim: AnimatedSprite2D
var _expr: Sprite2D              ## expression frame, swapped in over the body
var _frames: SpriteFrames
var _current: String = "idle"
var _expression: String = ""
var _target: Vector2 = Vector2.ZERO
var _moving: bool = false
var _step_t: float = 0.0

signal arrived()


func setup(id: String) -> void:
	sprite_id = id
	_frames = SpriteFrames.new()
	for pair in [["idle", 6.0, true], ["walk", 11.0, true], ["eat", 9.0, true],
			["react", 7.0, false]]:
		DB.sprite_frames("character", "%s/%s" % [id, pair[0]], str(pair[0]),
				float(pair[1]), bool(pair[2]), _frames)
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _frames
	_anim.centered = true
	# Feet at the node origin: y-sorting and table alignment both key off the
	# ground point, not the sprite centre.
	var rec := DB.asset("character", "%s/idle" % id)
	var fh := int(rec.get("fh", 64))
	_anim.offset = Vector2(0, -fh / 2.0)
	add_child(_anim)
	_anim.play("idle")

	_expr = Sprite2D.new()
	_expr.centered = true
	_expr.offset = _anim.offset
	_expr.visible = false
	add_child(_expr)
	y_sort_enabled = true


func height() -> int:
	return int(DB.asset("character", "%s/idle" % sprite_id).get("fh", 64))


func play(anim: String) -> void:
	if _current == anim or _anim == null:
		return
	if not _frames.has_animation(anim):
		return
	_current = anim
	_anim.play(anim)


## Show one of the 12 expression frames. Passing "" returns to the body
## animation - the expression sheet is a still, so it is only held briefly.
func set_expression(e: String) -> void:
	if e == _expression:
		return
	_expression = e
	if e == "" or not (e in EXPRESSIONS):
		_expr.visible = false
		_anim.visible = true
		return
	var tex := DB.atlas_frame("character", "%s/expressions" % sprite_id,
			EXPRESSIONS.find(e))
	if tex == null:
		return
	_expr.texture = tex
	_expr.visible = true
	_anim.visible = false


func face(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	_anim.flip_h = dir < 0
	_expr.flip_h = dir < 0


func walk_to(p: Vector2) -> void:
	_target = p
	_moving = true


func stop() -> void:
	_moving = false
	play("idle")


func is_moving() -> bool:
	return _moving


func _process(delta: float) -> void:
	if not _moving:
		return
	var to := _target - position
	if to.length() < 2.0:
		position = _target
		_moving = false
		play("idle")
		arrived.emit()
		return
	var step := to.normalized() * minf(to.length(), speed * delta)
	position += step
	face(1 if to.x > 0.5 else (-1 if to.x < -0.5 else facing))
	if _expression == "":
		play("walk")
	_step_t += delta
	if _step_t > 0.30:
		_step_t = 0.0
		Audio.play_sfx_varied("footstep", 0.16)
