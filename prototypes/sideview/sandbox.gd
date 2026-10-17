extends Node2D
const Terrain = preload("res://terrain.gd")
const Player = preload("res://player.gd")
const Business = preload("res://simulation.gd")
const Navigation = preload("res://navigation.gd")
var terrain = Terrain.new()
var inn = Business.new()
var player: CharacterBody2D
var camera: Camera2D
var geometry: Node2D
var lighting: Node2D
var atlas = preload("res://assets/world_tileset.png")
var font = preload("res://assets/InnKorean.otf")
var ui: Control
var labels: Dictionary = {}
var modes: Dictionary = {}
var mode = "move"
var build_material = "wood"
var target = Vector2i(-999,-999)
var pointer_down = false
var active_touch = -1
var cursor_world = Vector2.ZERO
var selected_person = -1
var clock = 0.0
var order_clock = 0.0
var wage_clock = 0.0
var guard_clock = 0.0
var noise_clock = 0.0
var suspicion = 0.0
var employee_alert = 0.0
var noise_pos = Vector2.ZERO
var noise_age = 99.0
var noise_power = 0.0
var hatch_open = false
var paused = false
var dragging = -1
var people: Array = []
var noise_player: AudioStreamPlayer
var gentle_opening=false
var save_path = "user://inn-object-v2.json"
var message = "바닥을 눌러 이동 · 손님을 눌러 행동 선택"
var rebuild_pending = false
var test_mode = false
var navigation=Navigation.new()
var walking_route: Array=[]
var navigation_testing=false
var navigation_pending_use=false
var navigation_jump_time=0.0
var navigation_step_started=false
var navigation_step_time=0.0
var destination=Vector2.ZERO
var destination_valid=false
var marker_time=0.0
var navigation_carrying=false
var automatic_mining=false
var navigation_job: Dictionary={}
var use_button: Button

var episode=preload("res://episode.gd").new()
var episode_ui
var tools: Control
var stop_button: Button
var room_button: Button
var room_picker: Control
var tools_visible=false

var object_context
var pending_person_action: Dictionary={}
var camera_overview=false
var camera_dragging=false
var drag_origin=Vector2.ZERO
var camera_pan=Vector2.ZERO
var context_cell=Vector2i.ZERO
var npc_bodies: Array=[]
var gesture_active=false
var gesture_started=0

func _ready() -> void:
	_setup_input()
	var canvas = CanvasModulate.new(); canvas.color=Color("8d91a2"); add_child(canvas)
	player=Player.new(); player.position=Vector2(27*32,21*32-28); add_child(player)
	camera=Camera2D.new(); camera.position=Vector2(23*32,300)
	camera.limit_left=0; camera.limit_top=-640; camera.limit_right=84*32; camera.limit_bottom=54*32
	camera.zoom=Vector2.ONE
	camera.position_smoothing_enabled=false; add_child(camera)
	people=[
		{"name":"상인","pos":Vector2(25*32,21*32),"face":1,"down":false,"room":0,"target":25*32,"idle":0.0},
		{"name":"수상한 손님","pos":Vector2(31*32,21*32),"face":-1,"down":false,"room":1,"target":31*32,"idle":0.0},
		{"name":"직원","pos":Vector2(29*32,21*32),"face":-1,"down":false,"room":0,"target":29*32,"idle":0.0}
	]
	for i in range(people.size()):
		var body=Player.new(); body.position=people[i].pos-Vector2(0,27); body.speed_factor=0.52; add_child(body)
		body.modulate=[Color("c9ba8b"),Color("ac7e83"),Color("80aba0")][i]; npc_bodies.append(body)
		people[i].route=[]; people[i].nav_started=false; people[i].nav_time=0.0; people[i].nav_jump=0.0
	noise_player=AudioStreamPlayer.new(); noise_player.stream=preload("res://assets/tap.wav"); noise_player.volume_db=-17; add_child(noise_player)
	_rebuild_geometry(); _rebuild_lights(); _setup_ui()
	episode_ui=preload("res://episode_ui.gd").new(); add_child(episode_ui); episode_ui.setup(self,episode)
	var args=OS.get_cmdline_user_args()
	if args.is_empty():
		gentle_opening=true; episode.data.briefed=true
		message="손님을 누르고 방을 골라주세요. 주인이 알아서 다가갑니다."
		for i in range(2):
			people[i].hidden=true; people[i].return_at=4.0 if i==0 else 52.0
		episode_ui.refresh()
	if "--episode-playthrough" in args or "--capture-ending" in args:
		test_mode=true
		var failed=await verify_episode_playthrough("--capture-ending" in args)
		get_tree().quit(failed); return
	if "--episode-verify" in args:
		test_mode=true; get_tree().quit(preload("res://episode_tests.gd").new().run()); return
	if "--capture-episode" in args or "--capture-episode-cellar" in args:
		await capture_episode("--capture-episode-cellar" in args); return
	if "--capture-context" in args or "--capture-context-clean" in args:
		await capture_context("--capture-context" in args); return
	if "--verify" in args:
		test_mode=true
		var failures: int=load("res://tests.gd").new().run()
		failures+=load("res://sandbox_tests.gd").new().run()
		get_tree().quit(0 if failures==0 else 1); return
	if "--input-verify" in args:
		test_mode=true; await _verify_inputs(); return

