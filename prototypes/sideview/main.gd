extends Node2D
const Rules = preload("res://simulation.gd")
var sim = Rules.new()
var font = preload("res://assets/InnKorean.otf")
var knight = preload("res://assets/knight.png")
var tiles = preload("res://assets/world_tileset.png")
var selected = "홀의 주문"
var selected_guest = -1
var lights: Array[PointLight2D] = []
var labels: Dictionary = {}
var buttons: Dictionary = {}
var sound: AudioStreamPlayer
var feedback_clock = 0.0
var ui: Control
var save_path = "user://sideview.json"
var speed = 1.0
var capture_mode = false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101722"))
	var canvas = CanvasModulate.new(); canvas.color = Color(0.56,0.57,0.63); add_child(canvas)
	for p in [Vector2(385,318),Vector2(385,548),Vector2(215,778)]:
		var lamp = PointLight2D.new()
		var gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color(1,1,1,0.9),Color(1,1,1,0)])
		var texture = GradientTexture2D.new(); texture.gradient = gradient
		texture.width = 512; texture.height = 512; texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5); texture.fill_to = Vector2(0.5,1)
		lamp.texture = texture; lamp.position = p; lamp.color = Color("ffc784")
		lamp.energy = 0.9; lamp.texture_scale = 1.45; lamp.shadow_enabled = true
		add_child(lamp); lights.append(lamp)
	for y in [398,628]:
		var occ = LightOccluder2D.new(); var polygon = OccluderPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(128,y),Vector2(674,y),Vector2(674,y+14),Vector2(128,y+14)])
		occ.occluder = polygon; add_child(occ)
	sound = AudioStreamPlayer.new(); sound.stream = preload("res://assets/tap.wav")
	sound.volume_db = -17; add_child(sound)
	_setup_ui()
	if "--verify" in OS.get_cmdline_user_args():
		var tests = load("res://tests.gd").new(); var failures: int = tests.run()
		get_tree().quit(0 if failures == 0 else 1); return
	if "--input-verify" in OS.get_cmdline_user_args():
		await _verify_inputs(); return
	if "--capture" in OS.get_cmdline_user_args() or "--capture-dark" in OS.get_cmdline_user_args():
		capture_mode = true
		sim.hired = true; sim.hatch_open = true; sim.dig_count = 3
		if "--capture-dark" in OS.get_cmdline_user_args():
			sim.owner.pos = Vector2(440,850); sim.owner.floor = 2
			sim.lamps[2] = false; selected = "지하 벽 · 굴착"; sim.emit_noise(0.9)
		sim.paused = true
		_update_ui(); queue_redraw()
		await get_tree().create_timer(0.5).timeout
		var name_part = "dark" if "--capture-dark" in OS.get_cmdline_user_args() else "overview"
		get_viewport().get_texture().get_image().save_png("res://../../docs/sideview-"+name_part+".png")
		get_tree().quit()

func _label(key: String, text: String, rect: Rect2, size: int = 20, color: Color = Color("ded5c3")) -> Label:
	var label = Label.new(); label.text = text; label.position = rect.position; label.size = rect.size
	label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label); labels[key] = label; return label

func _panel(rect: Rect2, color: Color) -> void:
	var panel = ColorRect.new(); panel.position = rect.position; panel.size = rect.size; panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(panel)

