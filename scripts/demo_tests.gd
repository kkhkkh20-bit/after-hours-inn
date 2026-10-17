extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
const C=preload("res://scripts/inn_campaign.gd")
const D=preload("res://scripts/inn_dialogue.gd")
var count=0
var failed=0
func check(ok: bool,message: String) -> void:
	count+=1
	if not ok:failed+=1;push_error(message)
func run(obstacles: Array) -> int:
	var s=Sim.new();s.obstacles.assign(obstacles);s.rebuild_grid();C.start(s);s.data.campaign.intro=false
	check(C.active(s) and s.data.campaign.day==1,"campaign starts")
	check(not s.data.people.guest_1.get("known",false),"unknown guest is not pre-received")
	check(not s.request_room(1,"guest_1"),"booking cannot skip the conversation")
	s.data.ops.inspector.state="waiting";check(C.goal(s).contains("순찰대"),"urgent visitors override tutorial hints");s.data.ops.inspector.state="idle"
	var line=D.begin(s,"guest_1")
	check(line.contains("조용한") and s.data.campaign.talks==1,"listen to the actual request")
	check(D.options(s,"guest_1").any(func(x):return x[0]=="offer_room") and not D.options(s,"guest_1").any(func(x):return x[0]=="book1"),"room numbers require a proposal first")
	check(D.choose(s,"guest_1","offer_room")=="reopen" and D.options(s,"guest_1")[0][0]=="book1","propose then choose a room")
	D.choose(s,"guest_1","ask_story");check(s.data.campaign.rumors.size()==1,"rumor is recorded")
	s.data.player.pos=s.data.people.guest_1.pos;s.data.people.guest_1.pos=Sim.ENTRY;s.data.player.pos=Sim.ENTRY;s.assign_room(1,"guest_1")
	check(s.data.campaign.bookings==1 and s.data.campaign.reputation==1,"correct room has a consequence")
	var worker=C.special(s,"worker","마라","test");s.data.money=20
	check(C.hire(s,worker) and s.data.money==12 and s.data.staff.hired and s.data.people[worker].state=="gone","hire a real applicant with actual cost")
	var broker=C.special(s,"broker","회색 망토","test");s.data.campaign.broker=broker
	C.broker_choice(s,true);check(s.data.campaign.cargo and s.data.money==24,"cargo arrives and is paid once")
	C.broker_choice(s,true);check(s.data.money==24,"duplicate deal cannot mint money")
	s.data.ops.inspector.state="waiting";s.data.excavation.hatch_open=true;C.guard_answer(s,"guard_lie")
	check(not s.data.campaign.cargo and s.data.money==12,"open hatch exposes cargo when lying")
	var saved=s.snapshot();var restored=Sim.new();check(restored.restore(saved) and C.active(restored) and restored.data.campaign.deal=="accepted" and restored.data.people.guest_1.known,"dialogue and campaign persist")
	s.data.campaign.ledger_found=false;s.data.player.floor=1;s.data.player.pos=Vector2.ZERO;s.data.money=100
	for x in [2,3,4]:s.queue_dig(Vector2i(x,0));s.tick(12);C.tick(s)
	check(s.data.campaign.ledger_found,"actual digging finds the buried permit")
	s.data.ops.inspector.state="waiting";C.guard_answer(s,"guard_evidence")
	check(s.data.campaign.evidence_used,"discovered evidence changes the investigation")
	var old_money=s.data.money;C.pay_tax(s);C.pay_tax(s)
	check(s.data.campaign.tax_paid and s.data.money==old_money-8,"tax is paid once")
	for ending in ["clean","protected","debt","evidence","smuggler"]:
		s=Sim.new();s.obstacles.assign(obstacles);s.rebuild_grid();C.start(s);s.data.money=100 if ending!="debt" else 0
		if ending=="protected":s.data.campaign.protected=true;s.data.campaign.deal="accepted"
		if ending=="debt":s.data.debt=25
		if ending=="evidence":s.data.campaign.evidence_used=true
		if ending=="smuggler":s.data.campaign.deal="accepted"
		for day in range(1,4):
			C.settle(s)
			if s.data.campaign.ending!="":break
			C.next_day(s)
		var expected={"clean":"다시 켜진 등불","protected":"국경의 은신처","debt":"빚으로 넘어간 열쇠","evidence":"여관의 진짜 주인","smuggler":"값비싼 침묵"}[ending]
		check(s.data.campaign.ending==expected,"different choices reach a real ending: "+ending)
	s=Sim.new();s.obstacles.assign(obstacles);s.rebuild_grid();C.start(s);s.data.ops.reports=3;C.tick(s)
	check(s.data.campaign.ending=="봉인된 여관","witness reports can end the run")
	print("DEMO STORY CHECKS: %d checks, %d failures" %[count,failed])
	return 1 if failed else 0
