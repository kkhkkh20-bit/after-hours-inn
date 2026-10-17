extends Node3D
const Sandbox=preload("res://scripts/inn_sandbox.gd")
var smoke_visual: Node3D
var sandbox_visual: Node3D
var sandbox_revision=-1
var build_point=Vector2.ZERO
var build_cell=Vector2i.ZERO
var entrance_placing=false
var last_ground_tap=Vector2(999,999)
var last_ground_time=0
const Campaign=preload("res://scripts/inn_campaign.gd")
const Dialogue=preload("res://scripts/inn_dialogue.gd")
var journal
var dialogue_paused=false
var dialogue_previous_pause=false
var buried_hint: Label3D
var cargo_visual: MeshInstance3D
var ambience: AudioStreamPlayer
var room_chime: AudioStreamPlayer
var last_cash=24
const Simulation = preload("res://scripts/simulation.gd")
var sim = Simulation.new()
var pressed_person=""
var pressed_owner=false
var pending_context_action: Dictionary={}
var mobile_ui
var touch_origin:=Vector2.ZERO
var touch_dragged:=false
var touch_blocked:=false
var mouse_blocked:=false
var mouse_origin:=Vector2.ZERO
var mouse_dragged:=false
var camera_offset:=Vector2.ZERO
var camera: Camera3D
var surface: Node3D
var basement: Node3D
var gallery: Node3D
var gallery_deck: Node3D
var terrain: Node3D
var world_root: Node3D
var actors_root: Node3D
var player: CharacterBody3D
var staff_visual: CharacterBody3D
var collector_visual: CharacterBody3D
var actors: Dictionary = {}
var carried_visuals: Dictionary = {}
var labels: Dictionary = {}
var ui_font: Font
var models_loaded := 0
var furniture_bounds: Array[AABB] = []
var last_cell_count := -1
var dig_cursor: MeshInstance3D
var hover_cell := Vector2i(99,99)
var capturing := false
var camera_focus := Vector3.ZERO
var earth_edges: Dictionary = {}
var earth_faces: Array = []
var viewed_floor := 0
var surface_zoom := 26.0
var basement_zoom := 14.0
var overview := true
var view_layer := "all"
const CAMERA_ARM := Vector3(3,12,32)
const CELLAR_OFFSET := Vector3(-3.25,-4.2,2.75)
var cellar_lamp: OmniLight3D
var light_spill: OmniLight3D
var noise_visual: MeshInstance3D
var pointer_position := Vector2.ZERO
var hatch_lid: Node3D
var tool_pivot: Node3D
var pick_head: MeshInstance3D
var shovel_head: MeshInstance3D
var inspector_visual: CharacterBody3D
var holding_visual: Node3D
var holding_position:=Vector2(99,99)
var staff_marker: Label3D
var vision_mesh: MeshInstance3D
var show_vision := false
var muted := false
var sound_clock := 0.0
var last_warning := 0
var knock: AudioStreamPlayer
var alert_sound: AudioStreamPlayer
var step_sound: AudioStreamPlayer3D
var vision_clock := 0.0

var episode=preload("res://scripts/episode.gd").new()
var episode_ui
var object_context
var context_soil=Vector2i.ZERO
var auto_floor_goal: Dictionary={}
var pending_chat=""
var touch_points: Dictionary={}
var pinch_span=0.0
var displayed_floor=-1
var apron: Node3D
var travel_marker: MeshInstance3D

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat

func box(size: Vector3, pos: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	world_root.add_child(mesh)
	mesh.position = pos
	if solid and world_root == surface and size.y > 0.4 and pos.y > 0.2:
		sim.add_obstacle(Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)))
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		col.shape = volume
		body.add_child(col)
		mesh.add_child(body)
	return mesh

func bounds_of(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var local_box: AABB = (root.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		if first:
			result = local_box
			first = false
		else:
			result = result.merge(local_box)
	return result

func model(group: String, name_: String, pos: Vector3, size: Vector3, angle := 0.0, solid := false) -> Node3D:
	var path := "res://assets/%s/%s.glb" % [group, name_]
	var scene := load(path) as PackedScene
	assert(scene != null, "Missing asset: " + path)
	var pivot := Node3D.new()
	world_root.add_child(pivot)
	var imported := scene.instantiate() as Node3D
	pivot.add_child(imported)
	for item in imported.find_children("*", "MeshInstance3D", true, false):
		var surface_mesh := item as MeshInstance3D
		for surface in range(surface_mesh.mesh.get_surface_count()):
			var original := surface_mesh.get_active_material(surface) as StandardMaterial3D
			if original != null:
				var muted := original.duplicate() as StandardMaterial3D
				muted.albedo_color *= Color(0.74, 0.72, 0.67)
				muted.roughness = 1.0
				if name_ == "tree":
					muted.albedo_color *= Color(0.65, 0.74, 0.72)
				surface_mesh.set_surface_override_material(surface, muted)
	var bounds := bounds_of(imported)
	assert(bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0)
	imported.scale = size / bounds.size
	imported.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * imported.scale
	pivot.position = pos
	pivot.rotation.y = angle
	models_loaded += 1
	if solid:
		if world_root == surface:
			var extent := Vector2(size.x,size.z) if absf(sin(angle)) < 0.5 else Vector2(size.z,size.x)
			sim.add_obstacle(Rect2(Vector2(pos.x,pos.z)-extent/2,extent))
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position.y = size.y / 2
		body.add_child(collision)
		pivot.add_child(body)
		furniture_bounds.append(AABB(pos - Vector3(size.x / 2, 0, size.z / 2), size))
	return pivot

func actor(pos: Vector3, color: Color) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	actors_root.add_child(body)
	body.position = pos
	body.collision_layer = 0
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = 0.78
	body.add_child(collision)
	var coat := MeshInstance3D.new()
	var torso := CylinderMesh.new()
	torso.top_radius = 0.22
	torso.bottom_radius = 0.30
	torso.height = 0.8
	torso.radial_segments = 6
	coat.mesh = torso
	coat.material_override = material(color)
	coat.position.y = 0.85
	body.add_child(coat)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius=0.17
	head_mesh.height=0.35
	head_mesh.radial_segments=8
	head_mesh.rings=4
	head.mesh = head_mesh
	head.material_override = material(Color("b6a28b"))
	head.position.y = 1.4
	body.add_child(head)
	var hair:=MeshInstance3D.new()
	var cap:=SphereMesh.new();cap.radius=0.18;cap.height=0.22;cap.radial_segments=8;cap.rings=3
	hair.mesh=cap;hair.material_override=material(Color("44392e"));hair.position.y=1.52;body.add_child(hair)
	for side in [-1,1]:
		var arm:=MeshInstance3D.new()
		var sleeve:=CylinderMesh.new();sleeve.top_radius=0.065;sleeve.bottom_radius=0.07;sleeve.height=0.6;sleeve.radial_segments=6
		arm.name="LeftArm" if side<0 else "RightArm";arm.mesh=sleeve;arm.material_override=material(color.darkened(0.12));arm.position=Vector3(side*0.28,0.93,0);arm.rotation.z=side*0.17;body.add_child(arm)
	for x in [-0.13, 0.13]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.15, 0.48, 0.18)
		leg.mesh = leg_mesh
		leg.material_override = material(Color("302e30"))
		leg.name = "LeftLeg" if x < 0 else "RightLeg"
		leg.position = Vector3(x, 0.24, 0)
		body.add_child(leg)
	return body

func light_at(pos: Vector3, energy: float) -> void:
	var light := OmniLight3D.new()
	world_root.add_child(light)
	light.position = pos
	light.light_color = Color("ffca85")
	light.light_energy = energy
	light.omni_range = 4.5
	light.shadow_enabled = false

func build_surface() -> void:
	preload("res://scripts/inn_architecture.gd").build(self)

func _ready() -> void:
	sim.travel_multiplier=1.7
	ui_font = load("res://assets/fonts/InnKorean.otf")
	surface = Node3D.new()
	add_child(surface)
	basement = Node3D.new()
	add_child(basement)
	basement.position=CELLAR_OFFSET
	terrain = Node3D.new()
	basement.add_child(terrain)
	actors_root = Node3D.new()
	add_child(actors_root)
	world_root = surface
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111d29")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da0b5")
	environment.ambient_light_energy = 0.48
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_color = Color("a3b7ce")
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	build_surface()
	build_backdrop()
	build_gallery()
	box(Vector3(1,0.03,1),Vector3(-3.25,0.09,2.75),Color("243632"))
	world_label("지하 입구 · 탭",Vector3(-3.25,0.4,2.75),surface)
	build_excavation_visuals()
	sim.rebuild_grid()
	player = actor(Vector3.ZERO,Color("8f7147"))
	attach_tools()
	staff_visual = actor(Vector3.ZERO,Color("4a7771"))
	collector_visual = actor(Vector3.ZERO,Color("6d3b47"))
	inspector_visual=actor(Vector3.ZERO,Color("933e32"))
	world_label("국경 경비",Vector3(0,1.95,0),inspector_visual)
	carried_visuals["player"] = make_tray(player)
	carried_visuals["staff"] = make_tray(staff_visual)
	world_label("주인",Vector3(0,1.95,0),player)
	staff_marker=world_label("직원",Vector3(0,1.95,0),staff_visual)
	setup_stealth_effects()
	noise_visual=MeshInstance3D.new()
	add_child(noise_visual)
	world_label("징수원",Vector3(0,1.95,0),collector_visual)
	world_root = basement
	cellar_lamp=OmniLight3D.new()
	basement.add_child(cellar_lamp)
	cellar_lamp.position=Vector3(-0.35,1.6,-1)
	cellar_lamp.light_color=Color("ffbb6b")
	cellar_lamp.light_energy=2.0
	cellar_lamp.omni_range=5
	cellar_lamp.shadow_enabled=true
	light_spill=OmniLight3D.new()
	surface.add_child(light_spill)
	light_spill.position=Vector3(Simulation.HATCH.x,0.6,Simulation.HATCH.y)
	light_spill.light_color=Color("e6a15a")
	light_spill.omni_range=2.7
	light_spill.light_energy=0.9
	world_label("위층 입구",Vector3(0,1.9,0),basement)
	for x in [-0.35,0.35]:box(Vector3(0.07,4.2,0.07),Vector3(x,2.1,-0.2),Color("8d754e"))
	for y in [0.25,0.65,1.05,1.45,1.85,2.25,2.65,3.05,3.45,3.85]:box(Vector3(0.7,0.07,0.07),Vector3(0,y,-0.2),Color("b09972"))
	world_root = surface
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = surface_zoom
	camera.keep_aspect=Camera3D.KEEP_WIDTH
	camera.position = CAMERA_ARM
	camera.look_at(Vector3.ZERO)
	camera.current = true
	travel_marker=MeshInstance3D.new(); var marker_mesh=CylinderMesh.new(); marker_mesh.top_radius=0.34; marker_mesh.bottom_radius=0.34; marker_mesh.height=0.025; marker_mesh.radial_segments=24
	travel_marker.mesh=marker_mesh; travel_marker.material_override=material(Color("c4bf7a")); add_child(travel_marker); travel_marker.hide()
	make_ui()
	set_layer("all")
	episode_ui=preload("res://scripts/episode_ui.gd").new()
	add_child(episode_ui); episode_ui.setup(self,episode)
	var args := OS.get_cmdline_user_args()
	journal=preload("res://scripts/inn_journal.gd").new();add_child(journal);journal.setup(self)
	if args.is_empty():start_campaign()
	if "--capture-sandbox" in args:
		await capture_sandbox();return
	if "--demo-verify" in args:
		set_physics_process(false);get_tree().quit(preload("res://scripts/demo_tests.gd").new().run(sim.obstacles));return
	if "--demo-playthrough" in args or "--demo-shadow" in args or "--capture-demo-ending" in args:
		await demo_playthrough();return
	if "--capture-demo" in args or "--capture-demo-talk" in args or "--capture-demo-intro" in args:
		await capture_demo("--capture-demo-talk" in args);return
	if "--capture-context" in args or "--capture-context-clean" in args or "--capture-actions" in args or "--capture-cycle" in args:
		await capture_context("--capture-context" in args); return
	if "--capture-episode" in args or "--capture-episode-cellar" in args:
		await capture_episode("--capture-episode-cellar" in args)
		return
	if "--episode-playthrough" in args or "--capture-ending" in args:
		var failed=await verify_episode_playthrough("--capture-ending" in args)
		get_tree().quit(failed); return
	if "--episode-verify" in args:
		get_tree().quit(preload("res://scripts/episode_tests.gd").new().run()); return
	if "--verify" in args:
		set_physics_process(false)
		var result: int = preload("res://scripts/tests.gd").run(sim.obstacles)
		get_tree().quit(result)
	elif "--input-verify" in args:
		await input_verify()
	elif "--capture-overview" in args or "--capture-cellar-wide" in args or "--capture-dark" in args:
		capturing=true
		sim.data.player.pos=Simulation.COUNTER
		sim.assign_room(1)
		sim.toggle_staff()
		Simulation.Intrigue.report(sim,"시안의 방문 신고")
		sim.tick(18)
		sim.data.player.pos=Simulation.HATCH
		sim.change_floor()
		sim.queue_dig(Vector2i(2,0))
		sim.tick(1.7)
		if "--capture-dark" in args:
			sim.data.excavation.lamp_on=false
			sim.data.excavation.hatch_open=false
		set_layer("below" if "--capture-cellar-wide" in args or "--capture-dark" in args else "all")
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/v09-dark.png" if "--capture-dark" in args else ("res://docs/v09-cellar.png" if "--capture-cellar-wide" in args else "res://docs/v09-overview.png"))
		get_tree().quit()
	elif "--capture-gallery" in args:
		capturing=true
		sim.data.player.pos=Simulation.COUNTER
		sim.assign_room(1)
		sim.toggle_staff()
		sim.queue_gallery()
		sim.tick(18)
		sim.queue_move(Vector2(3.25,-4.25))
		sim.tick(5)
		sync_view(0)
		frame_owner()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/v08-gallery.png")
		get_tree().quit()
	elif "--capture-excavation" in args:
		capturing=true
		sim.queue_floor()
		sim.tick(4)
		sim.queue_dig(Vector2i(2,0))
		sim.tick(2)
		sync_view(0)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/v08-excavation.png")
		get_tree().quit()
	elif "--capture-service" in args or "--capture" in args or "--capture-basement" in args or "--capture-stealth" in args or "--capture-operation" in args or "--capture-prison" in args:
		capturing = true
		sim.data.player.pos = Simulation.COUNTER
		sim.assign_room(1)
		sim.toggle_staff()
		sim.tick(24)
		if "--capture" in args or "--capture-service" in args:
			sim.queue_move(Vector2(0.25,1.75))
			sim.tick(3)
			frame_owner()
		if "--capture-service" in args:mobile_ui.open_sheet("영업")
		if "--capture-basement" in args:
			sim.data.player.pos = Simulation.HATCH
			sim.change_floor()
			sim.data.player.pos = Vector2(1,0)
			sim.start_dig(Vector2i(2,0))
			sim.tick(1.5)
		if "--capture-stealth" in args:
			sim.data.player.pos=Simulation.HATCH
			sim.change_floor()
			sim.data.player.pos=Vector2(1,0)
			sim.start_dig(Vector2i(2,0))
			sim.tick(4.1)
			sim.data.player.pos=Vector2(2,0)
			sim.start_dig(Vector2i(3,0))
			sim.tick(1.5)
		if "--capture-operation" in args or "--capture-prison" in args:
			# Stage using the same commands/state transitions as gameplay.
			sim.data.player.pos=Simulation.HATCH
			sim.change_floor()
			sim.data.player.pos=Vector2(1,0)
			sim.start_dig(Vector2i(2,0))
			sim.tick(4.1)
			sim.data.player.pos=Vector2(2,0)
			Simulation.Intrigue.build_or_hold(sim)
			sim.data.player.pos=Vector2.ZERO
			sim.change_floor()
			sim.data.player.pos=Simulation.COUNTER
			sim.data.ops.selected="guest_1"
			Simulation.Intrigue.contract_action(sim)
			sim.data.player.pos=sim.data.people.guest_1.pos
			Simulation.Intrigue.subdue(sim)
			sim.tick(2.1)
			Simulation.Intrigue.drag_or_release(sim)
			if "--capture-prison" in args:
				sim.data.player.pos=Simulation.HATCH
				sim.change_floor()
				sim.data.player.pos=Vector2(2,0)
				Simulation.Intrigue.sync_drag(sim)
				Simulation.Intrigue.build_or_hold(sim)
				sim.data.player.pos=Vector2(1,0)
				sim.tick(30.1)
		sync_view(0)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := "res://docs/v04-stealth.png" if "--capture-stealth" in args else ("res://docs/v04-basement.png" if "--capture-basement" in args else "res://docs/v08-surface.png")
		if "--capture-service" in args:output="res://docs/v07-service.png"
		if "--capture-operation" in args:output="res://docs/v05-operation.png"
		if "--capture-prison" in args:output="res://docs/v05-prison.png"
		get_viewport().get_texture().get_image().save_png(output)
		get_tree().quit()

