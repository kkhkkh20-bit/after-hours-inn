extends Node3D
const Pointer=preload("res://scripts/inn_pointer.gd")
const Selection=preload("res://scripts/inn_selection.gd")
const Commands=preload("res://scripts/inn_commands.gd")
var mobile_scene=preload("res://scripts/inn_mobile_scene.gd").new()
var inn_view=false
var world_hints: Array[Label3D]=[]
var comfort=preload("res://scripts/inn_comfort.gd").new()
var pointer=Pointer.new()
var selection_options: Array=[]
var request_anchor=Vector2.ZERO
var walking_route: MeshInstance3D
const Excavation=preload("res://scripts/inn_excavation.gd")
var dig_mode=""
var view_angle=0.0
var dig_board: MeshInstance3D
var dig_route: MeshInstance3D
var dig_cancel: Button
var route_count=-1
const Tycoon=preload("res://scripts/inn_tycoon.gd")
var receptionist_visual: CharacterBody3D
var cleaner_visual: CharacterBody3D
var tycoon_room_marks: Dictionary={}
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
var owner_beacon: Label3D
var floor_journey: int=-1
var journey_entry: String=""
var earth_edges: Dictionary = {}
var earth_faces: Array = []
var viewed_floor := 0
var surface_zoom := 26.0
var basement_zoom := 14.0
var overview := true
var view_layer := "all"
const CAMERA_ARM := Vector3(6,27,22)
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
var footing: MeshInstance3D
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
	pointer.host=self
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
	environment.ambient_light_energy = 0.62
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_color = Color("a3b7ce")
	sun.light_energy = 0.50
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
	owner_beacon=world_label("▼ 주인",Vector3(0,2.7,0),player)
	owner_beacon.pixel_size=0.012;owner_beacon.modulate=Color("ffe29a");owner_beacon.no_depth_test=true
	var owner_ring=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=0.39;ring.outer_radius=0.49;owner_ring.mesh=ring;owner_ring.position.y=0.09
	var ring_mat=material(Color("ffe29a"));ring_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_mat.no_depth_test=true;owner_ring.material_override=ring_mat;player.add_child(owner_ring)
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
	camera.position = camera_arm()
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
	comfort.setup(self)
	mobile_scene.setup(self)
	if args.is_empty():start_campaign();comfort.offer_resume()
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
	world_hints.append(label)
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
	if walking_route==null:
		walking_route=preload("res://scripts/inn_route_view.gd").new();add_child(walking_route)
	walking_route.update_route(self)
	var d: Dictionary=sim.data
	var surface_shown: bool=view_layer!="below"
	if apron!=null: apron.visible=view_layer=="surface"
	for child in surface.get_children():
		if child.has_meta("outside_ground"):child.visible=view_layer=="surface"
	if footing==null:
		var previous_root=world_root;world_root=surface
		footing=box(Vector3(2.2,.12,2.2),Vector3.ZERO,Color("626551"));world_root=previous_root
	footing.position=Vector3(d.player.pos.x,-.12,d.player.pos.y)
	footing.visible=surface_shown and int(d.player.floor)==0 and not Rect2(-10,-6,20,12).has_point(d.player.pos)
	if travel_marker!=null:
		travel_marker.visible=comfort.routes and Selection.visible_floor(self,int(d.player.floor)) and not d.excavation.path.is_empty()
		if travel_marker.visible: travel_marker.position=world_point(d.excavation.path.back(),d.player.floor,0.05)
	var cellar_shown: bool=view_layer in ["all","below"]
	viewed_floor=d.player.floor
	surface.visible=surface_shown
	gallery.visible=surface_shown and view_layer!="surface"
	gallery_deck.visible=true
	basement.visible=cellar_shown
	staff_visual.visible=Selection.visible_floor(self,int(d.staff.get("floor",0))) and d.staff.hired
	collector_visual.visible=surface_shown and d.collector
	sync_actor(player,d.player.pos,dt,d.player.floor)
	player.visible=Selection.visible_floor(self,d.player.floor)
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
		actors[id].visible=(cellar_shown if person.floor==1 else surface_shown) and person.state!="gone" and Selection.visible_floor(self,person.floor)
		sync_actor(actors[id],person.pos,dt,person.floor)
		if person.state=="dining" and person.get("visit","")=="meal":
			var seated=sim.Layout.seat_display(person.pos)
			actors[id].position=world_point(seated,0,-.28)
			actors[id].rotation.y=0 if person.pos.y>0 else PI
			actors[id].get_node("LeftLeg").rotation.x=-PI/2;actors[id].get_node("RightLeg").rotation.x=-PI/2
		actors[id].rotation.z=PI/2 if person.state in ["down","dead"] or (person.state=="captive" and person.get("life",{}).get("action","")=="수면") else 0
		if person.state in ["down","dead"]:
			actors[id].position=world_point(person.pos,person.floor,0.35)
			actors[id].get_node("LeftLeg").rotation.x=0; actors[id].get_node("RightLeg").rotation.x=0
		if person.state=="restrained": actors[id].position=world_point(person.pos+Vector2(0.45,0.15),person.floor,0.08)
		# Labels remain upright even when the body is lying on its side.
		labels[id].global_rotation=Vector3.ZERO
		labels[id].global_position=world_point(person.pos,person.floor,0.95 if person.state in ["down","dead"] else 2.03)
		labels[id].text=("표적 · " if sim.Contracts.target(sim)==id and not sim.Contracts.current(sim).get("paid",false) else "")+str(person.name)
		if Sandbox.active(sim) and person.get("known",false) and person.get("faction","")!="":labels[id].text+=" · "+str(person.faction)
		if Sandbox.active(sim) and person.get("bubble_until",0)>d.clock:labels[id].text+="\n「"+str(person.get("bubble",""))+"」"
		labels[id].pixel_size=(0.014 if Sandbox.active(sim) else (0.0045 if person.floor==1 else 0.007))
		if Campaign.active(sim) and person.state in ["waiting","arriving","dining"]:
			labels[id].text+=(" · 식사 중" if d.orders.values().any(func(o):return o.guest==id and o.status=="served") else " · 주문 대기") if person.state=="dining" else (" · 말 걸기" if not person.get("known",false) else "")
		elif person.state=="waiting":labels[id].text+=" · 대기"
		if person.state=="dead":labels[id].text+=" · 사망"
		if person.state=="restrained":labels[id].text+=" · 붙잡힘"
		if person.state=="captive" and person.get("life",{}).get("informant",false):labels[id].text+=" · 정보원"
		if person.state=="captive":labels[id].text+=" · "+str(person.get("life",{}).get("action","구금"))
		labels[id].modulate=Color("ffd394") if d.ops.selected==id else Color.WHITE
	if Sandbox.active(sim):sync_sandbox_smoke()
	if Tycoon.active(sim):sync_tycoon_workers(dt)
	if Tycoon.active(sim):sync_dig_visual()
	if last_cell_count!=d.cells.size():rebuild_basement()
	if Sandbox.active(sim) and sandbox_revision!=int(d.sandbox.revision):preload("res://scripts/inn_sandbox_view.gd").build(self)
	if sandbox_visual!=null:
		for child in sandbox_visual.get_children():
			if child.has_meta("floor"):child.visible=Selection.visible_floor(self,int(child.get_meta("floor")))
			if child.has_meta("prison"):
				var cell=Sandbox.facility(sim,str(child.get_meta("prison")))
				if not cell.is_empty():
					if child.has_node("PrisonGuard"):
						child.get_node("PrisonGuard").visible=cell.get("guard",true)
						child.get_node("PrisonGuard").position.z=.6+sin(d.clock*.5)*.35
					if child.has_node("FacilityTitle"):child.get_node("FacilityTitle").text="감옥 관리 · %d/%d명" %[cell.get("members",[]).size(),cell.get("capacity",6)]
	staff_marker.text=("마라" if Campaign.active(sim) else "직원")+" · 확인 중" if d.stealth.phase!="idle" else ("직원 · 업무 거부" if d.clock<d.stealth.refuse_until else "직원")
	staff_marker.modulate=Color("ffb882") if d.stealth.suspicion>=10 else Color.WHITE
	if Sandbox.active(sim):staff_marker.text="마라 · 홀 맡는 중";staff_marker.pixel_size=0.014;hatch_lid.hide()
	vision_mesh.visible=surface_shown and d.staff.hired and show_vision
	vision_clock+=dt
	if vision_clock>=0.12 or dt==0:
		vision_clock=0
		refresh_vision()
	tool_pivot.visible=d.player.floor==1 and d.ops.drag==""
	tool_pivot.rotation.x=sin(clampf(1.0-float(d.dig.remaining)/float(d.dig.get("duration",.8)),0,1)*PI)*0.85-0.3 if not d.dig.is_empty() else -0.2
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
	if inn_view:return Vector3(-2,0,1)
	if overview and Sandbox.active(sim):
		if view_layer=="all":return Vector3(5,-.5,7)
		if view_layer=="below":return Sandbox.OFFSET+Vector3(10,0,-5)
		if view_layer=="rooms":return Vector3(1.5,3.2,-4.8)
		return Vector3(3.0,.8,.7)
	if overview:return CELLAR_OFFSET+Vector3(4,.7,1) if view_layer=="below" else Vector3(0,1,0)
	return world_point(sim.data.player.pos,sim.data.player.floor)

