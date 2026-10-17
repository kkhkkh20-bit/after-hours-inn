extends SceneTree
var app
var checks: Array=[]
func check(label_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func settle(seconds: float=30) -> void:
	for i in int(seconds*10):
		app.sim.tick(.1);app.advance_floor_journey()
	app.displayed_floor=app.sim.data.player.floor;app.frame_owner();app.sync_view(0)
	await process_frame
func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	var s=app.sim
	for p in s.data.people.values():p.state="gone"
	app.object_context.refresh();await process_frame
	await app.pointer_click(app.object_context.controls["@view:rooms"].get_global_rect().get_center(),true)
	check("upstairs button starts physical stair route",app.floor_journey==2 and s.data.player.floor==0 and s.data.excavation.intent=="gallery_up")
	await settle()
	check("upstairs route arrives and follows owner",s.data.player.floor==2 and app.floor_journey==-1 and app.view_layer=="rooms" and not app.overview)
	var stair=app.camera.unproject_position(app.world_point(Vector2(8,1),2,.2))
	check("upstairs stair slope is a down target",app.transit_at(stair).get("floor",-1)==0)
	await app.pointer_click(stair,true)
	check("single upstairs stair tap starts descent",app.floor_journey==0 and s.data.excavation.intent=="gallery_down" and not app.object_context.panel.visible)
	await settle()
	check("descent returns to ground",s.data.player.floor==0 and app.floor_journey==-1)
	var entry=s.data.sandbox.entrances[0]
	app.request_floor(1,entry.id);await settle(40)
	check("exact entrance takes owner to basement",s.data.player.floor==1 and s.data.player.pos.distance_to(Vector2(entry.bottom))<.1)
	var ladder=app.camera.unproject_position(app.world_point(Vector2(entry.bottom),1,1.2))
	check("ladder body above foot is clickable",app.transit_at(ladder).get("entry","")==entry.id and app.transit_at(ladder).floor==0)
	await app.pointer_click(ladder,true)
	check("single ladder body tap queues ascent without menu",app.floor_journey==0 and s.data.excavation.intent=="sandbox:portal" and not app.object_context.panel.visible)
	await settle(40)
	check("ladder ascent completes through chosen entrance",s.data.player.floor==0 and s.data.player.pos.distance_to(entry.top)<.1)
	app.request_floor(1);await settle(40);app.request_floor(2)
	check("basement to upstairs begins with ground transfer",s.data.excavation.intent=="sandbox:portal" and app.floor_journey==2)
	await settle(60)
	check("basement to upstairs chains both legs",s.data.player.floor==2 and app.floor_journey==-1)
	app.request_floor(1);await settle(60)
	check("upstairs to basement chains both legs",s.data.player.floor==1 and app.floor_journey==-1)
	app.request_floor(2);app.Commands.cancel(app,true);await settle(2)
	check("stop cancels multi-floor journey",app.floor_journey==-1 and s.data.excavation.intent=="")
	app.request_floor(2);app.Commands.move(app,Vector2(entry.bottom));check("new ground command cancels floor destination",app.floor_journey==-1)
	app.Commands.cancel(app,true);s.data.paused=true;app.request_floor(0)
	check("paused travel does not silently unpause",s.data.paused and app.floor_journey==-1)
	print("FLOOR TRAVEL CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size());quit(0 if checks.all(func(x):return x) else 1)