func make_tray(owner_: Node3D) -> Node3D:
	var tray := box(Vector3(0.38,0.08,0.28),Vector3.ZERO,Color("cfa56e"))
	tray.reparent(owner_)
	tray.position=Vector3(0,0.95,-0.4)
	return tray

func world_label(text_: String, pos: Vector3, owner_: Node3D) -> Label3D:
	var label := Label3D.new()
	label.text=text_
	label.font=ui_font
	label.font_size=44
	label.pixel_size=0.007
	label.outline_size=8
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	owner_.add_child(label)
	label.position=pos
	return label

func make_ui() -> void:
	mobile_ui=preload("res://scripts/mobile_ui.gd").new()
	add_child(mobile_ui)
	mobile_ui.setup(self)
	object_context=preload("res://scripts/object_context.gd").new(); add_child(object_context); object_context.setup(self)

func room_text(number: int) -> String:
	var room_: Dictionary=sim.data.rooms[str(number)]
	if room_.guest!="":return "%d호  %s" % [number,sim.data.people[room_.guest].name]
	return "%d호  청소 필요" % number if room_.dirty else "%d호  빈방" % number

func when_text(value: float) -> String:
	var minute:=int(value)
	return "%d일 %02d:%02d" % [minute/1440+1,(minute%1440)/60,minute%60]

func refresh_ui() -> void:
	mobile_ui.refresh()
	if object_context!=null: object_context.refresh()

func sync_actor(visual: Node3D, pos: Vector2, dt: float, floor_: int=0) -> void:
	var before:=Vector2(visual.position.x,visual.position.z)
	var moving:=before.distance_to(pos)>0.001
	visual.position=world_point(pos,floor_,0.08)
	if moving and dt>0:
		var diff:=pos-before
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-diff.x,-diff.y),minf(1.0,dt*12.0))
	var swing:=sin(sim.data.clock*10)*0.40 if moving else 0.0
	visual.get_node("LeftLeg").rotation.x=swing
	visual.get_node("RightLeg").rotation.x=-swing
	if visual.has_node("LeftArm"):
		visual.get_node("LeftArm").rotation.x=-swing*0.65;visual.get_node("RightArm").rotation.x=swing*0.65

func sync_view(dt: float) -> void:
	var d: Dictionary=sim.data
	var surface_shown: bool=view_layer!="below"
	if apron!=null: apron.visible=view_layer=="surface"
	if travel_marker!=null:
		travel_marker.visible=not d.excavation.path.is_empty()
		if travel_marker.visible: travel_marker.position=world_point(d.excavation.path.back(),d.player.floor,0.05)
	var cellar_shown: bool=view_layer!="surface"
	viewed_floor=d.player.floor
	surface.visible=surface_shown
	gallery.visible=surface_shown
	gallery_deck.visible=true
	basement.visible=cellar_shown
	staff_visual.visible=surface_shown and d.staff.hired
	collector_visual.visible=surface_shown and d.collector
	sync_actor(player,d.player.pos,dt,d.player.floor)
	player.visible=cellar_shown if d.player.floor==1 else surface_shown
	sync_actor(staff_visual,d.staff.pos,dt,int(d.staff.get("floor",0)))
	staff_visual.rotation.y=atan2(-d.staff.facing.x,-d.staff.facing.y)
	collector_visual.position=Vector3(-0.2,0.08,-1.5)
	if cargo_visual==null:
		world_root=basement;cargo_visual=box(Vector3(0.8,0.6,0.65),Vector3(1,0.4,1),Color("76523a"));world_root=surface
	cargo_visual.visible=Campaign.active(sim) and d.campaign.get("cargo",false) and cellar_shown
	if buried_hint==null:buried_hint=world_label("낡은 자국",Vector3(2,1.1,0),basement)
	buried_hint.visible=not Sandbox.active(sim) and Campaign.active(sim) and cellar_shown and d.campaign.rumors.size()>0 and not d.campaign.ledger_found
	var inspection: Dictionary=d.ops.inspector
	inspector_visual.visible=inspection.state not in ["idle","scheduled"] and (cellar_shown if inspection.floor==1 else surface_shown)
	sync_actor(inspector_visual,inspection.pos,dt,inspection.floor)
	if d.ops.built and holding_position!=d.ops.cell:build_holding_visual()
	if holding_visual!=null:holding_visual.visible=d.ops.built and cellar_shown
	carried_visuals.player.visible=d.player.carry!=""
	carried_visuals.staff.visible=d.staff.carry!=""
	for id in actors.keys():
		if not d.people.has(id):
			actors[id].queue_free()
			actors.erase(id)
			labels.erase(id)
	for id in d.people:
		var person: Dictionary=d.people[id]
		if not actors.has(id):
			actors[id]=actor(Vector3.ZERO,Color("667f8c") if int(id.get_slice("_",1))%2 else Color("77534d"))
			labels[id]=world_label(person.name,Vector3(0,1.95,0),actors[id])
		actors[id].visible=(cellar_shown if person.floor==1 else surface_shown) and person.state!="gone"
		sync_actor(actors[id],person.pos,dt,person.floor)
		actors[id].rotation.z=PI/2 if person.state in ["down","dead"] else 0
		if person.state in ["down","dead"]:
			actors[id].position=world_point(person.pos,person.floor,0.35)
			actors[id].get_node("LeftLeg").rotation.x=0; actors[id].get_node("RightLeg").rotation.x=0
		if person.state=="restrained": actors[id].position=world_point(person.pos+Vector2(0.45,0.15),person.floor,0.08)
		# Labels remain upright even when the body is lying on its side.
		labels[id].global_rotation=Vector3.ZERO
		labels[id].global_position=world_point(person.pos,person.floor,0.95 if person.state in ["down","dead"] else 2.03)
		labels[id].text=str(person.name)
		if Sandbox.active(sim) and person.get("known",false) and person.get("faction","")!="":labels[id].text+=" · "+str(person.faction)
		if Sandbox.active(sim) and person.get("bubble_until",0)>d.clock:labels[id].text+="\n「"+str(person.get("bubble",""))+"」"
		labels[id].pixel_size=(0.014 if Sandbox.active(sim) else (0.0045 if person.floor==1 else 0.007))
		if Campaign.active(sim) and person.state in ["waiting","arriving","dining"]:
			labels[id].text+=" · 말 걸기" if not person.get("known",false) else (" · 식사" if person.get("visit","")=="meal" else "")
		elif person.state=="waiting":labels[id].text+=" · 대기"
		if person.state=="dead":labels[id].text+=" · 사망"
		if person.state=="restrained":labels[id].text+=" · 붙잡힘"
		if person.state=="captive":labels[id].text+=" · 구금"
		labels[id].modulate=Color("ffd394") if d.ops.selected==id else Color.WHITE
	if Sandbox.active(sim):sync_sandbox_smoke()
	if last_cell_count!=d.cells.size():rebuild_basement()
	if Sandbox.active(sim) and sandbox_revision!=int(d.sandbox.revision):preload("res://scripts/inn_sandbox_view.gd").build(self)
	staff_marker.text=("마라" if Campaign.active(sim) else "직원")+" · 확인 중" if d.stealth.phase!="idle" else ("직원 · 업무 거부" if d.clock<d.stealth.refuse_until else "직원")
	staff_marker.modulate=Color("ffb882") if d.stealth.suspicion>=10 else Color.WHITE
	if Sandbox.active(sim):staff_marker.text="마라 · 홀 맡는 중";staff_marker.pixel_size=0.014;hatch_lid.hide()
	vision_mesh.visible=surface_shown and d.staff.hired and show_vision
	vision_clock+=dt
	if vision_clock>=0.12 or dt==0:
		vision_clock=0
		refresh_vision()
	tool_pivot.visible=d.player.floor==1 and d.ops.drag==""
	tool_pivot.rotation.x=sin(d.clock*13)*0.85-0.3 if not d.dig.is_empty() else -0.2
	pick_head.visible=not d.stealth.quiet
	shovel_head.visible=d.stealth.quiet
	hatch_lid.rotation.x=-1.25 if d.excavation.hatch_open else 0
	cellar_lamp.visible=d.excavation.get("lamp_on",true)
	light_spill.visible=d.excavation.get("lamp_on",true) and d.excavation.hatch_open
	refresh_noise()
	refresh_ui()

func world_point(pos: Vector2, floor_: int, height: float=0.0) -> Vector3:
	return Vector3(pos.x,height+Simulation.floor_height(pos,floor_),pos.y)+((Sandbox.OFFSET if Sandbox.active(sim) else CELLAR_OFFSET) if floor_==1 else Vector3.ZERO)

func focus_position() -> Vector3:
	if overview and Sandbox.active(sim):return Vector3(5,-0.5,7) if view_layer=="all" else (Sandbox.OFFSET+Vector3(8,0,0) if view_layer=="below" else Vector3(5,1,0))
	if overview:return CELLAR_OFFSET+Vector3(4,0.7,1) if view_layer=="below" else (Vector3(0,-0.2,0.5) if view_layer=="all" else Vector3(0,1.3,-0.4))
	return world_point(sim.data.player.pos,sim.data.player.floor)