func set_layer(value: String) -> void:
	if object_context!=null:object_context.close()
	inn_view=false;view_layer=value;overview=true;camera_offset=Vector2.ZERO
	camera.size={"all":68.0,"below":48.0,"rooms":24.0,"surface":44.0}.get(value,31.0)
	camera_focus=focus_position();camera.position=camera_focus+camera_arm();camera.look_at(camera_focus)
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
	box(Vector3(18.2,0.6,0.2),Vector3(0,3.55,-8.5),Color("9a8568"))
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
	world_root=surface
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
	Commands.reset_view(self)
	if DisplayServer.get_name()!="headless":
		if ambience==null:
			ambience=AudioStreamPlayer.new();ambience.stream=preload("res://assets/audio/inn-wind.wav");ambience.volume_db=-26;add_child(ambience)
			ambience.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;ambience.stream.loop_begin=0;ambience.stream.loop_end=128000
			room_chime=AudioStreamPlayer.new();room_chime.stream=preload("res://assets/audio/inn-chime.wav");room_chime.volume_db=-19;add_child(room_chime)
		ambience.play()
	Campaign.start(sim);sim.rebuild_guest_grid();
	for id in sim.data.people:
		if sim.data.people[id].state=="arriving" and sim.data.people[id].get("role","")=="":sim.retarget_arrival(id)
	basement.position=Sandbox.OFFSET;camera.keep_aspect=Camera3D.KEEP_WIDTH
	for child in basement.get_children():
		if child!=terrain and child!=cellar_lamp:child.hide()
	hatch_lid.hide();last_cell_count=-1;sandbox_revision=-1
	for child in surface.get_children():
		if child is Label3D and child.text.begins_with("지하 입구"):child.hide()
	world_root=surface
	box(Vector3(1.65,0.18,1.65),Vector3(Simulation.HATCH.x,-0.02,Simulation.HATCH.y),Color("604c36"))
	episode.data.briefed=true;episode_ui.root.hide();sim.data.campaign.intro=false;show_inn()

func context_opened(kind_: String) -> void:
	if Campaign.active(sim) and kind_ in ["conversation","guard_talk","staff_talk","automation","pick","room","navigation","person","actions","other","system","confirm","comfort","help","recent","resume"] and not dialogue_paused:
		dialogue_previous_pause=sim.data.paused;dialogue_paused=true;sim.data.paused=true

func context_closed(_kind: String) -> void:
	if dialogue_paused:sim.data.paused=dialogue_previous_pause;dialogue_paused=false

func rest_until_dawn() -> void:
	if not Campaign.can_rest(sim):return
	while not sim.data.campaign.summary and sim.data.campaign.ending=="":
		sim.tick(0.5);Campaign.tick(sim)
	journal.refresh()

func save_game() -> void:
	comfort.save("user://inn-tycoon-v15.json" if Campaign.active(sim) else "user://inn-v03.json")

func load_game(source: String="") -> void:
	var save_path=source if source!="" else ("user://inn-tycoon-v15.json" if Campaign.active(sim) else "user://inn-v03.json")
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(save_path+".bak"):save_path+=".bak"
	if not FileAccess.file_exists(save_path):
		sim.note("저장된 기록이 없다. 메뉴에서 먼저 저장하자.")
		return
	var saved: Variant=comfort.read_save(save_path)
	var loaded=sim.restore(saved)
	if not loaded and FileAccess.file_exists(save_path+".bak"):
		saved=comfort.read_save(save_path+".bak");loaded=sim.restore(saved)
	if not loaded:
		sim.note("이 버전에서 읽을 수 없는 저장 파일이다.")
		return
	Commands.reset_view(self)
	if sim.data.has("episode"):
		episode.data=sim.data.episode.duplicate(true)
		episode_ui.ending_shown=false
	if Tycoon.active(sim) and sim.data.ops.reports==0:sim.data.ops.inspector.state="idle";sim.data.stealth.suspicion=0;sim.data.stealth.phase="idle"
	if Campaign.active(sim):
		sim.data.paused=false;episode_ui.root.hide();journal.opened=false;journal.panel.hide();journal.refresh()
	last_cell_count=-1
	sim.note("저장한 상태로 돌아왔다.")
	comfort.restore_meta(saved)
	sync_view(0)

func pan_camera(relative: Vector2) -> void:
	if not overview:
		var at=focus_position()+Vector3(camera_offset.x,0,camera_offset.y)
		overview=true
		var base=focus_position();camera_offset=Vector2(at.x-base.x,at.z-base.z)
	var scale_: float=camera.size/get_viewport().get_visible_rect().size.x
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	camera_offset-=(right*relative.x+down*relative.y)*scale_
	camera_offset=camera_offset.limit_length(70)

