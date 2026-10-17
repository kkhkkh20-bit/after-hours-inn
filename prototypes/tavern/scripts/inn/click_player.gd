extends Player
## Keep upstream carry/animation API while replacing keyboard input with paths.
func _process(delta: float) -> void:
	if not _moving:
		play("idle")
		return
	var offset := _target - position
	if offset.length() < 2.0:
		position = _target
		_moving = false
		play("idle")
		arrived.emit()
		return
	position = position.move_toward(_target, speed * delta)
	face(1 if offset.x > 0 else -1)
	play("walk")
	_step_t += delta
	if _step_t > 0.3:
		_step_t = 0
		Audio.play_sfx_varied("footstep", 0.1)

func _unhandled_input(_event: InputEvent) -> void:
	pass
