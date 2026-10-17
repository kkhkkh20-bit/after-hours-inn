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
	check("selection stays active for repeat placement",app.builder.active and app.dig_mode=="build:furnace")
	await app.pointer_click(at,true);await process_frame
	check("overlap cannot duplicate or charge",s.data.sandbox.facilities.size()==count+1 and s.data.money==cash-10)
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
	print("BUILDING ",checks.filter(func(v):return v).size(),"/",checks.size())
	quit(0 if not checks.has(false) else 1)
