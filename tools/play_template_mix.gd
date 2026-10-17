extends SceneTree
var app
var checks=[]
func check(label_: String,value: bool) -> void:checks.append(value);print("TOUCH PASS " if value else "TOUCH FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func until(done: Callable,seconds: float) -> bool:
	for i in int(seconds*20):
		app._physics_process(.05)
		if i%5==0:await process_frame
		if done.call():return true
	return false
func run() -> void:
	root.size=Vector2i(720,1360);app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.show_inn();app.sim.data.next_guest=99999
	app.supplies.update();var cash=app.sim.data.money
	await app.pointer_click(app.supplies.button.get_global_rect().get_center(),true);await process_frame
	check("warehouse opens from a real screen touch",app.object_context.kind=="supplies")
	await app.pointer_click(app.object_context.controls["stock:food"].get_global_rect().get_center(),true);await process_frame
	check("touch purchase changes the live inventory",app.supplies.count(app.sim,"food")==34 and app.sim.data.money==cash-4)
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/mix-v184-touch-stock.png")
	app.object_context.close();app.sim.data.player.pos=Vector2(-.25,2.25);app.show_inn();app.object_context.refresh();app.mobile_scene.update()
	var target=Vector2(-6.25,2.25);var at=app.camera.unproject_position(app.world_point(target,0,.08))
	await app.pointer_click(at,true)
	check("ground touch chooses a walking destination",app.sim.data.excavation.intent=="move")
	check("live simulation reaches touched destination",await until(func():return app.sim.data.excavation.intent=="",10) and app.sim.data.player.pos.distance_to(target)<.08)
	var guest: Dictionary=app.sim.data.people.guest_1;guest.state="arriving";guest.floor=0;guest.pos=Vector2(-1.75,.25);guest.path=app.sim.path_to(guest.pos,app.sim.COUNTER);guest.role="";guest.visit="stay";guest.room=0;guest.known=false
	app.Commands.move(app,Vector2(-.25,2.25));var old_owner=app.sim.data.player.pos;app.mobile_scene.update()
	await app.pointer_click(app.mobile_scene.pins.reception.get_global_rect().get_center(),true);await process_frame
	check("reception touch interrupts an existing walk and opens request",app.object_context.kind=="conversation")
	await app.pointer_click(app.object_context.controls["recommend_room"].get_global_rect().get_center(),true);await process_frame
	check("room guidance is immediate while owner stays put",guest.room>0 and app.sim.data.rooms[str(guest.room)].guest=="guest_1" and app.sim.data.player.pos==old_owner and app.sim.data.booking_request.is_empty())
	app.object_context.refresh();await app.pointer_click(app.object_context.controls["@view:attic"].get_global_rect().get_center(),true)
	check("third-floor touch physically reaches the attic",await until(func():return app.sim.data.player.floor==3 and app.floor_journey==-1,50))
	app.object_context.refresh();await app.pointer_click(app.object_context.controls["@view:below"].get_global_rect().get_center(),true)
	check("basement touch completes the return journey",await until(func():return app.sim.data.player.floor==1 and app.floor_journey==-1,65))
	app.supplies.update();await process_frame
	await app.pointer_click(app.builder.launch.get_global_rect().get_center(),true);await process_frame
	check("build tray opens from a screen touch",app.builder.active)
	await app.pointer_click(app.builder.buttons["build:stash"].get_global_rect().get_center(),true);await process_frame
	var chosen=Vector2.ZERO;var found=false
	for x in range(0,28):
		for y in range(-13,5):
			var cell=Vector2i(x,y)
			if app.Sandbox.placement_error(app.sim,"stash",cell)!="":continue
			var screen=app.camera.unproject_position(app.world_point(Vector2(cell),1,.08))
			if screen.x>50 and screen.x<670 and screen.y>410 and screen.y<940:chosen=screen;found=true;break
		if found:break
	var count=app.sim.data.sandbox.facilities.size();cash=app.sim.data.money
	await app.pointer_click(chosen,true);await process_frame
	check("touching a valid floor installs one structure",found and app.sim.data.sandbox.facilities.size()==count+1 and app.sim.data.money==cash-4)
	await app.pointer_click(chosen,true);await process_frame
	check("a second touch cannot double-place or double-charge",app.sim.data.sandbox.facilities.size()==count+1 and app.sim.data.money==cash-4)
	app.builder.close();app.object_context.refresh();app.journal.refresh();app.mobile_scene.update();app.supplies.update()
	await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/mix-v184-touch-built.png")
	print("LIVE TOUCH ",checks.filter(func(v):return v).size(),"/",checks.size());app.free();await process_frame;await process_frame;quit(1 if checks.has(false) else 0)
