extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
var sim = Simulation.new()
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
var viewed_floor := 0
var surface_zoom := 18.0
var basement_zoom := 12.0
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
var show_vision := true
var muted := false
var sound_clock := 0.0
var last_warning := 0
var knock: AudioStreamPlayer
var alert_sound: AudioStreamPlayer
var step_sound: AudioStreamPlayer3D
var vision_clock := 0.0

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
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.3, 0.33, 0.29)
	head.mesh = head_mesh
	head.material_override = material(Color("b6a28b"))
	head.position.y = 1.4
	body.add_child(head)
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
	light.shadow_enabled = true

func build_surface() -> void:
	box(Vector3(42, 0.3, 34), Vector3(0, -0.5, 0), Color("283b43"), true)
	box(Vector3(20.4, 0.35, 12.4), Vector3(0, -0.17, 0), Color("342e29"), true)
	for x in range(-10, 10):
		for z in range(-6, 6):
			model("town", "planks", Vector3(x + 0.5, 0.01, z + 0.5), Vector3(0.99, 0.06, 0.99))
	# Back and west walls remain tall; front walls are deliberately cut away.
	for x in range(-10, 10):
		model("town", "wall-wood-window-small" if x % 4 == 0 else "wall-wood", Vector3(x + 0.5, 0.07, -6), Vector3(0.17, 2.5, 1), PI / 2, true)
	for z in range(-6, 6):
		model("town", "wall-wood", Vector3(-10, 0.07, z + 0.5), Vector3(0.17, 2.5, 1), 0, true)
	box(Vector3(0.15, 0.45, 12), Vector3(10, 0.24, 0), Color("66523a"), true)
	box(Vector3(9, 0.45, 0.15), Vector3(-5.5, 0.24, 6), Color("66523a"), true)
	box(Vector3(9, 0.45, 0.15), Vector3(5.5, 0.24, 6), Color("66523a"), true)
	# Room partition with two open doorways at z=-2 and z=2.
	for z in range(-6, 6):
		if z == -3 or z == 1:
			continue
		box(Vector3(0.16, 1.0, 1), Vector3(2, 0.55, z + 0.5), Color("76654c"), true)
	box(Vector3(8, 1, 0.15), Vector3(6, 0.55, 0), Color("76654c"), true)
	for z in [-2.0, 2.0]:
		model("furniture", "bedSingle", Vector3(5.6, 0.08, z), Vector3(1.1, 0.75, 2.0), 0, true)
		model("furniture", "rugRectangle", Vector3(3.7, 0.08, z), Vector3(1.4, 0.025, 2.0))
	model("furniture", "table", Vector3(-1.7, 0.08, -2.7), Vector3(2.7, 0.95, 0.9), 0, true)
	model("furniture", "books", Vector3(-2.4, 1.04, -2.7), Vector3(0.5, 0.17, 0.35))
	model("furniture", "bookcaseOpen", Vector3(-5.4, 0.08, -3.4), Vector3(1.35, 1.9, 0.4), 0, true)
	for x in [-7.5, -4.8]:
		model("furniture", "tableRound", Vector3(x, 0.08, 0.4), Vector3(1.4, 0.8, 1.4), 0, true)
		for z in [-0.7, 1.6]:
			model("furniture", "chair", Vector3(x, 0.08, z), Vector3(0.52, 1, 0.58), PI if z < 0 else 0, true)
	model("furniture", "bench", Vector3(-8.5, 0.08, 3), Vector3(1.8, 0.9, 0.6), 0, true)
	model("furniture", "coatRackStanding", Vector3(0.7, 0.08, 3.2), Vector3(0.5, 1.7, 0.5))
	for pos in [Vector3(-4, 0.08, -3.3), Vector3(3.4, 0.08, -3.3), Vector3(3.4, 0.08, 3.2)]:
		model("town", "lantern", pos, Vector3(0.25, 1.8, 0.25))
		light_at(pos + Vector3(0, 1.9, 0), 0.9)
	model("town", "cart", Vector3(-10, -0.33, 2), Vector3(1.7, 1.3, 3.0), 0.5)
	model("town", "stairs-wood", Vector3(8.6, -0.33, -1), Vector3(1.3, 0.7, 1.8))
	for pos in [Vector3(-11, -0.33, -6), Vector3(8, -0.33, -7), Vector3(11, -0.33, 4), Vector3(-10, -0.33, 7)]:
		model("town", "tree", pos, Vector3(2.5, 5, 2.5))
	for x in range(-9, 11, 2):
		model("town", "fence", Vector3(x, -0.33, -8), Vector3(0.15, 1.1, 2), PI / 2)

