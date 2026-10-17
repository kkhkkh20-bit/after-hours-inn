extends Node2D
const Terrain = preload("res://terrain.gd")
const Player = preload("res://player.gd")
const Business = preload("res://simulation.gd")
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
var mode = "mine"
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
var save_path = "user://sandbox-v1.json"
var message = "직접 걷고 점프해서 가까운 땅을 파보세요."
var rebuild_pending = false
var test_mode = false

func _ready() -> void:
	_setup_input()
	var canvas = CanvasModulate.new(); canvas.color=Color("8d91a2"); add_child(canvas)
	player=Player.new(); player.position=Vector2(27*32,21*32-28); add_child(player)
	camera=Camera2D.new(); camera.position=player.position+Vector2(-32,65)
	camera.limit_left=0; camera.limit_top=-96; camera.limit_right=84*32; camera.limit_bottom=54*32
	camera.zoom=Vector2(0.82,0.82)
	camera.position_smoothing_enabled=false; add_child(camera)
	people=[
		{"name":"상인","pos":Vector2(25*32,21*32),"face":1,"down":false,"room":0,"target":25*32,"idle":0.0},
		{"name":"수상한 손님","pos":Vector2(31*32,21*32),"face":-1,"down":false,"room":1,"target":31*32,"idle":0.0},
		{"name":"직원","pos":Vector2(29*32,21*32),"face":-1,"down":false,"room":0,"target":29*32,"idle":0.0}
	]
	noise_player=AudioStreamPlayer.new(); noise_player.stream=preload("res://assets/tap.wav"); noise_player.volume_db=-17; add_child(noise_player)
	_rebuild_geometry(); _rebuild_lights(); _setup_ui()
	var args=OS.get_cmdline_user_args()
	if "--verify" in args:
		test_mode=true
		var failures: int=load("res://tests.gd").new().run()
		failures+=load("res://sandbox_tests.gd").new().run()
		get_tree().quit(0 if failures==0 else 1); return
	if "--input-verify" in args:
		test_mode=true; await _verify_inputs(); return
	if "--capture" in args or "--capture-dark" in args:
		test_mode=true; inn.hired=true
		if "--capture-dark" in args:
			hatch_open=true; _rebuild_geometry()
			player.position=Vector2(19*32,29*32-28)
			camera.position=player.position+Vector2(-32,65)
			mode="mine"; target=Vector2i(23,28); terrain.mining_cell=target; terrain.mining_progress=0.28
			message="지하에서도 직접 이동·채굴·발판과 횃불 설치"
		else: message="공개 타일을 지형에 적용한 실제 플레이 화면"
		paused=true; player.active=false; _update_ui(); queue_redraw()
		await get_tree().create_timer(0.6).timeout
		var suffix="cellar" if "--capture-dark" in args else "surface"
		get_viewport().get_texture().get_image().save_png("res://../../docs/direct-"+suffix+".png")
		get_tree().quit()

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
	for y in range(Terrain.HEIGHT):
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
	_panel(Rect2(0,0,720,153)); _panel(Rect2(0,1000,720,360))
	_label("title","문 닫은 뒤 · 직접 조작",Rect2(22,15,570,40),28)
	_button("멈춤",Rect2(593,16,105,52),_pause)
	_label("stats","",Rect2(22,63,675,34),25)
	_label("hint","A/D 이동 · Space 점프 · W/S 사다리 · E 사용",Rect2(22,108,676,34),20)
	_label("context","",Rect2(20,1009,680,36),23)
	var mode_list=[["mine","곡괭이"],["block","블록"],["platform","발판"],["torch","횃불"],["hand","손님"]]
	for i in range(mode_list.size()):
		var entry=mode_list[i]
		modes[entry[0]]=_button(entry[1],Rect2(20+i*139,1057,124,70),_select_mode.bind(entry[0]))
	_button("재료 변경",Rect2(20,1142,200,58),_material_next)
	_button("사용 / E",Rect2(240,1142,220,58),_interact)
	_button("저장",Rect2(480,1142,100,58),_save)
	_button("읽기",Rect2(598,1142,100,58),_load_save)
	_touch_button("왼쪽",Rect2(20,1217,105,89),"walk_left")
	_touch_button("오른쪽",Rect2(140,1217,105,89),"walk_right")
	_touch_button("아래",Rect2(260,1217,105,89),"climb_down")
	_touch_button("위",Rect2(380,1217,105,89),"climb_up")
	_touch_button("점프",Rect2(510,1217,188,89),"leap")
	_label("log",message,Rect2(20,1315,678,38),21)
	_update_ui()

func _pause() -> void:
	paused=not paused; player.active=not paused
	pointer_down=false
	for action in ["walk_left","walk_right","leap","climb_up","climb_down"]: Input.action_release(action)
	_update_ui()