func _button(key: String, title: String, rect: Rect2, callback: Callable) -> void:
	var b = Button.new(); b.text = title; b.position = rect.position; b.size = rect.size
	b.add_theme_font_override("font",font); b.add_theme_font_size_override("font_size",26)
	for state in ["normal","hover","pressed","disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("354249") if state == "normal" else Color("53605a")
		if state == "disabled": style.bg_color = Color("252c32")
		style.border_color = Color("7d7868"); style.set_border_width_all(1); style.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(callback); ui.add_child(b); buttons[key] = b

func _setup_ui() -> void:
	var layer = CanvasLayer.new(); add_child(layer)
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	_panel(Rect2(0,0,720,152),Color("111a22"))
	_panel(Rect2(20,14,4,40),Color("c59b5e"))
	_label("title","문 닫은 뒤",Rect2(38,13,400,42),30)
	_label("version","2D 단면 실험 0.1",Rect2(468,25,240,30),18,Color("a6aaa5"))
	_label("stats","",Rect2(26,64,670,36),26)
	_label("clock","",Rect2(26,106,480,30),21)
	_button("pause","일시정지",Rect2(540,91,156,56),_pause)
	_label("floor0","2층 · 객실",Rect2(43,240,250,27),17,Color("bdc6c9"))
	_label("room0","101호",Rect2(363,248,90,25),16)
	_label("room1","102호",Rect2(534,248,90,25),16)
	_label("floor1","1층 · 식당과 접객",Rect2(43,434,300,30),17,Color("bdc6c9"))
	_label("floor2","지하 · 주인만 아는 길",Rect2(43,688,420,30),17,Color("bdc6c9"))
	_label("hint","빈 바닥을 누르면 이동 · 물건과 인물을 눌러 선택",Rect2(26,918,680,28),17,Color("a9b3b5"))
	_panel(Rect2(0,956,720,404),Color("111a22"))
	_label("selected","",Rect2(24,965,680,38),27)
	_label("activity","",Rect2(24,1005,680,30),21,Color("c5ad7a"))
	_button("primary","식사 제공",Rect2(24,1040,328,80),_primary)
	_button("secondary","직원 고용 · 8닢",Rect2(368,1040,328,80),_secondary)
	var actions = [["serve","접객"],["lamp","등불"],["hatch","덮개"],["dig","굴착"]]
	for i in range(actions.size()):
		_button(actions[i][0],actions[i][1],Rect2(24+i*172,1136,156,80),_request.bind(actions[i][0]))
	_button("save","저장",Rect2(24,1232,208,80),_save)
	_button("load","불러오기",Rect2(256,1232,208,80),_load_save)
	_button("reset","새 실험",Rect2(488,1232,208,80),_reset)
	_label("log","",Rect2(24,1320,672,40),21)

func _pause() -> void:
	sim.paused = not sim.paused; _update_ui()

func _request(action: String) -> void:
	sim.request(action); _update_ui()

func _primary() -> void:
	if selected_guest >= 0:
		sim.request("drag" if sim.guests[selected_guest].down else "ambush", selected_guest)
	elif selected == "지하 벽 · 굴착": sim.request("dig")
	elif selected == "지하 덮개": sim.request("hatch")
	elif selected == "현재 층 등불": sim.request("lamp")
	else: sim.request("serve")
	_update_ui()

func _secondary() -> void:
	if selected_guest >= 0: sim.request("room",selected_guest)
	else: sim.request("delegate" if sim.hired else "hire")
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_world_click(get_global_transform_with_canvas().affine_inverse() * event.position)

func _handle_world_click(p: Vector2) -> void:
	if p.y < 200 or p.y > 918: return
	selected_guest = -1
	for i in range(sim.guests.size()):
		if p.distance_to(sim.guests[i].pos + Vector2(0,-20)) < 45:
			selected_guest = i; selected = sim.guests[i].name; _update_ui(); return
	if absf(p.x-96)<34 and absf(p.y-620)<38:
		selected = "지하 덮개"
	elif p.y > 715 and p.x >= 260 + sim.dig_count*54:
		selected = "지하 벽 · 굴착"
	elif p.distance_to(Vector2(510,580)) < 65:
		selected = "홀의 주문"
	else:
		selected = "이동"
		var floor_id = 0 if p.y < 413 else (1 if p.y < 665 else 2)
		sim.walk_to(p,floor_id)
	_update_ui()

func _process(delta: float) -> void:
	sim.tick(minf(delta,0.1)*speed)
	for i in range(3): lights[i].enabled = sim.lamps[i]
	feedback_clock += delta
	if feedback_clock >= 0.3:
		feedback_clock = 0
		_update_ui()
		if (sim.digging or not sim.route.is_empty()) and not sim.paused: sound.play()
	queue_redraw()

func _update_ui() -> void:
	labels.stats.text = "%d닢    목재 %d    주문 %d    의심 %d%%" % [sim.coins,sim.wood,sim.orders,sim.suspicion]
	labels.clock.text = "첫날  %02d:%02d   ·   경비 방문까지 %d초" % [18+int(sim.clock/60),int(sim.clock)%60,75-int(sim.guard_clock)]
	labels.selected.text = "선택: " + selected
	labels.activity.text = "굴착 중 %d%% · 소리 %.0f%%" % [sim.dig_work/4*100,sim.last_noise*100] if sim.digging else ("목적지로 이동 중…" if not sim.route.is_empty() else "주인이 직접 걸어가서 행동합니다")
	if sim.staff_investigation > 0: labels.activity.text = "직원이 소리를 듣고 확인하러 움직인다!"
	buttons.pause.text = "계속하기" if sim.paused else "일시정지"
	buttons.primary.text = "식사 제공 · +4닢"
	if selected_guest >= 0:
		buttons.primary.text = "내려놓기" if sim.dragging >= 0 else ("끌고 가기" if sim.guests[selected_guest].down else "기절 · 틈 노리기")
		buttons.secondary.text = "객실 변경 → %d호" % (102-sim.guests[selected_guest].room)
	else:
		buttons.secondary.text = ("접객 중지" if sim.delegated else "접객 맡기기") if sim.hired else "직원 고용 · 8닢"
		if selected == "지하 벽 · 굴착": buttons.primary.text = "직접 파기 · 목재 1"
		elif selected == "지하 덮개": buttons.primary.text = "덮개 닫기" if sim.hatch_open else "덮개 열기"
		elif selected == "현재 층 등불": buttons.primary.text = "등불 조작"
	labels.log.text = sim.event_log[0]
	labels.log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons.dig.disabled = sim.dig_count >= 6

func _save() -> void:
	if not sim.route.is_empty() or sim.digging or sim.pending != "" or sim.dragging >= 0:
		sim.log_event("작업·이동·운반을 마친 뒤 저장하자."); return
	var data = {"version":1,"coins":sim.coins,"wood":sim.wood,"dug":sim.dig_count,"lamps":sim.lamps,"hatch":sim.hatch_open,"hired":sim.hired,"delegated":sim.delegated,"suspicion":sim.suspicion,"clock":sim.clock,"guard_clock":sim.guard_clock,"wage_clock":sim.wage_clock,"orders":sim.orders,"served":sim.served,"x":sim.owner.pos.x,"floor":sim.owner.floor,"guests":[]}
	for g in sim.guests: data.guests.append({"x":g.pos.x,"y":g.pos.y,"floor":g.floor,"face":g.face,"room":g.room,"down":g.down})
	var f = FileAccess.open(save_path,FileAccess.WRITE)
	if f == null: sim.log_event("저장 실패"); return
	f.store_string(JSON.stringify(data)); sim.log_event("2D 실험 저장 완료. 기존 3D 저장과 별개다.")

func _load_save() -> void:
	if not FileAccess.file_exists(save_path): sim.log_event("저장 기록이 없다."); return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version",0) != 1: sim.log_event("저장 형식을 읽을 수 없다."); return
	sim = Rules.new()
	sim.coins = maxi(0,int(data.get("coins",24))); sim.wood = maxi(0,int(data.get("wood",8)))
	sim.dig_count = clampi(int(data.get("dug",0)),0,6)
	if data.get("lamps",[]) is Array and data.lamps.size() == 3: sim.lamps = data.lamps
	sim.hatch_open = bool(data.get("hatch",false)); sim.hired = bool(data.get("hired",false)); sim.delegated = bool(data.get("delegated",true))
	sim.suspicion = clampf(float(data.get("suspicion",0)),0,100)
	sim.clock = maxf(0,float(data.get("clock",0))); sim.guard_clock = clampf(float(data.get("guard_clock",0)),0,74.99)
	sim.wage_clock = clampf(float(data.get("wage_clock",0)),0,89.99)
	sim.orders = clampi(int(data.get("orders",1)),0,4); sim.served = maxi(0,int(data.get("served",0)))
	sim.owner.floor = clampi(int(data.get("floor",1)),0,2)
	sim.owner.pos = Vector2(clampf(float(data.get("x",360)),62,295+sim.dig_count*54 if sim.owner.floor == 2 else 654),sim.FLOORS[sim.owner.floor])
	if data.get("guests",[]) is Array and data.guests.size() == 2:
		for i in range(2):
			var g = data.guests[i]
			if not g is Dictionary: continue
			sim.guests[i].floor = clampi(int(g.get("floor",1)),0,2)
			sim.guests[i].pos = Vector2(clampf(float(g.get("x",300)),62,654),sim.FLOORS[sim.guests[i].floor])
			sim.guests[i].face = int(g.get("face",1)); sim.guests[i].room = clampi(int(g.get("room",0)),0,1)
			sim.guests[i].down = bool(g.get("down",false))
	sim.evidence = sim.guests[0].down or sim.guests[1].down
	selected_guest = -1; selected = "불러온 여관"; sim.log_event("2D 실험을 불러왔다."); _update_ui()

func _reset() -> void:
	sim = Rules.new(); selected_guest = -1; selected = "홀의 주문"; _update_ui()

func _wood(rect: Rect2, color: Color = Color("705039")) -> void:
	draw_rect(rect,color)
	for x in range(int(rect.position.x),int(rect.end.x),26):
		draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),color.darkened(0.23),2)