func _ready() -> void:
	ui_font = load("res://assets/fonts/InnKorean.otf")
	surface = Node3D.new()
	add_child(surface)
	basement = Node3D.new()
	add_child(basement)
	terrain = Node3D.new()
	basement.add_child(terrain)
	actors_root = Node3D.new()
	add_child(actors_root)
	world_root = surface
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17242e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8da0b5")
	environment.ambient_light_energy = 0.36
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_color = Color("a3b7ce")
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	build_surface()
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
	world_label("징수원",Vector3(0,1.95,0),collector_visual)
	world_root = basement
	light_at(Vector3(0,2.8,0),1.2)
	world_label("위층 입구",Vector3(0,1.9,0),basement)
	for x in [-0.35,0.35]:box(Vector3(0.07,1.7,0.07),Vector3(x,0.85,-0.2),Color("8d754e"))
	for y in [0.25,0.55,0.85,1.15,1.45]:box(Vector3(0.7,0.07,0.07),Vector3(0,y,-0.2),Color("b09972"))
	world_root = surface
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = surface_zoom
	camera.position = Vector3(16,18,21)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	make_ui()
	sync_view(0)
	var args := OS.get_cmdline_user_args()
	if "--verify" in args:
		set_physics_process(false)
		var result: int = preload("res://scripts/tests.gd").run(sim.obstacles)
		get_tree().quit(result)
	elif "--input-verify" in args:
		await input_verify()
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
		get_viewport().get_texture().get_image().save_png("res://docs/v07-excavation.png")
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
		var output := "res://docs/v04-stealth.png" if "--capture-stealth" in args else ("res://docs/v04-basement.png" if "--capture-basement" in args else "res://docs/v07-surface.png")
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

func room_text(number: int) -> String:
	var room_: Dictionary=sim.data.rooms[str(number)]
	if room_.guest!="":return "%d호  %s" % [number,sim.data.people[room_.guest].name]
	return "%d호  청소 필요" % number if room_.dirty else "%d호  빈방" % number

func when_text(value: float) -> String:
	var minute:=int(value)
	return "%d일 %02d:%02d" % [minute/1440+1,(minute%1440)/60,minute%60]

func refresh_ui() -> void:
	mobile_ui.refresh()

func sync_actor(visual: Node3D, pos: Vector2, dt: float) -> void:
	var before:=Vector2(visual.position.x,visual.position.z)
	var moving:=before.distance_to(pos)>0.001
	visual.position=Vector3(pos.x,0.08,pos.y)
	if moving and dt>0:
		var diff:=pos-before
		visual.rotation.y=atan2(-diff.x,-diff.y)
	var swing:=sin(sim.data.clock*10)*0.45 if moving else 0.0
	visual.get_node("LeftLeg").rotation.x=swing
	visual.get_node("RightLeg").rotation.x=-swing

func sync_view(dt: float) -> void:
	var d: Dictionary=sim.data
	var upstairs: bool=d.player.floor==0
	if viewed_floor!=d.player.floor:
		if viewed_floor==0: surface_zoom=camera.size
		else: basement_zoom=camera.size
		camera.size=surface_zoom if upstairs else basement_zoom
		viewed_floor=d.player.floor
	surface.visible=upstairs
	basement.visible=not upstairs
	staff_visual.visible=upstairs and d.staff.hired
	collector_visual.visible=upstairs and d.collector
	sync_actor(player,d.player.pos,dt)
	sync_actor(staff_visual,d.staff.pos,dt)
	staff_visual.rotation.y=atan2(-d.staff.facing.x,-d.staff.facing.y)
	collector_visual.position=Vector3(-0.2,0.08,-1.5)
	var inspection: Dictionary=d.ops.inspector
	inspector_visual.visible=inspection.state not in ["idle","scheduled"] and inspection.floor==d.player.floor
	sync_actor(inspector_visual,inspection.pos,dt)
	if d.ops.built and holding_position!=d.ops.cell:build_holding_visual()
	if holding_visual!=null:holding_visual.visible=d.ops.built and not upstairs
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
		actors[id].visible=person.floor==d.player.floor and person.state!="gone"
		sync_actor(actors[id],person.pos,dt)
		actors[id].rotation.z=PI/2 if person.state=="down" else 0
		if person.state=="down":actors[id].position.y=0.35
		# Labels remain upright even when the body is lying on its side.
		labels[id].global_rotation=Vector3.ZERO
		labels[id].global_position=Vector3(person.pos.x,0.95 if person.state=="down" else 2.03,person.pos.y)
		labels[id].text=str(person.name)
		labels[id].pixel_size=0.0045 if person.floor==1 else 0.007
		if person.state=="waiting":labels[id].text+=" · 대기"
		if person.state=="captive":labels[id].text+=" · 구금"
		labels[id].modulate=Color("ffd394") if d.ops.selected==id else Color.WHITE
	if last_cell_count!=d.cells.size():rebuild_basement()
	staff_marker.text="직원 · 확인 중" if d.stealth.phase!="idle" else ("직원 · 업무 거부" if d.clock<d.stealth.refuse_until else "직원")
	staff_marker.modulate=Color("ffb882") if d.stealth.suspicion>=10 else Color.WHITE
	vision_mesh.visible=upstairs and d.staff.hired and show_vision
	vision_clock+=dt
	if vision_clock>=0.12 or dt==0:
		vision_clock=0
		refresh_vision()
	tool_pivot.visible=not upstairs and d.ops.drag==""
	tool_pivot.rotation.x=sin(d.clock*13)*0.85-0.3 if not d.dig.is_empty() else -0.2
	pick_head.visible=not d.stealth.quiet
	shovel_head.visible=d.stealth.quiet
	hatch_lid.rotation.x=-1.25 if d.excavation.hatch_open else 0
	refresh_ui()