func _input(event: InputEvent) -> void:
	var modal=(episode_ui!=null and episode_ui.opened) or (journal!=null and journal.opened)
	var point=Vector2.ZERO
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:point=event.position
	pointer.observe(event,modal or (mobile_ui!=null and mobile_ui.blocks_point(point)))
	if event is InputEventMouseMotion or event is InputEventScreenDrag:pointer_position=event.position
	if not modal and event is InputEventMagnifyGesture:
		camera.size=clampf(camera.size/event.factor,12,90);comfort.zoom=camera.size;comfort.remember();get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not ((journal!=null and journal.opened) or (episode_ui!=null and episode_ui.opened)):
		if object_context.panel.visible:object_context.close()
		else:cancel_everything()
		get_viewport().set_input_as_handled();return
	if episode_ui!=null and episode_ui.opened or journal!=null and journal.opened: return
	if event is InputEventKey and event.pressed and not event.echo:
		if Campaign.active(sim) and event.physical_keycode not in [KEY_ESCAPE,KEY_M,KEY_F5,KEY_F9]:return
		match event.physical_keycode:
			KEY_ESCAPE:
				if object_context.panel.visible:object_context.close()
				elif dig_mode!="":
					dig_mode=""
					if dig_cancel!=null:dig_cancel.hide()
				else:object_context.open("system")
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
	if event is InputEventMouseButton and event.device!=-1 and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(12,camera.size-2);comfort.zoom=camera.size;comfort.remember()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(90,camera.size+2);comfort.zoom=camera.size;comfort.remember()
	if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed):
		var tap: Dictionary=pointer.take()
		if not tap.is_empty():world_tap(tap.point,tap.candidates)

func world_tap(point: Vector2,captured: Variant=null) -> void:
	if mobile_ui.blocks_point(point):return
	pointer_position=point
	var choices: Array=captured if captured!=null else selection_candidates(point)
	if object_context.panel.visible:
		object_context.close()
	if dig_mode!="":apply_dig_point(point);return
	var transit=transit_at(point)
	if not transit.is_empty() and not choices.any(func(c):return c.get("body",false) and c.kind!="owner"):
		request_floor(int(transit.floor),str(transit.get("entry","")));return
	if not choices.is_empty():
		request_anchor=point
		selection_options=choices
		if choices.size()>1:object_context.open("pick","","누구를 선택할까요?")
		else:activate_selection(choices[0])
		return
	if Sandbox.active(sim) and sandbox_objects(point):return
	if view_layer!="below":
		if Selection.visible_floor(self,0) and point.distance_to(camera.unproject_position(world_point(Simulation.COUNTER,0,0.8)))<44:
			object_context.open("counter");return
		if Selection.visible_floor(self,0) and point.distance_to(camera.unproject_position(world_point(Simulation.STAIRS,0,0.4)))<30:
			request_floor(0 if sim.data.player.floor==2 else 2);return
		for number in ([1,2,3,4,5] if Sandbox.active(sim) else [1,2]):
			var floor_=Sandbox.floor_of(number)
			if not Selection.visible_floor(self,floor_):continue
			var rp=Sandbox.room_point(number) if Sandbox.active(sim) else sim.room_target(number)
			var center=camera.unproject_position(world_point(rp,floor_,0.6))
			var bed=camera.unproject_position(world_point(Vector2(5.6,-2.0 if number==1 else 2.0) if number<3 else rp,floor_,0.65))
			if point.distance_to(center)<44 or point.distance_to(bed)<44:object_context.open("room",str(number));return
	var target_floor=1 if view_layer=="below" else (2 if view_layer=="rooms" else int(sim.data.player.floor))
	if target_floor!=sim.data.player.floor:
		request_anchor=point;object_context.open("navigation",str(target_floor),"화면만 보고 있습니다. 주인을 이 층으로 이동할까요?");return
	if sim.data.player.floor==1:
		var soil=soil_at(point)
		if soil!=Vector2i(99,99):
			context_soil=soil
			if Tycoon.active(sim):sim.data.sandbox.tunnel_plan=[];sim.queue_dig(soil)
			else:object_context.open("soil")
			return
	var hit: Variant=walking_hit(point)
	if hit!=null:Commands.move(self,Vector2(hit.x,hit.z))

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
		if displayed_floor==0:show_inn()
		elif not overview:frame_owner()
		elif view_layer!="all":set_layer("below" if displayed_floor==1 else ("rooms" if displayed_floor==2 else "surface"))
		object_context.close()
	advance_floor_journey()
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
	if not pointer.pressed and not object_context.panel.visible:
		camera_focus=camera_focus.lerp(focus_target,1.0-exp(-delta*6))
	camera.position=camera_focus+camera_arm()
	camera.look_at(camera_focus)
	sync_view(delta)
	episode_ui.refresh()
	if Campaign.active(sim):
		if room_chime!=null and sim.data.money>last_cash and not muted:room_chime.play()
		last_cash=sim.data.money
		if ambience!=null:ambience.volume_db=-80 if muted else -26
	if journal!=null:journal.refresh()
	comfort.tick(delta)
	mobile_scene.update()

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

func follow_owner(snap: bool=true) -> void:
	inn_view=false
	var floor_=int(sim.data.player.floor)
	var layer_="below" if floor_==1 else ("rooms" if floor_==2 else "surface")
	if view_layer!=layer_ and object_context!=null:object_context.close()
	view_layer=layer_;overview=false;camera_offset=Vector2.ZERO
	if snap:
		camera.size=comfort.zoom
		camera_focus=focus_position()
		camera.position=camera_focus+camera_arm();camera.look_at(camera_focus)
	sync_view(0)

func frame_owner() -> void:
	if object_context!=null:object_context.close()
	follow_owner(true)

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
	if Tycoon.active(sim):return "%d닢 · 객실 %d/5 · 오늘 매출 %d · 알바 %d명" %[sim.data.money,sim.data.rooms.values().filter(func(r):return r.guest!="").size(),sim.data.tycoon.day_sales,1+int(sim.data.tycoon.reception)+int(sim.data.tycoon.cleaning)]
	if Campaign.active(sim):return "%d닢 · 새벽 납부 %d · 평판 %d · 신고 %d" %[sim.data.money,Campaign.daily_cost(sim),sim.data.campaign.reputation,sim.data.ops.reports]
	return "%d닢 · 손님 %d · 식사 %d%s" %[sim.data.money,sim.data.people.values().filter(func(p): return p.state!="gone").size(),sim.data.served," · 멈춤" if sim.data.paused else ""]