func set_layer(value: String) -> void:
	view_layer=value
	overview=true
	camera_offset=Vector2.ZERO
	camera.size=(39.5 if Sandbox.active(sim) else (22.8 if Campaign.active(sim) else 25.0)) if value!="below" else 24.0
	camera_focus=(Vector3(0,-0.2,0.5) if value=="all" else Vector3(0,1.3,-0.4)) if value!="below" else CELLAR_OFFSET+Vector3(4,0.7,1)
	camera_focus=focus_position()
	camera.position=camera_focus+CAMERA_ARM
	camera.look_at(camera_focus)
	sync_view(0)

func walking_hit(point: Vector2) -> Variant:
	var origin:=camera.project_ray_origin(point)
	var ray:=camera.project_ray_normal(point)
	if sim.data.player.floor==1:
		var hit: Variant=Plane(Vector3.UP,(Sandbox.OFFSET.y if Sandbox.active(sim) else CELLAR_OFFSET.y)+0.08).intersects_ray(origin,ray)
		return hit-(Sandbox.OFFSET if Sandbox.active(sim) else CELLAR_OFFSET) if hit!=null else null
	if sim.data.player.floor==0:return Plane(Vector3.UP,0.08).intersects_ray(origin,ray)
	var deck: Variant=Plane(Vector3.UP,3.28).intersects_ray(origin,ray)
	if deck!=null and Simulation.gallery_walkable(Vector2(deck.x,deck.z)) and deck.z<=1:return deck
	# y + .8z = 4.08 is the actual stair slope, not an upper-floor horizontal plane.
	var stairs: Variant=Plane(Vector3(0,1,0.8).normalized(),4.08/Vector3(0,1,0.8).length()).intersects_ray(origin,ray)
	if stairs!=null and stairs.x>=7 and stairs.x<9 and stairs.z>=1 and stairs.z<=5.2:return stairs
	return null

func build_gallery() -> void:
	gallery=Node3D.new()
	add_child(gallery)
	gallery_deck=Node3D.new()
	gallery.add_child(gallery_deck)
	world_root=gallery_deck
	var wood:=Color("67513b")
	# L-shaped gallery: a real void over the dining hall, not a full opaque second map.
	box(Vector3(18,0.18,2),Vector3(0,3.1,-4.5),wood)
	box(Vector3(2,0.18,4.5),Vector3(8,3.1,-1.25),wood)
	for x in range(-9,9):
		for z in [-5,-4]:model("town","planks",Vector3(x+0.5,3.2,z+0.5),Vector3(1,0.04,1))
	for z in range(-3,1):
		for x in [7,8]:model("town","planks",Vector3(x+0.5,3.2,z+0.5),Vector3(1,0.04,1))
	world_root=gallery
	box(Vector3(18,0.18,3),Vector3(0,3.1,-7),wood)
	for x in range(-9,9):
		for z in range(-8,-5):model("town","planks",Vector3(x+0.5,3.2,z+0.5),Vector3(1,0.04,1))
	box(Vector3(18.2,2.5,0.2),Vector3(0,4.45,-8.5),Color("9a8568"))
	for x in [-9,-3,3,9]:
		box(Vector3(0.16,2.7,0.25),Vector3(x,4.5,-8.5),Color("453327"))
		if x in [-3,3]:box(Vector3(0.13,1.25,2),Vector3(x,3.85,-7.5),Color("877355"))
	for x in [-6,0,6]:
		model("furniture","bedSingle",Vector3(x,3.24,-7.25),Vector3(1.3,0.8,2.1))
		model("furniture","rugRectangle",Vector3(x+1.6,3.24,-6.7),Vector3(1.2,0.02,1.8))
		model("town","lantern",Vector3(x+1.9,3.24,-8.1),Vector3(0.16,1.5,0.16))
		light_at(Vector3(x+1.9,4.7,-7.4),0.9)
		box(Vector3(0.8,1.25,0.09),Vector3(x,4.5,-8.36),Color("514134"))
	# A rear roof slope and exposed front rafters leave upstairs readable.
	var roof:=box(Vector3(19.2,0.15,1.0),Vector3(0,6.1,-8.5),Color("36434b"))
	roof.rotation.x=-0.28
	for x in [-9,-3,3,9]:
		var rafter:=box(Vector3(0.14,0.14,5.5),Vector3(x,6,-5.8),Color("4b3629"))
		rafter.rotation.x=0.19
	# Two long timber beams and slim rails keep the silhouette architectural.
	for z in [-5.5,-3.5]:
		box(Vector3(18.2,0.2,0.2),Vector3(0,3.0,z),Color("3b3026"))
	for x in [-9,-5,-1,3,7]:
		box(Vector3(0.16,3.1,0.16),Vector3(x,1.55,-3.5),Color("443526"))
		box(Vector3(0.09,1,0.09),Vector3(x,3.7,-3.5),Color("8c7150"))
	box(Vector3(16,0.09,0.09),Vector3(-1,4.17,-3.5),Color("94764f"))
	for z in [-3.5,-2,-0.5,1]:
		box(Vector3(0.09,1,0.09),Vector3(7,3.7,z),Color("8c7150"))
	box(Vector3(0.09,0.09,4.5),Vector3(7,4.17,-1.25),Color("94764f"))
	for i in range(16):
		var z:=4.875-i*0.25
		var y: float=(i+1)*0.2
		box(Vector3(1.9,0.12,0.26),Vector3(8,y-0.06,z),Color("806345"))
		for x in [7.05,8.95]:
			if i%4==0:box(Vector3(0.075,0.8,0.075),Vector3(x,y+0.35,z),Color("68513a"))
	for x in [7.05,8.95]:
		var rail:=box(Vector3(0.07,0.07,5.12),Vector3(x,2.3,3),Color("94764f"))
		rail.rotation.x=atan(0.8)
	for x in [-4,4]:
		model("town","lantern",Vector3(x,3.2,-5.2),Vector3(0.18,1.3,0.18))
		light_at(Vector3(x,4.5,-4.5),1.0)
	world_label("2층 계단 · 탭",Vector3(8,0.6,5.25),gallery)
	var label:=world_label("1층 홀",Vector3(-2,0.16,0),gallery)
	label.pixel_size=0.005
	world_root=surface

func earth_mesh(vertices: PackedVector3Array, colors: PackedColorArray) -> void:
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	var normals:=PackedVector3Array()
	for i in range(0,vertices.size(),3):
		var normal: Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
		for j in range(3):normals.append(normal)
	arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual:=MeshInstance3D.new()
	visual.mesh=mesh
	var mat:=material(Color.WHITE)
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled=true
	mat.emission=Color("5c4a35")
	mat.emission_energy_multiplier=0.22
	visual.material_override=mat
	terrain.add_child(visual)

func rebuild_basement() -> void:
	preload("res://scripts/cellar_terrain.gd").build(self)

func start_campaign() -> void:
	if DisplayServer.get_name()!="headless":
		if ambience==null:
			ambience=AudioStreamPlayer.new();ambience.stream=preload("res://assets/audio/inn-wind.wav");ambience.volume_db=-26;add_child(ambience)
			ambience.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;ambience.stream.loop_begin=0;ambience.stream.loop_end=128000
			room_chime=AudioStreamPlayer.new();room_chime.stream=preload("res://assets/audio/inn-chime.wav");room_chime.volume_db=-19;add_child(room_chime)
		ambience.play()
	Campaign.start(sim);basement.position=Sandbox.OFFSET;camera.keep_aspect=Camera3D.KEEP_WIDTH
	for child in basement.get_children():
		if child!=terrain and child!=cellar_lamp:child.hide()
	hatch_lid.hide();last_cell_count=-1;sandbox_revision=-1
	for child in surface.get_children():
		if child is Label3D and child.text.begins_with("지하 입구"):child.hide()
	world_root=surface
	box(Vector3(1.65,0.18,1.65),Vector3(Simulation.HATCH.x,-0.02,Simulation.HATCH.y),Color("604c36"))
	episode.data.briefed=true;episode_ui.root.hide();journal.open("intro");set_layer("all")

func context_opened(kind_: String) -> void:
	if Campaign.active(sim) and kind_ in ["conversation","guard_talk","staff_talk"] and not dialogue_paused:
		dialogue_previous_pause=sim.data.paused;dialogue_paused=true;sim.data.paused=true

func context_closed(_kind: String) -> void:
	if dialogue_paused:sim.data.paused=dialogue_previous_pause;dialogue_paused=false

func rest_until_dawn() -> void:
	if not Campaign.can_rest(sim):return
	while not sim.data.campaign.summary and sim.data.campaign.ending=="":
		sim.tick(0.5);Campaign.tick(sim)
	journal.refresh()

func save_game() -> void:
	var file:=FileAccess.open("user://inn-secret-v14.json" if Campaign.active(sim) else "user://inn-v03.json",FileAccess.WRITE)
	if file==null:
		sim.note("저장 파일을 만들 수 없다.")
		return
	sim.data.episode=episode.data.duplicate(true)
	file.store_string(JSON.stringify(sim.snapshot()))
	file.close()
	sim.note("저장했다. 진행 중인 주문과 작업도 함께 기록했다.")

func load_game() -> void:
	var save_path="user://inn-secret-v14.json" if Campaign.active(sim) else "user://inn-v03.json"
	if not FileAccess.file_exists(save_path):
		sim.note("저장된 기록이 없다. 메뉴에서 먼저 저장하자.")
		return
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not sim.restore(saved):
		sim.note("이 버전에서 읽을 수 없는 저장 파일이다.")
		return
	if sim.data.has("episode"):
		episode.data=sim.data.episode.duplicate(true)
		episode_ui.ending_shown=false
	if Campaign.active(sim):
		sim.data.paused=false;episode_ui.root.hide();journal.opened=false;journal.panel.hide();journal.refresh()
	last_cell_count=-1
	sim.note("저장한 상태로 돌아왔다.")
	sync_view(0)

func pan_camera(relative: Vector2) -> void:
	var scale_: float=camera.size/get_viewport().get_visible_rect().size.x
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	camera_offset-=(right*relative.x+down*relative.y)*scale_
	camera_offset=camera_offset.limit_length(18)

func _input(event: InputEvent) -> void:
	if episode_ui!=null and episode_ui.opened or journal!=null and journal.opened: return
	if event is InputEventMagnifyGesture:
		camera.size=clampf(camera.size/event.factor,9,40); get_viewport().set_input_as_handled(); return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index]=event.position
			if touch_points.size()>=2:
				var points=touch_points.values(); pinch_span=points[0].distance_to(points[1]); touch_dragged=true; touch_blocked=true; get_viewport().set_input_as_handled(); return
		else:
			var was_pinch=pinch_span>0; touch_points.erase(event.index)
			if was_pinch:
				if touch_points.is_empty(): pinch_span=0
				get_viewport().set_input_as_handled(); return
	if event is InputEventScreenDrag and touch_points.has(event.index):
		touch_points[event.index]=event.position
		if touch_points.size()>=2:
			var points=touch_points.values(); var span: float=points[0].distance_to(points[1])
			if span>20 and pinch_span>20: camera.size=clampf(camera.size*pinch_span/span,9,40)
			pinch_span=span; get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		pressed_person=pick_person(event.position) if not mobile_ui.blocks_point(event.position) else ""
		pressed_owner=not mobile_ui.blocks_point(event.position) and actor_hit_distance(event.position,sim.data.player.pos,sim.data.player.floor)<12 and (pressed_person=="" or actor_hit_distance(event.position,sim.data.player.pos,sim.data.player.floor)<actor_hit_distance(event.position,sim.data.people[pressed_person].pos,sim.data.people[pressed_person].floor))
		if pressed_owner:pressed_person=""
		mouse_origin=event.position
		mouse_dragged=false
		mouse_blocked=mobile_ui.blocks_point(event.position)
	if event is InputEventMouseMotion:
		pointer_position=event.position
		if event.device!=-1 and event.button_mask&MOUSE_BUTTON_MASK_LEFT and not mobile_ui.blocks_point(mouse_origin):
			if event.position.distance_to(mouse_origin)>24:mouse_dragged=true
			if mouse_dragged:pan_camera(event.relative)
	if event is InputEventScreenTouch and event.pressed:
		pressed_person=pick_person(event.position) if not mobile_ui.blocks_point(event.position) else ""
		pressed_owner=not mobile_ui.blocks_point(event.position) and actor_hit_distance(event.position,sim.data.player.pos,sim.data.player.floor)<12 and (pressed_person=="" or actor_hit_distance(event.position,sim.data.player.pos,sim.data.player.floor)<actor_hit_distance(event.position,sim.data.people[pressed_person].pos,sim.data.people[pressed_person].floor))
		if pressed_owner:pressed_person=""
		touch_origin=event.position
		touch_dragged=false
		touch_blocked=mobile_ui.blocks_point(event.position)
	if event is InputEventScreenDrag:
		pointer_position=event.position
		if event.position.distance_to(touch_origin)>24:touch_dragged=true
		if touch_dragged and not touch_blocked:pan_camera(event.relative)

