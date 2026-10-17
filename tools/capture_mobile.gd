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
	var tag="v180"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):tag=arg.trim_prefix("--tag=")
	var prefix="candidate" if "--candidate" in OS.get_cmdline_user_args() else ("after" if "--after" in OS.get_cmdline_user_args() else "before")
	root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-"+prefix+".png")
	app.object_context.open("owner");
	if app.mobile_scene.host!=null:app.mobile_scene.update()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-"+prefix+"-menu.png")
	app.object_context.close();
	if prefix=="after":
		app.show_inn();var waiting=app.sim.waiting()
		if not waiting.is_empty():app.activate_selection({"kind":"person","id":str(waiting[0])})
		app.mobile_scene.update();app.journal.refresh();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-after-guest.png")
	app.object_context.close();app.request_floor(2);app.object_context.refresh();app.journal.refresh();app.mobile_scene.update()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-"+prefix+"-cancel.png")
	if prefix=="after" and tag=="v181":
		for floor_ in [2,3]:
			app.object_context.close();app.cancel_everything();app.sim.data.player.floor=floor_;app.sim.data.player.pos=Vector2(8,-4.25);app.show_upper(floor_);app.camera.size=24;app.sync_view(0);app.journal.refresh();app.object_context.refresh();app.mobile_scene.update()
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/mobile-v181-after-floor%d.png" %floor_)
	if tag in ["v182","v183"]:
		app.object_context.close();app.cancel_everything();app.sim.data.player.floor=1;app.sim.data.player.pos=Vector2(16,-5);app.displayed_floor=1
		app.set_dig_mode("build:furnace");app.sync_view(0);app.journal.refresh();app.object_context.refresh();app.mobile_scene.update()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-"+prefix+"-build.png")
		if prefix=="after":
			var chosen=Vector2.ZERO;var best=INF
			for x in range(5,26):
				for y in range(-12,4):
					var c=Vector2i(x,y)
					if app.Sandbox.placement_error(app.sim,"furnace",c)!="":continue
					var screen=app.camera.unproject_position(app.world_point(Vector2(c),1,.08))
					if screen.x<80 or screen.x>640 or screen.y<450 or screen.y>930:continue
					var distance=screen.distance_to(Vector2(350,720))
					if distance<best:best=distance;chosen=screen
			if tag=="v183":app.builder.backend.quarter=1;app.builder.ghost_key=""
			app.builder.preview(chosen);app.mobile_scene.update()
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-after-preview.png")
			await app.pointer_click(chosen,true);app.sync_view(0);app.mobile_scene.update();app.builder.close();app.mobile_scene.update();app.object_context.refresh();app.journal.refresh()
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/mobile-"+tag+"-after-placed.png")
	quit()