func rebuild_basement() -> void:
	for child in terrain.get_children():child.free()
	world_root=terrain
	var edge: Dictionary={}
	for key in sim.data.cells:
		var cell: Vector2i=Simulation.parse_cell(key)
		box(Vector3(0.98,0.12,0.98),Vector3(cell.x,-0.02,cell.y),Color("51483a"))
		for shift in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i=cell+shift
			if not sim.data.cells.has(Simulation.cell_key(neighbor)):edge[Simulation.cell_key(neighbor)]=true
	for key in edge:
		var cell: Vector2i=Simulation.parse_cell(key)
		box(Vector3(0.97,0.9,0.97),Vector3(cell.x,0.45,cell.y),Color("65543e"))
	earth_edges=edge
	dig_cursor=box(Vector3(0.97,0.04,0.97),Vector3(99,0.94,99),Color("c09b4d"))
	world_root=surface
	last_cell_count=sim.data.cells.size()

func save_game() -> void:
	var file:=FileAccess.open("user://inn-v03.json",FileAccess.WRITE)
	if file==null:
		sim.note("저장 파일을 만들 수 없다.")
		return
	file.store_string(JSON.stringify(sim.snapshot()))
	file.close()
	sim.note("저장했다. 진행 중인 주문과 작업도 함께 기록했다.")

func load_game() -> void:
	if not FileAccess.file_exists("user://inn-v03.json"):
		sim.note("저장된 기록이 없다. 메뉴에서 먼저 저장하자.")
		return
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://inn-v03.json"))
	if not sim.restore(saved):
		sim.note("이 버전에서 읽을 수 없는 저장 파일이다.")
		return
	last_cell_count=-1
	sim.note("저장한 상태로 돌아왔다.")
	sync_view(0)

func pan_camera(relative: Vector2) -> void:
	var scale_: float=camera.size/get_viewport().get_visible_rect().size.y
	var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	camera_offset-=(right*relative.x+down*relative.y)*scale_
	camera_offset=camera_offset.limit_length(18)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		mouse_origin=event.position
		mouse_dragged=false
		mouse_blocked=mobile_ui.blocks_point(event.position)
	if event is InputEventMouseMotion:
		pointer_position=event.position
		if event.device!=-1 and event.button_mask&MOUSE_BUTTON_MASK_LEFT and not mobile_ui.blocks_point(mouse_origin):
			if event.position.distance_to(mouse_origin)>24:mouse_dragged=true
			if mouse_dragged:pan_camera(event.relative)
	if event is InputEventScreenTouch and event.pressed:
		touch_origin=event.position
		touch_dragged=false
		touch_blocked=mobile_ui.blocks_point(event.position)
	if event is InputEventScreenDrag:
		pointer_position=event.position
		if event.position.distance_to(touch_origin)>24:touch_dragged=true
		if touch_dragged and not touch_blocked:pan_camera(event.relative)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
	pointer_position=point
	var target_id:=pick_person(point)
	if target_id!="":
		sim.data.excavation.path=[]
		sim.data.excavation.intent=""
		sim.data.ops.selected=target_id
		return
	if point.distance_to(camera.unproject_position(Vector3(Simulation.HATCH.x,0.15,Simulation.HATCH.y)))<32 and sim.data.player.floor==0:
		sim.queue_floor()
		return
	if sim.data.player.floor==1:
		var soil:=soil_at(point)
		if soil!=Vector2i(99,99):
			sim.queue_dig(soil)
			return
	var hit: Variant=Plane(Vector3.UP,0.08).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	if hit!=null:
		sim.data.ops.selected=""
		sim.queue_move(Vector2(hit.x,hit.z))

