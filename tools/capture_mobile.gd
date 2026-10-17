extends SceneTree
var app
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1360)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.comfort.zoom=24;app.view_angle=0;seed(180)
	for i in 120:app.sim.tick(.2);app.Campaign.tick(app.sim)
	app.frame_owner();app.sync_view(0);app.object_context.refresh();app.journal.refresh()
	if app.has_method("show_inn"):app.show_inn()
	if "--candidate" in OS.get_cmdline_user_args():
		app.set_layer("surface");app.camera.size=24;app.camera_focus=Vector3(3,0,2);app.camera.position=app.camera_focus+Vector3(26,34,0);app.camera.look_at(app.camera_focus)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var prefix="candidate" if "--candidate" in OS.get_cmdline_user_args() else ("after" if "--after" in OS.get_cmdline_user_args() else "before")
	root.get_texture().get_image().save_png("res://docs/mobile-v180-"+prefix+".png")
	app.object_context.open("owner");
	if app.mobile_scene.host!=null:app.mobile_scene.update()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/mobile-v180-"+prefix+"-menu.png")
	app.object_context.close();
	if prefix=="after":
		app.show_inn();var waiting=app.sim.waiting()
		if not waiting.is_empty():app.activate_selection({"kind":"person","id":str(waiting[0])})
		app.mobile_scene.update();app.journal.refresh();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/mobile-v180-after-guest.png")
	app.object_context.close();app.request_floor(2);app.object_context.refresh();app.journal.refresh();app.mobile_scene.update()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/mobile-v180-"+prefix+"-cancel.png")
	quit()
