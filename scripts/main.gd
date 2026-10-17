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
	box(Vector3(14.4, 0.35, 8.4), Vector3(0, -0.17, 0), Color("342e29"), true)
	for x in range(-7, 7):
		for z in range(-4, 4):
			model("town", "planks", Vector3(x + 0.5, 0.01, z + 0.5), Vector3(0.99, 0.06, 0.99))
	# Back and west walls remain tall; front walls are deliberately cut away.
	for x in range(-7, 7):
		model("town", "wall-wood-window-small" if x % 4 == 0 else "wall-wood", Vector3(x + 0.5, 0.07, -4), Vector3(0.17, 2.5, 1), PI / 2, true)
	for z in range(-4, 4):
		model("town", "wall-wood", Vector3(-7, 0.07, z + 0.5), Vector3(0.17, 2.5, 1), 0, true)
	box(Vector3(0.15, 0.45, 8), Vector3(7, 0.24, 0), Color("66523a"), true)
	box(Vector3(14, 0.45, 0.15), Vector3(0, 0.24, 4), Color("66523a"), true)
	# Room partition with two open doorways at z=-2 and z=2.
	for z in range(-4, 4):
		if z == -3 or z == 1:
			continue
		box(Vector3(0.16, 1.0, 1), Vector3(2, 0.55, z + 0.5), Color("76654c"), true)
	box(Vector3(5, 1, 0.15), Vector3(4.5, 0.55, 0), Color("76654c"), true)
	for z in [-2.0, 2.0]:
		model("furniture", "bedSingle", Vector3(5.6, 0.08, z), Vector3(1.1, 0.75, 2.0), 0, true)
		model("furniture", "rugRectangle", Vector3(3.7, 0.08, z), Vector3(1.4, 0.025, 2.0))
	model("furniture", "table", Vector3(-1.7, 0.08, -2.7), Vector3(2.7, 0.95, 0.9), 0, true)
	model("furniture", "books", Vector3(-2.4, 1.04, -2.7), Vector3(0.5, 0.17, 0.35))
	model("furniture", "bookcaseOpen", Vector3(-5.4, 0.08, -3.4), Vector3(1.35, 1.9, 0.4), 0, true)
	for x in [-4.8, -1.6]:
		model("furniture", "tableRound", Vector3(x, 0.08, 0.4), Vector3(1.4, 0.8, 1.4), 0, true)
		for z in [-0.7, 1.6]:
			model("furniture", "chair", Vector3(x, 0.08, z), Vector3(0.52, 1, 0.58), PI if z < 0 else 0, true)
	model("furniture", "bench", Vector3(-5.5, 0.08, 3), Vector3(1.8, 0.9, 0.6), 0, true)
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
	world_label("Q  지하",Vector3(-3.25,0.18,2.75),surface)
	sim.rebuild_grid()
	player = actor(Vector3.ZERO,Color("8f7147"))
	staff_visual = actor(Vector3.ZERO,Color("4a7771"))
	collector_visual = actor(Vector3.ZERO,Color("6d3b47"))
	carried_visuals["player"] = make_tray(player)
	carried_visuals["staff"] = make_tray(staff_visual)
	world_label("주인",Vector3(0,1.95,0),player)
	world_label("직원",Vector3(0,1.95,0),staff_visual)
	world_label("징수원",Vector3(0,1.95,0),collector_visual)
	world_root = basement
	light_at(Vector3(0,2.8,0),1.2)
	world_label("Q  위층",Vector3(0,0.45,0),basement)
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
	elif "--capture" in args or "--capture-basement" in args:
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
		sync_view(0)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := "res://docs/v03-basement.png" if "--capture-basement" in args else "res://docs/v03-surface.png"
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

