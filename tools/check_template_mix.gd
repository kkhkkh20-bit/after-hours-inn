extends SceneTree
var app
var checks=[]
func check(name_: String,okay: bool) -> void:checks.append(okay);print("PASS " if okay else "FAIL ",name_)
func _initialize() -> void:call_deferred("run")
func advance(seconds: float) -> void:
	for i in int(seconds*20):app.sim.tick(.05);app.advance_floor_journey()
func run() -> void:
	root.size=Vector2i(720,1360);app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false
	var s=app.sim;app.supplies.ensure(s)
	check("GLoot Inventory is active",app.supplies.inventory is Inventory and app.supplies.count(s,"food")==24)
	app.supplies.open();await process_frame
	var cash=s.data.money
	await app.pointer_click(app.object_context.controls["stock:food"].get_global_rect().get_center(),true);await process_frame
	check("touch purchase adds a GLoot stack and charges once",app.supplies.count(s,"food")==34 and s.data.money==cash-4)
	app.object_context.close();app.supplies.take(s,"food",34);s.data.money=100
	check("automatic replenishment buys and consumes",app.supplies.take(s,"food") and app.supplies.count(s,"food")==9 and s.data.money==96)
	s.data.supplies.auto=false;app.supplies.take(s,"food",9);cash=s.data.money
	check("empty stock with auto off cannot consume or charge",not app.supplies.take(s,"food") and s.data.money==cash)
	app.supplies.buy(s,"food");var saved=s.snapshot();app.supplies.take(s,"food",3);s.restore(saved)
	check("saved stocks rebuild real GLoot items",app.supplies.count(s,"food")==10)
	app.supplies.take(s,"medicine");check("separate stacks do not affect food",app.supplies.count(s,"medicine")==3 and app.supplies.count(s,"food")==10)
	app.supplies.ensure(s);var p: Dictionary=s.data.people.guest_1;p.state="dining";p.floor=0;p.pos=s.data.player.pos;p.visit="meal"
	s.data.orders["test_meal"]={"status":"carried","holder":"player","paid":false,"guest":"guest_1"};s.data.player.carry="test_meal"
	check("real meal service consumes one food",s.deliver("test_meal","player") and app.supplies.count(s,"food")==9)
	app.activate_selection({"kind":"person","id":"guest_1"})
	check("Interactable signal opens the selected person's menu",app.object_context.target=="guest_1" and app.template_interactions.nodes["person:guest_1"] is Interactable)
	app.object_context.close();p.state="gone";app.activate_selection({"kind":"person","id":"guest_1"})
	check("disabled departed targets cannot reopen menus",not app.object_context.panel.visible)
	app.cancel_everything();s.data.player.floor=0;s.data.player.pos=Vector2(-.25,2.25);s.data.next_guest=99999
	check("click movement accepts reachable ground",app.Commands.move(app,Vector2(-6.25,2.25)))
	check("upstream destination marker is visible",app.template_interactions.marker.visible)
	advance(.05);var speed1=s.motion.speed;advance(.1)
	check("GroundMotion accelerates rather than teleporting",speed1>0 and s.motion.speed>speed1)
	advance(5)
	check("owner reaches target without overshoot",s.data.player.pos.distance_to(Vector2(-6.25,2.25))<.05 and s.data.excavation.intent=="")
	app.request_floor(3);advance(50)
	check("accelerated movement still traverses two upstairs legs",s.data.player.floor==3 and app.floor_journey==-1)
	app.request_floor(1);advance(65)
	check("third floor can still reach basement",s.data.player.floor==1 and app.floor_journey==-1)
	p.state="waiting";var cell=s.Prison.available_cell(s);s.Prison.admit(s,cell,"guest_1");p.life.energy=30.0
	var meds=app.supplies.count(s,"medicine");s.Prison.manage(s,"guest_1","care_inmate")
	check("prison care consumes medicine and restores energy",app.supplies.count(s,"medicine")==meds-1 and p.life.energy==60)
	p.state="dead";s.data.ops.drag="guest_1";var furnace=s.data.sandbox.facilities.filter(func(f):return f.type=="furnace")[0]
	var fuel=app.supplies.count(s,"fuel");s.Sandbox.operate(s,furnace.id)
	check("furnace starts a real job using two logs",app.supplies.count(s,"fuel")==fuel-2 and s.data.work.get("type","")=="dispose")
	app.cancel_everything();s.data.ops.drag=""
	s.data.supplies.auto=true
	for day in 3:
		s.data.paused=false;advance(210);app.Campaign.tick(s)
		if s.data.campaign.get("summary",false):app.Campaign.next_day(s)
		s.data.paused=false
	check("three-day simulation retains valid stocks and positions",app.supplies.count(s,"food")>=0 and s.data.player.pos.is_finite() and s.data.money>=0)
	print("TEMPLATE MIX ",checks.filter(func(v):return v).size(),"/",checks.size());app.queue_free();await process_frame;quit(1 if checks.has(false) else 0)
