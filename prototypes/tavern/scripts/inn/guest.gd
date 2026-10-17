extends Customer
var inn: Node
var party: int = 1
var request_room: bool = false
var room_number: int = -1
var talked: bool = false
var followers: Array[Actor] = []
var caption: Label

func walk_to(p: Vector2) -> void:
	if inn != null:
		inn.navigate(self, p)
	else:
		super.walk_to(p)

func _on_arrived() -> void:
	if inn != null and inn.advance_route(self):
		return
	super._on_arrived()
	if fsm.state == CustomerStateMachine.S.LEAVE:
		fsm.set_state(CustomerStateMachine.S.GONE)

func _on_wants_line(situation: String) -> void:
	match situation:
		"wait": _bubble.say("천천히 해도 괜찮소.")
		"perfect", "good": _bubble.say("잘 먹었소.")
		"bad": _bubble.say("오늘은 좀 아쉽군.")

func _on_state_changed(from: int, to: int) -> void:
	super._on_state_changed(from, to)
	if caption != null:
		caption.text = "%s · %d인" % [display_name().split(" ")[0], party]
		if to == CustomerStateMachine.S.WAIT:
			caption.text += " · 주문"
		elif to == CustomerStateMachine.S.EAT:
			caption.text += " · 식사 중"

func _exit_tree() -> void:
	for follower in followers:
		if is_instance_valid(follower):
			follower.queue_free()
