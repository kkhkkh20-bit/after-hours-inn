extends Node2D
## After Hours: a portrait, click-operated medieval inn fork.
## Upstream DB/Game/Actor/Customer/RestaurantSystem/Audio remain the service core.
const GuestBody = preload("res://scripts/inn/guest.gd")
const ClickOwner = preload("res://scripts/inn/click_player.gd")
const Furniture = preload("res://scripts/inn/furniture.gd")
const FONT = preload("res://assets/ui/font/InnKorean.otf")
const SAVE := "user://border-inn-v1.json"
const COLORS := [Color("e9d4b1"),Color("b9cfdd"),Color("d7c0db"),Color("bbd4ae"),Color("ddbe9a"),Color("b8c9c3")]
var ground: Node2D
var upstairs: Node2D
var world: Node2D
var actors: Node2D
var keeper: Player
var service: RestaurantSystem
var guests: Dictionary = {}
var nav: AStarGrid2D
var routes: Dictionary = {}
var tasks: Array = []
var cook_timer := 0.0
var clerk_timer := 0.0
var serial := 0
var staff: Array[Actor] = []
var staff_tasks: Dictionary = {}
var room_marks: Array[Label] = []
var rooms: Array = []
var lodgers: Array[Actor] = []
var stock: int = 36
var meal_income: int = 0
var room_income: int = 0
var day_cost: int = 0
var floor_number := 0
var unlocked_tables := 4
var dining_points := [Vector2(145,510),Vector2(355,510),Vector2(565,510),Vector2(145,730),Vector2(355,730),Vector2(565,730)]
var table_nodes: Array[Node2D] = []
var desk := Vector2(360,345)
var stove := Vector2(100,335)
var stairs := Vector2(615,280)
var notice := Vector2(555,160)
var door := Vector2(355,1070)
var selected: Node2D
var context: PanelContainer
var context_box: VBoxContainer
var context_pos := Vector2.ZERO
var hud: Control
var status: Label
var hint: Label
var floor_button: Button
var day_bar: ProgressBar
var summary: PanelContainer
var elapsed_save := 0.0
var pulse := 0.0
var auto_reception := false
var resume_minutes: int = 480
var resume_summary := false
var room_rects: Array[Rect2] = []
var marker: Node2D

func _ready() -> void:
	randomize()
	Game.reset()
	Game.upgrades["tables"] = unlocked_tables
	for i in 5:
		rooms.append({"capacity": 2 if i < 3 else 4, "name":"", "party":0, "dirty":false, "until":0})
	_load()
	Game.upgrades["tables"] = unlocked_tables
	world = Node2D.new()
	add_child(world)
	world.position.y = 150
	ground = Node2D.new()
	world.add_child(ground)
	upstairs = Node2D.new()
	world.add_child(upstairs)
	upstairs.visible = false
	_build_ground()
	_build_rooms()
	_build_nav()
	actors = Node2D.new()
	actors.y_sort_enabled = true
	ground.add_child(actors)
	keeper = ClickOwner.new()
	actors.add_child(keeper)
	keeper.position = Vector2(350,850)
	keeper.speed = 310
	keeper.modulate = Color("fff0cc")
	keeper.arrived.connect(func():
		if not advance_route(keeper): _owner_arrived())
	marker = Node2D.new()
	ground.add_child(marker)
	service = RestaurantSystem.new()
	add_child(service)
	service.customer_arrived.connect(_arrive)
	service.customer_served.connect(func(_id: String,_sat: float,gold: int): meal_income += gold)
	_build_ui()
	for i in int(Game.upgrades.get("staff",0)):
		_add_worker(i)
	_refresh_lodgers()
	DayCycle.phase_changed.connect(_phase_changed)
	DayCycle.start_day()
	DayCycle.open_restaurant()
	DayCycle.minutes = resume_minutes
	if resume_summary:
		DayCycle.phase = DayCycle.Phase.SUMMARY
		DayCycle.running = false
		call_deferred("_show_summary")
	Audio.music_volume = 0.18
	Audio.ambience_volume = 0.20
	Audio.play_music("morning")
	Audio.play_ambience("restaurant")
	_toast("손님을 눌러 이야기를 듣고, 주문을 받아보세요.")
	service.request_spawn()

