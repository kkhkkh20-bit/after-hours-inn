extends SceneTree
var app
var checks: Array=[]
func check(label_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func advance(seconds: float) -> void:
	for i in int(seconds*10):app.sim.tick(.1);app.advance_floor_journey()
func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	var s=app.sim;s.data.tycoon.reception=false
	check("physical beds exist only on floors two and three",app.surface.get_children().filter(func(n):return str(n.get_meta("asset",""))=="furniture/bedSingle").size()==0 and app.gallery.get_children().filter(func(n):return str(n.get_meta("asset",""))=="furniture/bedSingle").size()==3 and app.attic.get_children().filter(func(n):return str(n.get_meta("asset",""))=="furniture/bedSingle").size()==2)
	check("all five rooms are upstairs",[1,2,3,4,5].all(func(n):return s.Sandbox.floor_of(n) in [2,3]) and s.Sandbox.floor_of(4)==3)
	check("ground lobby is walkable after bedrooms removed",s.surface_walkable(Vector2(3.25,-2.25)) and not s.path_to(Vector2(-.25,2.25),Vector2(3.25,-2.25)).is_empty())
	check("each upper room has a navigable landing route",[1,2,3,4,5].all(func(n):return not s.gallery_route(s.Upper.stair(0,s.Sandbox.floor_of(n)) if n<=3 else s.Upper.TOP_STAIRS,s.Sandbox.room_point(n),s.Sandbox.floor_of(n)).is_empty()))
	app.request_floor(3);advance(40)
	check("owner travels ground to third through two real stair legs",s.data.player.floor==3 and app.floor_journey==-1)
	app.frame_owner();check("third floor view selects attic",app.view_layer=="attic" and app.attic.visible and app.gallery.visible)
	app.request_floor(1);advance(55)
	check("third floor reaches basement through ground",s.data.player.floor==1 and app.floor_journey==-1)
	app.request_floor(0);advance(35)
	check("basement returns to ground inn overview",s.data.player.floor==0 and app.inn_view)
	var p: Dictionary=s.data.people.guest_1;p.state="waiting";p.floor=0;p.pos=Vector2(-1.75,.25);p.visit="stay";p.role="";p.path=[];p.checkout=99999
	check("guest can book a third floor room",s.Tycoon.check_in(s,"guest_1",4))
	p.checkout=99999;p.order_at=99999
	for i in 350:
		s.tick(.1);app.advance_floor_journey()
		if p.floor==3 and p.state=="staying":p.order_at=99999;break
	check("booked guest physically reaches third floor",p.floor==3 and p.state=="staying" and p.pos.distance_to(s.Sandbox.room_point(4))<.5)
	p.order_at=s.data.clock
	advance(22)
	check("overnight guest comes downstairs to restaurant",p.floor==0 and p.state in ["dining","entering"] and p.meal_trip)
	for i in 600:
		s.tick(.1)
		if p.meals>=1 and p.floor==3 and p.state=="staying":break
	check("restaurant service returns overnight guest upstairs",p.meals>=1 and p.room==4 and p.floor==3 and p.state=="staying")
	s.checkout("guest_1");advance(35)
	check("third floor checkout walks out and frees room",s.data.rooms["4"].guest=="" and p.state=="gone")
	advance(45)
	check("cleaner reaches and cleans third floor room",not s.data.rooms["4"].dirty and int(s.data.tycoon.cleaner.floor)==3)
	s.data.sandbox.erase("upper_version");s.data.rooms["1"].guest="guest_1";p.state="staying";p.room=1;p.floor=0;p.pos=Vector2(3.25,-2.25)
	var old_ticket=s.create_order("guest_1");s.data.orders[old_ticket].status="cooking";s.data.work={"type":"cook","order":old_ticket,"remaining":2.0};s.data.service_target="guest_1"
	s.Upper.migrate(s)
	check("old room-service work is safely rescheduled for restaurant",s.data.orders[old_ticket].status=="cancelled" and s.data.work.is_empty() and s.data.service_target=="")
	check("old occupied ground room migrates safely upstairs",p.floor==2 and p.pos==s.Sandbox.room_point(1) and s.data.rooms["1"].guest=="guest_1")
	var saved=s.snapshot();check("new floor assignments survive save restore",s.restore(saved) and s.data.people.guest_1.floor==2 and s.data.sandbox.upper_version==1)
	check("upper floor paths do not cross unsupported air",s.gallery_route(s.Upper.TOP_STAIRS,Vector2(0,0),3).is_empty())
	check("floor three height is continuous at stair bottom",is_equal_approx(s.floor_height(s.Upper.TOP_STAIRS,3),s.floor_height(s.Upper.TOP_STAIRS,2)))
	print("UPPER FLOOR CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size());quit(0 if checks.all(func(x):return x) else 1)