func _unhandled_input(event: InputEvent) -> void:
	if episode_ui!=null and episode_ui.opened or journal!=null and journal.opened: return
	if event is InputEventKey and event.pressed and not event.echo:
		if Campaign.active(sim) and event.physical_keycode not in [KEY_ESCAPE,KEY_M,KEY_F5,KEY_F9]:return
		match event.physical_keycode:
			KEY_ESCAPE:
				if OS.has_feature("web"):sim.data.paused=not sim.data.paused
				else:get_tree().quit()
			KEY_SPACE:sim.data.paused=not sim.data.paused
			KEY_TAB:sim.data.speed=1 if sim.data.speed==3 else 3
			KEY_1:sim.assign_room(1)
			KEY_2:sim.assign_room(2)
			KEY_G:sim.reject_guest()
			KEY_E:sim.interact()
			KEY_H:sim.toggle_staff()
			KEY_Q:sim.queue_floor()
			KEY_T:sim.repair_tools()
			KEY_I:toggle_information()
			KEY_X:sim.cancel_work()
			KEY_Z:Simulation.Intrigue.subdue(sim)
			KEY_C:Simulation.Intrigue.drag_or_release(sim)
			KEY_B:Simulation.Intrigue.build_or_hold(sim)
			KEY_J:Simulation.Intrigue.contract_action(sim)
			KEY_K:Simulation.Intrigue.contract_action(sim,true)
			KEY_O:Simulation.Intrigue.inspector_action(sim,true)
			KEY_R:sim.toggle_dig_mode()
			KEY_V:show_vision=not show_vision
			KEY_M:muted=not muted
			KEY_F5:save_game()
			KEY_F9:load_game()
	if event is InputEventScreenTouch and not event.pressed and not touch_dragged and not touch_blocked:
		world_tap(event.position)
	if event is InputEventMouseButton and event.device!=-1:
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(8,camera.size-1)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(36,camera.size+1)
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not mouse_dragged and not mouse_blocked:world_tap(event.position)

func world_tap(point: Vector2) -> void:
	if mobile_ui.blocks_point(point):return
	if object_context.panel.visible:
		object_context.close()
	if Sandbox.active(sim) and not sim.data.work.is_empty() and sim.data.work.get("type","") not in ["construction","dispose"]:sim.cancel_work()
	elif sim.data.work.get("type","")=="quick":sim.cancel_work()
	if (view_layer=="surface" and sim.data.player.floor==1) or (view_layer=="below" and sim.data.player.floor!=1):return
	pointer_position=point
	if Sandbox.active(sim) and sandbox_ground_request(point):pressed_owner=false;pressed_person="";return
	if Sandbox.active(sim):sim.data.sandbox.tunnel_plan=[]
	var inspector: Dictionary=sim.data.ops.inspector
	if inspector.state not in ["idle","scheduled"] and inspector.floor==sim.data.player.floor and point.distance_to(camera.unproject_position(world_point(inspector.pos,inspector.floor,0.9)))<30:
		pressed_owner=false
		if Campaign.active(sim):
			if inspector.state=="waiting":context_action("inspector","","talk_guard")
			else:sim.note("경비가 현장을 살피고 있다. 지금은 설명을 듣지 않는다.")
		else:object_context.open("inspector")
		return
	if Sandbox.active(sim) and sandbox_objects(point):pressed_owner=false;pressed_person="";return
	if pressed_owner:
		pressed_owner=false; object_context.open("owner"); return
	var target_id: String=pressed_person if pressed_person!="" and sim.data.people.has(pressed_person) and sim.data.people[pressed_person].state!="gone" else pick_person(point)
	pressed_person=""
	if target_id!="":
		sim.data.excavation.path=[]; sim.data.excavation.intent=""; sim.data.ops.selected=target_id
		if Campaign.active(sim):context_action("person",target_id,"greet")
		else:object_context.open("person",target_id)
		return
	if view_layer!="below":
		for number in ([1,2,3,4,5] if Sandbox.active(sim) else [1,2]):
			var rp=Sandbox.room_point(number) if Sandbox.active(sim) else Vector2(5.6,-2.0 if number==1 else 2.0)
			if point.distance_to(camera.unproject_position(world_point(rp,Sandbox.floor_of(number),0.55)))<24:
				object_context.open("room",str(number)); return
		if sim.data.staff.hired and point.distance_to(camera.unproject_position(world_point(sim.data.staff.pos,int(sim.data.staff.get("floor",0)),0.9)))<28:
			if Campaign.active(sim):context_action("staff","","talk_staff")
			else:object_context.open("staff")
			return
	if view_layer!="below" and point.distance_to(camera.unproject_position(world_point(Simulation.COUNTER,0,0.8)))<34:
		object_context.open("counter"); return
	if not Sandbox.active(sim) and point.distance_to(camera.unproject_position(Vector3(Simulation.HATCH.x,0.15,Simulation.HATCH.y)))<32 and sim.data.player.floor==0:
		object_context.open("hatch"); return
	if Sandbox.active(sim) and sandbox_tap(point):return
	if sim.data.player.floor==1:
		if point.distance_to(camera.unproject_position(world_point(Vector2(-0.35,-1),1,1.6)))<24:
			object_context.open("lamp"); return
		if not Sandbox.active(sim) and point.distance_to(camera.unproject_position(world_point(Vector2.ZERO,1,1.9)))<30:
			object_context.open("hatch"); return
		var soil:=soil_at(point)
		if soil!=Vector2i(99,99):
			context_soil=soil
			if Sandbox.active(sim):sim.data.stealth.quiet=false;sim.queue_dig(soil)
			else:object_context.open("soil")
			return
	if sim.data.player.floor==0 and point.distance_to(camera.unproject_position(Vector3(8,0.3,4.5)))<50:
		object_context.open("stairs"); return
	if actor_hit_distance(point,sim.data.player.pos,sim.data.player.floor)<12:
		object_context.open("owner"); return
	# Upstairs walking can be requested directly, without an external floor button.
	if sim.data.player.floor==0 and view_layer!="below":
		var origin=camera.project_ray_origin(point); var ray=camera.project_ray_normal(point)
		var upper: Variant=Plane(Vector3.UP,3.28).intersects_ray(origin,ray)
		if upper!=null and upper.z<-3.5 and Simulation.gallery_walkable(Vector2(upper.x,upper.z)):
			auto_floor_goal={"floor":2,"point":Vector2(upper.x,upper.z)}; sim.queue_gallery(); return
	var hit: Variant=walking_hit(point)
	if hit!=null:
		pending_context_action.clear(); sim.data.booking_request={}
		sim.data.service_target=""
		auto_floor_goal.clear()
		sim.data.ops.selected=""
		sim.queue_move(Vector2(hit.x,hit.z))

func _physics_process(delta: float) -> void:
	if capturing:return
	if not sim.data.paused:
		var direction:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
		var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
		var speed_: float=1.15 if sim.data.ops.drag!="" else (2.2 if sim.data.player.carry!="" else 2.9)
		sim.move_player((right*direction.x+down*direction.y)*delta*speed_*sim.data.speed*sim.travel_multiplier)
		sim.tick(delta*sim.data.speed)
		if not sim.gentle_opening(): episode.tick(delta*sim.data.speed,episode_facts())
		Campaign.tick(sim)
		if pending_chat!="" and sim.data.excavation.intent=="" and sim.data.work.is_empty():
			var id=pending_chat; pending_chat=""
			if id=="@staff":
				if sim.data.player.floor==int(sim.data.staff.get("floor",0)) and sim.data.player.pos.distance_to(sim.data.staff.pos)<1.35:object_context.open("staff_talk","","홀은 제가 볼게요. 주인님 비밀도 지킬 테니 걱정 마세요. 손님들끼리 다투면 알려드릴게요. 방 청소도 도울게요.")
				else:pending_chat="@staff";sim.queue_command("listen_staff")
			elif id=="@guard" and sim.near_counter():object_context.open("guard_talk","","몇 가지 확인하겠소. 이 여관 아래에는 무엇을 보관하고 있소?")
			elif sim.data.people.has(id) and Simulation.Intrigue.close(sim,id):
				if Campaign.active(sim):object_context.open("conversation",id,Dialogue.begin(sim,id))
				else:object_context.open("person",id,str(sim.data.people[id].trait))
		update_stealth_audio(delta)
	if Sandbox.active(sim) and view_layer=="all":
		if sandbox_visual!=null:sandbox_visual.visible=true
	if sim.data.player.floor!=displayed_floor:
		displayed_floor=sim.data.player.floor
		if view_layer!="all":set_layer("below" if displayed_floor==1 else "surface")
		object_context.close()
	if not pending_context_action.is_empty() and sim.data.excavation.intent=="" and sim.data.work.is_empty():
		var job=pending_context_action
		if sim.data.player.floor==int(job.floor):
			pending_context_action={}; context_action(job.kind,job.id,job.action)
		else: travel_to_floor(int(job.floor))
	if not auto_floor_goal.is_empty() and sim.data.player.floor==int(auto_floor_goal.floor) and sim.data.excavation.intent=="":
		sim.queue_move(auto_floor_goal.point); auto_floor_goal.clear()
	if sim.data.player.floor==1:
		hover_cell=soil_at(pointer_position)
		if dig_cursor!=null:
			dig_cursor.visible=earth_edges.has(Simulation.cell_key(hover_cell))
			dig_cursor.position=Vector3(hover_cell.x,0.07,hover_cell.y)
	if not overview and sim.data.excavation.intent!="":camera_offset=camera_offset.lerp(Vector2.ZERO,minf(1,delta*3))
	var focus_target:=focus_position()+Vector3(camera_offset.x,0,camera_offset.y)
	camera_focus=camera_focus.lerp(focus_target,minf(1,delta*4))
	camera.position=camera_focus+CAMERA_ARM
	camera.look_at(camera_focus)
	sync_view(delta)
	episode_ui.refresh()
	if Campaign.active(sim):
		if room_chime!=null and sim.data.money>last_cash and not muted:room_chime.play()
		last_cash=sim.data.money
		if ambience!=null:ambience.volume_db=-80 if muted else -26
	if journal!=null:journal.refresh()

