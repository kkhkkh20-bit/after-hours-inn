extends RefCounted
const Rules = preload("res://simulation.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func advance(s, seconds: float) -> void:
	for i in range(int(seconds*20)): s.tick(0.05)
func run() -> int:
	var s = Rules.new()
	check(not s.walk_to(Vector2(200,850),2),"closed hatch allowed entry")
	check(s.owner.floor == 1,"blocked movement changed floor")
	s.request("hire"); check(not s.hired,"hire teleported")
	advance(s,3); check(s.hired and s.coins == 16,"physical hire failed")
	advance(s,6); check(s.served > 0,"staff did not serve")
	check(s.heard_loudness(0.9,2,1) < 0.2,"closed hatch did not muffle noise")
	s.hatch_open = true
	check(s.heard_loudness(0.9,2,1) >= 0.2,"open hatch did not transmit noise")
	check(s.walk_to(Vector2(270,850),2),"open hatch blocked entry")
	advance(s,8); check(s.owner.floor == 2 and s.owner.pos.distance_to(Vector2(270,850)) < 1,"stair route failed")
	s.request("dig"); advance(s,5)
	check(s.dig_count == 1 and s.wood == 7,"excavation cost/expansion mismatch")
	check(s.investigation_count > 0,"employee ignored open-hatch digging")
	check(s.suspicion > 0,"hearing did not affect suspicion")
	s = Rules.new(); s.hired = true; s.owner.floor = 2; s.owner.pos = Vector2(275,850)
	s.request("dig"); advance(s,5)
	check(s.investigation_count == 0,"closed hatch digging incorrectly heard upstairs")
	check(s.dig_count == 1,"closed hatch prevented work inside cellar")
	s = Rules.new()
	var observer = {"pos":Vector2(250,620),"floor":1,"face":1}
	check(s.can_see(observer,Vector2(390,620),1),"lit target not seen")
	s.lamps[1] = false
	check(not s.can_see(observer,Vector2(390,620),1),"darkness not affecting sight")
	check(s.can_see(observer,Vector2(270,620),1),"close target invisible in dark")
	check(not s.can_see(observer,Vector2(210,620),1),"rear target seen")
	check(not s.can_see(observer,Vector2(260,390),0),"saw through floor")
	s.guests[1].pos = Vector2(500,390); s.guests[1].floor = 0; s.guests[1].face = 1
	s.owner.floor = 0; s.owner.pos = Vector2(468,390)
	check(s.perform("ambush",1),"rear ambush failed")
	check(s.guests[1].down and s.evidence,"ambush left no persistent state")
	check(s.perform("drag",1),"body could not be picked up")
	s.walk_to(Vector2(420,390),0); advance(s,1)
	check(s.guests[1].pos.distance_to(s.owner.pos) <= 19,"body not following")
	check(s.perform("drag",1) and s.dragging == -1,"cannot drop body")
	s = Rules.new(); s.owner.floor = 0; s.owner.pos = Vector2(540,390)
	check(not s.perform("ambush",1) and not s.guests[1].down,"front ambush should be noticed")
	s = Rules.new(); s.wood = 0; s.owner.floor = 2; s.owner.pos = Vector2(275,850)
	check(not s.perform("dig"),"dig without supports")
	s = Rules.new(); s.owner.pos = Vector2(200,620); s.paused = true
	s.walk_to(Vector2(400,620),1); advance(s,2)
	check(s.owner.pos == Vector2(200,620) and s.clock == 0,"pause leaked time/movement")
	s = Rules.new(); s.suspicion = 65; s.guard_clock = 74.9; advance(s,0.2)
	check(s.guard_visits == 1 and s.coins == 14,"guard investigation consequence absent")
	s = Rules.new(); s.dig_count = 6
	check(not s.request("dig"),"dig outside prototype bounds")
	s = Rules.new(); s.coins = 0
	check(not s.perform("hire") and not s.hired,"unfunded hire")
	s = Rules.new(); s.orders = 1; s.perform("serve")
	check(s.served == 1 and s.coins == 28 and s.orders == 0,"manual service transaction")
	print("SIDEVIEW RULE CHECKS: ",checks," checks; ",failures," failures")
	return failures