func _select_mode(value: String) -> void:
	mode=value; pointer_down=false; terrain.mining_progress=0
	if value!="hand": selected_person=-1
	_update_ui()
func _material_next() -> void:
	var options=["wood","dirt","stone"]; build_material=options[(options.find(build_material)+1)%3]; _update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and event.position.y>153 and event.position.y<1000:
		active_touch=event.index; pointer_down=true
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
		if mode=="hand": _select_person()
	if event is InputEventScreenDrag and event.index==active_touch:
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if active_touch>=0: return
		pointer_down=event.pressed
		if event.pressed:
			cursor_world=get_canvas_transform().affine_inverse()*event.position
			target=terrain.cell_at(cursor_world)
			if mode=="hand": _select_person()
	if event is InputEventMouseMotion and pointer_down:
		cursor_world=get_canvas_transform().affine_inverse()*event.position; target=terrain.cell_at(cursor_world)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E: _interact()
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_5:
			_select_mode(["mine","block","platform","torch","hand"][event.physical_keycode-KEY_1])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and active_touch<0:
		pointer_down=false; terrain.mining_progress=0
	if event is InputEventScreenTouch and not event.pressed and event.index==active_touch:
		pointer_down=false; terrain.mining_progress=0; active_touch=-1

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer_down=false; active_touch=-1
		for action in ["walk_left","walk_right","leap","climb_up","climb_down"]:
			if InputMap.has_action(action): Input.action_release(action)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or test_mode or paused: return
	player.axis=Input.get_axis("walk_left","walk_right")
	player.jump_held=Input.is_action_pressed("leap")
	if Input.is_action_just_pressed("leap"): player.jump_requested=true
	player.climb_axis=Input.get_axis("climb_up","climb_down")
	player.climbing=absf(player.position.x-15*32)<30 and player.position.y>13*32 and player.position.y<30*32
	player.crouch=Input.is_action_pressed("climb_down") and not player.climbing
	if Input.is_action_just_pressed("climb_down") and not player.climbing: player.drop_down()
	player.carrying=dragging>=0

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not paused and not test_mode:
		clock+=delta; order_clock+=delta; wage_clock+=delta; guard_clock+=delta; noise_age+=delta
		employee_alert=maxf(0,employee_alert-delta)
		if pointer_down: _work_target(delta)
		if absf(player.velocity.x)>50 and player.is_on_floor():
			noise_clock+=delta
			if noise_clock>0.45:
				_noise(0.30 if dragging>=0 else (0.06 if player.crouch else 0.12)); noise_clock=0
		_business_tick(delta)
		if dragging>=0:
			people[dragging].pos=player.position+Vector2(-22*player.facing,18)
			if _witnessed(player.position): suspicion=minf(100,suspicion+delta*8)
		if player.position.y>52*32:
			player.position=Vector2(27*32,21*32-28); player.velocity=Vector2.ZERO; message="지하 경계에서 여관으로 복귀했다."
		camera.position=player.position+Vector2(-32,65)
	_update_ui(); queue_redraw()

func _work_target(delta: float) -> void:
	if mode=="mine":
		var old=terrain.mining_progress
		if terrain.mine(target,player.position,delta):
			message="채굴 완료. 자원이 가방에 들어왔다."; _changed(); _noise(0.9)
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
	if order_clock>=8:
		order_clock-=8
		if inn.hired and employee_alert<=0 and inn.orders>0:
			inn.orders-=1; inn.coins+=4; inn.served+=1
		inn.orders=mini(4,inn.orders+1)
	if inn.hired and wage_clock>=90:
		wage_clock-=90
		if inn.coins>=6: inn.coins-=6
		else: inn.hired=false; message="급여가 부족해 직원이 떠났다."
	for i in range(people.size()):
		var p: Dictionary=people[i]
		if p.down or (i==2 and not inn.hired): continue
		p.idle+=delta
		if i<2 and p.idle>6+i*3:
			p.idle=0; p.target=(24+i*6)*32 if absf(p.pos.x-(28-i*2)*32)<5 else (28-i*2)*32
		if i==2 and employee_alert<=0: p.target=29*32
		var dx: float=p.target-p.pos.x
		if absf(dx)>1:
			p.face=signf(dx)
			var next: Vector2=p.pos+Vector2(signf(dx)*delta*45,0)
			# Guests do not walk across holes made by the owner.
			var floor_cell=terrain.cell_at(next+Vector2(0,2))
			if terrain.cells.has(floor_cell) or (not hatch_open and floor_cell.x in [14,15]): p.pos=next
	if guard_clock>=75:
		guard_clock-=75
		if suspicion>=35:
			inn.coins=maxi(0,inn.coins-10); suspicion=maxf(0,suspicion-15); message="경비 조사 이벤트: 수상한 정황으로 벌금 10닢."
		else: message="경비가 영업장을 확인하고 떠났다."

