extends SceneTree
var app
var checks: Array=[]
func check(label_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false
	var s=app.sim
	check("new game follows owner on current floor",not app.overview and app.view_layer=="surface" and app.camera_offset==Vector2.ZERO)
	app.set_layer("below");app.camera_offset=Vector2(22,18);app.frame_owner()
	check("find owner clears remote offset and returns to correct floor",not app.overview and app.view_layer=="surface" and app.camera_offset==Vector2.ZERO and app.camera_focus.distance_to(app.world_point(s.data.player.pos,0))<.01)
	var before=app.camera_focus;app.pan_camera(Vector2(30,0));var expected=app.focus_position()+Vector3(app.camera_offset.x,0,app.camera_offset.y)
	check("manual pan freezes view without jumping to map center",app.overview and expected.distance_to(before)<4)
	var fixed=expected;s.data.player.pos+=Vector2(2,0)
	check("manual overview stays put while owner walks",(app.focus_position()+Vector3(app.camera_offset.x,0,app.camera_offset.y)).distance_to(fixed)<.01)
	s.data.player.pos=Vector2(-0.25,2.25)
	check("ground command resumes owner follow",app.Commands.move(app,Vector2(-2.25,2.25)) and not app.overview and app.camera_offset==Vector2.ZERO)
	app.Commands.cancel(app,true);app.frame_owner();app.sync_view(0)
	var pos=Vector2(-1.75,.25);var head=app.camera.unproject_position(app.world_point(pos,0,1.9));var foot=app.camera.unproject_position(app.world_point(pos,0,.05))
	var midpoint=head.lerp(foot,.5)
	check("precise body click remains selectable",not app.Selection.body(app,midpoint,pos,0,"person","guest_1").is_empty())
	check("empty ground beside person no longer has giant click halo",app.Selection.body(app,midpoint+Vector2(45,0),pos,0,"person","guest_1").is_empty())
	check("visible name remains clickable",not app.Selection.body(app,head,pos,0,"person","guest_1").is_empty())
	app.pointer.fingers[0]=midpoint
	check("touch keeps a modest forgiving body target",not app.Selection.body(app,midpoint+Vector2(25,0),pos,0,"person","guest_1").is_empty())
	app.pointer.reset()
	app.set_layer("below");app.object_context.refresh();await process_frame
	await app.pointer_click(app.object_context.owner_button.get_global_rect().get_center(),true)
	check("real touch on find owner returns from basement view",not app.overview and app.view_layer=="surface")
	check("find owner touch does not issue world movement",s.data.excavation.intent=="")
	s.data.player.floor=1;s.data.player.pos=Vector2.ZERO;app.frame_owner()
	check("basement follow uses basement world coordinates",app.view_layer=="below" and app.camera_focus.distance_to(app.world_point(Vector2.ZERO,1))<.01)
	s.data.player.floor=2;s.data.player.pos=Vector2(1,-4);app.frame_owner()
	check("upstairs find owner picks upstairs layer",app.view_layer=="rooms" and app.camera_offset==Vector2.ZERO)
	check("owner beacon is distinctive and visible through occlusion",app.owner_beacon.no_depth_test and app.owner_beacon.text.contains("주인"))
	print("MOVEMENT CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size());quit(0 if checks.all(func(x):return x) else 1)