func context_title(kind_: String,id_: String) -> String:
	if kind_ in ["confirm","comfort","operations","recent","help","resume"]:return {"resume":"이전 영업 이어하기","confirm":"실행 확인","comfort":"조작·화면·소리","operations":"손님·객실 바로 찾기","recent":"최근 알림","help":"조작 도움말"}[kind_]
	if kind_=="pick":return "대상 선택"
	if kind_=="contracts":return "현상수배 게시판"
	if kind_=="intel_archive":return "정보와 단서 기록"
	if kind_=="prison_overview":return "감옥 전체 관리"
	if kind_=="prison_policy":return "생활 일정"
	if kind_=="prison_settings":return "경비와 증설"
	if kind_=="questioning":return "심문과 금품"
	if kind_=="zones":return "구역 바로 보기"
	if kind_ in ["prison","prison_roster"]:return "감옥 생활 관리"
	if kind_=="inmate":return sim.data.people[id_].name+" · 수감 생활"
	if kind_=="counter_more":return "접수대 · 다른 관리"
	if kind_=="navigation":return "층 이동"
	if kind_=="conversation":return str(sim.data.people[id_].name)
	if kind_=="ground":return "비밀 입구 자리"
	if kind_=="cellar_floor":return "지하 시설 공사"
	if kind_=="portal":return Sandbox.entrance(sim,id_).get("name","비밀 입구")
	if kind_=="dig_tools":return "구멍과 통로 파기"
	if kind_=="build_tools":return "지하 시설 설치"
	if kind_=="view_tools":return "화면 방향"
	if kind_=="automation":return "알바 고용 · 여관 성장"
	if kind_=="facility":return Sandbox.TYPES[Sandbox.facility(sim,id_).type].name
	if kind_=="guard_talk":return "국경 순찰대"
	if kind_=="staff_talk":return "마라 · 믿을 수 있는 동료"
	if kind_=="person": return str(sim.data.people[id_].name)+(" · 식사" if sim.data.people[id_].get("visit","")=="meal" else "")
	if kind_=="room": return room_text(int(id_))
	return {"counter":"접수대 · 장부","hatch":"지하 입구","stairs":"계단","soil":"흙벽","lamp":"지하 등불","staff":"직원","owner":"여관 주인","system":"여관 설정","actions":"손님에게 할 행동","inspector":"국경 경비"}.get(kind_,"여관")