func _bed(x: float) -> void:
	_wood(Rect2(x,358,84,23)); draw_rect(Rect2(x+4,347,74,24),Color("82918c"))
	draw_rect(Rect2(x+8,347,23,15),Color("d3cbb4")); draw_rect(Rect2(x+36,347,39,20),Color("6c777c"))
	_wood(Rect2(x,337,7,48)); _wood(Rect2(x+80,355,6,30))

func _table(x: float,y: float) -> void:
	_wood(Rect2(x,y,74,12)); _wood(Rect2(x+8,y+12,8,30)); _wood(Rect2(x+58,y+12,8,30))
	draw_rect(Rect2(x+29,y-10,12,10),Color("b49a76")); draw_line(Vector2(x+41,y-9),Vector2(x+46,y-4),Color("b49a76"),3)

func _actor(a: Dictionary, tint: Color, tag: String, is_owner: bool = false) -> void:
	var p: Vector2 = a.pos
	if a.get("down",false):
		draw_rect(Rect2(p-Vector2(26,16),Vector2(46,13)),tint)
		draw_rect(Rect2(p+Vector2(17,-16),Vector2(13,12)),Color("c9ad86"))
	else:
		var frame = int(sim.clock*7)%4 if (is_owner and not sim.route.is_empty()) or not a.get("route",[]).is_empty() else int(sim.clock*3)%4
		var row = 2 if (is_owner and not sim.route.is_empty()) or not a.get("route",[]).is_empty() else 0
		var dest = Rect2(p-Vector2(32,58),Vector2(64,64))
		if a.face < 0: dest.position.x += 64; dest.size.x = -64
		draw_texture_rect_region(knight,dest,Rect2(frame*32,row*32,32,32),tint)
		# Coloured coat markers distinguish the placeholder characters.
		draw_rect(Rect2(p-Vector2(7,25),Vector2(14,15)),tint)
	if is_owner: draw_arc(p+Vector2(0,-17),30,0,TAU,32,Color("dfc58b"),2)
	draw_string(font,p+Vector2(-33,-62),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e6d9bd"))

func _draw() -> void:
	# Original procedural cutaway furnishings; imported CC0 tiles provide garden texture.
	draw_rect(Rect2(0,155,720,500),Color("233039"))
	for x in range(0,720,32):
		draw_rect(Rect2(x,190+(x%5)*7,17,440),Color("1b272f"))
	for i in range(36):
		var x = fmod(i*139+sim.clock*18,720); var y = fmod(i*67+sim.clock*150,450)+160
		draw_line(Vector2(x,y),Vector2(x-4,y+13),Color(0.5,0.65,0.72,0.2),1)
	draw_colored_polygon(PackedVector2Array([Vector2(25,225),Vector2(130,168),Vector2(590,168),Vector2(699,225)]),Color("493f3d"))
	for y in range(178,226,12): draw_line(Vector2(138-(y-178)*2,y),Vector2(580+(y-178)*2,y),Color("67564a"),3)
	draw_rect(Rect2(37,226,646,414),Color("504a40"))
	draw_rect(Rect2(54,244,612,146),Color("6b6250"))
	draw_rect(Rect2(54,414,612,206),Color("645a47"))
	# Window recesses and wooden frames.
	for p in [Vector2(180,280),Vector2(420,285),Vector2(585,285),Vector2(195,470),Vector2(580,470)]:
		draw_rect(Rect2(p,Vector2(42,56)),Color("293b46"))
		draw_rect(Rect2(p,Vector2(42,56)),Color("947752"),false,4)
		draw_line(p+Vector2(21,0),p+Vector2(21,56),Color("947752"),3)
		draw_line(p+Vector2(0,29),p+Vector2(42,29),Color("947752"),3)
	for x in [48,333,502,666]: _wood(Rect2(x,235,10,160),Color("493a30"))
	for x in [48,666]: _wood(Rect2(x,410,10,218),Color("493a30"))
	_bed(366); _bed(536)
	_wood(Rect2(245,346,42,40),Color("66503a")); draw_rect(Rect2(259,359,12,5),Color("c6ab70"))
	_table(215,575); _table(350,575)
	_wood(Rect2(470,578,143,42),Color("78583c")); _wood(Rect2(462,571,159,10),Color("a17b51"))
	for x in [485,514,543,572]:
		draw_rect(Rect2(x,490,18,23),Color("a29067")); draw_rect(Rect2(x+5,482,8,10),Color("759287"))
	_wood(Rect2(470,514,143,7)); _wood(Rect2(470,558,143,7))
	for y in [390,620]: _wood(Rect2(40,y,644,15),Color("8e7250"))
	# Continuous excavation silhouette, with irregular earth boundary instead of cubes.
	draw_rect(Rect2(0,650,720,267),Color("3f3631"))
	for i in range(48):
		var p = Vector2((i*113)%720,658+(i*43)%245)
		draw_line(p,p+Vector2(20+(i%3)*8,5),Color("51443a"),2)
	var edge = 302+sim.dig_count*54
	draw_rect(Rect2(56,714,edge-56,145),Color("2d2a2a"))
	var cut = PackedVector2Array([Vector2(edge-10,714),Vector2(edge+6,734),Vector2(edge-1,763),Vector2(edge+11,799),Vector2(edge-8,827),Vector2(edge,859),Vector2(56,859),Vector2(56,714)])
	draw_colored_polygon(cut,Color("302e2b"))
	for x in range(62,edge-8,95):
		_wood(Rect2(x,718,9,133),Color("665039")); _wood(Rect2(x,715,90,10),Color("806443"))
	_wood(Rect2(56,850,edge-56,10),Color("72604a"))
	_wood(Rect2(169,810,44,39),Color("70543a")); _wood(Rect2(225,819,30,30),Color("715a3f"))
	draw_line(Vector2(edge+11,735),Vector2(edge+28,719),Color("cebd95"),3)
	draw_arc(Vector2(edge+24,738),25,0,TAU,24,Color("a7936a"),2)
	draw_string(font,Vector2(edge+10,780),"굴착",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("cbb583"))
	# Stairwell is a visible continuous route; closed hatch blocks basement access.
	for top in [390,620]:
		var bottom = top+230
		draw_rect(Rect2(71,top-4,49,234),Color("302e29"))
		for y in range(top+12,bottom,20):
			draw_line(Vector2(76,y),Vector2(118,y+5),Color("a38a62"),5)
		draw_line(Vector2(76,top),Vector2(76,bottom),Color("826e51"),4)
		draw_line(Vector2(118,top),Vector2(118,bottom),Color("826e51"),4)
	if sim.hatch_open: _wood(Rect2(120,589,10,36),Color("b89969"))
	else: _wood(Rect2(71,615,55,12),Color("b89969"))
	for i in range(3):
		var p: Vector2 = lights[i].position
		draw_line(p-Vector2(0,22),p,Color("362c26"),4)
		draw_rect(Rect2(p-Vector2(7,1),Vector2(14,21)),Color("a38550"))
		draw_rect(Rect2(p-Vector2(4,-2),Vector2(8,12)),Color("ffd38d") if sim.lamps[i] else Color("4b4540"))
	# Small CC0 foliage details from the downloaded bundle.
	for x in [12,688]:
		draw_texture_rect_region(tiles,Rect2(x,592,32,32),Rect2(0,64,16,16))
	for i in range(sim.guests.size()):
		_actor(sim.guests[i],Color("c6b292") if i == 0 else Color("aa8083"),sim.guests[i].name)
		if selected_guest == i: draw_arc(sim.guests[i].pos+Vector2(0,-20),36,0,TAU,32,Color("bcccab"),2)
	if sim.hired: _actor(sim.staff,Color("9cb6b0"),"직원 · 확인 중" if sim.staff_investigation>0 else "직원")
	_actor(sim.owner,Color("d6be88"),"주인",true)
	if sim.noise_age < 1.4:
		var alpha = 1.0-sim.noise_age/1.4
		draw_arc(sim.noise_origin+Vector2(0,-20),24+sim.noise_age*95,0,TAU,40,Color(0.9,0.65,0.33,alpha),2)
	if sim.digging:
		draw_rect(Rect2(sim.owner.pos-Vector2(28,83),Vector2(56,6)),Color("373d3c"))
		draw_rect(Rect2(sim.owner.pos-Vector2(28,83),Vector2(56*sim.dig_work/4,6)),Color("d9be7c"))

func _verify_inputs() -> void:
	# These checks dispatch pointer events through Godot's real Control routing.
	await get_tree().process_frame
	save_path = "user://input-test-only.json"
	var failures = 0
	for key in ["pause","pause","secondary"]:
		var b: Button = buttons[key]
		for pressed in [true,false]:
			var ev = InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed
			ev.position = b.get_global_rect().get_center(); get_viewport().push_input(ev,true)
			await get_tree().process_frame
	for i in range(70): sim.tick(0.1)
	if not sim.hired: failures += 1; push_error("Touch hire did not execute")
	await _test_tap(Vector2(96,620))
	await _test_tap(buttons.primary.get_global_rect().get_center())
	for i in range(60): sim.tick(0.1)
	if not sim.hatch_open: failures += 1; push_error("Hatch selection failed")
	await _test_tap(Vector2(320,760))
	await _test_tap(buttons.primary.get_global_rect().get_center())
	for i in range(120): sim.tick(0.1)
	if sim.dig_count != 1: failures += 1; push_error("Dig selection did not create passage")
	sim.paused = true
	var saved_coins = sim.coins
	_save(); sim.coins = 0; _load_save()
	if sim.coins != saved_coins or sim.dig_count != 1 or not sim.hired:
		failures += 1; push_error("Save/load lost progression")
	DirAccess.remove_absolute(save_path)
	print("SIDEVIEW INPUT CHECKS: ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)

func _test_tap(p: Vector2) -> void:
	for pressed in [true,false]:
		var ev = InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressed
		ev.position = p; get_viewport().push_input(ev,true)
		await get_tree().process_frame
