extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
var sim = Simulation.new()
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
var hud: Label
var reception: Label
var status: Label
var feed: Label
var hint: Label
var notice: Label
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
var surface_zoom := 24.0
var basement_zoom := 12.0
var pointer_position := Vector2.ZERO
var hatch_lid: Node3D
var tool_pivot: Node3D
var pick_head: MeshInstance3D
var shovel_head: MeshInstance3D
var dig_progress: ProgressBar
var floor_button: Button
var panels_hidden:=false
var information_controls: Array[Control]=[]
var action_buttons: Dictionary={}
var contract_panel: Label
var target_panel: Label
var inspector_visual: CharacterBody3D
var holding_visual: Node3D
var holding_position:=Vector2(99,99)
var awareness: Label
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
	world_label("지하 입구 · 클릭 / Q",Vector3(-3.25,0.4,2.75),surface)
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
	world_label("Q  위층",Vector3(0,1.9,0),basement)
	for x in [-0.35,0.35]:box(Vector3(0.07,1.7,0.07),Vector3(x,0.85,-0.2),Color("8d754e"))
	for y in [0.25,0.55,0.85,1.15,1.45]:box(Vector3(0.7,0.07,0.07),Vector3(0,y,-0.2),Color("b09972"))
	world_root = surface
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
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
		get_viewport().get_texture().get_image().save_png("res://docs/v06-excavation.png")
		get_tree().quit()
	elif "--capture" in args or "--capture-basement" in args or "--capture-stealth" in args or "--capture-operation" in args or "--capture-prison" in args:
		capturing = true
		sim.data.player.pos = Simulation.COUNTER
		sim.assign_room(1)
		sim.toggle_staff()
		sim.tick(24)
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
		var output := "res://docs/v04-stealth.png" if "--capture-stealth" in args else ("res://docs/v04-basement.png" if "--capture-basement" in args else "res://docs/v06-surface.png")
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

func panel(canvas: CanvasLayer, pos: Vector2, size_: Vector2) -> void:
	var rect:=ColorRect.new()
	rect.position=pos
	rect.size=size_
	rect.color=Color(0.04,0.07,0.09,0.91)
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)