func _label(text: String, pos: Vector2, size: int = 20, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("eadcc0"))
	l.add_theme_color_override("font_shadow_color",Color("30252a"))
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else ground).add_child(l)
	return l

func _tile_area(area: Rect2i, key: String, parent: Node2D) -> void:
	for y in range(area.position.y,area.end.y,32):
		for x in range(area.position.x,area.end.x,32):
			var s := Sprite2D.new()
			s.texture = DB.env_texture(key)
			s.centered = false
			s.position = Vector2(x,y)
			parent.add_child(s)

func _prop(key: String, pos: Vector2, parent: Node2D, scale_by: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = DB.env_texture(key)
	s.position = pos
	s.scale = Vector2.ONE * scale_by
	if s.texture != null:
		s.offset.y = -s.texture.get_height()/2.0
	parent.add_child(s)
	return s

func _rect(area: Rect2, color: String, parent: Node) -> ColorRect:
	var r := ColorRect.new()
	r.position = area.position
	r.size = area.size
	r.color = Color(color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _furniture(kind: String, pos: Vector2, parent: Node2D) -> Node2D:
	var n := Furniture.new()
	n.kind = kind
	n.position = pos
	parent.add_child(n)
	return n

func _build_ground() -> void:
	_tile_area(Rect2i(0,0,736,1120),"grass_0",ground)
	_rect(Rect2(15,80,690,880),"352b2b",ground)
	_tile_area(Rect2i(32,176,656,768),"floor_plank_0",ground)
	_tile_area(Rect2i(32,80,656,96),"wall_0",ground)
	_tile_area(Rect2i(32,176,192,240),"floor_tile_0",ground)
	_tile_area(Rect2i(32,152,656,32),"wainscot",ground)
	for x in [260,420,600]:
		_prop("window_day",Vector2(x,148),ground)
	_prop("shelf",Vector2(110,140),ground)
	_prop("stove",Vector2(85,325),ground,1.1)
	_prop("barrel",Vector2(180,270),ground)
	_prop("crate",Vector2(180,355),ground)
	_prop("counter_long",Vector2(360,295),ground,1.5)
	_prop("pot",Vector2(320,269),ground)
	_prop("pan",Vector2(390,270),ground)
	_furniture("desk",Vector2(560,880),ground)
	_furniture("stairs",stairs,ground)
	_label("객실 ↑",Vector2(575,195),18)
	_label("주방 · 식재료",Vector2(45,200),18)
	_label("문 닫은 뒤",Vector2(265,80),28)
	_label("고용 게시판",Vector2(490,117),18)
	_prop("painting",notice,ground)
	_prop("plant",Vector2(55,450),ground)
	_prop("plant",Vector2(665,450),ground)
	_prop("plant",Vector2(60,880),ground)
	_prop("rug",Vector2(355,920),ground,1.4)
	for i in dining_points.size():
		var n := Node2D.new()
		ground.add_child(n)
		var p: Vector2 = dining_points[i]
		_prop("table",p,n,1.4)
		_prop("chair",p+Vector2(-54,12),n)
		_prop("chair",p+Vector2(54,12),n)
		_prop("chair",p+Vector2(-54,52),n)
		_prop("chair",p+Vector2(54,52),n)
		_prop("candle",p-Vector2(0,30),n)
		n.visible = i < unlocked_tables
		table_nodes.append(n)
		if i >= unlocked_tables:
			_label("+ 식탁 확장",p-Vector2(60,20),17,n)
			n.visible = true
			for c in n.get_children():
				if c is Sprite2D: c.visible = false
	_label("접수 · 객실 안내",Vector2(480,894),18)
	_label("국경 가도",Vector2(290,1054),18)
	_tile_area(Rect2i(290,960,128,160),"cobble_0",ground)
	for x in [70,650]:
		_prop("plant",Vector2(x,1040),ground,1.7)
		_prop("barrel",Vector2(x+25,985),ground)
	var fire := AnimatedSprite2D.new()
	fire.sprite_frames = DB.sprite_frames("vfx","fire","burn",10,true)
	fire.position = Vector2(85,290)
	fire.scale = Vector2(.7,.7)
	ground.add_child(fire)
	fire.play("burn")
	for p in [Vector2(110,350),Vector2(355,450),Vector2(565,685)]:
		var light := PointLight2D.new()
		var image := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1,1,1,.35),Color(1,1,1,0)])
		image.gradient = gradient
		image.fill = GradientTexture2D.FILL_RADIAL
		image.fill_from = Vector2(.5,.5)
		image.fill_to = Vector2(1,.5)
		image.width = 256
		image.height = 256
		light.texture = image
		light.position = p
		light.color = Color("ffd397")
		light.energy = .35
		ground.add_child(light)