func context_anchor(kind_: String,id_: String) -> Vector2:
	if kind_ in ["pick","navigation"]:return request_anchor
	var pos: Vector2=Simulation.COUNTER; var floor_: int=sim.data.player.floor
	match kind_:
		"person","actions","other","conversation","inmate","questioning":
			if sim.data.people.has(id_): pos=sim.data.people[id_].pos; floor_=sim.data.people[id_].floor
		"room": pos=Sandbox.room_point(int(id_)) if Sandbox.active(sim) else Vector2(5.6,-2.0 if id_=="1" else 2.0); floor_=Sandbox.floor_of(int(id_))
		"ground":pos=build_point;floor_=0
		"cellar_floor":pos=Vector2(build_cell);floor_=1
		"facility","prison","prison_roster","prison_policy","prison_settings":pos=Sandbox.facility(sim,id_).pos;floor_=1
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
	if kind_ in ["confirm","comfort","operations","recent","help","resume"]:return comfort.items(kind_)
	if kind_=="counter_more":return [["zones","넓은 지도 · 구역 보기"],["recruit","마라와 이야기"],["private_entry","주인 전용 창고로 이동"],["view_tools","화면 방향"],["system","저장·설정"]]
	if Sandbox.active(sim) and kind_=="owner":
		var items=[]
		if command_status()!="":items.append(["stop","현재 작업 취소"])
		if sim.data.ops.drag!="" or sim.data.player.carry!="":items.append(["drop","운반 내려놓기"])
		items.append(["build_tools","지하 시설 설치"] if sim.data.player.floor==1 else ["private_entry","비밀 창고로 이동"])
		items.append(["operations","손님·객실 바로 찾기"])
		items.append(["contracts","현상수배 · 범죄 의뢰"])
		if items.size()<4:items.append(["prison_overview","감옥 전체 관리"])
		if items.size()<4:items.append(["dig_tools","구멍·통로 파기"])
		return items
	if kind_=="contracts":
		sim.Contracts.ensure(sim);var case=sim.Contracts.current(sim)
		var entries=[sim.Contracts.next_action(sim)]
		if not case.is_empty():entries.append(["case_focus","표적 위치 보기"])
		entries.append(["intel_archive","정보·단서 기록"]);entries.append(["prison_overview","감옥 전체 관리"]);return entries
	if kind_=="questioning":
		var p: Dictionary=sim.data.people[id_];sim.Prison.ensure(sim);sim.Contracts.profile(p)
		var q: Dictionary=p.questioning;var ready=sim.data.clock>=float(q.cooldown) and not q.intel
		return [["question","차분히 심문 · 진술 +35" if ready else "심문 대기 / 진술 확보됨",ready],["recruit_informant","협력 제안 · 정보원으로 영입" if not p.life.informant else "정보원이 보고 중",not p.life.informant and p.life.trust>=40 and p.life.mood>=40],["ransom","금품 회수 완료" if q.money else "금품 갈취 · 20닢",not q.money],["coerce","강압 심문 · 빠르지만 불확실",ready],["verify_intel","정보 대조 · 정보 1건 또는 5닢",q.intel and not q.reliable]]

	if kind_=="zones":return [["zone:inn","중앙 여관"],["zone:west","서쪽 식당"],["zone:prison","지하 서쪽 수감동"],["zone:security","지하 동쪽 보안동"],["zone:expansion","지하 남쪽 확장동"]]
	if kind_=="prison_overview":
		sim.Prison.ensure(sim);var entries=[["secure_all","전체 식사·휴식·기본 경비 복구"]]
		var cells=sim.Prison.cells(sim)
		for index in cells.size():
			var cell: Dictionary=cells[index];entries.append(["open_prison:"+str(cell.id),"%d번 감옥 · %d/%d명 · 보안 %d" %[index+1,cell.members.size(),cell.capacity,sim.Prison.security(cell)]])
		return entries
	if kind_=="prison":return [["group_care","식사·휴식·경비 한 번에 관리"],["prison_roster","수감자 목록"],["prison_policy","생활 일정 선택"],["prison_settings","경비·증설 설정"]]
	if kind_=="prison_policy":return [["policy:balanced","균형 자동 관리"],["policy:comfort","휴식 우선 · 신뢰 회복"],["policy:lockdown","30초 임시 봉쇄 후 자동 해제"],["prison_back","감옥 관리로"]]
	if kind_=="prison_settings":
		var cell=Sandbox.facility(sim,id_);sim.Prison.ensure(sim)
		return [["care_toggle","자동 돌봄 끄기" if cell.care else "자동 돌봄 켜기"],["security_toggle","경비·잠금 해제" if cell.guard else "경비·잠금 켜기"],["prison_expand","수용 인원 +2 · 8닢",int(cell.capacity)<12],["prison_back","감옥 관리로"]]

	if kind_=="prison_roster":
		sim.Prison.ensure(sim);var cell=Sandbox.facility(sim,id_);var entries=[]
		for inmate in cell.members:entries.append(["inmate:"+inmate,sim.data.people[inmate].name+" · "+str(sim.data.people[inmate].life.action)])
		return entries if not entries.is_empty() else [["prison_back","수감자가 없습니다 · 감옥으로"]]
	if kind_=="inmate":return [["questioning","심문·정보·금품 갈취"],["feed_inmate","식사 주기"],["rest_inmate","편히 쉬게 하기"],["release_inmate","석방하기"],["inmate_prison","감옥 관리"]]
	if kind_=="pick":
		var items=[]
		for i in selection_options.size():
			var c: Dictionary=selection_options[i]
			var name_=str(sim.data.people[c.id].name) if c.kind=="person" and sim.data.people.has(c.id) else {"owner":"주인","staff":"마라 · 직원","inspector":"국경 경비","prison":"감옥 관리"}.get(c.kind,"대상")
			items.append(["pick:"+str(i),name_])
		return items
	if kind_=="navigation":return [["go_floor","이 층으로 이동"]]
	if kind_=="build_tools":return [["place_build:prison","감옥 · 6닢"],["place_build:stash","은닉 창고 · 4닢"],["place_build:refuge","은신처 · 6닢"],["place_build:furnace","처리 화로 · 10닢"]]
	if kind_=="dig_tools":return [["build_tools","지하 시설 설치",sim.data.player.floor==1],["place_shaft","구멍 파기 · 지상 위치 지정 / 3닢"],["place_tunnel","통로 파기 · 지하 목적지 지정"],["stop_dig","굴착 계획 취소"]]
	if kind_=="view_tools":return [["view_front","앞에서 보기"],["view_back","뒤에서 보기"],["view_left","왼쪽에서 보기"],["view_right","오른쪽에서 보기"]]
	if kind_=="automation":
		var t: Dictionary=sim.data.tycoon
		return [["hire_reception","접수 알바 · 근무 중" if t.reception else "접수 알바 · 10닢 / 일당 2닢",not t.reception],["hire_cleaning","청소 알바 · 근무 중" if t.cleaning else "청소 알바 · 10닢 / 일당 2닢",not t.cleaning],["upgrade_kitchen","주방 개선 · %d닢 / 식사값·속도 상승" %(12+int(t.kitchen)*8),int(t.kitchen)<3],["delegate","마라에게 식사 자동 운영 맡기기"]]
	if kind_=="conversation":return Dialogue.options(sim,id_)
	if Sandbox.active(sim):
		match kind_:
			"ground":return [["walk_here","여기로 이동"],["make_entrance","이곳에 구멍 파기 · 3닢"]]
			"cellar_floor":return [["place_tunnel","통로 파기 · 목적지 지정"],["walk_below","여기로 이동"],["build_prison","감옥 · 6닢"],["build_stash","은닉 창고 · 4닢"],["build_refuge","은신처 · 6닢"],["build_furnace","처리 화로 · 10닢"],["surface_exit","이 위치에 지상 출구 공사 · 3닢"]]
			"portal":
				var e_=Sandbox.entrance(sim,id_)
				var items=[["portal_use",("올라가기" if sim.data.player.floor==1 else "내려가기")+(" · 덮개 자동 닫힘" if sim.data.get("tycoon",{}).get("easy",false) else "")],["portal_cover","덮개 숨기기 · 현재 열림" if e_.get("open",false) else "덮개 열기 · 현재 숨김"],["dig_tools","구멍·통로 파기"]]
				for e in sim.data.sandbox.entrances:
					if e.id!=id_:items.append(["connect:"+e.id,e.name+"까지 통로 연결"])
				return items
			"facility":
				var f=Sandbox.facility(sim,id_)
				return [["facility_use",{"prison":"데려온 대상 구금 / 감옥 확인","furnace":"운반 중인 시신 처리 · 12초","stash":"의뢰 상자 은닉 · 추가 6닢","refuge":"데려온 사람 보호"}[f.type]],["facility_remove","시설 철거 · 절반 환급"]]
			"owner":return [["stop","현재 행동 취소"],["automation","알바 고용 · 여관 성장"],["floor","가까운 입구로 층 이동"],["dig_tools","구멍·통로 파기"],["drop","운반 내려놓기"],["journal","장부 · 의뢰"],["system","저장 · 화면 설정"]]
			"room":
				var level=int(sim.data.tycoon.rooms[id_]) if Tycoon.active(sim) else 0
				return [["room_chat","묵는 손님과 이야기"],["room_chute_target","객실 시신을 비밀 통로로 보내기"],["upgrade_room","객실 개선 · %d닢 / 숙박비 +2닢" %(8+level*6),level<3],["clean","정리하기"],["automation","알바 고용 · 자동화"]]
	if kind_=="guard_talk":
		var items=[["guard_honest","장부를 보여드리겠습니다."],["guard_lie","식재료 창고뿐입니다."],["guard_pay","수고비를 받으시죠. · 8닢"]]
		if sim.data.campaign.ledger_found:items.push_front(["guard_evidence","이 반입 허가를 확인해보시죠."])
		return items
	if kind_=="staff_talk":return [["automation","접수·청소 알바 고용"],["delegate","식사는 계속 맡아주세요."],["takeover","내가 직접 서빙할게요."],["ally_story","손님들 사이에 무슨 일이 있나요?"]]
	if Campaign.active(sim) and kind_=="counter":return [["contracts","현상수배 · 범죄 의뢰"],["automation","알바 고용·주방 개선"],["journal","영업 장부"],["counter_more","지도·창고·다른 관리"]]
	if sim.data.paused and not dialogue_paused and kind_!="system": return [["resume","영업 계속"],["journal","오늘의 장부"],["system","저장 · 화면 설정"]]
	match kind_:
		"person":
			var p: Dictionary=sim.data.people[id_]
			if p.state=="dead": return [["room_chute","객실 비밀 통로로 지하에 보내기"],["drag","끌기 / 내려놓기"],["greet","상태 확인"]] if sim.Layout.room_of_body(sim,id_)>0 else [["drag","끌기 / 내려놓기"],["greet","상태 확인"]]
			if p.state=="restrained": return [["imprison","감옥에 가두기 · 자동 호송"],["sleep","잠시 기절시키기"],["kill","살해"],["drop","놓아주기"]]
			if p.state in ["down","captive"]: return [["imprison","감옥에 가두기 · 자동 호송"],["drag","끌기 / 석방"],["kill","살해"],["greet","상태 확인"]]
			if p.state in ["waiting","arriving"] and p.get("visit","")!="meal":
				var items=[["admit1","1호 정리 후 안내" if sim.data.rooms["1"].dirty else ("1호 사용 중" if sim.data.rooms["1"].guest!="" else "1호로 안내"),sim.data.rooms["1"].guest==""],["admit2","2호 정리 후 안내" if sim.data.rooms["2"].dirty else ("2호 사용 중" if sim.data.rooms["2"].guest!="" else "2호로 안내"),sim.data.rooms["2"].guest==""],["greet","말 걸기"]]
				if not sim.gentle_opening() or sim.data.served>=3: items.append(["actions","다른 행동"])
				return items
			var items=[["service","식사 내어주기"],["greet","말 걸기"]]
			if not sim.gentle_opening() or sim.data.served>=3: items.append(["actions","다른 행동"])
			return items
		"actions": return [["imprison","감옥에 가두기 · 자동 호송"],["grab","붙잡기"],["sleep","잠시 기절시키기"],["kill","살해"],["other","다른 조치"]]
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
		"system": return [["operations","손님·객실 바로 찾기"],["comfort","조작·화면·소리"],["recent","최근 알림 다시 보기"],["load_auto","자동 저장 이어하기",FileAccess.file_exists(comfort.AUTO)],["zones","넓은 지도 · 구역 보기"],["easy_toggle","쉬운 운영 끄기 · 고용 유지" if sim.data.get("tycoon",{}).get("easy",false) else "쉬운 운영 켜기 · 무료 직원 지원"],["view_tools","앞·뒤·옆에서 보기"],["pause","일시 정지"],["overview","여관 전체 보기"],["follow","주인 따라 보기"],["save","저장"],["load","불러오기"],["fullscreen","전체화면 전환"]]
	return []

func floor_route_step(target: int,entry: String="") -> bool:
	if int(sim.data.player.floor)==target:return true
	follow_owner(false)
	if sim.data.player.floor==2 or (sim.data.player.floor==0 and target==2):return sim.queue_gallery()
	if entry!="":return Sandbox.use_entrance(sim,entry)
	return sim.queue_floor()

