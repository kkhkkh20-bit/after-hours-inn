class_name Customer
extends Actor
## Visual + spatial body for a customer. All behaviour lives in
## CustomerStateMachine; this node moves the sprite, shows the bubble and
## reports back to the restaurant.

signal left(customer: Customer)
signal ordered(customer: Customer)
signal reacted(customer: Customer, satisfaction: float)

var fsm: CustomerStateMachine
var char_id: String = ""
var table_pos: Vector2 = Vector2.ZERO
var door_pos: Vector2 = Vector2.ZERO
var table_index: int = -1

var _bubble: CustomerBubble
var _fx: AnimatedSprite2D
var _react_timer: float = 0.0


func setup_customer(id: String, door: Vector2, table: Vector2, t_index: int) -> void:
	char_id = id
	door_pos = door
	table_pos = table
	table_index = t_index
	var sprite := str(DB.character(id).get("sprite", "slime"))
	setup(sprite)
	speed = 56.0 * float(DB.character(id).get("tempo", 1.0))
	position = door

	fsm = CustomerStateMachine.new()
	fsm.setup(id)
	fsm.state_changed.connect(_on_state_changed)
	fsm.wants_line.connect(_on_wants_line)

	_bubble = CustomerBubble.new()
	_bubble.position = Vector2(0, -height() - 14)
	add_child(_bubble)

	_fx = AnimatedSprite2D.new()
	_fx.centered = true
	_fx.position = Vector2(14, -height() - 6)
	_fx.visible = false
	add_child(_fx)

	arrived.connect(_on_arrived)


func _process(delta: float) -> void:
	super._process(delta)
	if fsm == null:
		return
	fsm.tick(delta)
	if fsm.state == CustomerStateMachine.S.WAIT:
		_bubble.set_patience(fsm.patience_fraction())
	if _react_timer > 0.0:
		_react_timer -= delta
		if _react_timer <= 0.0:
			set_expression("")
	if fsm.state == CustomerStateMachine.S.GONE:
		left.emit(self)
		queue_free()


func _on_state_changed(_from: int, to: int) -> void:
	match to:
		CustomerStateMachine.S.FIND_TABLE:
			walk_to(table_pos)
		CustomerStateMachine.S.ORDER:
			ordered.emit(self)
		CustomerStateMachine.S.WAIT:
			_bubble.show_order(fsm.wanted_recipe, DB.character(char_id))
		CustomerStateMachine.S.RECEIVE:
			_bubble.hide_all()
			_burst("sparkle" if fsm.satisfaction > 0.8 else "puff")
		CustomerStateMachine.S.EAT:
			play("eat")
			Audio.play_sfx("eat")
		CustomerStateMachine.S.REACT:
			play("react")
			_react()
		CustomerStateMachine.S.PAY:
			_burst("coin")
		CustomerStateMachine.S.LEAVE:
			_bubble.hide_all()
			walk_to(door_pos)
	set_expression(fsm.expression())
	_react_timer = 1.6


func _on_arrived() -> void:
	if fsm.state == CustomerStateMachine.S.FIND_TABLE:
		fsm.set_state(CustomerStateMachine.S.SIT)
		face(-1 if position.x > 640 else 1)


func _on_wants_line(situation: String) -> void:
	var lvl := Game.friendship_level(char_id)
	var text := DB.pick_line(char_id, situation, lvl)
	_bubble.say(text)
	if situation in ["perfect", "good", "bad", "order"]:
		var voice := str(DB.character(char_id).get("voice", ""))
		if voice != "":
			Audio.play_sfx(voice, 1.0, 0.55)


func _react() -> void:
	reacted.emit(self, fsm.satisfaction)
	if fsm.satisfaction >= 0.85:
		_burst("sparkle")
		Audio.play_sfx("perfect")
		_burst_hearts()
	elif fsm.satisfaction < 0.35:
		_burst("anger")
		Audio.play_sfx("fail")


func _burst(fx_name: String) -> void:
	var sf := DB.sprite_frames("vfx", fx_name, "play", 12.0, false)
	if sf.get_frame_count("play") == 0:
		return
	_fx.sprite_frames = sf
	_fx.visible = true
	_fx.play("play")
	if not _fx.animation_finished.is_connected(_hide_fx):
		_fx.animation_finished.connect(_hide_fx)


func _hide_fx() -> void:
	_fx.visible = false


func _burst_hearts() -> void:
	var h := AnimatedSprite2D.new()
	h.sprite_frames = DB.sprite_frames("vfx", "heart", "play", 9.0, false)
	h.centered = true
	h.position = Vector2(-12, -height() - 8)
	add_child(h)
	h.play("play")
	h.animation_finished.connect(h.queue_free)


func serve_dish(recipe_id: String, quality: String) -> float:
	if fsm.state != CustomerStateMachine.S.WAIT:
		return -1.0
	return fsm.serve(recipe_id, quality)


func is_waiting() -> bool:
	return fsm != null and fsm.state == CustomerStateMachine.S.WAIT


func display_name() -> String:
	return str(DB.character(char_id).get("name", char_id))
