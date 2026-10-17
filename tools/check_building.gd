extends SceneTree
var app
var checks=[]
func check(name_: String,ok: bool) -> void:checks.append(ok);print("PASS " if ok else "FAIL ",name_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1360);app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false
	var s=app.sim;var owner=s.data.player.pos;var floor_=s.data.player.floor
	app.builder.choose("build:furnace")
	check("construction pauses and frames a close basement",s.data.paused and app.view_layer=="below" and app.camera.size==21)
	check("construction does not move the owner",s.data.player.pos==owner and s.data.player.floor==floor_)
	var target=Vector2i.ZERO;var found=false
	for x in range(5,24):
		for y in range(-12,3):
			var c=Vector2i(x,y)
			if app.Sandbox.placement_error(s,"furnace",c)!="":continue
			var screen=app.camera.unproject_position(app.world_point(Vector2(c),1,.08))
			if screen.y>410 and screen.y<950 and screen.x>40 and screen.x<680:target=c;found=true;break
		if found:break
	check("a valid facility fits the visible work area",found)
	var at=app.camera.unproject_position(app.world_point(Vector2(target),1,.08));app.builder.preview(at)
	check("preview snaps to the intended cell",app.builder.cell==target and app.builder.error=="" and is_instance_valid(app.builder.ghost))
	var cash=s.data.money;var count=s.data.sandbox.facilities.size()
	await app.pointer_click(at,true);await process_frame
	check("one touch installs once and charges once",s.data.sandbox.facilities.size()==count+1 and s.data.money==cash-10)
	check("one placement ends with no duplicate cursor",not app.builder.active and app.dig_mode=="" and app.builder.ghost==null)
	await app.pointer_click(at,true);await process_frame
	check("overlap cannot duplicate or charge",s.data.sandbox.facilities.size()==count+1 and s.data.money==cash-10)
	app.builder.choose("dig")
	var dig=Vector2i.ZERO
	for x in range(-25,45):
		for y in range(-15,20):
			var c=Vector2i(x,y)
			if not s.data.cells.has(s.cell_key(c)) and s.data.cells.has(s.cell_key(c+Vector2i.LEFT)):dig=c;break
		if dig!=Vector2i.ZERO:break
	var cells=s.data.cells.size();cash=s.data.money
	check("one pickaxe tap opens exactly one free cell",app.Sandbox.dig_cell(s,dig) and s.data.cells.size()==cells+1 and s.data.money==cash)
	check("disconnected excavation is rejected",not app.Sandbox.dig_cell(s,Vector2i(60,35)))
	check("palette blocks world clicks",app.mobile_ui.blocks_point(Vector2(360,1200)))
	var pos=app.camera_focus;app.builder.close()
	check("done resumes and preserves camera position",not s.data.paused and not app.builder.active and app.camera_focus==pos)
	app.builder.open();app.cancel_everything()
	check("global cancel clears ghost and construction mode",not app.builder.active and app.dig_mode=="")
	var backend=app.builder.backend
	check("actual Kenney builder is inherited",backend.get_script().get_base_script().resource_path=="res://third_party/kenney_city_builder/builder.gd")
	check("actual Kenney view rig is inherited",app.template_camera.get_script().get_base_script().resource_path=="res://third_party/kenney_city_builder/view.gd")
	app.builder.choose("build:stash");var candidate=Vector2i.ZERO
	for x in range(5,24):
		for y in range(-12,3):
			var c=Vector2i(x,y)
			if app.Sandbox.placement_error(s,"stash",c)=="":candidate=c;break
		if candidate!=Vector2i.ZERO:break
	backend.quarter=1;cash=s.data.money
	check("template placement deducts the selected resource price",backend.stamp("stash",candidate) and s.data.money==cash-4)
	check("rotation survives in the inn save model",int(s.data.sandbox.facilities.back().rotation)==1)
	check("template GridMap records placed structures",backend.gridmap.get_cell_item(Vector3i(candidate.x,0,candidate.y))==2)
	check("template removal refunds once",backend.remove(candidate) and s.data.money==cash-2)
	check("repeated removal cannot refund twice",not backend.remove(candidate) and s.data.money==cash-2)
	var prison=s.data.sandbox.facilities.filter(func(f):return f.type=="prison")[0];prison.members=["test"]
	check("occupied prison cannot be demolished",not backend.remove(Vector2i(prison.pos)))
	prison.members=[];app.builder.close();app.template_camera.capture();var start=app.camera.global_position
	app.camera_offset+=Vector2(4,0);app.template_camera.drive(.016)
	check("template camera smoothly moves toward pan target",app.camera.global_position!=start and app.template_camera.position.distance_to(app.template_camera.camera_position)>0.1)
	app.builder.open();app.builder.toggle_camera_pan();app.pointer.pressed=true;app.pointer.dragged=true;start=app.camera.global_position
	app.pan_camera(Vector2(70,0));app._physics_process(.016)
	check("explicit camera mode pans before finger release",app.camera.global_position!=start)
	app.pointer.reset();app.builder.close()
	print("BUILDING ",checks.filter(func(v):return v).size(),"/",checks.size())
	quit(0 if not checks.has(false) else 1)