func travel_to_floor(target: int) -> void:
	floor_route_step(target)

func request_floor(target: int,entry: String="") -> void:
	if object_context!=null:object_context.close()
	if sim.data.paused:sim.note("일시정지 중입니다. 상단 재개를 눌러주세요.");return
	if int(sim.data.player.floor)==target:
		if target==0:show_inn()
		else:frame_owner()
		return
	Commands.cancel(self,true)
	floor_journey=target;journey_entry=entry
	follow_owner(true)
	advance_floor_journey()

func advance_floor_journey() -> void:
	if floor_journey<0 or sim.data.paused:return
	if sim.data.player.floor==floor_journey:
		var arrived=floor_journey;floor_journey=-1;journey_entry=""
		if arrived==0:show_inn()
		else:follow_owner(false)
		return
	if sim.data.excavation.intent!="" or not sim.data.work.is_empty():return
	if not floor_route_step(floor_journey,journey_entry):
		floor_journey=-1;journey_entry="";sim.note("층 이동 경로가 막혀 있습니다. 다른 입구를 선택해주세요.")

func transit_at(point: Vector2) -> Dictionary:
	var best={};var distance=INF
	if Sandbox.active(sim):
		for e in sim.data.sandbox.entrances:
			for floor_ in [0,1]:
				if not Selection.visible_floor(self,floor_):continue
				var pos: Vector2=e.top if floor_==0 else Vector2(e.bottom)
				var foot=camera.unproject_position(world_point(pos,floor_,.1))
				var head=camera.unproject_position(world_point(pos,floor_,1.65 if floor_==1 else .35))
				var d=point.distance_to(Geometry2D.get_closest_point_to_segment(point,foot,head))
				var label=camera.unproject_position(world_point(pos+Vector2(0,.9),floor_,.35))
				if Rect2(label-Vector2(75,12),Vector2(150,24)).has_point(point):d=minf(d,12)
				if d<30 and d<distance:best={"floor":0 if floor_==1 else 1,"entry":e.id};distance=d
	for floor_ in [0,2]:
		if not Selection.visible_floor(self,floor_):continue
		var bottom=camera.unproject_position(world_point(Simulation.STAIRS,floor_,.2))
		var upper=camera.unproject_position(world_point(Vector2(8,1),2,.2))
		var d=point.distance_to(Geometry2D.get_closest_point_to_segment(point,bottom,upper))
		if d<30 and d<distance:best={"floor":0 if sim.data.player.floor==2 else 2};distance=d
	return best

func context_action(kind_: String,id_: String,action: String) -> void:
	if comfort.gate(kind_,id_,action):return
	if comfort.act(kind_,id_,action):return
	if kind_ in ["person","conversation","actions","other"] and (not sim.data.people.has(id_) or sim.data.people[id_].state=="gone"):
		sim.note("그 손님은 이미 떠났습니다.");return
	if action.begins_with("pick:"):
		var index=int(action.get_slice(":",1))
		if index>=0 and index<selection_options.size():activate_selection(selection_options[index])
		return
	if action=="prison_overview":object_context.open("prison_overview","",sim.Prison.overview(sim));return
	if action=="secure_all":
		for cell in sim.Prison.cells(sim):sim.Prison.group_care(sim,cell.id)
		object_context.open("prison_overview","",sim.Prison.overview(sim));return
	if action.begins_with("open_prison:"):
		var id=action.trim_prefix("open_prison:");var cell=Sandbox.facility(sim,id);set_layer("below")
		var point=world_point(cell.pos,1);var focus=focus_position();camera_offset=Vector2(point.x-focus.x,point.z-focus.z);camera_focus=point;camera.size=22;camera.position=camera_focus+camera_arm();camera.look_at(camera_focus)
		object_context.open("prison",id,sim.Prison.summary(sim,id));return
	if action=="group_care":sim.Prison.group_care(sim,id_);object_context.open("prison",id_,sim.Prison.summary(sim,id_));return
	if action in ["prison_policy","prison_settings"]:object_context.open(action,id_);return
	if action.begins_with("policy:"):sim.Prison.policy(sim,id_,action.get_slice(":",1));object_context.open("prison",id_,sim.Prison.summary(sim,id_));return
	if action=="recruit_informant":sim.Prison.recruit(sim,id_);object_context.open("inmate",id_,sim.Prison.inmate_summary(sim,id_));return
	if action in ["case_question","case_ransom","case_verify"]:
		var id=sim.Contracts.target(sim);sim.Contracts.act(sim,id,{"case_question":"question","case_ransom":"ransom","case_verify":"verify_intel"}[action]);sim.Contracts.tick(sim);object_context.open("contracts","",sim.Contracts.summary(sim));return
	if action=="case_capture":Commands.cancel(self,true);sim.Prison.request(sim,sim.Contracts.target(sim));return
	if action=="intel_archive":object_context.open("intel_archive","",sim.Contracts.archive(sim));return
	if action=="contracts":sim.Contracts.ensure(sim);object_context.open("contracts","",sim.Contracts.summary(sim));return
	if action=="case_accept":sim.Contracts.accept(sim);object_context.open("contracts","",sim.Contracts.summary(sim));return
	if action=="case_dossier":
		var target=sim.Contracts.target(sim)
		if target!="":object_context.open("contracts","",sim.Contracts.dossier(sim,target)+"\n"+sim.Contracts.summary(sim))
		return
	if action=="case_claim":sim.Contracts.claim(sim);object_context.open("contracts","",sim.Contracts.summary(sim));return
	if action=="case_next":
		if sim.Contracts.current(sim).get("paid",false):sim.Contracts.next(sim)
		else:sim.Contracts.retry(sim)
		object_context.open("contracts","",sim.Contracts.summary(sim));return
	if action=="case_focus":
		var target=sim.Contracts.target(sim)
		if sim.data.people.has(target):
			var person: Dictionary=sim.data.people[target];set_layer("below" if person.floor==1 else ("rooms" if person.floor==2 else "surface"));camera_offset=person.pos-Vector2(focus_position().x,focus_position().z)+(Vector2(Sandbox.OFFSET.x,Sandbox.OFFSET.z) if person.floor==1 else Vector2.ZERO);camera.size=22
		return
	if action=="questioning":object_context.open("questioning",id_,sim.Contracts.questioning(sim,id_));return
	if action in ["question","ransom","coerce","verify_intel"]:
		sim.Contracts.act(sim,id_,action);object_context.open("questioning",id_,sim.Contracts.questioning(sim,id_));return
	if action=="dossier":object_context.open("conversation",id_,sim.Contracts.dossier(sim,id_));return
	if action=="zones":object_context.open("zones");return
	if action.begins_with("zone:"):
		var zone=action.get_slice(":",1);set_layer("surface" if zone in ["inn","west"] else "below")
		var point={"inn":Vector2(0,0),"west":Vector2(-16,0),"prison":Vector2(-14,-7),"security":Vector2(38,-7),"expansion":Vector2(12,15)}[zone]
		var world=world_point(point,0 if zone in ["inn","west"] else 1);var focus=focus_position();camera_offset=Vector2(world.x-focus.x,world.z-focus.z);camera.size=28 if zone!="inn" else 38
		return
	if action=="imprison":
		Commands.cancel(self,true);sim.Prison.request(sim,id_);return
	if action=="prison_roster":object_context.open("prison_roster",id_);return
	if action=="prison_back":object_context.open("prison",id_,sim.Prison.summary(sim,id_));return
	if action.begins_with("inmate:"):
		var inmate=action.trim_prefix("inmate:");object_context.open("inmate",inmate,sim.Prison.inmate_summary(sim,inmate));return
	if action=="inmate_prison":
		var cell=str(sim.data.people[id_].get("prison",""));object_context.open("prison",cell,sim.Prison.summary(sim,cell));return
	if action in ["feed_inmate","rest_inmate","release_inmate","care_toggle","security_toggle","prison_expand"]:
		sim.Prison.manage(sim,id_,action)
		if action=="release_inmate":return
		object_context.open("inmate" if kind_=="inmate" else "prison",id_,sim.Prison.inmate_summary(sim,id_) if kind_=="inmate" else sim.Prison.summary(sim,id_));return
	if action=="build_tools":object_context.open("build_tools");return
	if action.begins_with("place_build:"):set_dig_mode("build:"+action.get_slice(":",1));return
	if action=="easy_toggle":
		Tycoon.set_easy(sim,not sim.data.get("tycoon",{}).get("easy",false));sim.note("쉬운 운영 설정을 변경했습니다.");return
	if action=="go_floor":
		Commands.cancel(self,true)
		pending_context_action={"kind":"arrival","id":"","action":"floor_arrived","floor":int(id_)}
		travel_to_floor(int(id_));return
	if action=="room_chute_target":
		for body in sim.data.people:
			if sim.Layout.room_of_body(sim,body)==int(id_):context_action("person",body,"room_chute");return
		sim.note("객실 안에 옮길 시신이 없습니다.");return
	if action=="room_chute":
		if sim.data.player.floor!=sim.data.people[id_].floor:
			Commands.cancel(self,true);pending_context_action={"kind":"person","id":id_,"action":"room_chute","floor":int(sim.data.people[id_].floor)};travel_to_floor(int(sim.data.people[id_].floor));return
		sim.Layout.send_body(sim,id_);return
	if action=="floor_arrived":return
	if action=="counter_more":object_context.open("counter_more");return
	if action=="stop":
		Commands.cancel(self);dig_mode=""
		if dig_cancel!=null:dig_cancel.hide()
		return
	if action=="greet" and Tycoon.active(sim) and sim.data.people.has(id_) and sim.data.people[id_].get("role","")=="" and sim.data.people[id_].state not in ["down","dead","restrained","captive","sheltered"]:
		object_context.open("conversation",id_,Dialogue.begin(sim,id_));return
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
		"follow": frame_owner(); return
		"save": save_game(); return
		"load": load_game(); return
		"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED); return
		"stop":
			if Sandbox.active(sim):stop_digging()
			pending_context_action.clear(); sim.data.booking_request={}; sim.cancel_work(); sim.data.service_target=""; auto_floor_goal.clear(); return
		"floor": request_floor(0 if sim.data.player.floor==1 else 1); return
		"gallery": request_floor(0 if sim.data.player.floor==2 else 2); return
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
	set_physics_process(false);capturing=true;Campaign.start(sim);sim.rebuild_guest_grid();basement.position=Sandbox.OFFSET;camera.keep_aspect=Camera3D.KEEP_WIDTH
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
				request_floor(0 if floor_==1 else 1,e.id);return true
	if sim.data.player.floor==1 and Selection.visible_floor(self,1):
		for f in sim.data.sandbox.facilities:
			if point.distance_to(camera.unproject_position(world_point(f.pos,1,0.5)))<26:object_context.open("prison",f.id,sim.Prison.summary(sim,f.id)) if f.type=="prison" else object_context.open("facility",f.id);return true
		var hit: Variant=walking_hit(point)
		if hit!=null:
			var cell=Vector2i(roundi(hit.x),roundi(hit.z))
			if sim.data.cells.has(Simulation.cell_key(cell)):
				build_cell=cell;object_context.open("cellar_floor");return true
	elif sim.data.player.floor==0:
		var hit: Variant=walking_hit(point)
		if hit!=null and sim.surface_walkable(Vector2(hit.x,hit.z)):
			var pos=Vector2(hit.x,hit.z)
			if entrance_placing:
				entrance_placing=false;build_point=pos;object_context.open("ground");return true
			last_ground_tap=pos;last_ground_time=Time.get_ticks_msec()
	return false

