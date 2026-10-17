extends SceneTree
var app
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(name_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",name_)
func fresh() -> void:
	app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	app.sim.data.people.guest_1.pos=Vector2(-1.75,.25);app.sim.data.people.guest_1.state="waiting";app.sim.data.people.guest_1.path=[];app.sim.data.people.guest_1.known=true
	app.sim.data.people.guest_1.visit="stay"
	app.sim.data.tycoon.reception=false;app.sim.data.tycoon.cleaning=false;app.sim.data.tycoon.easy=false
	app.set_layer("surface");app.sync_view(0)
func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.set_physics_process(false);fresh()
	var s=app.sim
	check("arrival point has a real route",not s.guest_path(Vector2(14.25,3.25),Vector2(-1.75,-.25)).is_empty())
	var reports=int(s.data.ops.reports);var clock=float(s.data.tycoon.get("next_missing_check",0))
	for i in 5:app.context_heading();app.context_stats();app.Tycoon.goal(s)
	check("reading UI does not mutate missing-person timer",float(s.data.tycoon.get("next_missing_check",0))==clock and int(s.data.ops.reports)==reports)
	check("manual room request reserves immediately",s.request_room(1,"guest_1") and s.data.rooms["1"].reserved=="guest_1" and s.data.rooms["1"].guest=="")
	s.spawn_guest();var g2="guest_"+str(int(s.data.serial));s.data.people[g2].visit="stay";s.data.people[g2].state="waiting";s.data.people[g2].path=[]
	check("second guest cannot steal reserved room",not s.request_room(1,g2) and s.data.rooms["1"].reserved=="guest_1")
	s.tick(20)
	check("reservation becomes occupied exactly once",s.data.rooms["1"].guest=="guest_1" and s.data.rooms["1"].reserved=="")
	var money=int(s.data.money);app.Tycoon.confirm(s,"guest_1")
	check("repeated confirmation cannot collect money twice",int(s.data.money)==money)
	s.checkout("guest_1");s.data.people[g2].pos=Vector2(-1.75,.25);s.data.player.floor=0;s.data.player.pos=Vector2(-1.75,.75);s.data.people[g2].known=true
	check("used room becomes dirty",s.data.rooms["1"].guest=="" and s.data.rooms["1"].dirty)
	check("dirty room can reserve for cleaning then reuse",s.request_room(1,g2))
	s.tick(35)
	check("cleaning then second occupancy completes",s.data.rooms["1"].guest==g2 and not s.data.rooms["1"].dirty)
	fresh();s=app.sim
	s.request_room(2,"guest_1");app.Commands.cancel(app,true)
	check("explicit cancellation releases room reservation",s.data.rooms["2"].get("reserved","")=="" and s.data.booking_request.is_empty())
	s.data.player.pos=Vector2(0,1);var pos=s.data.player.pos
	check("unreachable click does not snap across map",not s.queue_move(Vector2(500,500)) and s.data.player.pos==pos)
	# Exercise the same pointer state used by GUI-delivered mouse and touch events.
	var point=app.camera.unproject_position(app.world_point(s.data.people.guest_1.pos,0,1.1))
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point
	app.pointer.observe(press,false)
	s.data.people.guest_1.pos+=Vector2(3,0)
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=point
	app.pointer.observe(release,false);var tap=app.pointer.take()
	check("moving guest stays captured at press",tap.candidates.any(func(c):return c.kind=="person" and c.id=="guest_1"))
	app.pointer.observe(press,false)
	var motion=InputEventMouseMotion.new();motion.position=point+Vector2(45,0);app.pointer.observe(motion,false);app.pointer.observe(release,false)
	check("drag release never emits a tap",app.pointer.take().is_empty())
	app.pointer.observe(press,true);app.pointer.observe(release,false)
	check("UI-owned gesture never emits a world tap",app.pointer.take().is_empty())
	app.pointer.reset()
	for pair in [[0,true,Vector2(200,500)],[1,true,Vector2(400,500)],[0,false,Vector2(200,500)],[1,false,Vector2(400,500)]]:
		var touch=InputEventScreenTouch.new();touch.index=pair[0];touch.pressed=pair[1];touch.position=pair[2];app.pointer.observe(touch,false)
	check("pinch release never emits a tap",app.pointer.take().is_empty())
	fresh();s=app.sim
	app.object_context.open("conversation","guest_1",app.Dialogue.begin(s,"guest_1"));await process_frame;await process_frame
	var at=app.object_context.panel.position;s.data.people.guest_1.pos+=Vector2(2,0);app.object_context.refresh()
	check("menu position stays fixed as guest moves",app.object_context.panel.position==at)
	check("context action uses 88px logical touch height",app.object_context.controls["offer_room"].size.y>=88)
	app.object_context.close();s.queue_move(Vector2(-4,2));var intent=str(s.data.excavation.intent)
	app.object_context.open("owner");await process_frame
	app.world_tap(Vector2(710,1275),[])
	check("outside invalid floor tap closes menu and preserves task",not app.object_context.panel.visible and s.data.excavation.intent==intent)
	app.object_context.open("system");await process_frame
	check("settings retain save and load while menu pauses time",app.object_context.controls.has("save") and app.object_context.controls.has("load"))
	app.object_context.close();s.data.paused=false
	app.object_context.open("conversation","guest_1",app.Dialogue.begin(s,"guest_1"));await process_frame;await process_frame
	var b: Button=app.object_context.controls["offer_room"]
	var center=b.get_global_rect().get_center()
	var down=InputEventMouseButton.new();down.position=center;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down,true);await process_frame
	var up=InputEventMouseButton.new();up.position=center;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true);await process_frame;await process_frame
	check("real GUI click opens room choices without world movement",app.object_context.kind=="conversation" and s.data.people.guest_1.dialogue_stage=="rooms" and app.object_context.controls.has("book1"))
	var room_button: Button=app.object_context.controls.get("book2")
	if room_button!=null:
		center=room_button.get_global_rect().get_center();down=InputEventMouseButton.new();down.position=center;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down,true);await process_frame
		up=InputEventMouseButton.new();up.position=center;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true);await process_frame
	check("real GUI booking click creates one reservation",s.data.rooms["2"].get("reserved","")=="guest_1" and s.data.booking_request.get("room",0)==2)
	var saved=s.snapshot();var serialized=JSON.parse_string(JSON.stringify(saved))
	check("JSON save restores active reservation",s.restore(serialized) and s.data.rooms["2"].reserved=="guest_1" and s.data.booking_request.room==2)
	var balance=int(s.data.money);var malformed=s.snapshot();malformed.state.player="bad"
	check("malformed save leaves current progress untouched",not s.restore(malformed) and int(s.data.money)==balance)
	app.object_context.close();s.data.paused=false
	app.object_context.open("conversation","guest_1",app.Dialogue.begin(s,"guest_1"));await process_frame;await process_frame
	var pause_button: Button=app.object_context.controls["@pause"];center=pause_button.get_global_rect().get_center()
	down=InputEventMouseButton.new();down.position=center;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down,true);await process_frame
	up=InputEventMouseButton.new();up.position=center;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;root.push_input(up,true);await process_frame
	check("resume button during a paused conversation really resumes",not s.data.paused and not app.object_context.panel.visible)
	var stair_route: Array=s.guest_path(Vector2(-1.75,.25),s.STAIRS)
	check("upstairs route uses public corridor instead of room two",not stair_route.is_empty() and stair_route.all(func(point):return not Rect2(2.2,.2,4.5,3.5).has_point(point)))
	fresh();s=app.sim
	s.request_room(2,"guest_1")
	var previous_booking: Dictionary=s.data.booking_request.duplicate(true)
	var previous_path: Array=s.data.excavation.path.duplicate()
	check("invalid destination preserves booking and route",not app.Commands.move(app,Vector2(500,500)) and s.data.booking_request==previous_booking and s.data.excavation.path==previous_path and s.data.rooms["2"].reserved=="guest_1")
	check("valid destination replaces booking and releases room",app.Commands.move(app,Vector2(-4,2)) and s.data.booking_request.is_empty() and s.data.rooms["2"].reserved=="" and s.data.excavation.intent=="move")
	var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	app.object_context.open("owner");app._unhandled_input(escape)
	check("escape closes selection instead of exiting",not app.object_context.panel.visible and not s.data.paused)
	app._unhandled_input(escape)
	check("escape from world opens settings",app.object_context.kind=="system" and app.object_context.panel.visible)
	app.object_context.close();app.set_layer("rooms");app.object_context.refresh()
	check("active floor remains indicated after menus",app.object_context.controls.has("@view:rooms") and app.object_context.controls["@view:rooms"].modulate!=app.object_context.controls["@view:surface"].modulate)
	fresh();s=app.sim;app.Tycoon.set_easy(s,true)
	check("easy mode provides all three operating jobs",s.data.tycoon.reception and s.data.tycoon.cleaning and s.data.staff.delegated)
	check("opening settlement caps combined cost at six",app.Tycoon.settlement_cost(s,24)==6)
	s.data.campaign.day=4
	check("fourth day restores original settlement",app.Tycoon.settlement_cost(s,24)==24)
	s.data.campaign.day=1;s.data.rooms["1"].dirty=true
	var recommended=app.Tycoon.recommended_room(s,"guest_1")
	check("recommendation prefers clean available room",recommended==2)
	app.Dialogue.choose(s,"guest_1","recommend_room")
	check("recommended action creates manual reservation",s.data.booking_request.get("room",0)==2 and s.data.rooms["2"].reserved=="guest_1")
	fresh();s=app.sim;app.Tycoon.set_easy(s,true);s.data.people.guest_1.arrival=0;s.data.clock=10
	app.Tycoon.tick(s,.1)
	check("staff leave time to read a new guest request",s.data.people.guest_1.room==0)
	s.data.clock=20;app.Tycoon.tick(s,.1)
	check("staff automatically admit unattended guest",s.data.people.guest_1.room>0)
	var entry: Dictionary=s.data.sandbox.entrances[0];s.data.player.floor=0;s.data.player.pos=entry.top;entry.open=true
	app.Sandbox.transit(s,entry.id)
	check("easy transit closes secret cover",s.data.player.floor==1 and not entry.open)
	app.Sandbox.transit(s,entry.id)
	check("covered entrance remains usable by owner",s.data.player.floor==0 and not entry.open)
	check("service corridor reaches private entrance",not s.path_to(Vector2(-.25,2.25),app.Tycoon.PRIVATE_ENTRY).is_empty())
	check("guest grid excludes private warehouse",s.guest_path(Vector2(-.25,2.25),app.Tycoon.PRIVATE_ENTRY).is_empty())
	fresh();s=app.sim
	check("all four basement facilities exist at start",["prison","stash","refuge","furnace"].all(func(type_):return s.data.sandbox.facilities.any(func(f):return f.type==type_)))
	check("starting cash permits free experimentation",int(s.data.money)>=300)
	var entry2: Dictionary=s.data.sandbox.entrances[0]
	check("starter rooms connect to warehouse entrance",s.data.sandbox.facilities.all(func(f):return not s.Intrigue.basement_route(s,Vector2(entry2.bottom),f.pos).is_empty()))
	var in_route: Array=s.Layout.route_in(s,s.GATE,Vector2(-1.75,-.25))
	check("arrival route actually passes through front door",not in_route.is_empty() and in_route.has(s.Layout.FRONT) and in_route.has(s.Layout.PORCH))
	s.spawn_guest();var meal_id="guest_2"
	check("meal guest reserves table rather than reception",s.data.people[meal_id].visit=="meal" and s.Layout.TABLES.has(s.data.people[meal_id].arrival_target))
	var edge=Vector2i.ZERO;var stand=Vector2i.ZERO;var found=false
	for key in s.data.cells:
		if found:break
		var cell=s.parse_cell(key)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not s.data.cells.has(s.cell_key(cell+offset)):edge=cell+offset;stand=cell;found=true;break
	s.data.player.floor=1;s.data.player.pos=Vector2(stand);var cell_count=s.data.cells.size()
	check("one pickaxe action starts on one adjacent cell",s.queue_dig(edge))
	s.tick(1)
	check("one pickaxe action opens exactly one cell",s.data.cells.size()==cell_count+1 and s.data.cells.has(s.cell_key(edge)))
	fresh();s=app.sim;s.data.clock=30;s.data.people.guest_1.arrival=0
	for room_ in s.data.rooms.values():room_.guest="occupied"
	s.data.tycoon.reception=true;app.Tycoon.tick(s,.1)
	check("staff turn away lodging guest when all rooms occupied",s.data.people.guest_1.get("full_rejected",false) and s.data.people.guest_1.state=="leaving")
	fresh();s=app.sim;var body=s.data.people.guest_1;body.state="dead";body.room=1;body.floor=0;body.pos=s.Sandbox.room_point(1);body.path=[]
	s.data.rooms["1"].guest=body.id;s.data.player.floor=0;s.data.player.pos=body.pos+Vector2(0,-.5)
	check("room chute accepts a body inside the room",s.Layout.send_body(s,body.id))
	s.tick(4)
	check("room chute transfers body without erasing evidence",body.floor==1 and body.state=="dead" and body.pos==Vector2(s.data.rooms["1"].secret_bottom) and s.data.rooms["1"].guest=="")
	check("all room chute outlets join starter basement",s.data.rooms.values().all(func(r):return not s.Intrigue.basement_route(s,Vector2(r.secret_bottom),Vector2(s.data.sandbox.entrances[0].bottom)).is_empty()))
	fresh();s=app.sim;var count=s.data.sandbox.facilities.size();s.Layout.setup(s)
	check("starter setup never duplicates facilities or money",s.data.sandbox.facilities.size()==count and s.data.money==300)
	s.data.player.floor=0;s.data.player.pos=Vector2(12.75,4);app.set_layer("all");app.sync_view(0)
	check("outdoor player has a visible first floor footing",app.footing.visible and app.footing.position.x==12.75)
	check("basement build menu offers all four structures",app.context_items("build_tools","").size()==4)
	fresh();s=app.sim;s.data.people.guest_1.state="gone";s.spawn_guest()
	var diner: Dictionary=s.data.people.guest_2
	for step in 600:
		s.tick(.1)
		if diner.state=="dining":break
	check("meal visitor reaches table and starts seated wait",diner.state=="dining" and s.Layout.TABLES.has(diner.pos))
	for step in 900:
		s.tick(.1)
		if diner.state=="gone":break
	check("meal visitor gets served then leaves",s.data.orders.values().any(func(o):return o.guest==diner.id and o.status=="served" and o.paid) and diner.state=="gone")
	fresh();s=app.sim;s.data.player.floor=1;s.data.player.pos=Vector2(s.data.sandbox.entrances[0].bottom)
	var facility_count=s.data.sandbox.facilities.size();var before_money=int(s.data.money)
	var build_at: Vector2i=s.data.sandbox.entrances[0].bottom+Vector2i(-3,0)
	check("new basement facility queues on open floor",s.Sandbox.build(s,"prison",build_at))
	s.tick(9)
	check("new basement facility completes and charges once",s.data.sandbox.facilities.size()==facility_count+1 and int(s.data.money)==before_money-6)
	fresh();s=app.sim
	check("capture command accepts living target",s.Prison.request(s,"guest_1"))
	s.tick(80)
	var captive: Dictionary=s.data.people.guest_1
	check("one capture command physically escorts and imprisons",captive.state=="captive" and captive.floor==1 and s.data.sandbox.get("capture",{}).is_empty())
	var prison=s.Prison.cells(s)[0]
	check("prison starts with six spaces and strong security",int(prison.capacity)==6 and s.Prison.security(prison)==99 and prison.care)
	check("prisoner life tracks needs without starving",captive.has("life") and captive.life.hunger>=0 and captive.life.hunger<60 and captive.life.energy>0)
	var actions={}
	for step in 70:
		s.tick(1);actions[captive.life.action]=true
	check("prisoner cycles through multiple daily activities",actions.size()>=3 and captive.state=="captive")
	s.spawn_guest();s.data.people.guest_2.state="down"
	check("shared prison admits a second prisoner",s.Prison.admit(s,prison,"guest_2") and prison.members.size()==2)
	s.data.people.guest_2.life.hunger=80;s.Prison.manage(s,"guest_2","feed_inmate")
	check("simple feeding immediately improves hunger",s.data.people.guest_2.life.hunger==35)
	var cash=int(s.data.money);s.Prison.manage(s,prison.id,"prison_expand")
	check("prison expansion adds capacity and charges once",int(prison.capacity)==8 and int(s.data.money)==cash-8)
	var serialized2=JSON.parse_string(JSON.stringify(s.snapshot()))
	check("save restores shared prison and needs",s.restore(serialized2) and s.data.people.guest_1.state=="captive" and s.data.people.guest_2.life.hunger==35)
	prison=s.Prison.cells(s)[0];captive=s.data.people.guest_1
	while absi(hash(captive.id+":"+str(int(captive.life.attempts)+1)))%100==99:captive.life.attempts+=1
	var caught=int(prison.caught);s.Prison.attempt(s,prison,captive)
	check("secure prison stops an escape attempt",int(prison.caught)==caught+1 and captive.state=="captive")
	prison.guard=false;prison.locked=false;s.Prison.attempt(s,prison,captive)
	check("unsecured prison allows real escape path",captive.state=="escaping" and not captive.path.is_empty() and int(prison.escaped)==1)
	app.set_layer("below");app.object_context.open("prison",prison.id,s.Prison.summary(s,prison.id));await process_frame
	check("prison dashboard keeps simulation running",not s.data.paused and app.object_context.controls.has("prison_roster"))
	app.object_context.close();app.object_context.open("inmate","guest_2",s.Prison.inmate_summary(s,"guest_2"));await process_frame
	s.data.people.guest_2.life.hunger=77;app.object_context.refresh()
	check("inmate needs update in the open menu",app.object_context.detail_label.text.contains("77/100"))
	app.object_context.close();var label_at=app.camera.unproject_position(app.world_point(prison.pos+Vector2(0,1.25),1,.25))
	check("prison sign is a direct clickable target",app.selection_candidates(label_at).any(func(c):return c.kind=="prison"))
	fresh();s=app.sim;s.data.people.guest_1.pos=Vector2(-1.75,.25)
	s.Prison.request(s,"guest_1");s.data.player.pos=s.data.people.guest_1.pos+Vector2(0,.5)
	for step in 20:
		s.tick(.1)
		if s.data.people.guest_1.state=="restrained":break
	app.Commands.cancel(app,true)
	check("cancelled escort clears command and leaves target recoverable",s.data.sandbox.get("capture",{}).is_empty() and s.data.ops.drag=="" and s.data.people.guest_1.state=="down")
	fresh();s=app.sim;app.object_context.open("owner");await process_frame
	var target_world=Vector2(-9,5);var target_screen=app.camera.unproject_position(app.world_point(target_world,0))
	app.world_tap(target_screen,[])
	check("one valid ground tap closes menu and moves",not app.object_context.panel.visible and s.data.excavation.intent=="move")
	fresh();s=app.sim
	check("surface navigation extends well beyond the old map",s.surface_walkable(Vector2(40,20)) and not s.path_to(Vector2(-.25,2.25),Vector2(40,20)).is_empty())
	check("west dining wing is connected to central hall",not s.guest_path(Vector2(-1.75,.25),Vector2(-19.25,2.25)).is_empty())
	check("basement has more than eight hundred open cells",s.data.cells.size()>800 and s.CELLAR_LIMIT==Vector2i(64,40))
	check("distant basement wings are genuinely connected",not s.Intrigue.basement_route(s,Vector2(-14,-7),Vector2(38,-7)).is_empty() and not s.Intrigue.basement_route(s,Vector2(38,-7),Vector2(12,15)).is_empty())
	var size_before=s.data.cells.size();s.Layout.expand(s)
	check("large expansion is applied only once",s.data.cells.size()==size_before)
	s.Contracts.accept(s);var wanted=s.Contracts.target(s)
	check("accepted case creates a real guest arriving at front door",s.data.people.has(wanted) and s.data.people[wanted].state=="arriving" and s.data.people[wanted].path.has(s.Layout.FRONT))
	s.Contracts.dossier(s,wanted);var cell=s.Prison.available_cell(s)
	s.Prison.admit(s,cell,wanted)
	for step in 3:s.Contracts.act(s,wanted,"question");s.tick(4.1)
	check("reliable prisoner intelligence completes first case",s.Contracts.current(s).ready and s.data.people[wanted].questioning.reliable)
	var reward=int(s.Contracts.current(s).reward);var balance2=int(s.data.money)
	s.Contracts.claim(s);s.Contracts.claim(s)
	check("case reward is paid exactly once",int(s.data.money)==balance2+reward and int(s.data.contracts.completed)==1)
	s.Contracts.next(s);s.Contracts.accept(s);wanted=s.Contracts.target(s);s.Contracts.dossier(s,wanted);s.Prison.admit(s,s.Prison.available_cell(s),wanted)
	balance2=int(s.data.money);s.Contracts.act(s,wanted,"ransom");s.Contracts.act(s,wanted,"ransom");s.Contracts.tick(s)
	check("money extraction pays once and completes correct case",int(s.data.money)==balance2+20 and s.Contracts.current(s).ready)
	s.Contracts.claim(s);s.Contracts.next(s);s.Contracts.accept(s);wanted=s.Contracts.target(s);s.Contracts.dossier(s,wanted)
	s.data.people[wanted].state="dead";s.data.people[wanted].death_at=s.data.clock;s.Contracts.tick(s)
	check("designated assassination satisfies third case",s.Contracts.current(s).ready)
	var saved3=JSON.parse_string(JSON.stringify(s.snapshot()))
	check("case identity and rewards survive saving",s.restore(saved3) and s.Contracts.target(s)==wanted and int(s.data.contracts.completed)==2)
	fresh();s=app.sim;s.Contracts.accept(s);wanted=s.Contracts.target(s);s.Contracts.dossier(s,wanted);s.Prison.admit(s,s.Prison.available_cell(s),wanted)
	s.Contracts.act(s,wanted,"coerce");s.tick(4.1);s.Contracts.act(s,wanted,"coerce");s.Contracts.tick(s)
	check("coerced information needs verification",s.data.people[wanted].questioning.intel and not s.data.people[wanted].questioning.reliable and not s.Contracts.current(s).ready)
	s.Contracts.act(s,wanted,"verify_intel");s.Contracts.tick(s)
	check("verified information unlocks case completion",s.Contracts.current(s).ready and s.data.people[wanted].questioning.reliable)
	s.data.contracts.alert=25;s.data.ops.inspector.state="idle";s.Contracts.tick(s)
	check("high tracking risk schedules an actual inspection",s.data.ops.inspector.state=="scheduled" and s.data.ops.inspector.at>s.data.clock)
	fresh();s=app.sim;s.Prison.ensure(s);var cell2=s.Prison.cells(s)[0]
	s.Prison.policy(s,cell2.id,"lockdown");s.tick(31)
	check("temporary lockdown expires even in empty prison",cell2.policy=="balanced")
	s.Prison.admit(s,cell2,"guest_1");var source: Dictionary=s.data.people.guest_1
	source.life.hunger=90;source.life.energy=5;source.life.mood=20;cell2.guard=false;cell2.locked=false
	s.Prison.group_care(s,cell2.id)
	check("one care command restores needs and basic security",source.life.hunger==50 and source.life.energy==25 and s.Prison.security(cell2)==99)
	source.life.trust=39;source.life.mood=60
	check("informant cooperation requires enough trust",not s.Prison.recruit(s,source.id))
	source.life.trust=45
	check("trust allows cooperative informant recruitment",s.Prison.recruit(s,source.id))
	s.tick(31)
	check("informant sends a timed persistent intelligence report",s.data.contracts.intel_stock==1 and s.data.contracts.records.size()==1 and s.Contracts.archive(s).contains(source.name))
	var intel_before=int(s.data.contracts.intel_stock);s.tick(1)
	check("informant cannot report every frame",int(s.data.contracts.intel_stock)==intel_before)
	s.Contracts.profile(source);source.questioning.intel=true;source.questioning.reliable=false;var cash3=int(s.data.money)
	s.Contracts.act(s,source.id,"verify_intel")
	check("stock intelligence verifies statements without cash cost",s.data.contracts.intel_stock==0 and int(s.data.money)==cash3 and source.questioning.reliable)
	var saved4=JSON.parse_string(JSON.stringify(s.snapshot()))
	check("informant and information records survive saving",s.restore(saved4) and s.data.people.guest_1.life.informant and s.data.contracts.records.size()>=2)
	fresh();s=app.sim;s.Contracts.accept(s);var focus_target=s.Contracts.target(s);s.Contracts.dossier(s,focus_target);s.Prison.admit(s,s.Prison.available_cell(s),focus_target)
	app.object_context.open("contracts","",s.Contracts.summary(s));await process_frame;await process_frame
	check("case board presents the next required action first",app.object_context.controls.has("case_question"))
	for step in 3:s.Contracts.act(s,focus_target,"question");s.tick(4.1)
	app.object_context.sync_live_actions(true);await process_frame;await process_frame
	check("open case board updates to claim without reopening",app.object_context.controls.has("case_claim") and not app.object_context.controls["case_claim"].disabled)
	var claim_button: Button=app.object_context.controls["case_claim"];var claim_center=claim_button.get_global_rect().get_center();var old_cash=int(s.data.money)
	var press_claim=InputEventMouseButton.new();press_claim.position=claim_center;press_claim.button_index=MOUSE_BUTTON_LEFT;press_claim.pressed=true;root.push_input(press_claim,true);await process_frame
	var release_claim=InputEventMouseButton.new();release_claim.position=claim_center;release_claim.button_index=MOUSE_BUTTON_LEFT;release_claim.pressed=false;root.push_input(release_claim,true);await process_frame
	check("real primary action click collects the case reward",int(s.data.money)==old_cash+60 and s.Contracts.current(s).paid)
	check("case checklist reflects collected reward",s.Contracts.checklist(s).contains("완료 보상 수령"))
	app.object_context.close()
	print("FOCUSED CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size())
	quit(0 if checks.all(func(x):return x) else 1)
