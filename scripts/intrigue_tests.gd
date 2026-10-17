extends RefCounted
const I=preload("res://scripts/intrigue.gd")
const Sim=preload("res://scripts/simulation.gd")

static func fresh(obstacles: Array):
	var sim=Sim.new()
	sim.obstacles.assign(obstacles)
	sim.rebuild_grid()
	return sim

static func expect(value: bool, label_: String, results: Array) -> void:
	results.append([value,label_])
	if not value:print("FAIL: "+label_)

static func run(obstacles: Array, results: Array) -> void:
	var sim=fresh(obstacles)
	expect(not I.subdue(sim),"Subdue rejects remote targets",results)
	sim.data.player.pos=sim.data.people.guest_1.pos
	expect(I.subdue(sim),"Near guest starts a timed subdue action",results)
	sim.tick(1)
	expect(sim.data.people.guest_1.state=="waiting","Subdue is not instantaneous",results)
	sim.cancel_work()
	sim.tick(2)
	expect(sim.data.people.guest_1.state=="waiting","Cancelled subdue leaves target awake",results)
	I.subdue(sim)
	sim.tick(2.1)
	expect(sim.data.people.guest_1.state=="down","Completed subdue downs the same guest entity",results)
	sim.data.ops.selected="guest_1"
	expect(I.drag_or_release(sim) and sim.data.ops.drag=="guest_1","Downed person attaches to one owner",results)
	sim.move_player(Vector2(-0.5,0))
	expect(sim.data.people.guest_1.pos==sim.data.player.pos,"Dragged position follows actual owner movement",results)
	sim.data.player.pos=sim.HATCH
	sim.change_floor()
	expect(sim.data.people.guest_1.floor==1 and sim.data.people.guest_1.pos==Vector2.ZERO,"Dragging crosses hatch without duplication",results)
	var clone=fresh(obstacles)
	expect(clone.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))) and clone.data.ops.drag=="guest_1","Drag owner and floor survive JSON save",results)
	expect(not clone.start_dig(Vector2i(2,0)),"Cannot dig while carrying a person",results)
	expect(not I.build_or_hold(clone),"Cannot place holding cell on exit",results)
	clone.data.cells["2,0"]=true
	clone.data.player.pos=Vector2(2,0)
	I.sync_drag(clone)
	var coins: int=clone.data.money
	expect(I.build_or_hold(clone) and clone.data.money==coins-8,"Holding cell consumes its build cost once",results)
	expect(I.build_or_hold(clone) and clone.data.people.guest_1.state=="captive" and clone.data.ops.drag=="","Holding changes the original entity and clears drag",results)
	clone.tick(30.1)
	expect(clone.data.people.guest_1.state=="captive" and clone.data.money==coins-9,"Captivity replaces wake timer and charges upkeep",results)
	expect(I.drag_or_release(clone) and clone.data.people.guest_1.state=="escaping","Captive release starts an actual basement escape",results)
	clone.tick(10)
	expect(clone.data.people.guest_1.state=="gone" and clone.data.ops.reports==1,"Released captive reaches exit before reporting",results)
	clone.tick(2)
	expect(clone.data.ops.reports==1,"A released captive cannot report every frame",results)
	var wake=fresh(obstacles)
	wake.data.player.pos=wake.data.people.guest_1.pos
	I.subdue(wake)
	wake.tick(2.1)
	I.drag_or_release(wake)
	wake.tick(46)
	expect(wake.data.ops.drag=="" and wake.data.people.guest_1.state in ["leaving","gone"],"Recovery breaks drag ownership and starts escape",results)
	var contract=fresh(obstacles)
	contract.data.player.pos=contract.COUNTER
	expect(I.contract_action(contract),"Counter accepts one explicit contract target",results)
	var target: String=contract.data.ops.contract.target
	contract.data.player.floor=1
	contract.data.player.pos=Vector2(2,0)
	contract.data.cells["2,0"]=true
	contract.data.ops.built=true
	contract.data.ops.cell=Vector2(2,0)
	contract.data.ops.upkeep=999
	contract.data.people[target].state="captive"
	contract.data.people[target].floor=1
	contract.data.people[target].pos=Vector2(2,0)
	contract.tick(30.1)
	expect(contract.data.ops.contract.state=="ready","Thirty seconds of real captivity completes condition",results)
	expect(not I.contract_action(contract),"Cannot collect contract money remotely from basement",results)
	contract.data.player.floor=0
	contract.data.player.pos=contract.COUNTER
	coins=contract.data.money
	expect(I.contract_action(contract) and contract.data.money==coins+24,"Reception pays contract once",results)
	I.contract_action(contract)
	expect(contract.data.money==coins+24,"Completed contract cannot pay twice",results)
	var protection=fresh(obstacles)
	protection.data.player.pos=protection.COUNTER
	I.contract_action(protection)
	coins=protection.data.money
	expect(I.contract_action(protection,true) and protection.data.money==coins+8,"Unharmed guest supports paid protection branch",results)
	I.contract_action(protection,true)
	expect(protection.data.money==coins+8,"Protection cannot be farmed",results)
	var declined=fresh(obstacles)
	declined.data.player.pos=declined.COUNTER
	expect(I.contract_action(declined,true) and declined.data.ops.contract.state=="declined","Declining leaves normal inn play available",results)
	var witness=fresh(obstacles)
	witness.spawn_guest()
	witness.data.people.guest_2.pos=Vector2(0.25,2.25)
	witness.data.people.guest_2.facing=Vector2.DOWN
	witness.data.player.pos=witness.data.people.guest_1.pos
	I.subdue(witness)
	witness.tick(2.1)
	expect(witness.data.people.guest_2.state in ["leaving","gone"],"Awake witness flees along a real surface route",results)
	witness.tick(4)
	expect(witness.data.ops.reports==1 and witness.data.ops.inspector.state=="scheduled","Witness exit schedules inspector rather than instant police",results)
	var hidden=fresh(obstacles)
	hidden.spawn_guest()
	hidden.data.people.guest_2.pos=Vector2(3.25,-1.75)
	hidden.data.people.guest_2.facing=Vector2.LEFT
	hidden.data.people.guest_1.pos=Vector2(0.25,-1.75)
	hidden.data.people.guest_1.state="down"
	hidden.data.people.guest_1.wake_at=100
	I.witness(hidden,"guest_1","body")
	expect(not hidden.data.people.guest_2.report_pending,"Partition blocks a guest witness",results)
	hidden.data.people.guest_1.floor=1
	hidden.data.people.guest_1.pos=hidden.data.people.guest_2.pos
	I.witness(hidden,"guest_1","body")
	expect(not hidden.data.people.guest_2.report_pending,"Guests cannot see across floors",results)
	var staff=fresh(obstacles)
	staff.data.staff.hired=true
	staff.data.staff.pos=Vector2(0.25,1.75)
	staff.data.staff.facing=Vector2.DOWN
	staff.data.people.guest_1.state="down"
	staff.data.people.guest_1.wake_at=999
	I.witness(staff,"guest_1","body")
	expect(staff.data.ops.staff_alarm=="pending","Staff seeing a body prepares a report",results)
	staff.tick(10)
	expect(staff.data.ops.reports==1,"Staff physically reaches door before calling guards",results)
	var bribery=fresh(obstacles)
	I.report(bribery,"test witness")
	bribery.tick(25)
	expect(bribery.data.ops.inspector.state=="waiting","Inspector walks from entrance to reception",results)
	bribery.data.player.pos=bribery.COUNTER
	coins=bribery.data.money
	expect(I.inspector_action(bribery,true) and bribery.data.money==coins-12,"One-report bribe is charged on acceptance",results)
	I.inspector_action(bribery,true)
	expect(bribery.data.money==coins-12,"Departure prevents repeated bribe charge",results)
	var refusal=fresh(obstacles)
	I.report(refusal,"one")
	I.report(refusal,"two")
	refusal.tick(25)
	refusal.data.player.pos=refusal.COUNTER
	coins=refusal.data.money
	I.inspector_action(refusal,true)
	expect(refusal.data.money==coins and refusal.data.ops.inspector.state=="waiting","Multiple reports prevent a cheap bribe",results)
	var search=fresh(obstacles)
	search.data.ops.built=true
	search.data.ops.cell=Vector2(2,0)
	search.data.ops.upkeep=999
	search.data.cells["2,0"]=true
	search.data.people.guest_1.state="captive"
	search.data.people.guest_1.floor=1
	search.data.people.guest_1.pos=Vector2(2,0)
	I.report(search,"witness")
	search.tick(25)
	search.data.player.pos=search.COUNTER
	I.inspector_action(search)
	coins=search.data.money
	search.tick(14)
	expect(search.data.ops.inspector.resolved and search.data.people.guest_1.state!="captive","Physical search discovers nearby captive and releases them",results)
	expect(search.data.money==maxi(0,coins-20) and search.data.debt==maxi(0,20-coins),"Fine uses ordinary cash and debt ledger",results)
	var deep=fresh(obstacles)
	for x in range(2,8):deep.data.cells["%d,0" % x]=true
	deep.data.ops.built=true
	deep.data.ops.cell=Vector2(7,0)
	deep.data.ops.upkeep=999
	deep.data.people.guest_1.state="captive"
	deep.data.people.guest_1.floor=1
	deep.data.people.guest_1.pos=Vector2(7,0)
	I.report(deep,"witness")
	deep.tick(85)
	expect(deep.data.people.guest_1.state=="captive" and deep.data.ops.inspector.state=="idle","Limited search does not know a distant underground cell",results)
	var old_save=fresh(obstacles).snapshot()
	old_save.state.erase("ops")
	for p in old_save.state.people.values():
		for key in ["floor","wake_at","seen","report_pending","incident"]:p.erase(key)
	expect(deep.restore(old_save) and deep.data.ops.drag=="" and deep.data.people.guest_1.floor==0,"Old saves migrate people and operation defaults",results)

	var memory=fresh(obstacles)
	memory.data.staff.hired=true
	memory.data.stealth.memory=2
	memory.data.stealth.suspicion=60
	memory.tick(40)
	expect(memory.data.stealth.phase=="idle" and memory.data.stealth.warning==0,"Old memory alone cannot trigger endless noise investigations",results)
	var deadline=fresh(obstacles)
	deadline.data.player.pos=deadline.COUNTER
	I.contract_action(deadline)
	deadline.data.ops.contract.deadline=1
	deadline.data.people.guest_1.state="captive"
	deadline.data.people.guest_1.floor=1
	deadline.tick(2)
	expect(deadline.data.ops.contract.state=="failed","Captivity does not bypass the contract deadline",results)
	var no_cash=fresh(obstacles)
	no_cash.data.ops.built=true
	no_cash.data.ops.cell=Vector2(2,0)
	no_cash.data.ops.upkeep=1
	no_cash.data.cells["2,0"]=true
	no_cash.data.people.guest_1.state="captive"
	no_cash.data.people.guest_1.floor=1
	no_cash.data.people.guest_1.pos=Vector2(2,0)
	no_cash.data.money=0
	no_cash.tick(1.1)
	expect(no_cash.data.people.guest_1.state=="escaping","Unpaid cell upkeep starts escape rather than negative cash",results)
	var paused=fresh(obstacles)
	paused.data.player.pos=paused.data.people.guest_1.pos
	I.subdue(paused)
	paused.data.paused=true
	paused.tick(10)
	expect(paused.data.clock==0 and paused.data.work.remaining==2,"Pause freezes covert actions too",results)
	var occupied=fresh(obstacles)
	occupied.data.player.pos=occupied.COUNTER
	occupied.assign_room(1)
	occupied.tick(15)
	occupied.data.player.pos=occupied.data.people.guest_1.pos
	I.subdue(occupied)
	occupied.tick(2.1)
	var cancelled: bool=true
	for meal in occupied.data.orders.values():cancelled=cancelled and meal.status=="cancelled"
	expect(cancelled,"Incapacitation cancels orphan meal ownership",results)
	var progress=JSON.parse_string(JSON.stringify(contract.snapshot()))
	var reload=fresh(obstacles)
	expect(reload.restore(progress) and reload.data.ops.contract.state=="paid" and reload.data.people[target].state=="captive","Paid contract, captive, and cell survive reload",results)