func sandbox_action(kind_: String,id_: String,action: String) -> bool:
	match action:
		"dig_tools":object_context.open("dig_tools");return true
		"place_shaft":set_dig_mode("shaft");return true
		"place_tunnel":set_dig_mode("tunnel");return true
		"stop_dig":stop_digging();return true
		"view_tools":object_context.open("view_tools");return true
		"view_front","view_back","view_left","view_right":
			view_angle={"view_front":0.0,"view_back":PI,"view_left":PI/2,"view_right":-PI/2}[action];set_layer("all");return true
	match action:
		"automation":object_context.open("automation");return true
		"hire_reception":Tycoon.hire(sim,"reception");return true
		"hire_cleaning":Tycoon.hire(sim,"cleaning");return true
		"upgrade_kitchen":Tycoon.upgrade_kitchen(sim);return true
		"upgrade_room":Tycoon.upgrade_room(sim,int(id_));return true
		"private_entry":
			if sim.data.player.floor!=0:
				pending_context_action={"kind":"owner","id":"","action":"private_entry","floor":0};travel_to_floor(0);return true
			Commands.move(self,Tycoon.PRIVATE_ENTRY);return true
	if action.begins_with("connect:"):Sandbox.connect_tunnel(sim,id_,action.trim_prefix("connect:"));return true
	if action.begins_with("build_") and action!="build_mode":Sandbox.build(sim,action.trim_prefix("build_"),build_cell);return true
	match action:
		"build_mode":set_dig_mode("shaft");return true
		"make_entrance":Excavation.shaft(sim,build_point);return true
		"walk_here":sim.queue_move(build_point);return true
		"walk_below":sim.queue_move(Vector2(build_cell));return true
		"portal_use":request_floor(0 if sim.data.player.floor==1 else 1,id_);return true
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
			var p: Dictionary=sim.data.people[id_];p.state="restrained";p.escorted=true;p.path=[];sim.data.ops.drag=id_;sim.note("같이 이동합니다. 은신처에 데려가 보호할 수 있습니다.");return true
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
		if not Selection.visible_floor(self,floor_):continue
		if point.distance_to(camera.unproject_position(world_point(p,floor_,0.1)))<44:
			request_floor(0 if floor_==1 else 1,e.id);return true
	if sim.data.player.floor==1 and Selection.visible_floor(self,1):
		for f in sim.data.sandbox.facilities:
			if point.distance_to(camera.unproject_position(world_point(f.pos,1,0.15)))<44:
				object_context.open("prison",f.id,sim.Prison.summary(sim,f.id)) if f.type=="prison" else object_context.open("facility",f.id);return true
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
	if entrance_placing:
		entrance_placing=false;last_ground_time=0;build_point=pos;object_context.open("ground");return true
	return false