func button(canvas: CanvasLayer, text_: String, pos: Vector2, size_: Vector2, callback: Callable) -> void:
	var control:=Button.new()
	control.text=text_
	control.position=pos
	control.size=size_
	control.add_theme_font_override("font",ui_font)
	control.add_theme_font_size_override("font_size",17)
	control.focus_mode=Control.FOCUS_NONE
	control.pressed.connect(callback)
	canvas.add_child(control)

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
	hud.text="문 닫은 뒤  /  국경 여관  0.3\n%d일  %02d:%02d    보유 %d닢    미납 %d닢    %s    %s" % [day,within/60,within%60,d.money,d.debt,"지하" if d.player.floor==1 else "위층","일시정지" if d.paused else "%d배속" % d.speed]
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
		var modes: Dictionary={"idle":"대기","counter":"접수대 이동","cooking":"식사 준비","delivery":"서빙","return":"복귀"}
		staff_status+=" · "+str(modes.get(d.staff.mode,d.staff.mode))
	status.text="객실\n%s\n%s\n\n직원  %s\n\n주문 %d건 / 제공 %d회\n%s\n\n예정 납기\n%s 임금 4닢\n%s 임대료 12닢\n%s 세금 8닢" % [room_text(1),room_text(2),staff_status,pending,d.served,"\n".join(order_lines.slice(0,3)),when_text(d.dues.wage),when_text(d.dues.rent),when_text(d.dues.tax)]
	if d.collector:status.text+="\n징수원 대기: 접수대 E"
	var lines: Array[String]=[]
	for item in d.logs.slice(maxi(0,d.logs.size()-3)):
		lines.append("· "+str(item.text))
	feed.text="최근 소식\n"+"\n".join(lines)
	var action: String="접수대 E: 식사 준비·집기  /  주문 손님 곁 E: 전달  /  퇴실한 객실 E: 청소"
	if d.player.floor==1:action="입구 Q: 위층 복귀  /  바로 옆 흙벽 클릭: 4초 굴착·1닢  /  위층 영업은 계속 진행"
	if not d.work.is_empty():action="작업 중  %.1f초 남음 · X로 중단" % d.work.remaining
	if not d.dig.is_empty():action="굴착 중  %.1f초 남음 · 소음 %.1f · X로 중단" % [d.dig.remaining,d.noise]
	hint.text=action+"\nWASD 이동   1/2 방 배정   G 거절   H 직원   Q 계단   Space 정지   Tab 배속   휠 확대\nF5 저장   F9 불러오기   X 작업 중단   Esc 종료   |   직원 임금·임대료·세금은 시제품 조정값"
	notice.text=""
	if d.player.carry!="":notice.text="식사 운반 중 → "+str(d.people[d.orders[d.player.carry].guest].name)
	if d.player.floor==1 and pending>0:notice.text="위층 주문 %d건 · 직원 %s" % [pending,staff_status]

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
	collector_visual.position=Vector3(-0.2,0.08,-1.5)
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
		actors[id].visible=upstairs and person.state!="gone"
		sync_actor(actors[id],person.pos,dt)
		labels[id].text=person.name+" · 대기" if person.state=="waiting" else person.name
	if last_cell_count!=d.cells.size():rebuild_basement()
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
			KEY_Q:sim.change_floor()
			KEY_X:sim.cancel_work()
			KEY_F5:save_game()
			KEY_F9:load_game()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(8 if sim.data.player.floor==1 else 15,camera.size-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(32,camera.size+1)
		if event.button_index==MOUSE_BUTTON_LEFT and sim.data.player.floor==1:sim.start_dig(hover_cell)

func _physics_process(delta: float) -> void:
	if capturing:return
	if not sim.data.paused:
		var direction:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		var right:=Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
		var down:=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
		var speed_: float=2.2 if sim.data.player.carry!="" else 2.9
		sim.move_player((right*direction.x+down*direction.y)*delta*speed_*sim.data.speed)
		sim.tick(delta*sim.data.speed)
	if sim.data.player.floor==1:
		var mouse:=pointer_position
		var hit: Variant=Plane(Vector3.UP,0.9).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null:
			hover_cell=Vector2i(roundi(hit.x),roundi(hit.z))
			if dig_cursor!=null:
				dig_cursor.visible=earth_edges.has(Simulation.cell_key(hover_cell))
				dig_cursor.position=Vector3(hover_cell.x,0.94,hover_cell.y)
	var focus_target:=Vector3(sim.data.player.pos.x,0,sim.data.player.pos.y) if sim.data.player.floor==1 else Vector3.ZERO
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
	var failed:=0
	for i in range(checks.size()):
		if not checks[i]:
			failed+=1
			print("INPUT FAIL: ",i)
	print("Viewport/input verification: %d checks, %d failures" % [checks.size(),failed])
	get_tree().quit(0 if failed==0 else 1)