func _update_ui() -> void:
	if labels.is_empty(): return
	labels.stats.text="%d닢 · 주문 %d · 의심 %d%% · 직원 %s" %[inn.coins,inn.orders,suspicion,"고용" if inn.hired else "없음"]
	var names={"wood":"목재","dirt":"흙","stone":"돌","platform":"발판","torch":"횃불"}
	labels.context.text="%s %d · 흙 %d · 돌 %d · 발판 %d · 횃불 %d" %[names[build_material],terrain.inventory[build_material],terrain.inventory.dirt,terrain.inventory.stone,terrain.inventory.platform,terrain.inventory.torch]
	labels.log.text=message
	for key in modes: modes[key].modulate=Color("e1bd7e") if mode==key else Color.WHITE

func _save() -> void:
	if pointer_down or dragging>=0 or not player.is_on_floor(): message="땅에 서서 작업·운반을 멈추고 저장하자."; return
	var data=terrain.encode(); data.player=[player.position.x,player.position.y]
	data.coins=inn.coins; data.hired=inn.hired; data.orders=inn.orders; data.suspicion=suspicion; data.hatch=hatch_open
	data.clock=clock; data.order_clock=order_clock; data.wage_clock=wage_clock; data.guard_clock=guard_clock
	data.people=[]
	for p in people: data.people.append({"x":p.pos.x,"y":p.pos.y,"face":p.face,"down":p.down})
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
	terrain=next; player.position=Vector2(clampf(float(p[0]),34,83*32-32),clampf(float(p[1]),-32,52*32)); player.velocity=Vector2.ZERO
	inn.coins=maxi(0,int(data.get("coins",24))); inn.orders=clampi(int(data.get("orders",1)),0,4); inn.hired=bool(data.get("hired",false))
	suspicion=clampf(float(data.get("suspicion",0)),0,100); hatch_open=bool(data.get("hatch",false))
	clock=maxf(0,float(data.get("clock",0))); order_clock=clampf(float(data.get("order_clock",0)),0,7.99)
	wage_clock=clampf(float(data.get("wage_clock",0)),0,89.99); guard_clock=clampf(float(data.get("guard_clock",0)),0,74.99)
	if data.get("people",[]) is Array and data.people.size()==3:
		for i in range(3):
			var v=data.people[i]
			if not v is Dictionary: continue
			people[i].pos=Vector2(clampf(float(v.get("x",800)),32,83*32),clampf(float(v.get("y",672)),0,53*32))
			people[i].target=people[i].pos.x; people[i].face=1 if int(v.get("face",1))>=0 else -1; people[i].down=bool(v.get("down",false))
	dragging=-1; selected_person=-1; pointer_down=false; employee_alert=0
	_changed(); message="직접 조작 실험을 불러왔다."

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
	draw_rect(Rect2(0,-200,84*32,22*32+200),Color("455a67"))
	# Mountain silhouettes and forest parallax remain behind the playable grid.
	for i in range(13):
		var x=i*240
		draw_colored_polygon(PackedVector2Array([Vector2(x-100,672),Vector2(x+130,200+(i%3)*80),Vector2(x+380,672)]),Color("354a54"))
	for i in range(32):
		var x=i*91; draw_rect(Rect2(x,400+(i%4)*30,11,272),Color("2c4346"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-45,520),Vector2(x+5,315+(i%4)*30),Vector2(x+60,520)]),Color("304d48"))
	draw_rect(Rect2(0,21*32,84*32,33*32),Color("2b2524"))
	# Plastered back walls, wood frames, furniture and tiled roof of the inn.
	draw_rect(Rect2(12*32,9*32,22*32,12*32),Color("826b50"))
	for x in range(12,34,4):
		for y in range(10,21): draw_texture_rect_region(atlas,Rect2(x*32,y*32,12,32),Rect2(112,64,6,16),Color("bba581"))
	for y in [14,21]: draw_rect(Rect2(12*32,y*32,22*32,12),Color("61432f"))
	for x in [19,25,31]:
		for y in [11,18]:
			draw_rect(Rect2(x*32,y*32,41,54),Color("b49762")); draw_rect(Rect2(x*32+5,y*32+5,31,44),Color("435b66"))
			draw_line(Vector2(x*32+20,y*32),Vector2(x*32+20,y*32+54),Color("b49762"),4)
	for x in range(11,35):
		draw_texture_rect_region(atlas,Rect2(x*32,8*32,32,32),Rect2(64,0,16,16),Color("997e73"))
	for x in [24,30]:
		draw_texture_rect_region(atlas,Rect2(x*32,13*32+10,64,22),Rect2(112,64,16,8))
		draw_rect(Rect2(x*32+5,13*32,54,22),Color("82938e")); draw_rect(Rect2(x*32+7,13*32,17,15),Color("e2cf9b"))
	draw_texture_rect_region(atlas,Rect2(28*32,20*32-15,96,47),Rect2(112,64,16,16))
	draw_string(font,Vector2(28*32-5,19*32-10),"카운터 · 사용 / E",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1d49d"))
	# Cellar background wall texture differentiates excavated air from solid earth.
	for x in range(14,24):
		for y in range(24,30):
			draw_texture_rect_region(atlas,Rect2(x*32,y*32,32,32),Rect2(48,16,16,16),Color("4e4e4d"))
	for c in terrain.cells:
		if view.intersects(Rect2(Vector2(c*32),Vector2(32,32))): _tile(c,terrain.cells[c])
	for y in range(13*32,30*32,19):
		draw_line(Vector2(15*32-20,y),Vector2(15*32+20,y),Color("b7935f"),5)
	draw_line(Vector2(15*32-20,13*32),Vector2(15*32-20,30*32),Color("806343"),5)
	draw_line(Vector2(15*32+20,13*32),Vector2(15*32+20,30*32),Color("806343"),5)
	if not hatch_open: draw_rect(Rect2(14*32,21*32,64,10),Color("a7895c"))
	else: draw_rect(Rect2(16*32,21*32-45,9,45),Color("a7895c"))
	for c in terrain.torches:
		var p=terrain.center(c)
		draw_rect(Rect2(p-Vector2(3,0),Vector2(6,18)),Color("775537"))
		draw_rect(Rect2(p-Vector2(5,7),Vector2(10,12)),Color("ffd374"))
	for i in range(people.size()):
		if i==2 and not inn.hired: continue
		var p: Dictionary=people[i]
		if p.down:
			draw_rect(Rect2(p.pos-Vector2(25,13),Vector2(43,13)),Color("927c68"))
		else:
			var dest=Rect2(p.pos-Vector2(48,84),Vector2(96,96))
			if p.face<0: dest.position.x+=96; dest.size.x=-96
			draw_texture_rect_region(preload("res://assets/knight.png"),dest,Rect2((int(clock*4)%4)*32,0,32,32),[Color("b7bd93"),Color("b48790"),Color("8ab8bf")][i])
		draw_string(font,p.pos-Vector2(40,62),p.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ead4af"))
		if selected_person==i: draw_arc(p.pos-Vector2(0,24),32,0,TAU,24,Color("eccb85"),2)
	if terrain.valid(target):
		var outline=Color("e1c275") if terrain.within_reach(target,player.position) else Color("a45354")
		draw_rect(Rect2(Vector2(target*32),Vector2(32,32)),outline,false,2)
		if terrain.mining_progress>0:
			draw_rect(Rect2(Vector2(target*32),Vector2(32*minf(1,terrain.mining_progress/0.48),4)),Color("ffe4a5"))
	if noise_age<1:
		draw_arc(noise_pos,20+noise_age*90,0,TAU,36,Color(1,0.8,0.4,1-noise_age),2)

func _verify_inputs() -> void:
	# Native physics frames are used for motion and collision, not hand-set positions.
	await get_tree().physics_frame
	var failures=0
	await _test_touch(0,Vector2(192,1255),true)
	await _test_touch(1,Vector2(600,1255),true)
	if not Input.is_action_pressed("walk_right") or not Input.is_action_pressed("leap"):
		failures+=1; push_error("Two-finger move/jump input failed")
	await _test_touch(1,Vector2(600,1255),false)
	if not Input.is_action_pressed("walk_right") or Input.is_action_pressed("leap"):
		failures+=1; push_error("Releasing jump cancelled movement")
	await _test_touch(0,Vector2(192,1255),false)
	if Input.is_action_pressed("walk_right"):
		failures+=1; push_error("Touch movement stuck after release")
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
	print("DIRECT PHYSICS CHECKS: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

func _save_test_roundtrip() -> bool:
	var snapshot=terrain.encode(); var copy=Terrain.new()
	return copy.decode(JSON.parse_string(JSON.stringify(snapshot))) and copy.cells==terrain.cells and copy.inventory==terrain.inventory

func _test_touch(index: int,p: Vector2,pressed: bool) -> void:
	var event=InputEventScreenTouch.new(); event.index=index; event.position=p; event.pressed=pressed
	get_viewport().push_input(event,true); await get_tree().process_frame