func ui_label(canvas: CanvasLayer, pos: Vector2, size_: Vector2, font_size: int) -> Label:
	var label:=Label.new()
	label.position=pos
	label.size=size_
	label.add_theme_font_override("font",ui_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	return label

func button(canvas: CanvasLayer, text_: String, pos: Vector2, size_: Vector2, callback: Callable) -> Button:
	var control:=Button.new()
	control.text=text_
	control.position=pos
	control.size=size_
	control.add_theme_font_override("font",ui_font)
	control.add_theme_font_size_override("font_size",17)
	control.focus_mode=Control.FOCUS_NONE
	control.pressed.connect(callback)
	canvas.add_child(control)
	return control

func make_ui() -> void:
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	panel(canvas,Vector2(20,18),Vector2(1240,78))
	hud=ui_label(canvas,Vector2(36,25),Vector2(1100,65),22)
	notice=ui_label(canvas,Vector2(32,103),Vector2(1200,27),17)
	panel(canvas,Vector2(20,138),Vector2(266,172))
	reception=ui_label(canvas,Vector2(32,146),Vector2(242,102),17)
	button(canvas,"1호 [1]",Vector2(32,260),Vector2(74,34),func():sim.assign_room(1))
	button(canvas,"2호 [2]",Vector2(111,260),Vector2(74,34),func():sim.assign_room(2))
	button(canvas,"거절 [G]",Vector2(190,260),Vector2(83,34),sim.reject_guest)
	panel(canvas,Vector2(994,138),Vector2(266,390))
	status=ui_label(canvas,Vector2(1008,148),Vector2(240,370),17)
	button(canvas,"직원 고용 / 위임 [H]",Vector2(994,540),Vector2(266,38),sim.toggle_staff)
	button(canvas,"저장 [F5]",Vector2(994,586),Vector2(128,36),save_game)
	button(canvas,"불러오기 [F9]",Vector2(1130,586),Vector2(130,36),load_game)
	panel(canvas,Vector2(20,464),Vector2(266,178))
	feed=ui_label(canvas,Vector2(32,474),Vector2(242,158),15)
	feed.max_lines_visible=6
	panel(canvas,Vector2(20,660),Vector2(1240,120))
	hint=ui_label(canvas,Vector2(34,670),Vector2(1210,100),17)
	panel(canvas,Vector2(320,138),Vector2(650,82))
	awareness=ui_label(canvas,Vector2(334,146),Vector2(622,70),17)
	panel(canvas,Vector2(20,320),Vector2(266,134))
	contract_panel=ui_label(canvas,Vector2(32,328),Vector2(242,78),15)
	button(canvas,"의뢰 / 보수 [J]",Vector2(32,412),Vector2(130,32),func():Simulation.Intrigue.contract_action(sim))
	button(canvas,"거절 / 보호 [K]",Vector2(166,412),Vector2(108,32),func():Simulation.Intrigue.contract_action(sim,true))
	floor_button=button(canvas,"지하 입구 열고 내려가기 [Q]",Vector2(320,230),Vector2(330,34),func():sim.queue_floor())
	action_buttons["dig"]=button(canvas,"가까운 흙벽 파기 [E]",Vector2(658,230),Vector2(312,34),func():sim.dig_nearest())
	button(canvas,"도구 수리 [T] · 2닢",Vector2(994,630),Vector2(266,26),func():sim.repair_tools())
	dig_progress=ProgressBar.new()
	dig_progress.position=Vector2(334,272)
	dig_progress.size=Vector2(622,18)
	dig_progress.show_percentage=true
	canvas.add_child(dig_progress)
	panel(canvas,Vector2(320,552),Vector2(650,90))
	target_panel=ui_label(canvas,Vector2(334,558),Vector2(620,36),16)
	action_buttons["subdue"]=button(canvas,"제압 2초 [Z]",Vector2(334,601),Vector2(140,32),func():Simulation.Intrigue.subdue(sim))
	action_buttons["drag"]=button(canvas,"끌기 / 풀기 [C]",Vector2(480,601),Vector2(152,32),func():Simulation.Intrigue.drag_or_release(sim))
	action_buttons["cell"]=button(canvas,"구금칸 [B]",Vector2(638,601),Vector2(140,32),func():Simulation.Intrigue.build_or_hold(sim))
	action_buttons["bribe"]=button(canvas,"경비 뇌물 [O]",Vector2(784,601),Vector2(168,32),func():Simulation.Intrigue.inspector_action(sim,true))
	for node in canvas.get_children():
		if node is Control and node.position.y>=138 and node.position.y<=654 and (node.position.x<300 or node.position.x>=994):information_controls.append(node)
	button(canvas,"정보 패널 접기 / 펼치기 [I]",Vector2(1000,100),Vector2(260,28),toggle_information)

func room_text(number: int) -> String:
	var room_: Dictionary=sim.data.rooms[str(number)]
	if room_.guest!="":return "%d호  %s" % [number,sim.data.people[room_.guest].name]
	return "%d호  청소 필요" % number if room_.dirty else "%d호  빈방" % number

func when_text(value: float) -> String:
	var minute:=int(value)
	return "%d일 %02d:%02d" % [minute/1440+1,(minute%1440)/60,minute%60]

func refresh_ui() -> void:
	var d: Dictionary=sim.data
	var minute:=int(420+d.clock*6)
	var day:=minute/1440+1
	var within:=minute%1440
	hud.text="문 닫은 뒤  /  국경 여관  0.6\n%d일  %02d:%02d    보유 %d닢    미납 %d닢    %s    %s" % [day,within/60,within%60,d.money,d.debt,"지하" if d.player.floor==1 else "위층","일시정지" if d.paused else "%d배속" % d.speed]
	var queue:=sim.waiting()
	if queue.is_empty(): reception.text="접수 대기  0명\n다음 손님을 기다리는 중"
	else:
		var person: Dictionary=d.people[queue[0]]
		reception.text="접수 대기  %d명\n%s / 숙박 %d닢\n%s" % [queue.size(),person.name,person.rate,person.trait]
	var pending:=0
	var order_lines: Array[String]=[]
	for oid in d.orders:
		var order_: Dictionary=d.orders[oid]
		if order_.status in ["served","cancelled"]:continue
		pending+=1
		var names: Dictionary={"queued":"준비 대기","cooking":"조리 중","ready":"전달 대기","carried":"운반 중"}
		order_lines.append("%s · %s" % [d.people[order_.guest].name,names.get(order_.status,order_.status)])
	var staff_status: String="미고용 / 준비금 3닢"
	if d.staff.hired:
		staff_status="위임 중" if d.staff.delegated else "위임 해제"
		var modes: Dictionary={"idle":"대기","counter":"접수대 이동","cooking":"식사 준비","delivery":"서빙","return":"복귀","investigate":"지하 확인","refuse":"업무 거부","alarm":"경비 부르러 이동"}
		staff_status+=" · "+str(modes.get(d.staff.mode,d.staff.mode))
	status.text="객실\n%s\n%s\n\n직원  %s\n\n주문 %d건 / 제공 %d회\n%s\n\n예정 납기\n%s 임금 4닢\n%s 임대료 12닢\n%s 세금 8닢" % [room_text(1),room_text(2),staff_status,pending,d.served,"\n".join(order_lines.slice(0,3)),when_text(d.dues.wage),when_text(d.dues.rent),when_text(d.dues.tax)]
	if d.collector:status.text+="\n징수원 대기: 접수대 E"
	var lines: Array[String]=[]
	for item in d.logs.slice(maxi(0,d.logs.size()-3)):
		lines.append("· "+str(item.text))
	feed.text="최근 소식\n"+"\n".join(lines)
	var action: String="접수대 E: 식사 준비·집기  /  주문 손님 곁 E: 전달  /  퇴실한 객실 E: 청소"
	if d.player.floor==1:action="흙벽 클릭: 걸어가서 직접 파기 / E: 가까운 벽 파기 / Q: 위층 복귀 / R: 곡괭이·삽"
	if not d.work.is_empty():action="작업 중  %.1f초 남음 · X로 중단" % d.work.remaining
	if not d.dig.is_empty():action="굴착 중  %.1f초 남음 · 소음 %.1f · X로 중단" % [d.dig.remaining,d.noise]
	hint.text=action+"\nWASD 이동   1/2 방 배정   G 거절   H 직원   Q 계단   Space 정지   Tab 배속   휠 확대\nR 굴착 방식   X 작업 중단   V 시야   M 소리   I 정보접기   F5 저장   F9 불러오기   Esc 종료"
	if OS.has_feature("web"):
		hint.text=hint.text.replace("F5 저장   F9 불러오기","저장·불러오기는 오른쪽 버튼").replace("Esc 종료","Esc 정지")
	var stealth: Dictionary=d.stealth
	var phases: Dictionary={"idle":"영업 중","alert":"소리에 주의 / 하던 일 마무리","approach":"지하 입구로 접근 중","listen":"계단에서 확인 중"}
	var stage: String=str(phases.get(stealth.phase,stealth.phase)) if d.staff.hired else "아직 직원 없음"
	if d.clock<stealth.refuse_until:stage="업무 거부 %.0f초" % (stealth.refuse_until-d.clock)
	awareness.text="직원 경계 %d / 100  ·  %s  ·  확인 기억 %d\n굴착 %s  |  소음 %.1f  |  직원에게 들리는 소리 %.1f" % [int(stealth.suspicion),stage,int(stealth.memory),"조용히 10초" if stealth.quiet else "빠르게 4초",d.noise,stealth.heard]
	awareness.modulate=Color("ffb882") if stealth.phase!="idle" or d.clock<stealth.refuse_until else Color("c3d8d0")
	if stealth.phase in ["approach","listen"] and d.player.floor==0:hint.text="직원 시야 안 가까이 E: 설명 / X: 작업 중단\n"+hint.text
	if d.excavation.intent!="":notice.text="이동 중 · 도착하면 작업 / WASD 또는 X로 취소"
	floor_button.text="위층 입구로 걸어가기 [Q]" if d.player.floor==1 else "지하 입구 열고 내려가기 [Q]"
	if d.player.floor==1 and d.ops.drag=="":
		target_panel.text="도구: %s / 내구도 %d · 흙벽을 클릭하면 이동해서 직접 판다" % ["삽 · 조용히 10초" if d.stealth.quiet else "곡괭이 · 빠르게 4초",int(d.excavation.durability)]
	var contract: Dictionary=d.ops.contract
	var contract_names: Dictionary={"offered":"그림자 의뢰 / 보수 24닢","active":"억류 의뢰 진행","ready":"조건 달성 / 접수대 J 보수","paid":"보수 수령 / 구금자는 남아 있음","protected":"의뢰 폭로 / 손님 보호","declined":"의뢰 거절 / 정상 영업","failed":"의뢰 실패"}
	contract_panel.text=str(contract_names.get(contract.state,contract.state))
	if contract.target!="":contract_panel.text+="\n"+str(d.people[contract.target].name)
	if contract.state=="active":contract_panel.text+=" / 남은 %.0f초\n지하 구금 %.0f / 30초" % [maxf(0,contract.deadline-d.clock),contract.held]
	elif contract.state=="offered":contract_panel.text+="\n손님을 지하에 30초 억류\nJ 수락 / K 거절 · 접수대에서"
	var target_id: String=Simulation.Intrigue.selected(sim)
	target_panel.text="손님 클릭으로 선택 / Z 제압 · C 끌기/내려놓기/석방 · 지하 B 구금칸 8닢"
	if target_id!="":
		var target: Dictionary=d.people[target_id]
		var states: Dictionary={"waiting":"접수 대기","entering":"입실 중","staying":"투숙","down":"기절 %.0f초" % maxf(0,target.wake_at-d.clock),"captive":"지하 구금","escaping":"탈출 중","leaving":"퇴장 중"}
		target_panel.text="선택: %s / %s / %s" % [target.name,states.get(target.state,target.state),"지하" if target.floor==1 else "위층"]
	if d.ops.drag!="":target_panel.text+="  ·  끄는 중: "+str(d.people[d.ops.drag].name)
	if d.player.floor==1 and target_id=="" and d.ops.drag=="":target_panel.text="흙벽 클릭 → 걸어가서 도구질 / E 가까운 벽 / R 곡괭이·삽 / 내구도 %d" % int(d.excavation.durability)
	var near_id: String=Simulation.Intrigue.select_near(sim)
	var actionable: bool=Simulation.Intrigue.available(sim)
	var reachable: bool=near_id!="" and Simulation.Intrigue.close(sim,near_id)
	action_buttons.subdue.disabled=not (actionable and reachable and d.people[near_id].state in ["waiting","staying","entering"] and d.ops.drag=="" and d.player.carry=="")
	action_buttons.drag.disabled=not (actionable and (d.ops.drag!="" or (reachable and d.people[near_id].state in ["down","captive"])))
	action_buttons.cell.disabled=not actionable or d.player.floor!=1
	action_buttons.cell.text="구금 [B]" if d.ops.built else "구금칸 8닢 [B]"
	action_buttons.dig.disabled=d.player.floor!=1 or not actionable or d.ops.drag!=""
	floor_button.disabled=not actionable
	action_buttons.bribe.disabled=not actionable or not sim.near_counter() or d.ops.inspector.state!="waiting"
	var investigation: Dictionary=d.ops.inspector
	if investigation.state!="idle":
		var phases_i: Dictionary={"scheduled":"경비 방문 %.0f초" % maxf(0,investigation.at-d.clock),"entering":"경비 도착","waiting":"접수대 E 조사 허용 / O 뇌물 12닢","search":"경비 입구 조사","sweep":"경비 지하 조사","return_below":"경비 복귀","leaving":"경비 퇴장"}
		awareness.text+="\n신고 %d건 · %s" % [int(d.ops.reports),phases_i.get(investigation.state,investigation.state)]
		awareness.add_theme_font_size_override("font_size",15)
	else:awareness.add_theme_font_size_override("font_size",17)
	notice.text=""
	if d.ops.drag!="":notice.text="대상 운반 중 · 이동이 느려진다 / 지하 B 구금 / C 내려놓기"
	if d.player.carry!="":notice.text="식사 운반 중 → "+str(d.people[d.orders[d.player.carry].guest].name)
	if d.player.floor==1 and d.ops.drag=="":notice.text="곡괭이·삽 기본 지급 / 내구도 %d · T: 접수대 수리 2닢 / 흙벽 클릭 또는 E로 파기" % int(d.excavation.durability)
	if d.excavation.intent!="":notice.text="입구/흙벽으로 이동 중 · WASD 또는 X로 취소"
	if d.player.floor==1 and pending>0:notice.text+=" / 위층 주문 %d건" % pending

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
	dig_progress.visible=not d.dig.is_empty()
	if not d.dig.is_empty():dig_progress.value=100*(1-d.dig.remaining/(10.0 if d.dig.get("quiet",false) else 4.0))
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
		sim.note("저장된 기록이 없다. F5로 먼저 저장하자.")
		return
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://inn-v03.json"))
	if not sim.restore(saved):
		sim.note("이 버전에서 읽을 수 없는 저장 파일이다.")
		return
	last_cell_count=-1
	sim.note("저장한 상태로 돌아왔다.")
	sync_view(0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: pointer_position=event.position

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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(8 if sim.data.player.floor==1 else 15,camera.size-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(32,camera.size+1)
		if event.button_index==MOUSE_BUTTON_LEFT:
			var target_id:=pick_person(event.position)
			if target_id!="":sim.data.ops.selected=target_id
			elif sim.data.player.floor==1:
				var hit: Variant=Plane(Vector3.UP,0.9).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
				if hit!=null:sim.queue_dig(Vector2i(roundi(hit.x),roundi(hit.z)))
			elif event.position.distance_to(camera.unproject_position(Vector3(Simulation.HATCH.x,0.15,Simulation.HATCH.y)))<40:sim.queue_floor()
			else:sim.data.ops.selected=""

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
		var mouse:=pointer_position
		var hit: Variant=Plane(Vector3.UP,0.9).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null:
			hover_cell=Vector2i(roundi(hit.x),roundi(hit.z))
			if dig_cursor!=null:
				dig_cursor.visible=earth_edges.has(Simulation.cell_key(hover_cell))
				dig_cursor.position=Vector3(hover_cell.x,0.94,hover_cell.y)
	var focus_target:=Vector3(sim.data.player.pos.x,0,sim.data.player.pos.y)
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

func input_verify() -> void:
	# Exercise actual viewport button/input dispatch, not only simulation calls.
	set_physics_process(false)
	var checks: Array=[]
	sim.data.player.pos=Simulation.COUNTER
	await get_tree().process_frame
	var initial_motion:=InputEventMouseMotion.new()
	initial_motion.position=Vector2(65,277)
	get_viewport().push_input(initial_motion,true)
	await get_tree().process_frame
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=Vector2(65,277)
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	mouse=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=Vector2(65,277)
	mouse.pressed=false
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	checks.append(sim.data.rooms["1"].guest!="")
	sim.tick(17)
	await send_key(KEY_E)
	checks.append(sim.data.work.get("type","")=="cook")
	sim.tick(4)
	await send_key(KEY_F5)
	var coins: int=sim.data.money
	sim.data.money=999
	await send_key(KEY_F9)
	checks.append(sim.data.money==coins and sim.data.player.carry!="")
	await send_key(KEY_SPACE)
	checks.append(sim.data.paused)
	await send_key(KEY_SPACE)
	checks.append(not sim.data.paused)
	sim.data.player.pos=Simulation.HATCH
	await send_key(KEY_Q)
	sync_view(0)
	checks.append(sim.data.player.floor==1 and not surface.visible and basement.visible)
	sim.data.player.pos=Vector2(1,0)
	var hit:=camera.unproject_position(Vector3(2,0.9,0))
	var motion:=InputEventMouseMotion.new()
	motion.position=hit
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	_physics_process(0)
	checks.append(hover_cell==Vector2i(2,0))
	mouse=InputEventMouseButton.new()
	mouse.position=hit
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	checks.append(not sim.data.dig.is_empty())
	await send_key(KEY_R)
	checks.append(not sim.data.stealth.quiet) # active dig cannot change its terms
	await send_key(KEY_X)
	checks.append(sim.data.dig.is_empty())
	await send_key(KEY_R)
	checks.append(sim.data.stealth.quiet)
	await send_key(KEY_V)
	checks.append(not show_vision)
	await send_key(KEY_M)
	checks.append(muted)
	var geometry: Array=sim.obstacles.duplicate()
	sim=Simulation.new()
	sim.obstacles.assign(geometry)
	sim.rebuild_grid()
	sim.data.player.pos=Simulation.COUNTER
	sync_view(0)
	var target_point:=camera.unproject_position(Vector3(sim.data.people.guest_1.pos.x,0.65,sim.data.people.guest_1.pos.y))
	mouse=InputEventMouseButton.new()
	mouse.position=target_point
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	mouse=InputEventMouseButton.new()
	mouse.position=target_point
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=false
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	checks.append(sim.data.ops.selected=="guest_1")
	await send_key(KEY_J)
	checks.append(sim.data.ops.contract.state=="active")
	sim.data.player.pos=sim.data.people.guest_1.pos
	await send_key(KEY_Z)
	checks.append(sim.data.work.get("type","")=="subdue")
	sim.tick(2.1)
	await send_key(KEY_C)
	checks.append(sim.data.ops.drag=="guest_1")
	sim.data.player.pos=Simulation.HATCH
	await send_key(KEY_Q)
	checks.append(sim.data.people.guest_1.floor==1 and sim.data.people.guest_1.pos==sim.data.player.pos)
	sim.data.cells["2,0"]=true
	sim.data.player.pos=Vector2(2,0)
	Simulation.Intrigue.sync_drag(sim)
	await send_key(KEY_B)
	checks.append(sim.data.ops.built)
	await send_key(KEY_B)
	checks.append(sim.data.people.guest_1.state=="captive" and sim.data.ops.drag=="")
	sim=Simulation.new()
	sim.obstacles.assign(geometry)
	sim.rebuild_grid()
	sync_view(0)
	mouse=InputEventMouseButton.new()
	mouse.position=Vector2(450,247)
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	mouse=InputEventMouseButton.new()
	mouse.position=Vector2(450,247)
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=false
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	checks.append(sim.data.excavation.intent=="floor")
	sim.tick(5)
	sync_view(0)
	checks.append(sim.data.player.floor==1 and sim.data.excavation.hatch_open)
	var soil_screen:=camera.unproject_position(Vector3(2,0.9,0))
	mouse=InputEventMouseButton.new()
	mouse.position=soil_screen
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	get_viewport().push_input(mouse,true)
	await get_tree().process_frame
	checks.append(sim.data.excavation.intent=="dig")
	sim.tick(6)
	checks.append(sim.data.cells.has("2,0") and sim.data.excavation.durability==23)
	await send_key(KEY_E)
	checks.append(sim.data.excavation.intent=="dig" or not sim.data.dig.is_empty())
	sim.tick(6)
	checks.append(sim.data.cells.size()==27 and sim.data.excavation.durability==22)
	sim.data.player.floor=0
	sim.data.player.pos=Simulation.COUNTER
	await send_key(KEY_T)
	checks.append(sim.data.excavation.durability==24)
	var failed:=0
	for i in range(checks.size()):
		if not checks[i]:
			failed+=1
			print("INPUT FAIL: ",i)
	print("Viewport/input verification: %d checks, %d failures" % [checks.size(),failed])
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
	panels_hidden=not panels_hidden
	for node in information_controls:node.visible=not panels_hidden