func _setup_input() -> void:
	var bindings={"walk_left":[KEY_A,KEY_LEFT],"walk_right":[KEY_D,KEY_RIGHT],"leap":[KEY_SPACE],"climb_up":[KEY_W,KEY_UP],"climb_down":[KEY_S,KEY_DOWN],"use":[KEY_E]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var ev=InputEventKey.new(); ev.physical_keycode=key; InputMap.action_add_event(action,ev)

func _make_shape(body: StaticBody2D,rect: Rect2,one_way: bool=false) -> void:
	var collision=CollisionShape2D.new(); var shape=RectangleShape2D.new(); shape.size=rect.size
	collision.shape=shape; collision.position=rect.get_center(); collision.one_way_collision=one_way
	collision.one_way_collision_margin=8; body.add_child(collision)

func _rebuild_geometry() -> void:
	if is_instance_valid(geometry):
		remove_child(geometry); geometry.queue_free()
	geometry=Node2D.new(); add_child(geometry)
	var solids=StaticBody2D.new(); solids.collision_layer=1; solids.collision_mask=0; geometry.add_child(solids)
	var platforms=StaticBody2D.new(); platforms.collision_layer=4; platforms.collision_mask=0; geometry.add_child(platforms)
	# Merge adjacent cells into row runs to keep collider count small.
	for y in range(-9,Terrain.HEIGHT):
		var start=-1
		for x in range(Terrain.WIDTH+1):
			var solid=x<Terrain.WIDTH and terrain.solid(Vector2i(x,y))
			if solid and start<0: start=x
			if not solid and start>=0:
				var rect=Rect2(start*32,y*32,(x-start)*32,32)
				_make_shape(solids,rect)
				var occ=LightOccluder2D.new(); var poly=OccluderPolygon2D.new()
				poly.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
				occ.occluder=poly; geometry.add_child(occ); start=-1
	for c in terrain.cells:
		if terrain.cells[c]=="platform": _make_shape(platforms,Rect2(c.x*32,c.y*32,32,7),true)
	if not hatch_open: _make_shape(solids,Rect2(14*32,21*32,64,10))
	_make_shape(solids,Rect2(0,0,32,54*32)); _make_shape(solids,Rect2(83*32,0,32,54*32))
	_make_shape(solids,Rect2(0,53*32,84*32,32))
	rebuild_pending=false

func _rebuild_lights() -> void:
	if is_instance_valid(lighting): lighting.queue_free()
	lighting=Node2D.new(); add_child(lighting)
	for c in terrain.torches:
		var point=PointLight2D.new(); var g=Gradient.new()
		g.colors=PackedColorArray([Color(1,1,1,0.95),Color(1,1,1,0)])
		var t=GradientTexture2D.new(); t.gradient=g; t.width=512; t.height=512
		t.fill=GradientTexture2D.FILL_RADIAL; t.fill_from=Vector2(0.5,0.5); t.fill_to=Vector2(0.5,1)
		point.texture=t; point.position=terrain.center(c); point.color=Color("ffb75f")
		point.energy=1.0; point.shadow_enabled=true; lighting.add_child(point)

func _label(key: String,text: String,rect: Rect2,size: int=24) -> Label:
	var l=Label.new(); l.text=text; l.position=rect.position; l.size=rect.size
	l.add_theme_font_override("font",font); l.add_theme_font_size_override("font_size",size)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(l); labels[key]=l; return l
func _panel(rect: Rect2) -> void:
	var panel=ColorRect.new(); panel.position=rect.position; panel.size=rect.size; panel.color=Color("111c29")
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(panel)
func _button(text: String,rect: Rect2,fn: Callable) -> Button:
	var b=Button.new(); b.text=text; b.position=rect.position; b.size=rect.size
	b.add_theme_font_override("font",font); b.add_theme_font_size_override("font_size",23)
	var style=StyleBoxFlat.new(); style.bg_color=Color("354957"); style.border_color=Color("859896")
	style.set_border_width_all(2); style.set_corner_radius_all(5); b.add_theme_stylebox_override("normal",style)
	b.pressed.connect(fn); ui.add_child(b); return b
func _touch_button(text: String,rect: Rect2,action: String) -> TouchScreenButton:
	var b=TouchScreenButton.new(); b.position=rect.position; b.action=action
	var gradient=Gradient.new(); gradient.colors=PackedColorArray([Color("405868"),Color("405868")])
	var texture=GradientTexture2D.new(); texture.gradient=gradient; texture.width=int(rect.size.x); texture.height=int(rect.size.y)
	b.texture_normal=texture
	var pressed_gradient=Gradient.new(); pressed_gradient.colors=PackedColorArray([Color("b68f54"),Color("b68f54")])
	var pressed_texture=GradientTexture2D.new(); pressed_texture.gradient=pressed_gradient
	pressed_texture.width=int(rect.size.x); pressed_texture.height=int(rect.size.y); b.texture_pressed=pressed_texture
	ui.add_child(b)
	var l=Label.new(); l.text=text; l.size=rect.size; l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font",font); l.add_theme_font_size_override("font_size",27); l.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(l)
	return b

func _setup_ui() -> void:
	var layer=CanvasLayer.new(); add_child(layer); ui=Control.new(); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	# Legacy references have no visible controls. All actions belong to clicked objects.
	use_button=Button.new(); ui.add_child(use_button); use_button.hide()
	stop_button=Button.new(); ui.add_child(stop_button); stop_button.hide()
	room_picker=Control.new(); ui.add_child(room_picker); room_picker.hide()
	tools=Control.new(); ui.add_child(tools); tools.hide()
	object_context=preload("res://object_context.gd").new(); add_child(object_context); object_context.setup(self)

func _toggle_tools() -> void:
	tools_visible=not tools_visible; tools.visible=tools_visible

func _choose_tool(value: String) -> void:
	_select_mode(value); tools_visible=false; tools.hide()

func _overview_camera() -> void:
	camera_overview=not camera_overview; camera_pan=Vector2.ZERO
	camera.zoom=Vector2(0.68,0.68) if camera_overview else Vector2.ONE

func _show_room_picker() -> void:
	room_picker.visible=not room_picker.visible

func _assign_guest_room(chosen: int) -> void:
	room_picker.hide()
	if paused: return
	var index=selected_person if selected_person in [0,1] else 0
	var p: Dictionary=people[index]
	if p.down: message="기절한 손님은 접수할 수 없다."; return
	if player.position.distance_to(p.pos-Vector2(0,19))>95: message="손님에게 먼저 다가가야 한다."; return
	# Guest reservations expire; a reused room must be cleaned before sale.
	if p.get("checkout",0.0)>clock: message="이미 투숙 중인 손님이다."; return
	if p.get("dirty",false): p.dirty=false; message="객실을 청소했다. 다시 눌러 새 손님을 받자."; return
	for guest in people.slice(0,2):
		if guest!=p and guest.room==chosen and guest.get("checkout",0.0)>clock:
			message="그 방은 이미 사용 중이다. 다른 손님을 선택하자."; return
	p.room=chosen; p.checkout=clock+70; p.dirty=true; inn.coins+=8
	_npc_route(index,Vector2((24 if chosen==1 else 33)*32+16,14*32))
	message="%s → %d호. 숙박비 8닢" %[p.name,chosen]

func _pause() -> void:
	paused=not paused; player.active=not paused
	pointer_down=false
	for action in ["walk_left","walk_right","leap","climb_up","climb_down"]: Input.action_release(action)
	_update_ui()
func _select_mode(value: String) -> void:
	_stop_navigation()
	mode=value; pointer_down=false; terrain.mining_progress=0
	if value!="hand": selected_person=-1
	_update_ui()

func _stop_navigation() -> void:
	pending_person_action.clear()
	walking_route.clear(); navigation_pending_use=false; navigation_step_started=false
	navigation_job.clear(); automatic_mining=false; pointer_down=false; terrain.mining_progress=0
	navigation_jump_time=0; navigation_step_time=0
	player.axis=0; player.climb_axis=0; player.jump_held=false

func _ensure_navigation() -> void:
	if navigation.revision!=terrain.revision or navigation.hatch_open!=hatch_open or navigation_carrying!=(dragging>=0):
		navigation.rebuild(terrain,hatch_open,dragging>=0); navigation_carrying=dragging>=0

func _navigate_to(point: Vector2) -> bool:
	_stop_navigation(); pointer_down=false
	if paused: message="계속하기를 누른 뒤 이동하자."; return false
	_ensure_navigation()
	walking_route=navigation.route(player.position,point)
	marker_time=4; destination=point; destination_valid=not walking_route.is_empty()
	if walking_route.is_empty():
		message="지금은 갈 수 없다. 덮개·막힌 길·발판을 확인하자."; return false
	destination=walking_route.back().point+Vector2(0,27)
	message="목적지로 이동 중. 다시 누르면 목적지를 바꾼다."
	return true

func _approach(point: Vector2,reach: float) -> bool:
	_stop_navigation(); _ensure_navigation()
	walking_route=navigation.route_near(player.position,point,reach)
	destination_valid=not walking_route.is_empty(); marker_time=4; destination=point
	if not destination_valid: message="작업할 수 있는 가까운 발판으로 갈 길이 없다."; return false
	destination=walking_route.back().point+Vector2(0,27); return true

func _tap_world() -> void:
	if object_context.panel.visible: object_context.close()
	if mode!="move":
		if mode=="hand": _select_person()
		return
	_stop_navigation(); selected_person=-1
	_ensure_navigation()
	for i in range(people.size()):
		if people[i].get("hidden",false): continue
		if cursor_world.distance_to(people[i].pos-Vector2(0,25))<38:
			selected_person=i; pointer_down=false; object_context.open("person",str(i)); return
	if cursor_world.distance_to(Vector2(29*32,20*32))<58:
		pointer_down=false; object_context.open("counter"); return
	if cursor_world.distance_to(Vector2(15*32,21*32))<43:
		pointer_down=false; object_context.open("hatch"); return
	if cursor_world.distance_to(player.position)<24:
		pointer_down=false; object_context.open("owner"); return
	object_context.close()
	if paused: return
	for c in terrain.torches:
		if cursor_world.distance_to(terrain.center(c))<22:
			if _approach(terrain.center(c),70): navigation_pending_use=true
			return
	var c=terrain.cell_at(cursor_world)
	# Tapping a floor should walk there. Buried earth/stone selects the pickaxe.
	if terrain.cells.get(c,"") in ["dirt","stone"] and not navigation.clear_at(navigation.world(c)):
		if player.position.distance_to(terrain.center(c))<=128:
			_begin_automatic_mining(c)
		elif _approach(terrain.center(c),118):
			navigation_job={"action":"mine","cell":c}; message="가까이 가서 곡괭이로 한 칸 채굴한다."
		return
	_navigate_to(cursor_world)

func _begin_automatic_mining(c: Vector2i) -> void:
	target=c; terrain.mining_progress=0; automatic_mining=true; pointer_down=true
	message="곡괭이 자동 선택 · 한 칸 채굴 중. 새 목적지를 누르면 취소."

func _drive_navigation(delta: float) -> void:
	if walking_route.is_empty(): return
	var step: Dictionary=walking_route[0]
	var diff: Vector2=step.point-player.position
	# A jump can land on a higher one-way platform than predicted.
	# Replan from the real landing rather than trying to descend through it.
	if navigation_step_started and player.is_on_floor() and ((step.kind=="jump" and diff.y>18) or (step.kind=="drop" and diff.y < -18 and navigation_step_time>0.3)):
		var goal=destination; var pending=navigation_pending_use; var job=navigation_job.duplicate(); var person_job=pending_person_action.duplicate()
		if _navigate_to(goal): navigation_pending_use=pending; navigation_job=job; pending_person_action=person_job
		return
	if absf(diff.x)<9 and absf(diff.y)<10 and (step.kind!="jump" or player.is_on_floor()):
		walking_route.pop_front(); navigation_step_started=false; navigation_step_time=0
		if walking_route.is_empty():
			player.axis=0; player.climb_axis=0; player.jump_held=false
			message="도착했다."
			if not navigation_job.is_empty():
				var job=navigation_job.duplicate(); navigation_job.clear()
				if job.action=="mine": _begin_automatic_mining(job.cell)
			if not pending_person_action.is_empty():
				var action_=pending_person_action.duplicate(); pending_person_action.clear(); _perform_person_action(int(action_.id),action_.action)
			if navigation_pending_use:
				navigation_pending_use=false; _interact()
			return
		step=walking_route[0]; diff=step.point-player.position
	navigation_step_time+=delta
	if navigation_step_time>4.5:
		if test_mode: print("NAV STALL ",step," at ",player.position," floor=",player.is_on_floor())
		_stop_navigation(); destination_valid=false; marker_time=3; message="길이 막혔다. 다른 바닥을 눌러 경로를 바꾸자."; return
	player.axis=clampf(diff.x/30.0,-1,1) if absf(diff.x)>5 else 0.0
	player.climbing=absf(player.position.x-15*32)<30 and player.position.y>-1*32 and player.position.y<26*32
	player.climb_axis=0; player.crouch=false
	if player.climbing and step.kind!="jump":
		player.axis=clampf(diff.x/20.0,-1,1); player.climb_axis=clampf(diff.y/12.0,-1,1)
		if step.kind=="walk" and absf(diff.x)>5:
			# Lift the feet slightly above the lip before leaving the ladder.
			player.climb_axis=clampf((step.point.y-2-player.position.y)/8.0,-0.35,0.35)
	if not navigation_step_started:
		if step.kind=="jump" and (player.is_on_floor() or player.climbing):
			if player.climbing: player.coyote=0.10
			player.jump_requested=true; navigation_jump_time=0.5; navigation_step_started=true
		elif step.kind=="drop":
			player.drop_down(); navigation_step_started=true
		elif step.kind!="jump": navigation_step_started=true
	navigation_jump_time=maxf(0,navigation_jump_time-delta)
	player.jump_held=navigation_jump_time>0
	if navigation_jump_time>0: player.climbing=false

func _go_counter() -> void:
	selected_person=-1; _select_mode("move")
	_navigate_to(Vector2(28*32+16,21*32))

func _go_hatch() -> void:
	selected_person=-1; _select_mode("move")
	_navigate_to(Vector2(16*32+16,21*32))

func _request_use() -> void:
	if dragging>=0: _interact(); return
	if selected_person>=0 and player.position.distance_to(people[selected_person].pos-Vector2(0,19))>65:
		var person: Dictionary=people[selected_person]
		if _navigate_to(person.pos-Vector2(person.face*32,0)): navigation_pending_use=true
	else: _interact()
func _material_next() -> void:
	var options=["wood","dirt","stone"]; build_material=options[(options.find(build_material)+1)%3]; _update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if camera_dragging: return
	if episode_ui!=null and episode_ui.opened: return
	if event is InputEventScreenTouch and event.pressed and event.position.y>153 and event.position.y<get_viewport().get_visible_rect().size.y:
		active_touch=event.index; pointer_down=true
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
		_tap_world()
	if event is InputEventScreenDrag and event.index==active_touch:
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if active_touch>=0: return
		if event.pressed: pointer_down=true
		elif not automatic_mining: pointer_down=false
		if event.pressed:
			cursor_world=get_canvas_transform().affine_inverse()*event.position
			target=terrain.cell_at(cursor_world)
			_tap_world()
	if event is InputEventMouseMotion and pointer_down:
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			context_cell=terrain.cell_at(get_canvas_transform().affine_inverse()*event.position); object_context.open("ground")
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var z=clampf(camera.zoom.x+(0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.1),0.55,1.5); camera.zoom=Vector2(z,z)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E: _request_use()
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_6:
			_select_mode(["move","mine","block","platform","torch","hand"][event.physical_keycode-KEY_1])

func _input(event: InputEvent) -> void:
	if episode_ui!=null and episode_ui.opened: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			gesture_active=not object_context.blocks(event.position); gesture_started=Time.get_ticks_msec(); drag_origin=event.position; camera_dragging=false
		else: gesture_active=false
	if event is InputEventScreenTouch:
		if event.pressed:
			gesture_active=not object_context.blocks(event.position); gesture_started=Time.get_ticks_msec(); drag_origin=event.position; camera_dragging=false
		else: gesture_active=false
	var dragged=event is InputEventScreenDrag or (event is InputEventMouseMotion and gesture_active and event.button_mask&MOUSE_BUTTON_MASK_LEFT)
	if dragged and gesture_active and mode=="move" and event.position.distance_to(drag_origin)>20:
		camera_dragging=true; _stop_navigation(); camera_pan-=event.relative/camera.zoom.x
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and active_touch<0 and not automatic_mining:
		pointer_down=false; terrain.mining_progress=0
	if event is InputEventScreenTouch and not event.pressed and event.index==active_touch:
		if not automatic_mining: pointer_down=false; terrain.mining_progress=0
		active_touch=-1

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer_down=false; active_touch=-1
		for action in ["walk_left","walk_right","leap","climb_up","climb_down"]:
			if InputMap.has_action(action): Input.action_release(action)

func _physics_process(_delta: float) -> void:
	_drive_npcs(_delta)
	if not is_instance_valid(player) or (test_mode and not navigation_testing) or paused: return
	var manual=absf(Input.get_axis("walk_left","walk_right"))>0 or Input.is_action_pressed("leap") or absf(Input.get_axis("climb_up","climb_down"))>0
	if not walking_route.is_empty() and not manual:
		_drive_navigation(_delta)
		return
	if manual and not walking_route.is_empty(): _stop_navigation()
	player.axis=Input.get_axis("walk_left","walk_right")
	player.jump_held=Input.is_action_pressed("leap")
	if Input.is_action_just_pressed("leap"): player.jump_requested=true
	player.climb_axis=Input.get_axis("climb_up","climb_down")
	player.climbing=absf(player.position.x-15*32)<30 and player.position.y>-1*32 and player.position.y<26*32 and not player.jump_held
	player.crouch=Input.is_action_pressed("climb_down") and not player.climbing
	if Input.is_action_just_pressed("climb_down") and not player.climbing: player.drop_down()
	player.carrying=dragging>=0

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if gesture_active and not camera_dragging and mode=="move" and not object_context.panel.visible and Time.get_ticks_msec()-gesture_started>550:
		gesture_active=false; _stop_navigation(); context_cell=terrain.cell_at(cursor_world); object_context.open("ground")
	if not paused and not test_mode:
		marker_time=maxf(0,marker_time-delta)
		clock+=delta; order_clock+=delta; wage_clock+=delta; guard_clock+=delta; noise_age+=delta
		employee_alert=maxf(0,employee_alert-delta)
		if pointer_down: _work_target(delta)
		if absf(player.velocity.x)>50 and player.is_on_floor():
			noise_clock+=delta
			if noise_clock>0.45:
				_noise(0.30 if dragging>=0 else (0.06 if player.crouch else 0.12)); noise_clock=0
		_business_tick(delta)
		if not gentle_opening: episode.tick(delta,episode_facts())
		if dragging>=0:
			people[dragging].pos=player.position+Vector2(-22*player.facing,18)
			if _witnessed(player.position): suspicion=minf(100,suspicion+delta*8)
		if player.position.y>52*32:
			player.position=Vector2(27*32,21*32-28); player.velocity=Vector2.ZERO; message="지하 경계에서 여관으로 복귀했다."
		var focus=Vector2(23*32,240) if camera_overview else Vector2(clampf(player.position.x,19*32,28*32),player.position.y if player.position.y>22*32 else 300)
		camera.position=camera.position.lerp(focus+camera_pan,minf(1,delta*5))
	_update_ui(); queue_redraw()
	episode_ui.refresh(); object_context.refresh()

func _work_target(delta: float) -> void:
	if mode=="mine" or automatic_mining:
		var old=terrain.mining_progress
		if terrain.mine(target,player.position,delta):
			message="채굴 완료. 자원이 가방에 들어왔다."
			if automatic_mining: pointer_down=false; automatic_mining=false
			_changed(); _noise(0.9)
		elif terrain.mining_progress>old:
			noise_clock+=delta
			if noise_clock>0.22: _noise(0.7); noise_clock=0
	elif mode in ["block","platform","torch"]:
		var kind=build_material if mode=="block" else mode
		var occupied=player.body_rect()
		# Do not seal an NPC or carried person into a new block.
		var rect=Rect2(Vector2(target*32),Vector2(32,32))
		for i in range(people.size()):
			if i==2 and not inn.hired: continue
			if rect.intersects(Rect2(people[i].pos-Vector2(14,38),Vector2(28,38))):
				message="사람이 있는 곳에는 설치할 수 없다."; pointer_down=false; return
		if terrain.place(target,player.position,kind,occupied):
			message="설치 완료."; _changed(); _noise(0.25)
		else: message="너무 멀거나, 자원·연결 면·빈 공간이 부족하다."
		pointer_down=false

func _changed() -> void:
	if not walking_route.is_empty():
		_stop_navigation(); message="지형이 바뀌었다. 목적지를 다시 눌러 경로를 확인하자."
	if not rebuild_pending:
		rebuild_pending=true; call_deferred("_rebuild_geometry")
	_rebuild_lights()

func _noise(power: float) -> void:
	noise_power=power; noise_age=0; noise_pos=player.position
	if power>0.2: noise_player.play()
	if not inn.hired: return
	var distance=people[2].pos.distance_to(player.position)
	var level=power*maxf(0,1-distance/550.0)
	if player.position.y>22*32 and not hatch_open: level*=0.3
	if level>=0.18:
		employee_alert=6; suspicion=minf(100,suspicion+power*2)
		people[2].target=15*32 if player.position.y>22*32 else player.position.x
		message="직원이 작업 소리를 듣고 출입구 쪽을 확인한다."

func _can_see(person: Dictionary,p: Vector2) -> bool:
	var eye: Vector2=person.pos-Vector2(0,28)
	var d=p-eye
	if absf(d.y)>70 or d.length()>260: return false
	if d.length()>30 and d.x*person.face<0: return false
	if d.length()>35 and terrain.light_at(p)<0.28: return false
	var ray=PhysicsRayQueryParameters2D.create(eye,p,1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func _witnessed(p: Vector2,excluded: int=-1) -> bool:
	for i in range(people.size()):
		if i==excluded or (i==2 and not inn.hired) or people[i].down: continue
		if _can_see(people[i],p): return true
	return false

func _select_person() -> void:
	selected_person=-1
	for i in range(2):
		if cursor_world.distance_to(people[i].pos-Vector2(0,22))<42:
			selected_person=i; message=people[i].name+" 선택. 가까이 가서 사용 / E."; break

func _interact() -> void:
	if paused: return
	if dragging>=0:
		dragging=-1; message="내려놓았다."; return
	if selected_person>=0:
		var p: Dictionary=people[selected_person]
		if player.position.distance_to(p.pos-Vector2(0,19))>65:
			message="선택한 손님에게 먼저 가까이 가자."; return
		if p.down: dragging=selected_person; message="운반 시작. 이동과 점프가 제한된다."; return
		if _can_see(p,player.position):
			suspicion=minf(100,suspicion+15); message="접근을 눈치챘다. 시선과 어둠을 살피자."; _noise(0.8); return
		p.down=true; suspicion=minf(100,suspicion+(35 if _witnessed(player.position,selected_person) else 0))
		_noise(0.45); message="기절시켰다. 손님을 다시 선택해 운반할 수 있다."; return
	var hatch=Vector2(15*32,21*32)
	if player.position.distance_to(hatch)<100:
		if hatch_open and player.body_rect().intersects(Rect2(14*32,21*32,64,12)):
			message="몸이 덮개에 걸려 있다. 옆으로 비켜서 닫자."; return
		hatch_open=not hatch_open; _changed(); message="덮개 "+("열림" if hatch_open else "닫힘"); return
	var nearest=-1; var distance=85.0
	for i in range(terrain.torches.size()):
		var d=terrain.center(terrain.torches[i]).distance_to(player.position)
		if d<distance: nearest=i; distance=d
	if nearest>=0:
		terrain.torches.remove_at(nearest); terrain.inventory.torch+=1; _rebuild_lights()
		message="횃불을 회수했다. 주변이 어두워진다."; return
	if player.position.distance_to(Vector2(29*32,21*32-19))<130:
		if not inn.hired:
			if inn.coins<8: message="직원 고용비 8닢이 필요하다."; return
			inn.coins-=8; inn.hired=true; message="직원 고용. 접객을 맡기고 자유롭게 움직이자."
		elif inn.orders>0:
			inn.orders-=1; inn.coins+=4; inn.served+=1; message="직접 식사 제공. +4닢"
		else: message="밀린 주문이 없다."
		return
	message="가까운 카운터·덮개·횃불 또는 선택한 손님에게 사용한다."

func _business_tick(delta: float) -> void:
	if order_clock>=12:
		order_clock-=12
		if inn.hired and employee_alert<=0 and inn.orders>0:
			inn.orders-=1; inn.coins+=2; inn.served+=1
		inn.orders=mini(4,inn.orders+1)
	if inn.hired and wage_clock>=90:
		wage_clock-=90
		if inn.coins>=6: inn.coins-=6
		else: inn.hired=false; message="급여가 부족해 직원이 떠났다."
	for i in range(people.size()):
		var p: Dictionary=people[i]
		if p.get("hidden",false):
			if clock>=p.get("return_at",INF) and (not gentle_opening or i==2 or not people.any(func(other): return other!=p and not other.get("hidden",false) and other.get("checkout",0.0)<=clock and other!=people[2])):
				p.hidden=false; p.down=false; p.room=0; p.checkout=0; p.pos=Vector2(38*32,21*32); npc_bodies[i].position=p.pos-Vector2(0,27)
				_npc_route(i,Vector2((25+i*4)*32,21*32))
			continue
		if p.down or (i==2 and not inn.hired): continue
		if p.get("checkout",0.0)>0 and clock>=p.checkout:
			p.checkout=0; _npc_route(i,Vector2((25+i*4)*32,21*32))
		if i==2 and employee_alert>0 and p.get("route",[]).is_empty(): _npc_route(i,Vector2(16*32+16,21*32))
	if guard_clock>=75:
		guard_clock-=75
		if suspicion>=35:
			inn.coins=maxi(0,inn.coins-10); suspicion=maxf(0,suspicion-15); message="경비 조사 이벤트: 수상한 정황으로 벌금 10닢."
		else: message="경비가 영업장을 확인하고 떠났다."

func _update_ui() -> void:
	if object_context!=null: object_context.refresh()

func _save() -> void:
	if pointer_down or dragging>=0 or not walking_route.is_empty() or not player.is_on_floor(): message="땅에 서서 이동·작업·운반을 멈추고 저장하자."; return
	var data=terrain.encode(); data.player=[player.position.x,player.position.y]
	data.coins=inn.coins; data.hired=inn.hired; data.orders=inn.orders; data.suspicion=suspicion; data.hatch=hatch_open
	data.opening=gentle_opening; data.episode=episode.data.duplicate(true)
	data.clock=clock; data.order_clock=order_clock; data.wage_clock=wage_clock; data.guard_clock=guard_clock
	data.people=[]
	for p in people: data.people.append({"x":p.pos.x,"y":p.pos.y,"face":p.face,"down":p.down,"room":p.room,"checkout":p.get("checkout",0.0),"dirty":p.get("dirty",false),"hidden":p.get("hidden",false),"return_at":p.get("return_at",0.0)})
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	if file==null: message="저장 실패"; return
	file.store_string(JSON.stringify(data)); message="지형·인벤토리·여관 상태 저장 완료."
func _load_save() -> void:
	if not FileAccess.file_exists(save_path): message="직접 조작 버전의 저장이 없다."; return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: message="저장을 읽을 수 없다."; return
	var next=Terrain.new()
	if not next.decode(data): message="지형 저장이 올바르지 않다."; return
	var p=data.get("player",[])
	if not p is Array or p.size()!=2: message="위치 저장이 올바르지 않다."; return
	gentle_opening=bool(data.get("opening",false))
	terrain=next; player.position=Vector2(clampf(float(p[0]),34,83*32-32),clampf(float(p[1]),-9*32,52*32)); player.velocity=Vector2.ZERO
	inn.coins=maxi(0,int(data.get("coins",24))); inn.orders=clampi(int(data.get("orders",1)),0,4); inn.hired=bool(data.get("hired",false))
	suspicion=clampf(float(data.get("suspicion",0)),0,100); hatch_open=bool(data.get("hatch",false))
	clock=maxf(0,float(data.get("clock",0))); order_clock=clampf(float(data.get("order_clock",0)),0,11.99)
	wage_clock=clampf(float(data.get("wage_clock",0)),0,89.99); guard_clock=clampf(float(data.get("guard_clock",0)),0,74.99)
	if data.get("people",[]) is Array and data.people.size()==3:
		for i in range(3):
			var v=data.people[i]
			if not v is Dictionary: continue
			people[i].pos=Vector2(clampf(float(v.get("x",800)),32,83*32),clampf(float(v.get("y",672)),0,53*32))
			people[i].hidden=bool(v.get("hidden",false)); people[i].return_at=float(v.get("return_at",0)); people[i].room=int(v.get("room",0)); people[i].checkout=float(v.get("checkout",0)); people[i].dirty=bool(v.get("dirty",false))
			people[i].target=people[i].pos.x; people[i].face=1 if int(v.get("face",1))>=0 else -1; people[i].down=bool(v.get("down",false))
	if data.get("episode",{}) is Dictionary and not data.get("episode",{}).is_empty():
		episode.data=data.episode.duplicate(true); episode_ui.ending_shown=false
	dragging=-1; selected_person=-1; pointer_down=false; employee_alert=0
	_stop_navigation()
	for i in range(people.size()):
		npc_bodies[i].position=people[i].pos-Vector2(0,27)
		people[i].route=[]
		if people[i].get("checkout",0.0)>clock: _npc_route(i,Vector2((24 if people[i].room==1 else 33)*32+16,14*32))
	_changed(); message="여관 상태를 불러왔다."

func _tile(c: Vector2i,kind: String) -> void:
	var dest=Rect2(Vector2(c*32),Vector2(32,32))
	if kind=="platform":
		draw_rect(Rect2(dest.position,Vector2(32,8)),Color("ae7d46"))
		draw_line(dest.position+Vector2(2,3),dest.position+Vector2(29,3),Color("6c4e31"),2); return
	if kind=="wood":
		draw_rect(dest,Color("93683c")); draw_rect(dest,Color("5b402e"),false,2)
		for y in [8,16,24]: draw_line(dest.position+Vector2(2,y),dest.position+Vector2(29,y),Color("b1854b"),2)
		return
	var source=Vector2(16,16)
	if kind=="stone": source=Vector2(48,16)
	if kind=="wood": source=Vector2(112,64)
	if kind=="dirt" and not terrain.cells.has(c+Vector2i.UP): source=Vector2(16,0)
	draw_texture_rect_region(atlas,dest,Rect2(source,Vector2(16,16)))
	if kind=="dirt" and c.y==21: draw_rect(Rect2(dest.position,Vector2(32,4)),Color("7b963d"))

func _draw() -> void:
	if not is_instance_valid(camera): return
	var view=Rect2(camera.position-Vector2(480,860),Vector2(960,1720))
	draw_rect(Rect2(0,-1000,84*32,22*32+1000),Color("455a67"))
	# Mountain silhouettes and forest parallax remain behind the playable grid.
	for i in range(13):
		var x=i*240
		draw_colored_polygon(PackedVector2Array([Vector2(x-100,672),Vector2(x+130,200+(i%3)*80),Vector2(x+380,672)]),Color("354a54"))
	for i in range(32):
		var x=i*91; draw_rect(Rect2(x,400+(i%4)*30,11,272),Color("2c4346"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-45,520),Vector2(x+5,315+(i%4)*30),Vector2(x+60,520)]),Color("304d48"))
	draw_rect(Rect2(0,21*32,84*32,33*32),Color("2b2524"))
	# Four readable storeys: dining hall, guest rooms, staff quarters and attic.
	draw_rect(Rect2(8*32,-6*32,31*32,27*32),Color("786347"))
	for floor_ in [0,7,14,21]:
		draw_rect(Rect2(8*32,floor_*32,31*32,12),Color("493528"))
		for x in [8,17,27,38]: draw_rect(Rect2(x*32,(floor_-7)*32,10,7*32),Color("493b2c"))
	for y in [-4,3,10,17]:
		for x in [10,20,30,36]:
			draw_rect(Rect2(x*32,y*32,38,54),Color("af8d53")); draw_rect(Rect2(x*32+5,y*32+5,28,44),Color("394e54"))
	for x in range(7,40): draw_texture_rect_region(atlas,Rect2(x*32,-7*32,32,32),Rect2(64,0,16,16),Color("827164"))
	for row_ in [0,7,14]:
		for x in [24,33]:
			draw_rect(Rect2(x*32-12,(row_-1)*32,92,26),Color("503c2a")); draw_rect(Rect2(x*32-7,(row_-1)*32-5,82,22),Color("819187")); draw_rect(Rect2(x*32-5,(row_-1)*32-5,22,18),Color("e4d5aa"))
	for x in [20,25,34]:
		draw_rect(Rect2(x*32,19*32,68,14),Color("654832")); draw_rect(Rect2(x*32+7,19*32+14,7,48),Color("493627")); draw_rect(Rect2(x*32+52,19*32+14,7,48),Color("493627"))
		for shift in [-20,80]: draw_rect(Rect2(x*32+shift,20*32,20,26),Color("a48654"))
	draw_rect(Rect2(9*32,18*32,64,3*32),Color("51493d")); draw_circle(Vector2(10*32,19*32),17,Color("c47b43"))
	draw_texture_rect_region(atlas,Rect2(28*32,20*32-15,96,47),Rect2(112,64,16,16))
	draw_string(font,Vector2(28*32,19*32-10),"접수 · 장부",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ead4ac"))
	for y in range(23,26):
		for x in range(14,22): draw_texture_rect_region(atlas,Rect2(x*32,y*32,32,32),Rect2(48,16,16,16),Color("4e4e4d"))
	for c in terrain.cells:
		if view.intersects(Rect2(Vector2(c*32),Vector2(32,32))): _tile(c,terrain.cells[c])
	for y in range(-1*32,26*32,19):
		draw_line(Vector2(15*32-20,y),Vector2(15*32+20,y),Color("b7935f"),5)
	draw_line(Vector2(15*32-20,-1*32),Vector2(15*32-20,26*32),Color("806343"),5)
	draw_line(Vector2(15*32+20,-1*32),Vector2(15*32+20,26*32),Color("806343"),5)
	if not hatch_open: draw_rect(Rect2(14*32,21*32,64,10),Color("a7895c"))
	else: draw_rect(Rect2(16*32,21*32-45,9,45),Color("a7895c"))
	for c in terrain.torches:
		var p=terrain.center(c)
		draw_rect(Rect2(p-Vector2(3,0),Vector2(6,18)),Color("775537"))
		draw_rect(Rect2(p-Vector2(5,7),Vector2(10,12)),Color("ffd374"))
	for i in range(people.size()):
		var p: Dictionary=people[i]
		if p.get("hidden",false): continue
		if p.down:
			draw_rect(Rect2(p.pos-Vector2(25,13),Vector2(43,13)),Color("927c68"))
		draw_string(font,p.pos-Vector2(40,62),p.name+(" · %d호" %p.room if p.get("checkout",0.0)>clock else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ead4af"))
		if selected_person==i: draw_arc(p.pos-Vector2(0,24),32,0,TAU,24,Color("eccb85"),2)
	if terrain.valid(target):
		var outline=Color("e1c275") if terrain.within_reach(target,player.position) else Color("a45354")
		draw_rect(Rect2(Vector2(target*32),Vector2(32,32)),outline,false,2)
		if terrain.mining_progress>0:
			draw_rect(Rect2(Vector2(target*32),Vector2(32*minf(1,terrain.mining_progress/0.48),4)),Color("ffe4a5"))
	if noise_age<1:
		draw_arc(noise_pos,20+noise_age*90,0,TAU,36,Color(1,0.8,0.4,1-noise_age),2)
	if not walking_route.is_empty():
		var last=player.position+Vector2(0,27)
		for step in walking_route:
			var next: Vector2=step.point+Vector2(0,27)
			draw_line(last,next,Color(0.67,0.82,0.68,0.55),2); draw_circle(next,3,Color("cee1b2")); last=next
	if marker_time>0 or not walking_route.is_empty():
		var color=Color("d6e8aa") if destination_valid else Color("dd7770")
		draw_arc(destination-Vector2(0,4),13,0,TAU,24,color,2)
		draw_line(destination-Vector2(0,12),destination-Vector2(0,35),color,2)

func _verify_inputs() -> void:
	# Native physics frames are used for motion and collision, not hand-set positions.
	await get_tree().physics_frame
	var failures=0
	for i in range(15): await get_tree().physics_frame
	var start=player.position
	player.axis=1
	for i in range(18): await get_tree().physics_frame
	if player.position.x<start.x+25: failures+=1; push_error("Direct walk failed")
	player.axis=0; player.jump_held=true; player.jump_requested=true
	var base=player.position.y
	for i in range(10): await get_tree().physics_frame
	if player.position.y>base-30: failures+=1; push_error("Jump failed")
	player.jump_held=false
	for i in range(70): await get_tree().physics_frame
	if not player.is_on_floor(): failures+=1; push_error("Gravity landing failed")
	var tile=terrain.cell_at(player.position+Vector2(38,44))
	var before=terrain.inventory.dirt+terrain.inventory.wood+terrain.inventory.stone+terrain.inventory.platform
	for i in range(30): terrain.mine(tile,player.position,0.05)
	if terrain.cells.has(tile): failures+=1; push_error("Nearby mining failed")
	var after=terrain.inventory.dirt+terrain.inventory.wood+terrain.inventory.stone+terrain.inventory.platform
	if after<=before: failures+=1; push_error("Mined build_material not collected")
	if not _save_test_roundtrip(): failures+=1; push_error("Terrain save roundtrip failed")
	failures+=await _verify_navigation()
	print("PHYSICS + TAP NAVIGATION CHECKS: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

func _save_test_roundtrip() -> bool:
	var snapshot=terrain.encode(); var copy=Terrain.new()
	return copy.decode(JSON.parse_string(JSON.stringify(snapshot))) and copy.cells==terrain.cells and copy.inventory==terrain.inventory

func _test_touch(index: int,p: Vector2,pressed: bool) -> void:
	var event=InputEventScreenTouch.new(); event.index=index; event.position=p; event.pressed=pressed
	get_viewport().push_input(event,true); await get_tree().process_frame

func _verify_navigation() -> int:
	var failures=0
	terrain=Terrain.new(); hatch_open=false; _rebuild_geometry()
	player.position=Vector2(27*32,21*32-28); player.velocity=Vector2.ZERO
	player.axis=0; navigation_testing=true
	for i in range(15): await get_tree().physics_frame
	# One mouse tap travels through the real viewport event pipeline.
	mode="move"
	var ground=Vector2(23*32+16,21*32)
	await _test_click(get_canvas_transform()*ground)
	if walking_route.is_empty(): failures+=1; push_error("Tap did not create route")
	await _wait_navigation(360)
	if player.position.distance_to(ground-Vector2(0,27))>15: failures+=1; push_error("Ground click did not arrive: "+str(player.position))
	var upstairs=Vector2(24*32+16,14*32)
	if not _navigate_to(upstairs): failures+=1; push_error("No upstairs route")
	await _wait_navigation(840)
	if player.position.distance_to(upstairs-Vector2(0,27))>18: failures+=1; push_error("Automatic upstairs traversal failed: "+str(player.position)+" "+message)
	var cellar=Vector2(19*32+16,26*32)
	if _navigate_to(cellar): failures+=1; push_error("Closed hatch route should fail")
	hatch_open=true; _rebuild_geometry()
	if not _navigate_to(cellar): failures+=1; push_error("Open hatch has no cellar route")
	await _wait_navigation(1000)
	if player.position.distance_to(cellar-Vector2(0,27))>18: failures+=1; push_error("Automatic cellar traversal failed: "+str(player.position)+" "+message)
	# A buried wall tap approaches, selects the pickaxe and completes one tile.
	var wall=Vector2i(22,24)
	await _test_click(get_canvas_transform()*terrain.center(wall))
	await _wait_navigation(480)
	for i in range(22):
		if automatic_mining: _work_target(0.05)
	if terrain.cells.has(wall): failures+=1; push_error("Context wall tap did not mine")
	if automatic_mining: failures+=1; push_error("Context mining did not stop after one tile")
	# Counter is a local menu; hiring is an explicit person action, never an implicit click.
	object_context.close()
	await _test_click(get_canvas_transform()*Vector2(29*32,19*32))
	if not object_context.panel.visible: failures+=1; push_error("Counter context did not open")
	object_context.open("counter"); await _click_context("staff"); await _click_context("hire")
	await _wait_navigation(1000)
	if not inn.hired: failures+=1; push_error("Local staff action did not approach and hire")
	object_context.close()
	# Native one-finger touch is tested separately from mouse events.
	var touch_goal=Vector2(26*32+16,21*32)
	await _test_touch(3,get_canvas_transform()*touch_goal,true)
	await _test_touch(3,get_canvas_transform()*touch_goal,false)
	await _wait_navigation(360)
	if player.position.distance_to(touch_goal-Vector2(0,27))>18: failures+=1; push_error("Native touch destination did not arrive")
	_navigate_to(Vector2(22*32+16,21*32))
	object_context.open("owner"); await _click_context("stop")
	if not walking_route.is_empty() or player.axis!=0: failures+=1; push_error("Cancel did not stop route")
	_stop_navigation()
	failures+=await _verify_context_reception()
	navigation_testing=false
	return failures

func _wait_navigation(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame
		if walking_route.is_empty(): break

func _test_click(p: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=p; event.pressed=pressed
		get_viewport().push_input(event,true); await get_tree().process_frame

func episode_font() -> Font:
	return font

func episode_facts() -> Dictionary:
	var bodies=0
	for p in people:
		if p.down: bodies+=1
	return {"opening":gentle_opening,"booked":people.filter(func(p): return p.get("checkout",0.0)>clock).size(),"money":inn.coins,"served":inn.served,"near_counter":player.position.distance_to(Vector2(29*32,21*32-19))<130,"risk":int(suspicion),"bodies":bodies,"hatch":hatch_open,"dug":int(terrain.inventory.dirt)+int(terrain.inventory.stone)}

func start_challenge() -> void:
	gentle_opening=false; episode.data.elapsed=0; episode.data.briefed=true

func episode_coins(amount: int) -> void:
	inn.coins+=amount

func episode_pause(value: bool) -> void:
	paused=value; player.active=not value; pointer_down=false

func capture_episode(cellar: bool) -> void:
	test_mode=true; episode.data.briefed=true; episode.data.elapsed=68; inn.hired=true
	if cellar:
		hatch_open=true; _rebuild_geometry(); player.position=Vector2(20*32,26*32-28)
	else: player.position=Vector2(24*32,21*32-28)
	camera.zoom=Vector2.ONE; camera.position=Vector2(23*32,player.position.y if cellar else 300)
	paused=true; player.active=false; _update_ui(); episode_ui.refresh(); queue_redraw()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("res://../../docs/episode-2d-"+("cellar" if cellar else "inn")+".png")
	get_tree().quit()

func episode_notice() -> String:
	return message

func verify_episode_playthrough(capture: bool=false) -> int:
	episode_ui.perform("start")
	for i in range(15): await get_tree().physics_frame
	_interact()
	assert(inn.hired)
	_assign_guest_room(1)
	assert(people[0].room==1 and people[0].checkout>clock)
	for step in range(400):
		clock+=0.5; order_clock+=0.5; wage_clock+=0.5; guard_clock+=0.5
		_business_tick(0.5); episode.tick(0.5,episode_facts())
		if step==90: episode_ui.perform("report")
		if step==260: episode_ui.perform("honest")
	assert(inn.served>=3)
	var money: int=inn.coins
	episode_ui.perform("settle")
	assert(episode.data.ending=="여관을 지킨 밤" and inn.coins==money-36)
	assert(episode_ui.panel.visible and episode_ui.heading.text==episode.data.ending)
	_save(); episode.data.ending=""; _load_save()
	assert(episode.data.ending=="여관을 지킨 밤")
	if capture:
		camera.zoom=Vector2.ONE; camera.position=Vector2(23*32,300)
		_update_ui(); episode_ui.refresh(); queue_redraw()
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("res://../../docs/episode-2d-ending.png")
	episode_ui.perform("freeplay")
	assert(not episode_ui.panel.visible and not paused and episode.data.freeplay)
	print("2D EPISODE PLAYTHROUGH: real booking, staff service, events, rent, ending, save/load, freeplay passed")
	return 0

func context_stats() -> String:
	return "%d닢 · 주문 %d · 직원 %s%s" %[inn.coins,inn.orders,"고용" if inn.hired else "없음"," · 멈춤" if paused else ""]

func context_title(kind_: String,id_: String) -> String:
	return str(people[int(id_)].name) if kind_=="person" else {"counter":"접수대 · 여관 장부","hatch":"지하 덮개","ground":"이 위치에서","owner":"여관 주인","system":"여관 설정"}.get(kind_,"여관")

func context_anchor(kind_: String,id_: String) -> Vector2:
	var p=Vector2(29*32,20*32)
	if kind_ in ["person","actions"]: p=people[int(id_)].pos-Vector2(0,36)
	elif kind_=="hatch": p=Vector2(15*32,21*32)
	elif kind_=="ground": p=terrain.center(context_cell)
	elif kind_=="owner": p=player.position
	return get_canvas_transform()*p

func context_items(kind_: String,id_: String) -> Array:
	if paused: return [["resume","영업 계속"],["journal","오늘의 장부"],["system","저장 · 화면 설정"]]
	match kind_:
		"person":
			var index=int(id_); var p: Dictionary=people[index]
			if dragging>=0: return [["drop","내려놓기"]]
			if p.down: return [["carry","끌고 가기"],["talk","상태 확인"]]
			if index==2:
				return [["talk","말 걸기"]] if gentle_opening and inn.served<1 else [["talk","말 걸기"],["hire","서빙 맡기기" if inn.hired else "고용 · 8닢"]]
			var items= [["serve","식사 내어주기"],["talk","말 걸기"],["actions","다른 행동"]] if p.get("checkout",0.0)>clock else [["room1","접수 · 1호 배정"],["room2","접수 · 2호 배정"],["talk","말 걸기"],["actions","다른 행동"]]
			if gentle_opening and inn.served<3: items=items.filter(func(item): return item[0]!="actions")
			return items
		"actions": return [["serve","식사 내어주기"],["expel","내보내기"],["subdue","제압 시도"]]
		"counter":
			if gentle_opening and inn.served<1: return [["journal","운영 안내"],["system","저장 · 화면 설정"],["stop","현재 행동 취소"]]
			return [["journal","오늘의 장부 · 사건/결산"],["staff","직원에게 말 걸기"],["system","저장 · 화면 설정"],["stop","현재 행동 취소"]]
		"hatch": return [["hatch","덮개 닫기" if hatch_open else "덮개 열기"],["enter","지하 창고로 이동" if player.position.y<22*32 else "여관으로 올라가기"]]
		"ground": return [["move","여기로 이동"],["mine","이곳 굴착"],["wood","목재 벽 설치"],["platform","발판 설치"],["torch","횃불 설치"],["drop","내려놓기"],["stop","현재 행동 취소"]]
		"owner": return [["stop","현재 행동 취소"],["journal","운영 안내 · 장부"],["drop","내려놓기"],["system","저장 · 화면 설정"]]
		"system": return [["pause","일시 정지"],["overview","전체 / 가까이 보기"],["save","저장"],["load","불러오기"],["fullscreen","전체화면 전환"]]
	return []

func context_action(kind_: String,id_: String,action: String) -> void:
	match action:
		"journal": episode_ui.open(); return
		"resume": episode_pause(false); return
		"pause": episode_pause(true); return
		"system": object_context.open("system"); return
		"actions": object_context.open("actions",id_); return
		"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED); return
		"overview": _overview_camera(); return
		"save": _save(); return
		"load": _load_save(); return
		"stop": _stop_navigation(); return
		"staff": selected_person=2; object_context.open("person","2"); return
		"drop": dragging=-1; return
	if kind_ in ["person","actions"]:
		var index=int(id_); selected_person=index
		var focus: Vector2=people[index].pos-Vector2(0,19)
		if player.position.distance_to(focus)<=85: _perform_person_action(index,action)
		elif _approach(focus,60): pending_person_action={"id":index,"action":action}
	elif kind_=="hatch":
		if action=="hatch": _go_hatch()
		elif action=="enter":
			if not hatch_open: message="먼저 덮개를 열자."; object_context.open("hatch"); return
			_navigate_to(Vector2(18*32+16,26*32) if player.position.y<22*32 else Vector2(16*32+16,21*32))
	elif kind_=="ground":
		if action=="move": _select_mode("move"); _navigate_to(terrain.center(context_cell))
		elif action=="mine":
			if player.position.distance_to(terrain.center(context_cell))<=128: _begin_automatic_mining(context_cell)
			elif _approach(terrain.center(context_cell),118): navigation_job={"action":"mine","cell":context_cell}
		else:
			mode="block" if action=="wood" else action; build_material="wood"; target=context_cell; _work_target(0.1); mode="move"

func _perform_person_action(index: int,action: String) -> void:
	selected_person=index
	var p: Dictionary=people[index]
	if p.get("hidden",false) or player.position.distance_to(p.pos-Vector2(0,19))>95:
		message="손님이 자리를 옮겼다. 다시 선택하자."; return
	match action:
		"talk":
			var line=["길이 막혔소. 조용한 방 하나와 따뜻한 식사가 필요하오.","누가 묻더라도 내가 여기 왔다는 말은 하지 마시오.","서빙을 맡기면 주인님은 다른 일을 보셔도 됩니다."][index]
			object_context.open("person",str(index),line)
		"room1","room2": _assign_guest_room(1 if action=="room1" else 2)
		"serve":
			if inn.orders<=0: object_context.open("person",str(index),"지금은 주문할 게 없소.")
			else: inn.orders-=1; inn.coins+=4; inn.served+=1; message=p.name+"에게 식사를 내었다. +4닢"
		"hire":
			if inn.hired: message="직원이 서빙을 맡고 있다."
			elif inn.coins>=8: inn.coins-=8; inn.hired=true; message="직원을 고용했다."
			else: object_context.open("person",str(index),"고용비 8닢이 필요합니다.")
		"expel":
			p.hidden=true; p.return_at=clock+24; p.checkout=0; p.room=0; message=p.name+"을 내보냈다."
		"subdue","carry": _interact()

func _npc_route(index: int,foot: Vector2) -> void:
	_ensure_navigation()
	var p: Dictionary=people[index]
	p.route=navigation.route(npc_bodies[index].position,foot); p.nav_started=false; p.nav_time=0.0; p.nav_jump=0.0; p.goal=foot

func _drive_npcs(delta: float) -> void:
	if npc_bodies.is_empty(): return
	for i in range(people.size()):
		var p: Dictionary=people[i]; var b=npc_bodies[i]
		b.visible=not p.down and not p.get("hidden",false)
		b.active=not paused and not p.down and not p.get("hidden",false)
		if p.down: b.position=p.pos-Vector2(0,27); continue
		if paused or p.get("hidden",false): continue
		p.pos=b.position+Vector2(0,27); p.face=b.facing
		b.axis=0; b.climb_axis=0; b.jump_held=false; b.climbing=false
		if object_context.panel.visible and object_context.kind=="person" and object_context.target==str(i): b.active=false; continue
		if not pending_person_action.is_empty() and int(pending_person_action.id)==i: b.active=false; continue
		if p.get("route",[]).is_empty(): continue
		var step: Dictionary=p.route[0]; var diff: Vector2=step.point-b.position
		b.climbing=absf(b.position.x-15*32)<30 and b.position.y>-32 and b.position.y<26*32
		if p.nav_started and b.is_on_floor() and ((step.kind=="jump" and diff.y>18) or (step.kind=="drop" and diff.y < -18 and p.nav_time>0.3)):
			_npc_route(i,p.goal); continue
		if absf(diff.x)<9 and absf(diff.y)<10 and (step.kind!="jump" or b.is_on_floor()):
			p.route.pop_front(); p.nav_started=false; p.nav_time=0.0
			if p.route.is_empty(): continue
			step=p.route[0]; diff=step.point-b.position
		p.nav_time+=delta
		if p.nav_time>5:
			_npc_route(i,p.goal); continue
		b.axis=clampf(diff.x/24.0,-1,1) if absf(diff.x)>5 else 0.0
		if b.climbing and step.kind!="jump":
			b.climb_axis=clampf(diff.y/12.0,-1,1)
			if step.kind=="walk" and absf(diff.x)>5: b.climb_axis=clampf((step.point.y-2-b.position.y)/8.0,-0.35,0.35)
		if not p.nav_started:
			if step.kind=="jump" and (b.is_on_floor() or b.climbing):
				if b.climbing: b.coyote=0.1
				b.jump_requested=true; p.nav_jump=0.5; p.nav_started=true
			elif step.kind=="drop": b.drop_down(); p.nav_started=true
			elif step.kind!="jump": p.nav_started=true
		p.nav_jump=maxf(0,p.nav_jump-delta); b.jump_held=p.nav_jump>0
		if b.jump_held: b.climbing=false

func _click_context(key: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_click(object_context.controls[key].get_global_rect().get_center())

func _verify_context_reception() -> int:
	var failed=0
	object_context.close(); camera_pan=Vector2.ZERO
	player.position=Vector2(26*32+16,21*32-27); player.velocity=Vector2.ZERO
	for i in range(people.size()):
		people[i].checkout=0; people[i].dirty=false; people[i].down=false; people[i].hidden=false; people[i].route=[]
		people[i].pos=Vector2((25+i*5)*32,21*32); npc_bodies[i].position=people[i].pos-Vector2(0,27)
	camera.position=Vector2(27*32,300)
	for i in range(12): await get_tree().physics_frame
	var money=inn.coins
	await _test_click(get_canvas_transform()*(people[1].pos-Vector2(0,25)))
	if not object_context.panel.visible or object_context.target!="1": failed+=1; push_error("Wrong guest context")
	await _click_context("room2")
	if inn.coins!=money: failed+=1; push_error("Remote reception charged before approach")
	await _wait_navigation(500)
	if people[1].room!=2 or people[1].checkout<=clock or inn.coins!=money+8: failed+=1; push_error("Direct reception selected wrong guest")
	var goal=Vector2(33*32+16,14*32)
	for i in range(1100):
		await get_tree().physics_frame
		if people[1].pos.distance_to(goal)<20: break
	if people[1].pos.distance_to(goal)>20: failed+=1; push_error("Guest did not physically enter room: "+str(people[1].pos))
	object_context.open("person","1")
	await get_tree().process_frame
	if object_context.panel.get_global_rect().end.x>get_viewport().get_visible_rect().size.x: failed+=1; push_error("Context overflowed viewport")
	object_context.close()
	print("2D LOCAL RECEPTION CHECKS: ",failed," failures")
	return failed

func capture_context(show_menu: bool) -> void:
	test_mode=true; paused=false; gentle_opening=true; player.active=false; episode.data.briefed=true; set_physics_process(false)
	camera.position=Vector2(26*32,300); camera.zoom=Vector2.ONE
	for body in npc_bodies: body.active=false
	if show_menu: object_context.open("person","0")
	queue_redraw(); episode_ui.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	object_context.refresh()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../../docs/context-2d-"+("guest" if show_menu else "inn")+".png")
	get_tree().quit()
