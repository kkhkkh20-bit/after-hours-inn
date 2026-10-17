extends RefCounted
const Sim = preload("res://scripts/simulation.gd")

static func fresh(obstacles: Array):
	var result=Sim.new()
	result.obstacles.assign(obstacles)
	result.rebuild_grid()
	return result

static func expect(value: bool, label_: String, results: Array) -> void:
	results.append([value,label_])
	if not value:print("FAIL: "+label_)

static func run(obstacles: Array) -> int:
	var results: Array=[]
	var sim=fresh(obstacles)
	expect(not sim.assign_room(1),"Remote room assignment rejected",results)
	sim.data.player.pos=Sim.COUNTER
	var before: int=sim.data.money
	expect(sim.assign_room(1),"Reception assigns room 1",results)
	expect(sim.data.money==before+10,"Lodging paid once",results)
	expect(not sim.assign_room(1) and sim.data.money==before+10,"Occupied room rejects duplicate booking",results)
	var route: Array=sim.data.people.guest_1.path
	var valid:=not route.is_empty()
	for point in route:valid=valid and sim.surface_walkable(point)
	expect(valid,"Room path traverses walkable cells",results)
	sim.tick(12)
	expect(sim.data.people.guest_1.state=="staying","Guest actually arrives in assigned room",results)
	sim.tick(4)
	expect(sim.data.orders.size()==1,"Arrived guest creates an order",results)
	sim.data.player.pos=Sim.COUNTER
	sim.interact()
	expect(sim.data.work.get("type","")=="cook","Owner starts timed preparation",results)
	var active_order: String=sim.data.orders.keys()[0]
	sim.tick(4)
	expect(sim.data.player.carry==active_order,"Prepared item attaches to owner",results)
	sim.data.player.floor=1
	sim.data.player.pos=sim.data.people.guest_1.pos
	expect(not sim.deliver(active_order,"player"),"Cannot deliver remotely from another floor",results)
	sim.data.player.floor=0
	before=sim.data.money
	expect(sim.deliver(active_order,"player"),"Actual owner-held meal delivered",results)
	expect(sim.data.money==before+4 and sim.data.player.carry=="","Delivery pays and clears holder",results)
	expect(not sim.deliver(active_order,"player") and sim.data.money==before+4,"No duplicate consumption or payment",results)
	sim.spawn_guest()
	sim.data.player.pos=Sim.COUNTER
	expect(sim.assign_room(2),"Second guest books different room",results)
	sim.data.player.pos=Sim.HATCH
	expect(sim.change_floor() and sim.data.player.floor==1,"Floor transition requires hatch",results)
	sim.data.player.pos=Vector2(1,0)
	before=sim.data.money
	expect(not sim.start_dig(Vector2i(4,0)),"Remote digging rejected",results)
	expect(sim.start_dig(Vector2i(2,0)),"Adjacent earth begins timed dig",results)
	expect(sim.data.money==before-1,"Digging charges exactly once",results)
	sim.tick(1)
	var snapshot: Dictionary=sim.snapshot()
	var saved: Variant=JSON.parse_string(JSON.stringify(snapshot))
	var restored=fresh(obstacles)
	expect(restored.restore(saved),"Full state JSON roundtrip",results)
	expect(not restored.data.dig.is_empty() and restored.data.dig.remaining>0,"Unfinished work persists",results)
	expect(restored.data.people.guest_1.pos is Vector2,"Actor position restored as vector",results)
	var elapsed: float=restored.data.clock
	var progress: float=restored.data.dig.remaining
	restored.data.paused=true
	restored.tick(20)
	expect(restored.data.clock==elapsed and restored.data.dig.remaining==progress,"Pause freezes all work and time",results)
	restored.data.paused=false
	restored.tick(4)
	expect(restored.data.cells.has("2,0") and restored.data.dig.is_empty(),"Resumed dig opens terrain",results)
	expect(restored.data.noise>0,"Dig emits simulation noise",results)
	expect(not restored.walkable(Vector2(4,0),1),"Unexcavated earth blocks player",results)
	expect(restored.data.people.guest_2.state=="staying","Upstairs guest continues during basement work",results)
	restored.data.player.pos=Vector2(2,0)
	expect(not restored.change_floor(),"Cannot teleport upstairs away from stairs",results)
	expect(not restored.restore({"version":-1}),"Incompatible save rejected",results)
	# Shared order ownership prevents owner/worker races.
	var staff=fresh(obstacles)
	staff.data.player.pos=Sim.COUNTER
	staff.assign_room(1)
	staff.toggle_staff()
	staff.data.player.pos=Sim.HATCH
	staff.change_floor()
	staff.tick(32)
	expect(staff.data.served>=1,"Worker prepares and delivers while owner is below",results)
	expect(staff.data.staff.distance>6,"Worker physically travels to customer",results)
	var paid:=0
	for order_ in staff.data.orders.values():
		if order_.paid:paid+=1
	expect(paid==staff.data.served,"One payment per served order",results)
	staff.tick(85)
	expect(staff.data.rooms["1"].dirty and staff.data.rooms["1"].guest=="","Checkout releases room and marks cleaning",results)
	staff.data.player.floor=0
	staff.data.player.pos=Sim.COUNTER
	expect(not staff.assign_room(1),"Dirty room cannot be reassigned",results)
	staff.data.player.pos=staff.room_target(1)
	staff.interact()
	staff.tick(5)
	expect(not staff.data.rooms["1"].dirty,"Owner completes timed cleaning",results)
	# Held item and holder survive save; checkout cancels held delivery.
	var carry=fresh(obstacles)
	carry.data.player.pos=Sim.COUNTER
	carry.assign_room(1)
	carry.tick(17)
	carry.interact()
	carry.tick(4)
	var carry_save: Variant=JSON.parse_string(JSON.stringify(carry.snapshot()))
	var clone=fresh(obstacles)
	clone.restore(carry_save)
	expect(clone.data.player.carry!="" and clone.data.orders[clone.data.player.carry].holder=="player","Item ownership survives save",results)
	clone.checkout("guest_1")
	expect(clone.data.player.carry=="","Checkout cancels orphaned held item",results)
	# Fees fire on the shared clock once, including across reload.
	var economy=fresh(obstacles)
	economy.data.money=2
	economy.data.clock=(1980.0-420.0)/6.0
	economy.update_money()
	expect(economy.data.money==0 and economy.data.debt==10,"Insufficient rent records partial payment and debt",results)
	var debt: int=economy.data.debt
	economy.update_money()
	expect(economy.data.debt==debt,"Due is not charged twice",results)
	economy.data.clock=(2160.0-420.0)/6.0
	economy.update_money()
	expect(economy.data.collector,"Tax collector arrives on game calendar",results)
	economy.data.money=10
	economy.data.player.pos=Sim.COUNTER
	economy.interact()
	expect(not economy.data.collector and economy.data.money==2,"Tax requires payment at reception",results)
	# Verify geometry-based movement rather than only marker locations.
	var mover=fresh(obstacles)
	mover.data.player.pos=Vector2(-1.75,-1.75)
	mover.move_player(Vector2(0,-3))
	expect(mover.data.player.pos.y > -2.1,"Counter collision blocks owner",results)
	mover.data.player.floor=1
	mover.data.player.pos=Vector2.ZERO
	mover.move_player(Vector2(6,0))
	expect(mover.data.player.pos.x<1.5,"Basement movement stops at unopened earth",results)
	var failures:=0
	for result in results:
		if not result[0]:failures+=1
	print("Simulation verification: %d checks, %d failures" % [results.size(),failures])
	return 0 if failures==0 else 1