func send_key(key: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.keycode=key
	event.pressed=true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event=InputEventKey.new()
	event.physical_keycode=key
	event.keycode=key
	event.pressed=false
	Input.parse_input_event(event)
	await get_tree().process_frame

func pointer_click(point: Vector2, touch: bool=false) -> void:
	if touch:
		var down:=InputEventScreenTouch.new()
		down.index=0
		down.position=point
		down.pressed=true
		get_viewport().push_input(down,true)
		await get_tree().process_frame
		var up:=InputEventScreenTouch.new()
		up.index=0
		up.position=point
		up.pressed=false
		get_viewport().push_input(up,true)
	else:
		var motion:=InputEventMouseMotion.new()
		motion.position=point
		get_viewport().push_input(motion,true)
		var down:=InputEventMouseButton.new()
		down.position=point
		down.button_index=MOUSE_BUTTON_LEFT
		down.pressed=true
		get_viewport().push_input(down,true)
		await get_tree().process_frame
		var up:=InputEventMouseButton.new()
		up.position=point
		up.button_index=MOUSE_BUTTON_LEFT
		up.pressed=false
		get_viewport().push_input(up,true)
	await get_tree().process_frame

func click_control(key: String) -> void:
	sync_view(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var control: Button=mobile_ui.controls[key]
	await pointer_click(control.get_global_rect().get_center())
	sync_view(0)

func touch_control(key: String) -> void:
	sync_view(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var control: Button=mobile_ui.controls[key]
	var point:=control.get_global_rect().get_center()
	var down:=InputEventScreenTouch.new()
	down.position=point
	down.pressed=true
	get_viewport().push_input(down,true)
	var mouse:=InputEventMouseButton.new()
	mouse.position=point
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.device=-1
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	mouse=InputEventMouseButton.new()
	mouse.position=point
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.device=-1
	mouse.pressed=false
	get_viewport().push_input(mouse,true)
	var up:=InputEventScreenTouch.new()
	up.position=point
	up.pressed=false
	get_viewport().push_input(up,true)
	await get_tree().process_frame
	sync_view(0)

func frame_owner() -> void:
	overview=false
	view_layer="all"
	camera.size=14
	camera_focus=focus_position()
	camera.position=camera_focus+CAMERA_ARM
	camera.look_at(camera_focus)
	sync_view(0)

# Small deterministic procedural sounds: no external service or paid asset.
func sound_sample(kind: String) -> AudioStreamWAV:
	var wave:=AudioStreamWAV.new()
	wave.format=AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate=22050
	var bytes:=PackedByteArray()
	var duration:=0.16 if kind!="alert" else 0.42
	var count:=int(duration*22050)
	bytes.resize(count*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=742
	for i in range(count):
		var t:=float(i)/22050
		var envelope:=minf(t*400,1)*exp(-t*(32 if kind=="step" else 18))
		var sample: float
		if kind=="alert": sample=sin(TAU*660*t)*exp(-t*9)*0.3
		else: sample=(sin(TAU*(120 if kind=="step" else 210)*t)*0.55+rng.randf_range(-0.3,0.3))*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*25000))
	wave.data=bytes
	return wave

func setup_stealth_effects() -> void:
	vision_mesh=MeshInstance3D.new()
	surface.add_child(vision_mesh)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	vision_mesh.material_override=mat
	knock=AudioStreamPlayer.new()
	knock.stream=sound_sample("dig")
	add_child(knock)
	alert_sound=AudioStreamPlayer.new()
	alert_sound.stream=sound_sample("alert")
	alert_sound.volume_db=-12
	add_child(alert_sound)
	step_sound=AudioStreamPlayer3D.new()
	step_sound.stream=sound_sample("step")
	step_sound.max_distance=32
	step_sound.unit_size=8
	step_sound.volume_db=-14
	add_child(step_sound)

func refresh_vision() -> void:
	if not vision_mesh.visible: return
	var worker: Dictionary=sim.data.staff
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var color:=Color(0.95,0.48,0.2,0.22) if sim.data.stealth.phase!="idle" else Color(0.35,0.75,0.65,0.16)
	for i in range(20):
		var a: Vector2=sim.sight_end(worker.pos,worker.facing.rotated(deg_to_rad(-50+i*5)))
		var b: Vector2=sim.sight_end(worker.pos,worker.facing.rotated(deg_to_rad(-45+i*5)))
		for point in [worker.pos,a,b]:
			vertices.append(Vector3(point.x,0.13,point.y))
			colors.append(color)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	vision_mesh.mesh=mesh

func update_stealth_audio(delta: float) -> void:
	if sim.data.stealth.warning!=last_warning:
		last_warning=sim.data.stealth.warning
		if not muted:alert_sound.play()
	sound_clock+=delta
	if sound_clock<0.55: return
	sound_clock=0
	if muted:return
	if not sim.data.dig.is_empty():
		knock.volume_db=-25 if sim.data.dig.get("quiet",false) else -9
		knock.pitch_scale=0.85 if sim.data.dig.get("quiet",false) else 1
		knock.play()
	elif sim.data.player.floor==0 and sim.heard_at(sim.data.player.pos)>0.7:
		knock.volume_db=-30+sim.heard_at(sim.data.player.pos)
		knock.play()
	if sim.data.player.floor==0 and sim.data.staff.hired and sim.data.staff.mode in ["delivery","counter","return","investigate"]:
		step_sound.position=staff_visual.position
		step_sound.play()

func actor_hit_distance(screen: Vector2,pos: Vector2,floor_: int) -> float:
	var foot=camera.unproject_position(world_point(pos,floor_,0.1))
	var head=camera.unproject_position(world_point(pos,floor_,1.95))
	return screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,foot,head))

func pick_person(screen: Vector2) -> String:
	var id: String=""
	var distance:=30.0
	for key in sim.data.people:
		var person: Dictionary=sim.data.people[key]
		if person.state=="gone" or (view_layer=="below" and person.floor!=1) or (view_layer=="surface" and person.floor==1):continue
		var delta=actor_hit_distance(screen,person.pos,person.floor)
		if delta<distance:id=key;distance=delta
	return id

func build_holding_visual() -> void:
	if holding_visual!=null:holding_visual.queue_free()
	holding_visual=Node3D.new()
	basement.add_child(holding_visual)
	holding_position=sim.data.ops.cell
	holding_visual.position=Vector3(holding_position.x,0.08,holding_position.y)
	world_root=holding_visual
	box(Vector3(0.95,0.04,0.95),Vector3.ZERO,Color("60372e"))
	for x in [-0.45,-0.15,0.15,0.45]:
		box(Vector3(0.055,1.25,0.055),Vector3(x,0.625,-0.45),Color("333c3b"))
	box(Vector3(1,0.07,0.08),Vector3(0,1.25,-0.45),Color("525a54"))
	var label:=world_label("구금칸",Vector3(-0.3,0.2,0.65),holding_visual)
	label.pixel_size=0.004
	world_root=surface

func build_excavation_visuals() -> void:
	# Lid, rim and ladder give the entrance a physical shape instead of a label.
	world_root=surface
	for x in [-0.6,0.6]:box(Vector3(0.1,0.12,1.3),Vector3(Simulation.HATCH.x+x,0.12,Simulation.HATCH.y),Color("8d754e"))
	hatch_lid=Node3D.new()
	surface.add_child(hatch_lid)
	hatch_lid.position=Vector3(Simulation.HATCH.x,0.14,Simulation.HATCH.y-0.6)
	world_root=hatch_lid
	box(Vector3(1.05,0.08,1.15),Vector3(0,0,0.55),Color("705037"))
	box(Vector3(0.24,0.08,0.08),Vector3(0,0.08,0.9),Color("b5a477"))
	world_root=surface
	# The tool is attached after the owner is created in _ready.

func attach_tools() -> void:
	tool_pivot=Node3D.new()
	player.add_child(tool_pivot)
	tool_pivot.position=Vector3(0.32,1.05,-0.2)
	world_root=tool_pivot
	box(Vector3(0.055,0.95,0.055),Vector3(0,-0.2,0),Color("8a6843"))
	pick_head=box(Vector3(0.52,0.09,0.11),Vector3(0,0.25,0),Color("9baba9"))
	shovel_head=box(Vector3(0.28,0.3,0.07),Vector3(0,0.25,0),Color("899893"))
	world_root=surface

func toggle_information() -> void:
	if mobile_ui.drawer.visible:mobile_ui.close_sheet()
	else:mobile_ui.open_sheet("메뉴")

func soil_at(screen: Vector2) -> Vector2i:
	var origin:=basement.to_local(camera.project_ray_origin(screen))
	var direction:=camera.project_ray_normal(screen)
	var nearest:=INF
	var chosen:=Vector2i(99,99)
	for face in earth_faces:
		var bounds: AABB=face.bounds
		var hit: Variant=bounds.intersects_ray(origin,direction)
		if hit!=null:
			var distance: float=origin.distance_squared_to(hit)
			if distance<nearest:nearest=distance;chosen=face.cell
	return chosen

func refresh_noise() -> void:
	noise_visual.visible=sim.data.noise>0.4 and view_layer=="all"
	if not noise_visual.visible:return
	var mesh:=ImmediateMesh.new()
	var mat:=material(Color("c89b57"))
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	var source:=world_point(sim.data.stealth.source,1,1.2)
	var entrance:=world_point(Vector2.ZERO,1,1.2)
	var top:=Vector3(Simulation.HATCH.x,0.4,Simulation.HATCH.y)
	for segment in [[source,entrance],[entrance,top]]:
		var a: Vector3=segment[0]
		var b: Vector3=segment[1]
		var length:=a.distance_to(b)
		for i in range(ceili(length/0.35)):
			var t:=float(i)*0.35/maxf(length,0.001)
			mesh.surface_add_vertex(a.lerp(b,t))
			mesh.surface_add_vertex(a.lerp(b,minf(1,t+0.12/maxf(length,0.001))))
	mesh.surface_end()
	noise_visual.mesh=mesh

func episode_font() -> Font:
	return ui_font

func episode_facts() -> Dictionary:
	var bodies=0
	for p in sim.data.people.values():
		if p.state in ["down","captive","restrained","dead"]: bodies+=1
	return {"opening":sim.gentle_opening(),"booked":2-sim.data.rooms.values().filter(func(room_): return room_.guest=="").size(),"money":sim.data.money,"served":sim.data.served,"near_counter":sim.near_counter(),"risk":int(sim.data.stealth.suspicion)+int(sim.data.ops.reports)*12,"bodies":bodies,"hatch":sim.data.excavation.hatch_open,"dug":maxi(0,sim.data.cells.size()-55)}

func start_challenge() -> void:
	sim.data.opening.active=false
	episode.data.elapsed=0; episode.data.briefed=true
	sim.note("운영에 익숙해졌다. 이제 첫날 밤의 사건이 시작된다.")

func episode_coins(amount: int) -> void:
	sim.data.money+=amount

func episode_pause(value: bool) -> void:
	sim.data.paused=value

func capture_episode(cellar: bool) -> void:
	capturing=true; episode.data.briefed=true; episode.data.elapsed=68
	sim.data.player.pos=Simulation.COUNTER; sim.assign_room(1); sim.toggle_staff(); sim.tick(20)
	if cellar:
		sim.data.player.pos=Simulation.HATCH; sim.change_floor(); sim.queue_dig(Vector2i(2,0)); sim.tick(5); set_layer("below")
	else: set_layer("all")
	sync_view(0); episode_ui.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/episode-3d-"+("cellar" if cellar else "inn")+".png")
	get_tree().quit()

func episode_notice() -> String:
	return str(sim.data.logs.back().text) if not sim.data.logs.is_empty() else ""

func verify_episode_playthrough(capture: bool=false) -> int:
	set_physics_process(false)
	episode_ui.perform("start")
	sim.data.player.pos=Simulation.COUNTER
	assert(sim.assign_room(1))
	sim.toggle_staff()
	for step in range(364):
		sim.tick(0.5); episode.tick(0.5,episode_facts())
		if step==90: episode_ui.perform("report")
		if step==132: assert(sim.assign_room(2))
		if step==260: episode_ui.perform("honest")
	assert(sim.data.served>=3)
	sim.data.player.pos=Simulation.COUNTER
	var money: int=sim.data.money
	episode_ui.perform("settle")
	assert(episode.data.ending=="여관을 지킨 밤" and sim.data.money==money-36)
	assert(episode_ui.panel.visible and episode_ui.heading.text==episode.data.ending)
	save_game(); episode.data.ending=""; load_game()
	assert(episode.data.ending=="여관을 지킨 밤")
	if capture:
		set_layer("all"); sync_view(0); episode_ui.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/episode-3d-ending.png")
	episode_ui.perform("freeplay")
	assert(not episode_ui.panel.visible and not sim.data.paused and episode.data.freeplay)
	print("3D EPISODE PLAYTHROUGH: real booking, staff service, events, rent, ending, save/load, freeplay passed")
	return 0

func context_heading() -> String:
	return "길목 여관 · 영업%d일 · %s" %[sim.data.campaign.day,sim.calendar_text().split(" ",true,1)[1]] if Campaign.active(sim) else sim.calendar_text()

func context_stats() -> String:
	if Campaign.active(sim):return "%d닢 · 새벽 납부 %d · 평판 %d · 신고 %d" %[sim.data.money,Campaign.rent(int(sim.data.campaign.day))+(4 if sim.data.staff.hired else 0)+(8 if int(sim.data.campaign.day)==3 and not sim.data.campaign.tax_paid else 0),sim.data.campaign.reputation,sim.data.ops.reports]
	return "%d닢 · 손님 %d · 식사 %d%s" %[sim.data.money,sim.data.people.values().filter(func(p): return p.state!="gone").size(),sim.data.served," · 멈춤" if sim.data.paused else ""]

func context_title(kind_: String,id_: String) -> String:
	if kind_=="conversation":return str(sim.data.people[id_].name)
	if kind_=="ground":return "비밀 입구 자리"
	if kind_=="cellar_floor":return "지하 시설 공사"
	if kind_=="portal":return Sandbox.entrance(sim,id_).get("name","비밀 입구")
	if kind_=="facility":return Sandbox.TYPES[Sandbox.facility(sim,id_).type].name
	if kind_=="guard_talk":return "국경 순찰대"
	if kind_=="staff_talk":return "마라 · 믿을 수 있는 동료"
	if kind_=="person": return str(sim.data.people[id_].name)+(" · 식사" if sim.data.people[id_].get("visit","")=="meal" else "")
	if kind_=="room": return room_text(int(id_))
	return {"counter":"접수대 · 장부","hatch":"지하 입구","stairs":"계단","soil":"흙벽","lamp":"지하 등불","staff":"직원","owner":"여관 주인","system":"여관 설정","actions":"손님에게 할 행동","inspector":"국경 경비"}.get(kind_,"여관")

func context_anchor(kind_: String,id_: String) -> Vector2:
	var pos: Vector2=Simulation.COUNTER; var floor_: int=sim.data.player.floor
	match kind_:
		"person","actions","other","conversation":
			if sim.data.people.has(id_): pos=sim.data.people[id_].pos; floor_=sim.data.people[id_].floor
		"room": pos=Sandbox.room_point(int(id_)) if Sandbox.active(sim) else Vector2(5.6,-2.0 if id_=="1" else 2.0); floor_=Sandbox.floor_of(int(id_))
		"ground":pos=build_point;floor_=0
		"cellar_floor":pos=Vector2(build_cell);floor_=1
		"facility":pos=Sandbox.facility(sim,id_).pos;floor_=1
		"portal":
			var e=Sandbox.entrance(sim,id_);pos=e.top if floor_==0 else Vector2(e.bottom)
		"hatch": pos=Vector2.ZERO if floor_==1 else Simulation.HATCH
		"stairs": pos=Simulation.STAIRS
		"soil": pos=Vector2(context_soil)
		"lamp": pos=Vector2(-0.35,-1)
		"staff","staff_talk":pos=sim.data.staff.pos;floor_=int(sim.data.staff.get("floor",0))
		"owner": pos=sim.data.player.pos
		"inspector","guard_talk": pos=sim.data.ops.inspector.pos; floor_=sim.data.ops.inspector.floor
	return camera.unproject_position(world_point(pos,floor_,0.9))

