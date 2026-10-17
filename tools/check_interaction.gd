extends SceneTree
var app
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(name_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",name_)
func fresh() -> void:
	app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	app.sim.data.people.guest_1.pos=Vector2(-1.75,.25);app.sim.data.people.guest_1.state="waiting";app.sim.data.people.guest_1.path=[];app.sim.data.people.guest_1.known=true
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
	check("outside tap closes menu without replacing task",not app.object_context.panel.visible and s.data.excavation.intent==intent)
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
	print("FOCUSED CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size())
	quit(0 if checks.all(func(x):return x) else 1)