func _physics_process(delta: float) -> void:
	if capturing:return
	if not sim.data.paused:
		var direction:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
		var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
		var speed_: float=1.15 if sim.data.ops.drag!="" else (2.2 if sim.data.player.carry!="" else 2.9)
		sim.move_player((right*direction.x+down*direction.y)*delta*speed_*sim.data.speed)
		sim.tick(delta*sim.data.speed)
		update_stealth_audio(delta)
	if sim.data.player.floor==1:
		hover_cell=soil_at(pointer_position)
		if dig_cursor!=null:
			dig_cursor.visible=earth_edges.has(Simulation.cell_key(hover_cell))
			dig_cursor.position=Vector3(hover_cell.x,0.94,hover_cell.y)
	if sim.data.excavation.intent!="":camera_offset=camera_offset.lerp(Vector2.ZERO,minf(1,delta*3))
	var focus_target:=Vector3(sim.data.player.pos.x+camera_offset.x,0,sim.data.player.pos.y+camera_offset.y)
	camera_focus=camera_focus.lerp(focus_target,minf(1,delta*4))
	camera.position=camera_focus+Vector3(16,18,21)
	camera.look_at(camera_focus)
	sync_view(delta)

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
	camera_focus=Vector3(sim.data.player.pos.x,0,sim.data.player.pos.y)
	camera.position=camera_focus+Vector3(16,18,21)
	camera.look_at(camera_focus)
	sync_view(0)