func context_items(kind_: String,id_: String) -> Array:
	if kind_=="conversation":return Dialogue.options(sim,id_)
	if Sandbox.active(sim):
		match kind_:
			"ground":return [["walk_here","여기로 이동"],["make_entrance","비밀 입구 공사 · 3닢 / 4초"]]
			"cellar_floor":return [["walk_below","여기로 이동"],["build_prison","감옥 · 6닢"],["build_stash","은닉 창고 · 4닢"],["build_refuge","은신처 · 6닢"],["build_furnace","처리 화로 · 10닢"],["surface_exit","이 위치에 지상 출구 공사 · 3닢"]]
			"portal":
				var items=[["portal_use","올라가기" if sim.data.player.floor==1 else "내려가기"],["portal_cover","덮개 열기 / 숨기기"]]
				for e in sim.data.sandbox.entrances:
					if e.id!=id_:items.append(["connect:"+e.id,e.name+"까지 통로 연결"])
				return items
			"facility":
				var f=Sandbox.facility(sim,id_)
				return [["facility_use",{"prison":"데려온 대상 구금 / 감옥 확인","furnace":"운반 중인 시신 처리 · 12초","stash":"의뢰 상자 은닉 · 추가 6닢","refuge":"데려온 사람 보호"}[f.type]],["facility_remove","시설 철거 · 절반 환급"]]
			"owner":return [["stop","현재 행동 취소"],["floor","가까운 입구로 층 이동"],["build_mode","비밀 입구 자리 고르기"],["drop","운반 내려놓기"],["journal","장부 · 의뢰"],["system","저장 · 화면 설정"]]
			"room":return [["room_chat","묵는 손님과 이야기"],["clean","정리하기"],["journal","객실과 장부"]]
	if kind_=="guard_talk":
		var items=[["guard_honest","장부를 보여드리겠습니다."],["guard_lie","식재료 창고뿐입니다."],["guard_pay","수고비를 받으시죠. · 8닢"]]
		if sim.data.campaign.ledger_found:items.push_front(["guard_evidence","이 반입 허가를 확인해보시죠."])
		return items
	if kind_=="staff_talk":return [["delegate","홀과 손님 식사를 맡아주세요."],["takeover","잠시 쉬세요. 내가 맡을게요."],["ally_story","요즘 손님들 사이에 무슨 일이 있나요?"]]
	if Campaign.active(sim) and kind_=="counter":return [["journal","오늘의 장부와 지출"],["recruit","마라와 이야기하기"],["build_mode","비밀 입구 자리 고르기"],["system","저장 · 화면 설정"]]
	if sim.data.paused: return [["resume","영업 계속"],["journal","오늘의 장부"],["system","저장 · 화면 설정"]]
	match kind_:
		"person":
			var p: Dictionary=sim.data.people[id_]
			if p.state=="dead": return [["drag","끌기 / 내려놓기"],["greet","상태 확인"]]
			if p.state=="restrained": return [["sleep","잠시 기절시키기"],["kill","살해"],["drop","놓아주기"]]
			if p.state in ["down","captive"]: return [["drag","끌기 / 석방"],["kill","살해"],["greet","상태 확인"]]
			if p.state in ["waiting","arriving"] and p.get("visit","")!="meal":
				var items=[["admit1","1호 정리 후 안내" if sim.data.rooms["1"].dirty else ("1호 사용 중" if sim.data.rooms["1"].guest!="" else "1호로 안내"),sim.data.rooms["1"].guest==""],["admit2","2호 정리 후 안내" if sim.data.rooms["2"].dirty else ("2호 사용 중" if sim.data.rooms["2"].guest!="" else "2호로 안내"),sim.data.rooms["2"].guest==""],["greet","말 걸기"]]
				if not sim.gentle_opening() or sim.data.served>=3: items.append(["actions","다른 행동"])
				return items
			var items=[["service","식사 내어주기"],["greet","말 걸기"]]
			if not sim.gentle_opening() or sim.data.served>=3: items.append(["actions","다른 행동"])
			return items
		"actions": return [["grab","붙잡기"],["sleep","잠시 기절시키기"],["kill","살해"],["other","다른 조치"]]
		"other": return [["dismiss","내보내기"],["contract","의뢰 확인"],["protect","의뢰 거절 · 보호"]]
		"counter":
			if sim.gentle_opening() and sim.data.served<1: return [["journal","운영 안내"],["system","저장 · 화면 설정"]]
			return [["journal","오늘의 장부 · 사건/결산"],["staff","직원 고용 / 업무 맡기기"],["repair","도구 수리 · 2닢"],["system","저장 · 화면 설정"]]
		"hatch": return [["floor","올라가기" if sim.data.player.floor==1 else "내려가기"],["hatch","덮개 열기 / 닫기"],["lamp","지하 등불 켜기 / 끄기"]]
		"inspector": return [["inspect","조사에 응하기"],["bribe","뇌물 제안 · 12닢"]] if sim.data.ops.inspector.state=="waiting" else [["journal","오늘의 장부"]]
		"lamp": return [["lamp","켜기 / 끄기"]]
		"stairs": return [["gallery","1층으로 내려가기" if sim.data.player.floor==2 else "2층으로 올라가기"]]
		"room": return [["assign","선택 손님에게 배정"],["clean","청소하기"]]
		"soil":
			if sim.gentle_opening() and sim.data.served<3: return [["dig","여기 파기 · 4초"]]
			return [["dig","빠르게 파기 · 4초"],["quiet","조용히 파기 · 10초"]]
		"staff": return [["staff","서빙 위임 전환"],["explain","말 걸기 · 소음 설명"]]
		"owner":
			var items=[["stop","현재 행동 취소"],["journal","운영 안내 · 장부"],["drop","운반 내려놓기"]]
			if sim.data.player.floor==1 and (not sim.gentle_opening() or sim.data.served>=3): items.append(["cell","구금칸 설치 / 구금"])
			items.append(["system","저장 · 화면 설정"])
			return items
		"system": return [["pause","일시 정지"],["overview","여관 전체 보기"],["follow","주인 따라 보기"],["save","저장"],["load","불러오기"],["fullscreen","전체화면 전환"]]
	return []

func travel_to_floor(target: int) -> void:
	if sim.data.player.floor==2 or (sim.data.player.floor==0 and target==2):sim.queue_gallery()
	else:sim.queue_floor()

func context_action(kind_: String,id_: String,action: String) -> void:
	if Sandbox.active(sim) and sandbox_action(kind_,id_,action):return
	if kind_=="conversation":
		var result=Dialogue.choose(sim,id_,action)
		if result=="reopen":object_context.open("conversation",id_,Dialogue.line(sim,id_));return
		if result=="close":return
	if action.begins_with("guard_"):
		Campaign.guard_answer(sim,action);return
	var target_floor=sim.data.player.floor
	if kind_ in ["person","actions","other"] and sim.data.people.has(id_):target_floor=sim.data.people[id_].floor
	elif kind_=="room":target_floor=Sandbox.floor_of(int(id_))
	elif kind_ in ["counter","staff","inspector"]:target_floor=0
	elif kind_ in ["soil","lamp"]:target_floor=1
	if action not in ["journal","system","actions","other","save","load","overview","pause","resume","stop","fullscreen"] and target_floor!=sim.data.player.floor:
		pending_context_action={"kind":kind_,"id":id_,"action":action,"floor":target_floor}; travel_to_floor(target_floor); return
	match action:
		"resume": sim.data.paused=false; return
		"pause": sim.data.paused=true; return
		"journal":
			if Campaign.active(sim):journal.open()
			else:episode_ui.open()
			return
		"recruit":
			if sim.data.staff.hired:context_action("staff","","talk_staff");return
			var id: String=sim.data.campaign.worker
			if id=="" or not sim.data.people.has(id) or sim.data.people[id].state in ["gone","leaving"]:sim.data.campaign.worker=Campaign.special(sim,"worker","마라","일할 사람을 구하신다고 들었어요.");sim.note("일할 사람이 마당에서 들어온다.")
			else:context_action("person",id,"greet")
			return
		"talk_staff":
			if sim.data.player.floor!=int(sim.data.staff.get("floor",0)):
				pending_context_action={"kind":"staff","id":"","action":"talk_staff","floor":int(sim.data.staff.get("floor",0))};travel_to_floor(int(sim.data.staff.get("floor",0)));return
			sim.cancel_work();pending_chat="@staff";sim.queue_command("listen_staff");return
		"delegate":sim.data.staff.delegated=true;sim.note("마라에게 서빙을 맡겼다.");return
		"takeover":sim.data.staff.delegated=false;sim.note("마라는 하던 주문을 마치고 쉰다.");return
		"talk_guard":sim.cancel_work();pending_chat="@guard";sim.queue_command("listen_guard");return
		"system": object_context.open("system"); return
		"actions","other": object_context.open(action,id_); return
		"overview": set_layer("all"); return
		"follow": frame_owner(); camera.size=18; return
		"save": save_game(); return
		"load": load_game(); return
		"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED); return
		"stop":
			if Sandbox.active(sim):sim.data.sandbox.tunnel_plan=[]
			pending_context_action.clear(); sim.data.booking_request={}; sim.cancel_work(); sim.data.service_target=""; auto_floor_goal.clear(); return
		"floor": auto_floor_goal.clear(); sim.queue_floor(); return
		"gallery": auto_floor_goal.clear(); sim.queue_gallery(); return
		"hatch": sim.queue_command("hatch"); return
		"lamp": sim.queue_command("lamp"); return
		"dig","quiet": sim.data.stealth.quiet=action=="quiet"; sim.queue_dig(context_soil); return
		"service": sim.request_direct_service(id_); return
		"drop": Simulation.Intrigue.drag_or_release(sim); return
		"clean": sim.queue_command("clean"+id_); return
		"assign":
			var selected: String=sim.data.ops.selected
			if selected=="" or not sim.data.people.has(selected): sim.note("먼저 손님에게 말을 걸어 원하는 것을 듣자."); return
			if Campaign.active(sim) and not sim.data.people[selected].get("known",false):context_action("person",selected,"greet");return
			sim.request_room(int(id_),selected); return
	if action.begins_with("admit"):sim.request_room(int(action.trim_prefix("admit")),id_);return
	if action=="farewell":return
	if action=="greet":
		if Campaign.active(sim):sim.cancel_work();sim.data.service_target="";sim.data.booking_request={}
		pending_chat=id_
	if kind_ in ["person","actions","other"]: sim.data.ops.selected=id_
	sim.queue_command(action,id_)

func build_backdrop() -> void:
	# Surround the inn with a readable courtyard/road instead of a void.
	apron=Node3D.new(); surface.add_child(apron); world_root=apron
	box(Vector3(38,0.18,20),Vector3(3,-0.31,16),Color("4f5142"))
	for x in range(-12,20,4):
		box(Vector3(1.5,0.025,1.0),Vector3(x,-0.2,8),Color("686858"))
	world_root=surface
	box(Vector3(80,0.2,45),Vector3(0,-0.5,-32),Color("35433e"))
	box(Vector3(10,0.23,45),Vector3(1,-0.48,-32),Color("6d6654"))
	for x in [-22,-17,-12,12,17,22]:
		for z in [-15,-25,-35]:
			box(Vector3(0.3,3.2,0.3),Vector3(x,1.2,z),Color("493b2d"))
			var crown=MeshInstance3D.new(); var mesh_=CylinderMesh.new()
			mesh_.top_radius=0; mesh_.bottom_radius=1.7; mesh_.height=4.0; mesh_.radial_segments=5
			crown.mesh=mesh_; crown.material_override=material(Color("304d43")); surface.add_child(crown); crown.position=Vector3(x,3.4,z)
	for x in range(-22,23,3):
		box(Vector3(0.18,1.6,0.18),Vector3(x,0.4,-13),Color("64553e"))
		if abs(x)>3: box(Vector3(3,0.14,0.14),Vector3(x+1.4,0.75,-13),Color("776547"))
	world_root=surface