func sync_tycoon_workers(dt: float) -> void:
	if receptionist_visual==null:
		receptionist_visual=actor(Vector3.ZERO,Color("6f8155"));world_label("토마 · 자동 접수",Vector3(0,1.95,0),receptionist_visual).pixel_size=0.014
		cleaner_visual=actor(Vector3.ZERO,Color("89718a"));world_label("리아 · 객실 청소",Vector3(0,1.95,0),cleaner_visual).pixel_size=0.014
	receptionist_visual.visible=sim.data.tycoon.reception and Selection.visible_floor(self,0)
	cleaner_visual.visible=sim.data.tycoon.cleaning and Selection.visible_floor(self,int(sim.data.tycoon.cleaner.floor))
	sync_actor(receptionist_visual,Vector2(-0.25,-1.25),dt)
	var worker: Dictionary=sim.data.tycoon.cleaner;sync_actor(cleaner_visual,worker.pos,dt,int(worker.floor))
	for n in sim.data.rooms:
		if not tycoon_room_marks.has(n):
			var at=world_point(Sandbox.room_point(int(n)),Sandbox.floor_of(int(n)),0.6);tycoon_room_marks[n]=world_label("",at,actors_root);tycoon_room_marks[n].pixel_size=0.012
		var room_: Dictionary=sim.data.rooms[n]
		tycoon_room_marks[n].visible=Selection.visible_floor(self,Sandbox.floor_of(int(n)))
		tycoon_room_marks[n].text="%s호 · %s%s" %[n,"예약 중" if room_.get("reserved","")!="" else ("청소 필요" if room_.dirty else ("이용 중" if room_.guest!="" else "빈방"))," · 개선 %d" %int(sim.data.tycoon.rooms[n]) if int(sim.data.tycoon.rooms[n])>0 else ""]
		tycoon_room_marks[n].modulate=Color("c6a06b") if room_.dirty else (Color("a9bd89") if room_.guest=="" else Color("d4d6cf"))

func camera_arm() -> Vector3:return Vector3(26,34,0) if inn_view else CAMERA_ARM.rotated(Vector3.UP,view_angle)

func set_dig_mode(value: String) -> void:
	object_context.close()
	dig_mode=value;set_layer("below" if value.begins_with("build:") else "all")
	if dig_cancel==null:
		dig_cancel=Button.new();dig_cancel.text="취소";dig_cancel.position=Vector2(580,121);dig_cancel.size=Vector2(115,60);dig_cancel.add_theme_font_override("font",ui_font);dig_cancel.add_theme_font_size_override("font_size",24);journal.root.add_child(dig_cancel);dig_cancel.pressed.connect(func():dig_mode="";dig_cancel.hide())
	dig_cancel.show()
	sim.note("열린 지하 바닥을 한 번 누르면 시설을 설치합니다." if value.begins_with("build:") else ("지상의 빈 바닥을 한 번 누르면 입구를 자동으로 만듭니다." if value=="shaft" else "지하에서 원하는 목적지를 한 번 누르세요. 그곳까지 자동으로 이어 팝니다."))

func apply_dig_point(point: Vector2) -> void:
	var plane_y=0.08 if dig_mode=="shaft" else Sandbox.OFFSET.y+0.08
	var hit: Variant=Plane(Vector3.UP,plane_y).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	if hit==null:return
	var okay=false
	if dig_mode.begins_with("build:"):
		var local: Vector3=hit-Sandbox.OFFSET;okay=Sandbox.build(sim,dig_mode.get_slice(":",1),Vector2i(roundi(local.x),roundi(local.z)))
	elif dig_mode=="shaft":okay=Excavation.shaft(sim,Vector2(hit.x,hit.z))
	else:
		var local: Vector3=hit-Sandbox.OFFSET;okay=Excavation.dig_to(sim,Vector2i(roundi(local.x),roundi(local.z)))
	if okay:dig_mode="";dig_cancel.hide();route_count=-1

func stop_digging() -> void:
	dig_mode=""
	if dig_cancel!=null:dig_cancel.hide()
	sim.data.sandbox.tunnel_plan=[];sim.data.sandbox.pending_exit={};sim.data.sandbox.erase("pending_tunnel");sim.data.sandbox.erase("pending_from_upper");sim.data.sandbox.erase("pending_shaft");sim.cancel_work()

func sync_dig_visual() -> void:
	if dig_board==null:
		dig_board=MeshInstance3D.new();var plane=BoxMesh.new();plane.size=Vector3(36,0.04,22);dig_board.mesh=plane
		var mat=material(Color(0.12,0.23,0.25,0.5));mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;dig_board.material_override=mat;add_child(dig_board);dig_board.position=world_point(Vector2(8,0),1,-0.18)
		dig_route=MeshInstance3D.new();add_child(dig_route)
	dig_board.visible=dig_mode=="tunnel"
	var plan: Array=sim.data.sandbox.get("tunnel_plan",[])
	if route_count==plan.size():return
	route_count=plan.size();dig_route.visible=route_count>0
	if plan.is_empty():return
	var line=ImmediateMesh.new();var mat=material(Color("d5be76"));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,mat);line.surface_add_vertex(world_point(sim.data.player.pos,1,0.3))
	for cell in plan:line.surface_add_vertex(world_point(Vector2(cell),1,0.3))
	line.surface_end();dig_route.mesh=line

func selection_candidates(point: Vector2) -> Array:
	return Selection.candidates(self,point)

func activate_selection(choice: Dictionary) -> void:
	var kind_=str(choice.kind);var id_=str(choice.id)
	match kind_:
		"person":
			if not sim.data.people.has(id_) or sim.data.people[id_].state=="gone":return
			sim.data.ops.selected=id_
			if sim.data.people[id_].state=="captive":object_context.open("inmate",id_,sim.Prison.inmate_summary(sim,id_))
			elif sim.data.people[id_].state in ["down","dead","restrained"]:object_context.open("person",id_)
			else:object_context.open("conversation",id_,Dialogue.begin(sim,id_))
		"prison":object_context.open("prison",id_,sim.Prison.summary(sim,id_))
		"staff":object_context.open("staff_talk","","식사 운영을 맡고 있어요. 업무를 바꿀까요?")
		"inspector":object_context.open("guard_talk","","몇 가지 확인할 일이 있소.")
		_:object_context.open("owner")

func command_status() -> String:return Commands.status(self)
func view_name() -> String:return {"surface":"식당·마당","rooms":"객실","below":"지하","all":"전체"}.get(view_layer,"여관")

func cancel_everything() -> void:
	Commands.cancel(self);dig_mode="";comfort.confirm_job.clear()
	if dig_cancel!=null:dig_cancel.hide()
	comfort.say("이동·작업·공사 위치 선택을 취소했습니다.")

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and comfort!=null and comfort.host!=null:
		comfort.background()

func show_inn() -> void:
	if object_context!=null:object_context.close()
	view_layer="surface";inn_view=true;overview=true;camera_offset=Vector2.ZERO;camera.size=28
	camera_focus=focus_position();camera.position=camera_focus+camera_arm();camera.look_at(camera_focus)
	sync_view(0)
	if mobile_scene.host!=null:mobile_scene.update()
	if journal!=null:journal.refresh()