func input_verify() -> void:
	# No keyboard events: actual GUI buttons, ground clicks and touch events.
	get_window().size=Vector2i(720,1280)
	await get_tree().process_frame
	await get_tree().process_frame
	set_physics_process(false)
	var checks: Array=[]
	var geometry: Array=sim.obstacles.duplicate()
	checks.append(get_viewport().get_visible_rect().size.y>get_viewport().get_visible_rect().size.x)
	frame_owner()
	var destination:=Vector2(0.25,0.25)
	await pointer_click(camera.unproject_position(Vector3(destination.x,0.08,destination.y)))
	checks.append(sim.data.excavation.intent=="move")
	sim.tick(3)
	checks.append(sim.data.player.pos.distance_to(destination)<0.1)
	frame_owner()
	destination=Vector2(-1.25,1.75)
	await pointer_click(camera.unproject_position(Vector3(destination.x,0.08,destination.y)),true)
	checks.append(sim.data.excavation.intent=="move")
	sim.tick(4)
	checks.append(sim.data.player.pos.distance_to(destination)<0.1)
	var before_drag: Vector2=sim.data.player.pos
	var touch_down:=InputEventScreenTouch.new()
	touch_down.position=Vector2(300,500)
	touch_down.pressed=true
	get_viewport().push_input(touch_down,true)
	var swipe:=InputEventScreenDrag.new()
	swipe.position=Vector2(360,550)
	swipe.relative=Vector2(60,50)
	get_viewport().push_input(swipe,true)
	var touch_up:=InputEventScreenTouch.new()
	touch_up.position=swipe.position
	touch_up.pressed=false
	get_viewport().push_input(touch_up,true)
	await get_tree().process_frame
	checks.append(camera_offset.length()>0 and sim.data.player.pos==before_drag and sim.data.excavation.intent=="")
	await click_control("center")
	checks.append(camera_offset==Vector2.ZERO)
	var emulated:=InputEventMouseButton.new()
	emulated.device=-1
	emulated.button_index=MOUSE_BUTTON_LEFT
	emulated.position=Vector2(300,500)
	emulated.pressed=true
	get_viewport().push_input(emulated,true)
	emulated=InputEventMouseButton.new()
	emulated.device=-1
	emulated.button_index=MOUSE_BUTTON_LEFT
	emulated.position=Vector2(300,500)
	emulated.pressed=false
	get_viewport().push_input(emulated,true)
	await get_tree().process_frame
	checks.append(sim.data.excavation.intent=="")
	await click_control("tab_메뉴")
	checks.append(mobile_ui.drawer.visible)
	sim.data.excavation.intent=""
	await pointer_click(Vector2(350,500),true)
	checks.append(sim.data.excavation.intent=="")
	await click_control("save")
	var money: int=sim.data.money
	sim.data.money=999
	await click_control("load")
	checks.append(sim.data.money==money)
	await click_control("close")
	await click_control("pause")
	checks.append(sim.data.paused)
	await click_control("pause")
	await click_control("speed")
	checks.append(sim.data.speed==3 and not sim.data.paused)
	await click_control("speed")
	# Full normal service via pointer buttons and target selection.
	sim=Simulation.new()
	sim.obstacles.assign(geometry)
	sim.rebuild_grid()
	frame_owner()
	await click_control("tab_영업")
	await touch_control("room1")
	checks.append(sim.data.excavation.intent=="command:room1")
	sim.tick(6)
	checks.append(sim.data.rooms["1"].guest=="guest_1" and sim.near_counter())
	sim.tick(17)
	await click_control("tab_영업")
	await click_control("prepare")
	sim.tick(4)
	checks.append(sim.data.player.carry!="")
	sync_view(0)
	checks.append(mobile_ui.primary.text.contains("전달"))
	await click_control("primary")
	sim.tick(10)
	checks.append(sim.data.served==1 and sim.data.player.carry=="")
	await click_control("tab_관리")
	await click_control("staff")
	sim.tick(8)
	checks.append(sim.data.staff.hired and sim.data.staff.delegated)
	# One covert contract through the same pointer-only UI.
	sim=Simulation.new()
	sim.obstacles.assign(geometry)
	sim.rebuild_grid()
	frame_owner()
	await click_control("tab_의뢰")
	await click_control("contract")
	sim.tick(6)
	checks.append(sim.data.ops.contract.state=="active")
	frame_owner()
	var guest: Vector2=sim.data.people.guest_1.pos
	await pointer_click(camera.unproject_position(Vector3(guest.x,0.65,guest.y)),true)
	await click_control("secondary")
	sim.tick(8)
	checks.append(sim.data.people.guest_1.state=="down")
	await click_control("primary")
	sim.tick(1)
	checks.append(sim.data.ops.drag=="guest_1")
	await click_control("floor")
	sim.tick(10)
	checks.append(sim.data.player.floor==1 and sim.data.people.guest_1.floor==1)
	frame_owner()
	await pointer_click(camera.unproject_position(Vector3(-2,0.08,0)))
	sim.tick(5)
	await click_control("secondary")
	checks.append(sim.data.ops.built)
	await click_control("secondary")
	checks.append(sim.data.people.guest_1.state=="captive" and sim.data.ops.drag=="")
	await click_control("secondary")
	checks.append(sim.data.stealth.quiet)
	await click_control("primary")
	sim.tick(12)
	checks.append(sim.data.cells.size()==26 and sim.data.excavation.durability==23)
	sim.tick(20)
	checks.append(sim.data.ops.contract.state=="ready")
	await click_control("floor")
	sim.tick(5)
	await click_control("tab_의뢰")
	await click_control("contract")
	sim.tick(5)
	checks.append(sim.data.ops.contract.state=="paid")
	await click_control("tab_메뉴")
	await click_control("save")
	sim.data.ops.contract.state="offered"
	await click_control("load")
	checks.append(sim.data.ops.contract.state=="paid" and sim.data.ops.built)
	var failed:=0
	for i in range(checks.size()):
		if not checks[i]:failed+=1;print("POINTER FAIL: ",i)
	print("Portrait/pointer verification: %d checks, %d failures" % [checks.size(),failed])
	get_tree().quit(0 if failed==0 else 1)

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

func pick_person(screen: Vector2) -> String:
	var id: String=""
	var distance:=38.0
	for key in sim.data.people:
		var person: Dictionary=sim.data.people[key]
		if person.state=="gone" or person.floor!=sim.data.player.floor:continue
		var point:=camera.unproject_position(Vector3(person.pos.x,0.65,person.pos.y))
		var delta:=screen.distance_to(point)
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
	var origin:=camera.project_ray_origin(screen)
	var direction:=camera.project_ray_normal(screen)
	var nearest:=INF
	var chosen:=Vector2i(99,99)
	for key in earth_edges:
		var cell:=Simulation.parse_cell(key)
		var bounds:=AABB(Vector3(cell.x-0.485,0,cell.y-0.485),Vector3(0.97,0.9,0.97))
		var hit: Variant=bounds.intersects_ray(origin,direction)
		if hit!=null:
			var distance: float=origin.distance_squared_to(hit)
			if distance<nearest:nearest=distance;chosen=cell
	return chosen
