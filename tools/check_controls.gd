extends SceneTree
var app
var checks=[]
func check(label_: String,ok: bool) -> void:checks.append(ok);print("PASS " if ok else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1360);app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false
	var s=app.sim;var fresh_guest=s.data.people.guest_1.duplicate(true);s.data.player.floor=1;s.data.player.pos=Vector2(16,-5);app.displayed_floor=1;app.builder.choose("build:furnace")
	app.mobile_scene.update();await process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/controls-v185-start.png")
	var initial=app.camera.global_transform;var count=s.data.sandbox.facilities.size()
	var down=InputEventScreenTouch.new();down.index=0;down.position=Vector2(320,700);down.pressed=true;root.push_input(down,true)
	for i in 5:
		var drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(320+i*22,700);drag.relative=Vector2(22,0);root.push_input(drag,true);app._physics_process(.05);await process_frame
	check("placement gesture really reaches the world",app.pointer.pressed and app.pointer.dragged and not app.pointer.blocked)
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/controls-v185-drag.png")
	var up=InputEventScreenTouch.new();up.index=0;up.position=Vector2(408,700);up.pressed=false;root.push_input(up,true)
	for i in 10:app._physics_process(.05)
	check("dragging a building never moves its camera",app.camera.global_transform.is_equal_approx(initial))
	check("placement drag release never installs accidentally",s.data.sandbox.facilities.size()==count)
	app.builder.close();app.cancel_everything();s.data.player.floor=0;s.data.player.pos=Vector2(-12,5);app.displayed_floor=0;s.data.paused=false
	var p: Dictionary=s.data.people.guest_1;p.state="arriving";p.floor=0;p.pos=Vector2(-1.75,.25);p.path=[];p.visit="stay";p.role="";p.known=true;p.room=0
	s.queue_move(Vector2(-8,3));var owner=s.data.player.pos
	var okay=s.request_room(1,"guest_1")
	check("room assignment completes without waiting for owner approach",okay and s.data.rooms["1"].guest=="guest_1" and s.data.booking_request.is_empty() and s.data.player.pos==owner)
	app.cancel_everything();s.data.player.floor=0;s.data.player.pos=Vector2(-.25,2.25)
	var route=s.path_to(s.data.player.pos,Vector2(-6.25,4.25));var diagonal=false;var previous: Vector2=s.data.player.pos
	for at in route:
		var d: Vector2=at-previous
		if absf(d.x)>.1 and absf(d.y)>.1:diagonal=true
		previous=at
	check("ground route contains genuine diagonal steps",diagonal)
	p.state="waiting";p.floor=0;p.pos=Vector2(-7.25,2.25);p.path=[];s.data.player.pos=Vector2(-.25,2.25);s.cancel_work();s.queue_command("approach","guest_1")
	p.pos=Vector2(-7.25,5.25)
	for i in 6:s.data.clock+=.05;s.update_excavation(.05)
	var endpoint: Vector2=s.data.excavation.path.back() if not s.data.excavation.path.is_empty() else s.data.player.pos
	check("chase updates destination before reaching stale position",endpoint.distance_to(p.pos)<1.4)
	app.cancel_everything();s.data.player.floor=0;s.data.player.pos=Vector2(-.25,2.25);s.data.people.guest_2=fresh_guest;fresh_guest.id="guest_2";p=s.data.people.guest_2;p.travel="";p.floor=0;p.state="leaving";p.pos=Vector2(-5.25,2.25);p.path=s.path_to(p.pos,Vector2(-12.25,2.25));p.room=0
	s.data.ops.selected="guest_2";s.queue_command("grab","guest_2")
	for i in 200:
		s.tick(.05)
		if p.state=="restrained":break
	check("moving fleeing guest is caught without waiting at old location",p.state=="restrained" and s.data.ops.drag=="guest_2")
	app.cancel_everything();app.builder.choose("build:furnace");app.mobile_scene.update();app.builder.toggle_camera_pan();initial=app.camera.global_transform
	app.pointer.start(Vector2(320,700),false);app.pointer.motion(Vector2(400,700));app._physics_process(.05)
	check("camera pans only after explicit screen-move mode",not app.camera.global_transform.is_equal_approx(initial))
	app.pointer.reset();app.builder.close()
	print("CONTROLS ",checks.filter(func(v):return v).size(),"/",checks.size());app.template_interactions.marker.fade_out();await process_frame;app.free();await process_frame;await process_frame;quit(1 if checks.has(false) else 0)
