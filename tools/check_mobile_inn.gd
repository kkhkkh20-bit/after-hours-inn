extends SceneTree
var app
var checks: Array=[]
func check(label_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1360);app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	var s=app.sim
	check("new game starts in stable inn overview",app.inn_view and app.overview and app.view_layer=="surface")
	var focus=app.camera_focus;s.data.player.pos+=Vector2(2,0);app.sync_view(0)
	check("inn overview does not chase owner while operating",app.camera_focus==focus)
	app.mobile_scene.update();app.object_context.refresh();app.journal.refresh();await process_frame
	check("all important zones have touch controls",app.mobile_scene.pins.size()==4 and app.mobile_scene.root.visible)
	var size=root.get_visible_rect().size
	check("gate and front door project inside portrait viewport",Rect2(Vector2(0,320),size-Vector2(0,320)).has_point(app.camera.unproject_position(app.world_point(Vector2(23.2,3),0))) and Rect2(Vector2(0,320),size-Vector2(0,320)).has_point(app.camera.unproject_position(app.world_point(app.sim.Layout.FRONT,0))))
	var separated=true;var buttons=app.mobile_scene.pins.values()
	for i in buttons.size():
		for j in range(i+1,buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):separated=false
	check("zone targets do not overlap",separated)
	check("mobile cancel control is always present",app.object_context.cancel_button.visible and app.object_context.cancel_button.disabled)
	s.data.player.pos=Vector2(-.25,2.25);app.request_floor(2);app.object_context.refresh();await process_frame
	check("cancel becomes available during physical floor travel",not app.object_context.cancel_button.disabled)
	await app.pointer_click(app.object_context.cancel_button.get_global_rect().get_center(),true)
	check("one touch cancels floor travel with no right click",app.floor_journey==-1 and s.data.excavation.intent=="")
	app.show_inn();s.data.player.pos=Vector2(-.25,2.25);app.Commands.move(app,Vector2(-2.25,2.25))
	check("ground movement keeps managerial overview",app.inn_view and app.overview)
	app.cancel_everything();app.show_inn();app.object_context.refresh();app.mobile_scene.update()
	var p: Dictionary=s.data.people.guest_1;p.state="waiting";p.visit="stay";p.role="";p.path=[];p.pos=Vector2(-1.75,.25);p.known=false;p.rival=""
	for id in s.data.people:
		if id!="guest_1":s.data.people[id].state="gone"
	app.mobile_scene.update();await process_frame
	await app.pointer_click(app.mobile_scene.pins.reception.get_global_rect().get_center(),true)
	check("one reception touch opens guest request",app.object_context.kind=="conversation" and app.object_context.target=="guest_1" and p.known)
	check("ordinary service menu prioritizes room instead of prison",app.object_context.controls.has("recommend_room") and not app.object_context.controls.has("imprison"))
	app.mobile_scene.update();check("map badges hide behind conversation",not app.mobile_scene.root.visible)
	await process_frame;await process_frame
	await app.pointer_click(app.object_context.controls.recommend_room.get_global_rect().get_center(),true)
	check("second touch reserves recommended room",s.data.rooms.values().any(func(r):return r.get("reserved","")=="guest_1"))
	app.object_context.close();app.show_inn();app.mobile_scene.update();app.journal.refresh()
	check("operating objective shows rooms and demand",app.journal.goal.text.contains("객실") and app.journal.goal.text.contains("숙박 문의"))
	check("hidden person labels do not keep invisible name hit areas",app.Selection.body(app,app.camera.unproject_position(app.world_point(p.pos,0,1.9))+Vector2(45,0),p.pos,0,"person","guest_1").is_empty())
	app.frame_owner();app.mobile_scene.update();check("owner follow is still available by explicit choice",not app.inn_view and not app.overview)
	app.request_floor(0);check("ground floor control returns to inn overview",app.inn_view)
	check("touch controls stay separated from status text",not app.object_context.cancel_button.get_global_rect().intersects(app.journal.goal.get_global_rect()))
	print("MOBILE INN CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size());quit(0 if checks.all(func(x):return x) else 1)