func click_context(key: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await pointer_click(object_context.controls[key].get_global_rect().get_center())
	await get_tree().process_frame

func input_verify() -> void:
	get_window().size=Vector2i(540,1020)
	await get_tree().process_frame
	await get_tree().process_frame
	set_physics_process(false)
	var checks: Array=[]
	var geometry_: Array=sim.obstacles.duplicate()
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.travel_multiplier=1.7
	sim.data.player.pos=Vector2(-7,3.25)
	sim.spawn_guest(); sim.data.people.guest_2.pos=Vector2(-3.75,3.25)
	set_layer("surface"); sync_view(0)
	await get_tree().process_frame
	await get_tree().process_frame
	checks.append(get_viewport().get_visible_rect().size.y>get_viewport().get_visible_rect().size.x)
	checks.append(not mobile_ui.root.visible and not episode_ui.journal.visible)
	var p: Vector2=sim.data.people.guest_2.pos
	await pointer_click(camera.unproject_position(world_point(p,0,0.65)),true)
	checks.append(object_context.panel.visible and object_context.target=="guest_2")
	checks.append(object_context.controls.has("admit2"))
	var before: int=sim.data.money
	await click_context("admit2")
	checks.append(sim.data.money==before and sim.data.rooms["2"].guest=="")
	sim.tick(0.1)
	checks.append(sim.data.money==before)
	sim.tick(4)
	checks.append(sim.data.rooms["2"].guest=="guest_2" and sim.data.money==before+sim.data.people.guest_2.rate)
	checks.append(sim.data.people.guest_1.state=="waiting" and not sim.near_counter())
	sim.tick(12)
	checks.append(sim.data.people.guest_2.state=="staying" and sim.data.people.guest_2.pos.distance_to(sim.room_target(2))<0.1)
	checks.append(sim.request_direct_service("guest_2"))
	sim.tick(15)
	checks.append(sim.data.served==1 and sim.data.player.carry=="")
	# Native touch still gives one destination and uses the faster owner speed.
	set_layer("surface"); sync_view(0)
	var dest=Vector2(-5.25,4.25)
	await pointer_click(camera.unproject_position(world_point(dest,0,0.08)),true)
	checks.append(sim.data.excavation.intent=="move")
	sim.tick(3)
	checks.append(sim.data.player.pos.distance_to(dest)<0.1)
	object_context.open("owner"); await click_context("stop")
	checks.append(sim.data.excavation.intent=="")
	var upper_goal=Vector2(-5.25,-4.25)
	await pointer_click(camera.unproject_position(world_point(upper_goal,2,0.08)))
	checks.append(not auto_floor_goal.is_empty())
	sim.tick(12); _physics_process(0); sim.tick(4)
	checks.append(sim.data.player.floor==2 and sim.data.player.pos.distance_to(upper_goal)<0.1)
	object_context.open("stairs"); await click_context("gallery"); sim.tick(12)
	checks.append(sim.data.player.floor==0)
	set_layer("surface"); sync_view(0)
	await pointer_click(camera.unproject_position(world_point(Simulation.HATCH,0,0.15)))
	checks.append(object_context.kind=="hatch")
	await click_context("floor"); sim.tick(4)
	checks.append(sim.data.player.floor==1)
	set_layer("below"); sync_view(0)
	var count: int=sim.data.cells.size()
	await pointer_click(camera.unproject_position(world_point(Vector2(-3.5,0),1,0.9)))
	checks.append(object_context.kind=="soil")
	await click_context("quiet"); sim.tick(15)
	checks.append(sim.data.cells.size()==count+1 and sim.data.stealth.quiet)
	object_context.open("system"); await click_context("save")
	before=sim.data.money; sim.data.money=999
	object_context.open("system"); await click_context("load")
	checks.append(sim.data.money==before and sim.data.cells.size()==count+1)
	object_context.open("system"); await click_context("pause")
	checks.append(sim.data.paused)
	object_context.open("owner"); await click_context("resume")
	checks.append(not sim.data.paused)
	# Opening uses physical arrivals, no queue at the counter, and no countdown.
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid()
	sim.start_gentle_opening()
	checks.append(sim.data.people.guest_1.state=="arriving" and sim.data.people.guest_1.pos.x>10)
	sim.tick(25)
	checks.append(sim.data.people.guest_1.state=="waiting" and sim.data.people.guest_1.pos.distance_to(Simulation.ENTRY)>2)
	sim.tick(60)
	checks.append(sim.data.serial==1 and sim.waiting().size()==1)
	var elapsed=episode.data.elapsed
	_physics_process(0.1)
	checks.append(episode.data.elapsed==elapsed and episode_facts().opening)
	checks.append(context_items("person","guest_1").size()==3 and context_items("soil","").size()==1)
	sim.data.opening.active=false; sim.data.player.floor=1
	checks.append(context_items("owner","").any(func(entry): return entry[0]=="cell"))
	sim.data.player.floor=0; sim.data.player.pos=Simulation.COUNTER
	sim.data.ops.inspector.state="waiting"; sim.data.ops.inspector.floor=0; sim.data.ops.inspector.pos=Simulation.COUNTER
	set_layer("surface"); sync_view(0); object_context.close()
	await pointer_click(camera.unproject_position(world_point(Simulation.COUNTER,0,0.9)))
	checks.append(object_context.kind=="inspector")
	await click_context("inspect")
	var guard_reached=sim.data.ops.inspector.state=="search"
	await pointer_click(camera.unproject_position(world_point(Vector2(5.6,-2.0),0,0.55)))
	checks.append(guard_reached and object_context.kind=="room" and object_context.target=="1")
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid()
	sim.data.player.pos=Simulation.ENTRY; sim.data.ops.selected="guest_1"
	object_context.open("actions","guest_1"); await click_context("grab")
	checks.append(sim.data.work.get("action","")=="grab")
	sim.tick(1); checks.append(sim.data.people.guest_1.state=="restrained" and sim.data.ops.drag=="guest_1")
	object_context.open("person","guest_1"); await click_context("sleep"); sim.tick(2)
	checks.append(sim.data.people.guest_1.state=="down" and sim.data.people.guest_1.wake_at>sim.data.clock+40)
	object_context.open("person","guest_1"); await click_context("kill"); sim.cancel_work(); sim.tick(2)
	checks.append(sim.data.people.guest_1.state=="down")
	object_context.open("person","guest_1"); await click_context("kill"); sim.tick(3)
	checks.append(sim.data.people.guest_1.state=="dead")
	object_context.open("owner"); await click_context("drop")
	checks.append(sim.data.ops.drag=="")
	sim.tick(55); checks.append(sim.data.people.guest_1.state=="dead")
	var saved=sim.snapshot(); sim.data.people.guest_1.state="waiting"
	checks.append(sim.restore(saved) and sim.data.people.guest_1.state=="dead")
	sim.data.money=100; sim.data.ops.inspector.resolved=false; sim.data.ops.inspector.pos=sim.data.people.guest_1.pos; sim.data.ops.inspector.floor=0
	checks.append(Simulation.Intrigue.discover(sim) and sim.data.money==60 and sim.data.people.guest_1.state=="dead")
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.data.ops.selected="guest_1"
	sim.data.player.pos=Simulation.ENTRY; Simulation.Intrigue.quick_action(sim,"grab"); sim.tick(1); Simulation.Intrigue.drag_or_release(sim)
	checks.append(sim.data.people.guest_1.state=="leaving" and sim.data.ops.drag=="")
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.data.ops.selected="guest_1"
	sim.data.player.pos=Simulation.ENTRY; Simulation.Intrigue.quick_action(sim,"sleep"); sim.tick(2); sim.tick(46)
	checks.append(sim.data.people.guest_1.state in ["leaving","gone"])
	# Both rooms must survive checkout -> cleaning -> a different guest's booking.
	for number in [1,2]:
		sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.data.next_guest=9999
		sim.data.player.pos=Simulation.ENTRY; sim.assign_room(number,"guest_1"); sim.tick(110)
		checks.append(sim.data.rooms[str(number)].guest=="" and sim.data.rooms[str(number)].dirty)
		sim.spawn_guest(); checks.append(sim.request_room(number,"guest_2")); sim.tick(30)
		checks.append(sim.data.rooms[str(number)].guest=="guest_2" and not sim.data.rooms[str(number)].dirty)
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.start_gentle_opening()
	checks.append(sim.calendar_text().begins_with("1일차 08:00"))
	sim.data.people.guest_1.pos=Simulation.ENTRY; sim.data.player.pos=Simulation.ENTRY; sim.assign_room(1,"guest_1")
	checks.append(sim.data.people.guest_1.checkout==480)
	sim.spawn_guest(); sim.data.next_guest=9999; sim.tick(30)
	checks.append(sim.data.people.guest_2.state=="dining" and sim.data.people.guest_2.room==0 and not sim.data.orders.is_empty())
	sim.request_direct_service("guest_2"); sim.tick(25)
	checks.append(sim.data.served==1 and sim.data.people.guest_2.state in ["leaving","gone"] and sim.data.rooms["2"].guest=="")
	sim.data.clock=240; checks.append(sim.calendar_text().contains("20:00") and sim.calendar_text().ends_with("밤"))
	sim.data.clock=320; checks.append(sim.calendar_text().begins_with("2일차 00:00"))
	# Capture the person at pointer down; release still targets that moving person.
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.data.next_guest=9999
	sim.data.player.pos=Vector2(-7.25,3.25); set_layer("all"); sync_view(0); object_context.close()
	var tap=camera.unproject_position(world_point(sim.data.people.guest_1.pos,0,1.7))
	var press=InputEventMouseButton.new(); press.position=tap; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; get_viewport().push_input(press,true)
	await get_tree().process_frame
	sim.data.people.guest_1.pos+=Vector2(2,0); sync_view(0)
	var release=InputEventMouseButton.new(); release.position=tap; release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; get_viewport().push_input(release,true)
	await get_tree().process_frame
	checks.append(object_context.panel.visible and object_context.target=="guest_1")
	var menu_at=object_context.panel.position; sim.data.people.guest_1.pos+=Vector2(2,0); object_context.refresh()
	checks.append(object_context.panel.position==menu_at)
	# Owner downstairs can see, select and serve the guest upstairs via actual stairs.
	sim=Simulation.new(); sim.obstacles.assign(geometry_); sim.rebuild_grid(); sim.data.next_guest=9999
	sim.data.player.pos=Simulation.ENTRY; sim.assign_room(1,"guest_1"); sim.tick(20)
	sim.data.player.floor=1; sim.data.player.pos=Vector2.ZERO; pending_context_action={}; set_layer("all"); sync_view(0); object_context.close()
	await pointer_click(camera.unproject_position(world_point(sim.data.people.guest_1.pos,0,1.5)),true)
	checks.append(object_context.target=="guest_1")
	await click_context("service")
	checks.append(not pending_context_action.is_empty())
	for step in range(250):sim.tick(0.1); _physics_process(0)
	checks.append(sim.data.player.floor==0 and sim.data.served==1 and view_layer=="all" and surface.visible and basement.visible)
	var failed=0
	for i in range(checks.size()):
		if not checks[i]: failed+=1; print("CONTEXT POINTER FAIL ",i)
	print("3D CONTEXT POINTER CHECKS: %d checks, %d failures" %[checks.size(),failed])
	get_tree().quit(1 if failed else 0)

func capture_context(show_menu: bool) -> void:
	capturing=true; episode.data.briefed=true
	sim.data.player.pos=Simulation.COUNTER; sim.assign_room(1); sim.toggle_staff(); sim.tick(18)
	sim.spawn_guest(); sim.data.people.guest_2.pos=Vector2(-3.75,2.25)
	sim.data.opening={"active":true,"natural":true}
	set_layer("surface"); sync_view(0); episode_ui.refresh()
	if show_menu:
		sim.data.ops.selected="guest_2"; object_context.open("person","guest_2")
	if "--capture-actions" in OS.get_cmdline_user_args():
		sim.data.served=3; sim.data.ops.selected="guest_2"; object_context.open("actions","guest_2")
	if "--capture-cycle" in OS.get_cmdline_user_args():
		sim.data.people.guest_2.visit="meal"; sim.data.people.guest_2.state="dining"; sim.create_order("guest_2")
		sim.data.player.pos=Simulation.HATCH; sim.change_floor(); sim.data.player.pos=Vector2(1,1); set_layer("all"); sync_view(0); object_context.close()
	await get_tree().process_frame
	await get_tree().process_frame
	object_context.refresh()
	await RenderingServer.frame_post_draw
	if "--capture-cycle" in OS.get_cmdline_user_args():
		get_viewport().get_texture().get_image().save_png("res://docs/cycle-3d-overview.png"); get_tree().quit(); return
	get_viewport().get_texture().get_image().save_png("res://docs/context-3d-"+("actions" if "--capture-actions" in OS.get_cmdline_user_args() else ("guest" if show_menu else "inn"))+".png")
	get_tree().quit()

func demo_advance(seconds: float) -> void:
	for i in range(ceili(seconds/0.1)):
		if sim.data.paused:break
		sim.tick(0.1);_physics_process(0)

func demo_talk(id: String) -> void:
	object_context.close()
	await pointer_click(camera.unproject_position(world_point(sim.data.people[id].pos,sim.data.people[id].floor,1.5)),true)
	for i in range(400):
		if object_context.kind=="conversation" and object_context.target==id:break
		sim.tick(0.1);_physics_process(0)
	await get_tree().process_frame

func demo_playthrough() -> void:
	get_window().size=Vector2i(540,1020);await get_tree().process_frame;set_physics_process(false)
	start_campaign();journal.choose("begin");set_layer("all");sync_view(0)
	await demo_talk("guest_1")
	assert(object_context.kind=="conversation" and sim.data.people.guest_1.known and not object_context.controls.has("admit1"))
	assert(sim.data.paused and object_context.detail.contains("조용한"))
	await click_context("offer_room");assert(object_context.controls.has("book1"))
	await click_context("book1");demo_advance(25)
	assert(sim.data.rooms["1"].guest=="guest_1")
	await demo_talk("guest_1");await click_context("serve_meal");demo_advance(25)
	assert(sim.data.served>=1)
	var worker: String=sim.data.campaign.worker
	await demo_talk(worker);await click_context("hire_worker")
	assert(sim.data.staff.hired and sim.data.staff.delegated)
	var shadow="--demo-shadow" in OS.get_cmdline_user_args()
	var safety=0
	while sim.data.campaign.ending=="" and safety<7000:
		safety+=1
		if sim.data.campaign.summary:
			journal.choose("continue");continue
		var acted=false
		for id in sim.data.people.keys():
			var p: Dictionary=sim.data.people[id]
			if p.state not in ["waiting","arriving"] or p.get("known",false) or p.get("role","")=="worker":continue
			if p.get("role","")=="broker":
				await demo_talk(id);await click_context("accept_cargo" if shadow else "refuse_cargo");acted=true;break
			if p.get("role","")=="fugitive":
				await demo_talk(id);await click_context("feed_fugitive");acted=true;break
			if p.get("visit","")=="stay" and sim.data.rooms.values().any(func(r):return r.guest==""):
				await demo_talk(id);await click_context("offer_room")
				await click_context("book1" if sim.data.rooms["1"].guest=="" else "book2");demo_advance(25);acted=true;break
		if sim.data.ops.inspector.state=="waiting":
			object_context.close();context_action("inspector","","talk_guard")
			for i in range(400):
				if object_context.kind=="guard_talk":break
				sim.tick(0.1);_physics_process(0)
			await click_context("guard_lie" if shadow else "guard_honest");acted=true
		if not acted:demo_advance(0.5)
	var expected_ending="국경의 은신처" if shadow else "다시 켜진 등불"
	assert(sim.data.campaign.ending==expected_ending)
	assert(sim.data.campaign.history.size()==3 and sim.data.served>=3 and journal.opened)
	var final_money=sim.data.money;save_game();sim.data.money=999;load_game()
	assert(sim.data.money==final_money and sim.data.campaign.ending==expected_ending)
	print("DEMO PLAYTHROUGH: talk -> listen -> room -> meal -> hire -> real visitors -> broker -> guards -> three paid dawns -> ending -> save/load passed; meals=",sim.data.served," balance=",sim.data.money," ending=",expected_ending)
	if ambience!=null:ambience.stop();room_chime.stop()
	if "--capture-demo-ending" in OS.get_cmdline_user_args():
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/demo-ending.png")
	await get_tree().process_frame
	get_tree().quit()

func capture_demo(talking: bool) -> void:
	set_physics_process(false);capturing=true;Campaign.start(sim);basement.position=Sandbox.OFFSET;camera.keep_aspect=Camera3D.KEEP_WIDTH
	for child in basement.get_children():
		if child!=terrain and child!=cellar_lamp:child.hide()
	hatch_lid.hide();last_cell_count=-1;sandbox_revision=-1
	for child in surface.get_children():
		if child is Label3D and child.text.begins_with("지하 입구"):child.hide()
	world_root=surface
	box(Vector3(1.65,0.18,1.65),Vector3(Simulation.HATCH.x,-0.02,Simulation.HATCH.y),Color("604c36"))
	episode.data.briefed=true;episode_ui.root.hide();sim.data.campaign.intro=false
	sim.data.player.pos=Vector2(-3.75,2.5);sim.data.people.guest_1.pos=Vector2(-4.75,2.5);sim.data.people.guest_1.state="waiting"
	set_layer("all");sync_view(0);journal.refresh()
	if talking:object_context.open("conversation","guest_1",Dialogue.begin(sim,"guest_1"))
	if "--capture-demo-intro" in OS.get_cmdline_user_args():sim.data.campaign.intro=true;journal.open("intro")
	await get_tree().process_frame;await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/demo-"+("intro" if "--capture-demo-intro" in OS.get_cmdline_user_args() else ("talk" if talking else "inn"))+".png")
	get_tree().quit()

func sandbox_tap(point: Vector2) -> bool:
	for e in sim.data.sandbox.entrances:
		for floor_ in [0,1]:
			var at: Vector2=e.top if floor_==0 else Vector2(e.bottom)
			if point.distance_to(camera.unproject_position(world_point(at,floor_,0.2)))<22:
				if floor_!=sim.data.player.floor:continue
				object_context.open("portal",e.id);return true
	if sim.data.player.floor==1:
		for f in sim.data.sandbox.facilities:
			if point.distance_to(camera.unproject_position(world_point(f.pos,1,0.5)))<26:object_context.open("facility",f.id);return true
		var hit: Variant=walking_hit(point)
		if hit!=null:
			var cell=Vector2i(roundi(hit.x),roundi(hit.z))
			if sim.data.cells.has(Simulation.cell_key(cell)):
				build_cell=cell;object_context.open("cellar_floor");return true
	elif sim.data.player.floor==0:
		var hit: Variant=walking_hit(point)
		if hit!=null and sim.surface_walkable(Vector2(hit.x,hit.z)):
			var pos=Vector2(hit.x,hit.z)
			if entrance_placing or (pos.distance_to(last_ground_tap)<1.2 and Time.get_ticks_msec()-last_ground_time<900):
				entrance_placing=false;build_point=pos;object_context.open("ground");return true
			last_ground_tap=pos;last_ground_time=Time.get_ticks_msec()
	return false

func sandbox_action(kind_: String,id_: String,action: String) -> bool:
	if action.begins_with("connect:"):Sandbox.connect_tunnel(sim,id_,action.trim_prefix("connect:"));return true
	if action.begins_with("build_") and action!="build_mode":Sandbox.build(sim,action.trim_prefix("build_"),build_cell);return true
	match action:
		"build_mode":entrance_placing=true;sim.note("마당이나 1층 바닥을 눌러 비밀 입구 위치를 고르세요.");return true
		"make_entrance":Sandbox.create_entrance(sim,build_point);return true
		"walk_here":sim.queue_move(build_point);return true
		"walk_below":sim.queue_move(Vector2(build_cell));return true
		"portal_use":Sandbox.use_entrance(sim,id_);return true
		"portal_cover":
			var e=Sandbox.entrance(sim,id_);e.open=not e.open;sim.data.sandbox.revision+=1;sim.note("입구를 열었다." if e.open else "덮개로 비밀 입구를 숨겼다.");return true
		"surface_exit":
			var top=Sandbox.above(Vector2(build_cell))
			if not sim.surface_walkable(top):sim.note("위쪽이 벽이나 가구에 막혀 있습니다. 다른 자리를 골라주세요.");return true
			if sim.data.money<3:sim.note("입구 공사비 3닢이 필요합니다.");return true
			if sim.data.sandbox.entrances.any(func(e):return e.top.distance_to(top)<2):sim.note("이미 가까운 입구가 있습니다.");return true
			sim.data.sandbox.route={"kind":"entrance","point":top,"cell":build_cell};sim.queue_move(Vector2(build_cell));sim.data.excavation.intent="sandbox:build";return true
		"facility_use":Sandbox.queue_facility(sim,id_);return true
		"facility_remove":
			var f=Sandbox.facility(sim,id_)
			if f.occupant!="":sim.note("먼저 사람이나 물건을 옮기세요.");return true
			sim.data.money+=int(int(Sandbox.TYPES[f.type].cost)/2);sim.data.sandbox.facilities.erase(f);sim.data.sandbox.revision+=1;return true
		"release_captive":Sandbox.release(sim,id_);return true
		"interrogate":
			var p: Dictionary=sim.data.people[id_];p.dialogue_stage="interrogate";object_context.open("conversation",id_,"살려주면 말하겠소. 회색 망토가 운반하는 건 군수 약품이오. 징수원은 그걸 알고 있소.");return true
		"escort":
			var p: Dictionary=sim.data.people[id_];p.state="restrained";p.path=[];sim.data.ops.drag=id_;sim.note("같이 이동합니다. 은신처에 데려가 보호할 수 있습니다.");return true
		"mediate":
			var p: Dictionary=sim.data.people[id_];p.feuds=0;p.last_feud=sim.data.clock+60;p.bubble="알겠소. 오늘은 참지.";p.bubble_until=sim.data.clock+5;sim.note("다툼을 말렸다. 방을 떨어뜨려 배정하면 다시 마주칠 일이 줄어든다.");return true
		"relocate":sim.data.people[id_].dialogue_stage="rooms";object_context.open("conversation",id_,"다른 방으로 옮길 수 있겠소?");return true
		"accept_hold":
			var target=""
			for id in sim.data.people:
				if sim.data.people[id].get("role","")=="" and sim.data.people[id].state in ["waiting","staying","dining"]:target=id;break
			if target=="":sim.note("대상이 아직 도착하지 않았다.");return true
			sim.data.sandbox.job={"state":"accepted","target":target,"reward":18,"held":0.0};sim.note("회색 망토의 의뢰: 장부를 가져간 %s을 죽이지 말고 감옥에 15초 붙잡아 두라. 보수 18닢. 거절하고 정상 영업만 해도 된다." %sim.data.people[target].name);return true
		"room_chat":
			var who: String=sim.data.rooms[id_].guest
			if who!="":context_action("person",who,"greet")
			else:sim.note("빈 객실입니다. 손님에게 말을 걸어 배정하세요.")
			return true
		"ally_story":object_context.open("staff_talk","","병사들은 밀수꾼을 싫어해요. 식당에서 다투면 중재하고, 객실은 서로 떨어뜨려 주세요. 뒤편 길이나 지하로 돌아가면 홀에서 마주치지 않을 수 있어요.");return true
	return false

func capture_sandbox() -> void:
	start_campaign();sim.data.campaign.intro=false;journal.close();sim.data.paused=false;set_physics_process(false)
	Sandbox.finish(sim,{"kind":"entrance","point":Vector2(13.25,3.25),"cell":Sandbox.underground(Vector2(13.25,3.25))})
	Sandbox.finish(sim,{"kind":"entrance","point":Vector2(-3.25,2.75),"cell":Vector2i.ZERO})
	for x in range(0,18):sim.data.cells[Simulation.cell_key(Vector2i(x,0))]=true
	Sandbox.finish(sim,{"kind":"prison","cell":Vector2i(4,0)})
	Sandbox.finish(sim,{"kind":"stash","cell":Vector2i(8,0)})
	Sandbox.finish(sim,{"kind":"furnace","cell":Vector2i(12,0)})
	sim.data.player.floor=1;sim.data.player.pos=Vector2(3,0);sync_view(0);set_layer("all")
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/secret-inn-v14.png");get_tree().quit()

func sandbox_objects(point: Vector2) -> bool:
	for e in sim.data.sandbox.entrances:
		var floor_: int=sim.data.player.floor
		if floor_==2:continue
		var p: Vector2=e.top if floor_==0 else Vector2(e.bottom)
		if point.distance_to(camera.unproject_position(world_point(p,floor_,0.1)))<15:
			object_context.open("portal",e.id);return true
	if sim.data.player.floor==1:
		for f in sim.data.sandbox.facilities:
			if point.distance_to(camera.unproject_position(world_point(f.pos,1,0.15)))<16:
				object_context.open("facility",f.id);return true
	return false

func sync_sandbox_smoke() -> void:
	if smoke_visual==null:
		smoke_visual=Node3D.new();surface.add_child(smoke_visual)
		for i in range(4):
			var puff=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=0.4+i*0.08;sphere.height=0.65;sphere.radial_segments=6;sphere.rings=3;puff.mesh=sphere;puff.material_override=material(Color("5b6466"));smoke_visual.add_child(puff)
	smoke_visual.visible=sim.data.work.get("type","")=="dispose"
	if not smoke_visual.visible:return
	var f=Sandbox.facility(sim,sim.data.work.facility)
	if f.is_empty():return
	var top=Sandbox.above(f.pos);smoke_visual.position=Vector3(top.x,1.0,top.y)
	for i in range(smoke_visual.get_child_count()):
		var phase=fmod(sim.data.clock*0.7+i*0.6,3.0);smoke_visual.get_child(i).position=Vector3(phase*0.2,phase,0);smoke_visual.get_child(i).scale=Vector3.ONE*(0.5+phase*0.3)

func sandbox_ground_request(point: Vector2) -> bool:
	if sim.data.player.floor!=0:return false
	var hit: Variant=walking_hit(point)
	if hit==null:return false
	var pos=Vector2(hit.x,hit.z)
	if not sim.surface_walkable(pos):return false
	if entrance_placing or (pos.distance_to(last_ground_tap)<1.2 and Time.get_ticks_msec()-last_ground_time<900):
		entrance_placing=false;last_ground_time=0;build_point=pos;object_context.open("ground");return true
	return false