func _build_rooms() -> void:
	_tile_area(Rect2i(0,0,736,1120),"floor_plank_0",upstairs)
	_label("객실동",Vector2(295,32),28,upstairs)
	_label("잠시 머물다 가는 사람들의 방",Vector2(178,78),18,upstairs)
	room_marks.clear()
	room_rects.clear()
	for i in 5:
		var x := 35.0 if i%2==0 else 405.0
		var y := 160.0 + floorf(i/2.0)*300.0
		var area := Rect2(x,y,280,250)
		room_rects.append(area)
		_rect(area,"514036",upstairs)
		_rect(Rect2(x+7,y+35,266,208),"b59166",upstairs)
		var beds := int(rooms[i].capacity)
		for b in beds:
			_furniture("bed",Vector2(x+62+(b%2)*145,y+125+floorf(b/2.0)*100),upstairs)
		_prop("plant",Vector2(x+240,y+85),upstairs)
		var l := _label("",Vector2(x+12,y+5),18,upstairs)
		room_marks.append(l)
	_furniture("stairs",Vector2(540,1000),upstairs)
	_label("↓ 식당으로",Vector2(480,1030),22,upstairs)
	_update_rooms()

func _build_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0,0,23,35)
	nav.cell_size = Vector2(32,32)
	nav.offset = Vector2(16,16)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for y in 35:
		for x in 23:
			var p := nav.get_point_position(Vector2i(x,y))
			var blocked := p.y < 210 or p.x < 48 or p.x > 672
			for area in [Rect2(40,235,90,90),Rect2(260,240,190,70),Rect2(490,815,135,65)]:
				blocked = blocked or area.has_point(p)
			for table in dining_points:
				blocked = blocked or Rect2(table-Vector2(43,62),Vector2(86,68)).has_point(p)
			nav.set_point_solid(Vector2i(x,y),blocked)

func _cell(p: Vector2) -> Vector2i:
	var cell := Vector2i(floori(p.x/32),floori(p.y/32))
	cell.x = clampi(cell.x,1,20)
	cell.y = clampi(cell.y,7,33)
	if not nav.is_point_solid(cell): return cell
	for radius in range(1,7):
		for y in range(cell.y-radius,cell.y+radius+1):
			for x in range(cell.x-radius,cell.x+radius+1):
				var c := Vector2i(x,y)
				if nav.is_in_boundsv(c) and not nav.is_point_solid(c): return c
	return Vector2i(10,26)

func navigate(actor: Actor, target: Vector2) -> void:
	var path := nav.get_point_path(_cell(actor.position),_cell(target))
	routes[actor.get_instance_id()] = Array(path)
	advance_route(actor)

func advance_route(actor: Actor) -> bool:
	var key := actor.get_instance_id()
	if not routes.has(key): return false
	var path: Array = routes[key]
	while not path.is_empty() and actor.position.distance_to(path[0]) < 3:
		path.pop_front()
	if path.is_empty():
		routes.erase(key)
		return false
	actor._target = path.pop_front()
	actor._moving = true
	return true

func _button(text: String, callback: Callable, parent: Node, width: float = 150) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width,54)
	b.add_theme_font_override("font",FONT)
	b.add_theme_font_size_override("font_size",21)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("463c37")
	style.border_color = Color("ad8960")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	b.add_theme_stylebox_override("normal",style)
	b.add_theme_stylebox_override("hover",style)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_rect(Rect2(0,0,720,147),"292b29",hud)
	status = _label("",Vector2(22,14),23,hud)
	var bar := HBoxContainer.new()
	bar.position = Vector2(20,59)
	bar.add_theme_constant_override("separation",8)
	hud.add_child(bar)
	floor_button = _button("1층 · 식당",func(): _switch_floor(1-floor_number),bar,200)
	_button("1배속",func():
		Engine.time_scale = 2.0 if Engine.time_scale == 1 else 1.0
		(bar.get_child(1) as Button).text = "2배속" if Engine.time_scale==2 else "1배속",bar,135)
	_button("일시정지",func():
		get_tree().paused = not get_tree().paused
		(bar.get_child(2) as Button).text = "계속" if get_tree().paused else "일시정지",bar,150).process_mode = Node.PROCESS_MODE_ALWAYS
	_button("저장",func(): _save(); _toast("저장했어요."),bar,135)
	day_bar = ProgressBar.new()
	day_bar.position = Vector2(20,128)
	day_bar.size = Vector2(680,5)
	day_bar.show_percentage = false
	hud.add_child(day_bar)
	hint = _label("",Vector2(24,150),19,hud)
	context = PanelContainer.new()
	context.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252c2af5")
	style.border_color = Color("d1b78c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	context.add_theme_stylebox_override("panel",style)
	hud.add_child(context)
	context_box = VBoxContainer.new()
	context_box.add_theme_constant_override("separation",8)
	context.add_child(context_box)

func _menu(at: Vector2, text: String, options: Array) -> void:
	for child in context_box.get_children():
		context_box.remove_child(child)
		child.queue_free()
	var l := _label(text,Vector2.ZERO,20,context_box)
	l.custom_minimum_size = Vector2(280,0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for option in options:
		_button(str(option[0]),option[1],context_box,280)
	_button("닫기",func(): context.hide(),context_box,280)
	context.reset_size()
	context_pos = at
	context.show()
	call_deferred("_position_menu")

func _position_menu() -> void:
	context.position = Vector2(clampf(context_pos.x+18,12,708-context.size.x),clampf(context_pos.y-context.size.y/2,165,1260-context.size.y))

func _toast(text: String) -> void:
	if hint == null: return
	hint.text = text
	var current := text
	get_tree().create_timer(5).timeout.connect(func():
		if is_instance_valid(hint) and hint.text == current: hint.text = "")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at := get_viewport().get_mouse_position()-hud.position
		if at.y < 150 or summary != null: return
		context.hide()
		var point := at-Vector2(0,150)
		if floor_number == 1:
			for i in room_rects.size():
				if room_rects[i].has_point(point): _room_menu(i,at); return
			if point.y > 950: _switch_floor(0)
			return
		for id in guests:
			var c: Customer = guests[id]
			if Rect2(c.position-Vector2(42,90),Vector2(84,110)).has_point(point):
				_guest_menu(c,at)
				return
		if point.distance_to(stairs)<80: _switch_floor(1); return
		if point.distance_to(notice)<75: _staff_menu(at); return
		if point.distance_to(desk)<85: _kitchen_menu(at); return
		if point.distance_to(stove)<95: _kitchen_menu(at); return
		if point.distance_to(Vector2(560,870))<100: _reception_menu(at); return
		for i in dining_points.size():
			if i >= unlocked_tables and point.distance_to(dining_points[i])<75:
				_expand_menu(at); return
		tasks.clear()
		cook_timer = 0
		navigate(keeper,point)
		queue_redraw()

func _guest_menu(c: Customer, at: Vector2) -> void:
	selected = c
	var g = c as GuestBody
	var need := "%s %d명입니다.\n%s" % [c.display_name(),g.party,"식사하고 하룻밤 묵으려오." if g.request_room else "식사만 하고 가겠습니다."]
	if not g.talked:
		_menu(at,c.display_name(),[["말 걸기",func():
			g.talked = true
			_talk_to(g)
			_guest_menu(c,at)]])
		return
	var options: Array = []
	if c.is_waiting():
		need += "\n주문: "+str(DB.recipe(c.fsm.wanted_recipe).get("name","식사"))
		options.append(["주문 요리하고 가져다주기",func(): _start_service(c)])
	if g.request_room and g.room_number < 0:
		for i in rooms.size():
			if _room_free(i) and int(rooms[i].capacity)>=g.party:
				var index := i
				options.append(["%d호실 안내 · %d인실 · %dG" % [i+1,int(rooms[i].capacity),g.party*14],func(): _book(g,index)])
		if options.is_empty(): need += "\n지금은 맞는 빈방이 없습니다. 식사는 가능합니다."
	elif g.room_number >= 0:
		need += "\n%d호실을 이용 중입니다." % [g.room_number+1]
	options.append(["정중히 돌려보내기",func():
		c.fsm.walked_out = true
		c.fsm.set_state(CustomerStateMachine.S.LEAVE)
		context.hide()])
	_menu(at,need,options)

func _talk_to(c: Customer) -> void:
	tasks = [{"kind":"talk","id":c.char_id}]
	navigate(keeper,c.position+Vector2(0,40))

func _start_service(c: Customer) -> void:
	context.hide()
	if not c.is_waiting(): return
	if stock < (c as GuestBody).party:
		_toast("식재료가 부족해요. 주방에서 보충할 수 있어요.")
		return
	tasks = [{"kind":"cook","id":c.char_id},{"kind":"serve","id":c.char_id}]
	cook_timer = 0
	navigate(keeper,stove+Vector2(65,25))
	_toast("주인이 주방으로 이동합니다.")

func _owner_arrived() -> void:
	if tasks.is_empty(): return
	var task: Dictionary = tasks[0]
	if task.kind == "cook":
		cook_timer = 1.8
		_toast("요리 중…")
	elif task.kind == "serve":
		var c: Customer = guests.get(str(task.id))
		if is_instance_valid(c) and c.is_waiting(): _serve(c)
		keeper.drop_carry()
		tasks.clear()
	elif task.kind == "talk":
		var c: Customer = guests.get(str(task.id))
		if is_instance_valid(c): c._bubble.say("%d명입니다. 잘 부탁하오." % (c as GuestBody).party)
		tasks.clear()

func _serve(c: Customer) -> void:
	var party := (c as GuestBody).party
	if stock < party: return
	stock -= party
	var sat := c.serve_dish(c.fsm.wanted_recipe,"good")
	if sat >= 0: Audio.play_sfx("plate")
	_save()

func _arrive(id: String, table: int) -> void:
	var c := GuestBody.new()
	c.inn = self
	serial += 1
	c.party = [1,2,2,4,1,2][(serial-1)%6]
	c.request_room = serial%3 != 1
	actors.add_child(c)
	c.setup_customer(id,door,dining_points[table]+Vector2(0,53),table)
	c.speed = 145
	c.modulate = COLORS[DB.character_ids().find(id)%COLORS.size()]
	c.ordered.connect(func(customer: Customer): customer.fsm.wanted_recipe = service.choose_order(customer.char_id))
	c.left.connect(_leave)
	guests[id] = c
	c.caption = _label("%s · %d인" % [c.display_name().split(" ")[0],c.party],Vector2(-58,10),14,c)
	for i in c.party-1:
		var follower := Actor.new()
		actors.add_child(follower)
		follower.setup("cook")
		follower.modulate = COLORS[(DB.character_ids().find(id)+i+1)%COLORS.size()]
		follower.speed = 140
		follower.position = door+Vector2((i-1)*25,25)
		c.followers.append(follower)
		follower.arrived.connect(func(): advance_route(follower))
	Audio.play_sfx("bell",1,.4)

func _settle(c: Customer) -> void:
	var result := service.complete_visit(c.char_id,c.fsm)
	var extra := int(result.get("gold",0))*((c as GuestBody).party-1)
	if extra>0:
		Game.add_gold(extra)
		meal_income+=extra

func _leave(c: Customer) -> void:
	var g = c as GuestBody
	_settle(c)
	guests.erase(c.char_id)
	if g.room_number>=0: _refresh_lodgers()
	routes.erase(c.get_instance_id())
	if selected == c: context.hide(); selected = null

func _room_free(i: int) -> bool:
	return str(rooms[i].name)=="" and not bool(rooms[i].dirty)

func _book(c: GuestBody, i: int) -> void:
	if not _room_free(i) or c.room_number>=0: return
	if c.party>int(rooms[i].capacity): return
	c.room_number = i
	rooms[i].name = c.display_name()
	rooms[i].party = c.party
	rooms[i].until = Game.day+1
	var fee := c.party*14
	Game.add_gold(fee)
	room_income += fee
	context.hide()
	_update_rooms()
	_toast("%d호실을 안내했어요. 숙박료 +%dG" % [i+1,fee])
	_refresh_lodgers()
	_save()

func _room_menu(i: int, at: Vector2) -> void:
	var room: Dictionary = rooms[i]
	var text := "%d호실 · %d인실\n" % [i+1,int(room.capacity)]
	if bool(room.dirty):
		_menu(at,text+"퇴실한 방입니다.",[["청소하기",func():
			room.dirty = false
			_update_rooms()
			context.hide()
			Audio.play_sfx("plate")
			_save()]])
	elif str(room.name)!="":
		_menu(at,text+"%s 일행 · %d명\n다음 날 아침 퇴실" % [room.name,int(room.party)],[])
	else:
		_menu(at,text+"깨끗한 빈방입니다.",[])

func _update_rooms() -> void:
	for i in room_marks.size():
		var r: Dictionary = rooms[i]
		var state := "청소 필요" if bool(r.dirty) else ("빈방" if str(r.name)=="" else "%d명 숙박" % int(r.party))
		room_marks[i].text = "%d호 · %d인실 · %s" % [i+1,int(r.capacity),state]

func _refresh_lodgers() -> void:
	for l in lodgers:
		if is_instance_valid(l): l.queue_free()
	lodgers.clear()
	for i in rooms.size():
		if str(rooms[i].name)=="": continue
		var dining := false
		for g in guests.values():
			if g.room_number==i: dining=true
		if dining: continue
		var area := room_rects[i]
		for j in int(rooms[i].party):
			var l := Actor.new()
			upstairs.add_child(l)
			l.setup("cook")
			l.modulate = COLORS[(i+j)%COLORS.size()]
			l.position = area.position+Vector2(90+(j%2)*115,140+floorf(j/2.0)*70)
			lodgers.append(l)

func _staff_menu(at: Vector2) -> void:
	var text := "고용 게시판\n직원이 주문·요리·서빙을 맡습니다.\n고용 45G · 하루 임금 12G\n현재 %d명 / 최대 3명" % staff.size()
	var options: Array = []
	if staff.size()<3:
		options.append(["직원 고용 · 45G",func():
			if not Game.spend(45): _toast("고용비가 부족해요."); return
			_add_worker(staff.size())
			Game.upgrades["staff"] = staff.size()
			context.hide()
			_toast("직원이 일을 시작했어요.")
			_save()])
	_menu(at,text,options)

func _add_worker(index: int) -> void:
	var a := Actor.new()
	actors.add_child(a)
	a.setup("cook")
	a.modulate = Color("abd8c8")
	a.speed = 240
	a.position = Vector2(260+index*40,370)
	a.arrived.connect(func(): advance_route(a))
	staff.append(a)
	_label("직원",Vector2(-18,8),14,a)

func _reception_menu(at: Vector2) -> void:
	_menu(at,"접수대\n직원이 빈방 안내와 퇴실 청소를\n함께 맡도록 설정할 수 있어요.",[["자동 방 안내: "+("켜짐" if auto_reception else "꺼짐"),func():
		auto_reception = not auto_reception
		_save()
		_reception_menu(at)],["객실 보기",func(): _switch_floor(1)]])

func _kitchen_menu(at: Vector2) -> void:
	_menu(at,"주방 · 식재료 %d인분\n주문을 누르면 주인이 요리부터\n서빙까지 이어서 합니다." % stock,[["식재료 20인분 · 16G",func():
		if Game.spend(16): stock+=20; Audio.play_sfx("coin"); _save()
		else: _toast("식재료 구입비가 부족해요.")
		_kitchen_menu(at)],["직원 고용",func(): _staff_menu(at)]])

func _expand_menu(at: Vector2) -> void:
	_menu(at,"식당 확장\n4인 테이블을 하나 더 설치합니다.",[["테이블 추가 · 65G",func():
		if unlocked_tables>=6: return
		if not Game.spend(65): _toast("확장비가 부족해요."); return
		unlocked_tables += 1
		Game.upgrades["tables"] = unlocked_tables
		service.rebuild_tables()
		var n: Node2D = table_nodes[unlocked_tables-1]
		for child in n.get_children():
			child.visible = child is Sprite2D
		context.hide()
		Audio.play_sfx("levelup")
		_save()]])

func _switch_floor(n: int) -> void:
	floor_number = n
	ground.visible = n==0
	upstairs.visible = n==1
	context.hide()
	floor_button.text = "1층 · 식당" if n==0 else "2층 · 객실"
	_update_rooms()

func _process(delta: float) -> void:
	if service == null: return
	var left := (get_viewport_rect().size.x-720)/2.0
	world.position.x = left
	hud.position.x = left
	status.text = "%d일  %02d:%02d     %dG     식재료 %d" % [Game.day,DayCycle.minutes/60,DayCycle.minutes%60,Game.gold,stock]
	day_bar.value = DayCycle.service_progress()*100
	service.tick(delta)
	if cook_timer>0:
		cook_timer -= delta
		if cook_timer<=0 and not tasks.is_empty():
			var id := str(tasks[0].id)
			tasks.pop_front()
			var c: Customer = guests.get(id)
			if is_instance_valid(c) and c.is_waiting():
				keeper.carry(c.fsm.wanted_recipe,"good")
				navigate(keeper,c.position+Vector2(0,35))
			else: tasks.clear()
	pulse += delta
	if pulse>0.45:
		pulse = 0
		for id in guests:
			var c = guests[id] as GuestBody
			for j in c.followers.size():
				var follower: Actor = c.followers[j]
				if not is_instance_valid(follower): continue
				var end: Vector2 = c.position+Vector2(-48 if j%2==0 else 48,25+floorf(j/2.0)*38)
				if c.fsm.state in [CustomerStateMachine.S.EAT,CustomerStateMachine.S.REACT]: follower.play("eat")
				elif follower.position.distance_to(end)>35: navigate(follower,end)
			if auto_reception and not staff.is_empty() and c.request_room and c.room_number<0:
				for i in rooms.size():
					if _room_free(i) and int(rooms[i].capacity)>=c.party: _book(c,i); break
	_tick_staff(delta)
	elapsed_save += delta
	if elapsed_save>12: elapsed_save=0; _save()

func _tick_staff(delta: float) -> void:
	for i in staff.size():
		var a: Actor = staff[i]
		var key := a.get_instance_id()
		if staff_tasks.has(key):
			var job: Dictionary = staff_tasks[key]
			var c: Customer = guests.get(str(job.id))
			if not is_instance_valid(c) or not c.is_waiting(): staff_tasks.erase(key); continue
			if a.is_moving(): continue
			if job.stage=="cook":
				job.timer = float(job.timer)-delta
				if float(job.timer)<=0:
					job.stage = "serve"
					navigate(a,c.position+Vector2(35,20))
			else:
				_serve(c)
				staff_tasks.erase(key)
			continue
		for id in guests:
			var c: Customer = guests[id]
			if not c.is_waiting() or stock<(c as GuestBody).party: continue
			var claimed := false
			for job in staff_tasks.values():
				if str(job.id)==id: claimed=true
			for task in tasks:
				if str(task.id)==id: claimed=true
			if claimed: continue
			staff_tasks[key] = {"id":id,"stage":"cook","timer":3.0}
			navigate(a,stove+Vector2(70,40+i*22))
			break
	clerk_timer += delta
	if clerk_timer>3 and not staff.is_empty():
		clerk_timer=0
		for r in rooms:
			if bool(r.dirty): r.dirty=false; _update_rooms(); break

func _phase_changed(phase: int) -> void:
	if phase==DayCycle.Phase.SUMMARY: call_deferred("_close_day")

func _close_day() -> void:
	# Settle served meals before clearing visual bodies, including chewing guests.
	for id in guests.keys():
		var c: Customer = guests[id]
		if c.fsm.served_quality!="": _settle(c)
		c.queue_free()
	guests.clear()
	service.clear_all()
	staff_tasks.clear()
	tasks.clear()
	keeper.drop_carry()
	for a in staff: a.stop()
	keeper.stop()
	routes.clear()
	day_cost = 14+staff.size()*12+(8 if Game.day%3==0 else 0)
	Game.add_gold(-day_cost)
	for r in rooms:
		if str(r.name)!="": r.name=""; r.party=0; r.dirty=true
	_update_rooms()
	_refresh_lodgers()
	context.hide()
	_show_summary()
	_save()

func _show_summary() -> void:
	summary = PanelContainer.new()
	summary.position = Vector2(55,385)
	summary.custom_minimum_size = Vector2(610,360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("292e2b")
	style.set_content_margin_all(26)
	style.set_corner_radius_all(14)
	summary.add_theme_stylebox_override("panel",style)
	hud.add_child(summary)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	summary.add_child(box)
	_label("%d일 영업을 마쳤습니다" % Game.day,Vector2.ZERO,28,box)
	_label("식사 매출  +%dG\n숙박 매출  +%dG\n임대료·임금·세금  -%dG\n오늘 순수입  %dG\n남은 돈  %dG" % [meal_income,room_income,day_cost,meal_income+room_income-day_cost,Game.gold],Vector2.ZERO,23,box)
	_button("다음 날 열기",func():
		summary.queue_free()
		summary=null
		meal_income=0
		room_income=0
		DayCycle.next_day()
		DayCycle.open_restaurant()
		_save()
		_toast("새 아침입니다. 빈방은 청소 후 다시 팔 수 있어요."),box,540)
	_save()

func _save() -> void:
	var f := FileAccess.open(SAVE,FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"game":Game.to_dict(),"rooms":rooms,"stock":stock,"tables":unlocked_tables,"auto_reception":auto_reception,"serial":serial,"minutes":DayCycle.minutes,"summary":DayCycle.phase==DayCycle.Phase.SUMMARY,"meal_income":meal_income,"room_income":room_income,"day_cost":day_cost}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE): return
	var f := FileAccess.open(SAVE,FileAccess.READ)
	if f==null: return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary: return
	var d: Dictionary = parsed
	if d.get("game") is Dictionary: Game.from_dict(d.game)
	if d.get("rooms") is Array and d.rooms.size()==5: rooms = d.rooms
	stock = maxi(0,int(d.get("stock",36)))
	unlocked_tables = clampi(int(d.get("tables",4)),4,6)
	auto_reception = bool(d.get("auto_reception",false))
	serial = int(d.get("serial",0))
	resume_minutes = clampi(int(d.get("minutes",480)),480,1320)
	resume_summary = bool(d.get("summary",false))
	meal_income = int(d.get("meal_income",0))
	room_income = int(d.get("room_income",0))
	day_cost = int(d.get("day_cost",0))
