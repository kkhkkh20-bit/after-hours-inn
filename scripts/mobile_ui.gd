extends CanvasLayer
## Landscape overview UI. All essential operations are exposed as buttons.
var host
var root: Control
var header: PanelContainer
var footer: PanelContainer
var alert_panel: PanelContainer
var zoom_box: VBoxContainer
var drawer: Control
var drawer_panel: PanelContainer
var sheet_body: Label
var sheet_buttons: VBoxContainer
var sheet_title: Label
var sheet: String=""
var hud: Label
var alert: Label
var target: Label
var progress: ProgressBar
var primary: Button
var secondary: Button
var floor_button: Button
var stop_button: Button
var pause_button: Button
var speed_button: Button
var controls: Dictionary={}
var primary_action: Callable
var secondary_action: Callable
var minimum_touch_height:=48.0

func text_node(text_: String, size_: int=20) -> Label:
	var label:=Label.new()
	label.text=text_
	label.add_theme_font_override("font",host.ui_font)
	label.add_theme_font_size_override("font_size",size_)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func style(color: Color) -> StyleBoxFlat:
	var value:=StyleBoxFlat.new()
	value.bg_color=color
	value.content_margin_left=12
	value.content_margin_right=12
	value.content_margin_top=8
	value.content_margin_bottom=8
	value.corner_radius_top_left=14
	value.corner_radius_top_right=14
	value.corner_radius_bottom_left=14
	value.corner_radius_bottom_right=14
	return value

func row(parent: Node) -> HBoxContainer:
	var box:=HBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	parent.add_child(box)
	return box

func make_button(parent: Node, text_: String, action: Callable, key: String="") -> Button:
	var value:=Button.new()
	value.text=text_
	value.custom_minimum_size=Vector2(0,minimum_touch_height)
	value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	value.add_theme_font_override("font",host.ui_font)
	value.add_theme_font_size_override("font_size",18)
	value.add_theme_stylebox_override("normal",style(Color("263d43")))
	value.add_theme_stylebox_override("pressed",style(Color("566b60")))
	value.add_theme_stylebox_override("disabled",style(Color("1b272c")))
	value.focus_mode=Control.FOCUS_NONE
	value.pressed.connect(action)
	parent.add_child(value)
	if key!="":controls[key]=value
	return value

func place(control: Control, parent: Control, anchors: Vector4, offsets: Vector4) -> void:
	parent.add_child(control)
	control.anchor_left=anchors.x
	control.anchor_top=anchors.y
	control.anchor_right=anchors.z
	control.anchor_bottom=anchors.w
	control.offset_left=offsets.x
	control.offset_top=offsets.y
	control.offset_right=offsets.z
	control.offset_bottom=offsets.w

func make_panel(parent: Control, anchors: Vector4, offsets: Vector4) -> PanelContainer:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",style(Color(0.035,0.065,0.085,0.96)))
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	place(panel,parent,anchors,offsets)
	return panel

func setup(owner_) -> void:
	host=owner_
	root=Control.new()
	add_child(root)
	root.anchor_left=0
	root.anchor_right=1
	root.anchor_bottom=1
	root.offset_left=0
	root.offset_right=0
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header=make_panel(root,Vector4(0,0,1,0),Vector4(12,10,-12,74))
	var top:=HBoxContainer.new()
	header.add_child(top)
	var top_row:=row(top)
	top_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top_row.add_child(text_node("문 닫은 뒤  0.9",22))
	pause_button=make_button(top_row,"정지",func():host.sim.data.paused=not host.sim.data.paused,"pause")
	pause_button.custom_minimum_size.x=100
	pause_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	speed_button=make_button(top_row,"1배",func():host.sim.data.speed=1 if host.sim.data.speed==3 else 3,"speed")
	speed_button.custom_minimum_size.x=90
	speed_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	hud=text_node("",18)
	hud.custom_minimum_size.x=420
	top.add_child(hud)
	alert_panel=make_panel(root,Vector4(0,0,1,0),Vector4(12,82,-500,126))
	alert=text_node("바닥을 탭해 이동하고 손님을 탭해 선택한다.",18)
	alert.max_lines_visible=1
	alert_panel.add_child(alert)
	footer=make_panel(root,Vector4(0,1,1,1),Vector4(12,-128,-12,-10))
	var bottom:=VBoxContainer.new()
	bottom.add_theme_constant_override("separation",8)
	footer.add_child(bottom)
	target=text_node("",20)
	target.custom_minimum_size.y=26
	target.max_lines_visible=1
	bottom.add_child(target)
	progress=ProgressBar.new()
	progress.show_percentage=false
	progress.custom_minimum_size.y=8
	bottom.add_child(progress)
	var actions:=row(bottom)
	primary=make_button(actions,"접수대로 이동",func():
		if primary_action.is_valid():primary_action.call(),"primary")
	secondary=make_button(actions,"손님 선택",func():
		if secondary_action.is_valid():secondary_action.call(),"secondary")
	var utility:=actions
	floor_button=make_button(utility,"지하로 내려가기",func():host.sim.queue_floor(),"floor")
	stop_button=make_button(utility,"선택 해제",func():
		host.sim.cancel_work()
		host.sim.data.ops.selected="","stop")
	var navigation:=actions
	for tab in ["영업","관리","의뢰","메뉴"]:
		make_button(navigation,tab,open_sheet.bind(tab),"tab_"+tab)
	zoom_box=VBoxContainer.new()
	zoom_box.add_theme_constant_override("separation",8)
	place(zoom_box,root,Vector4(1,0,1,0),Vector4(-110,140,-12,520))
	make_button(zoom_box,"전체",func():host.set_layer("all"),"overview")
	make_button(zoom_box,"지상",func():host.set_layer("surface"),"surface_view")
	make_button(zoom_box,"지하",func():host.set_layer("below"),"below_view")
	make_button(zoom_box,"+",func():host.camera.size=maxf(8,host.camera.size-2),"zoom_in")
	make_button(zoom_box,"−",func():host.camera.size=minf(36,host.camera.size+2),"zoom_out")
	make_button(zoom_box,"주인",func():host.camera_offset=Vector2.ZERO;host.frame_owner(),"center")
	drawer=Control.new()
	place(drawer,root,Vector4(0,0,1,1),Vector4.ZERO)
	var dim:=ColorRect.new()
	dim.color=Color(0,0,0,0.45)
	place(dim,drawer,Vector4(0,0,1,1),Vector4.ZERO)
	dim.mouse_filter=Control.MOUSE_FILTER_STOP
	drawer_panel=make_panel(drawer,Vector4(0,0,1,1),Vector4(350,110,-350,-150))
	var sheet_layout:=VBoxContainer.new()
	sheet_layout.add_theme_constant_override("separation",12)
	drawer_panel.add_child(sheet_layout)
	var heading:=row(sheet_layout)
	sheet_title=text_node("",30)
	heading.add_child(sheet_title)
	make_button(heading,"닫기",close_sheet,"close").size_flags_horizontal=Control.SIZE_SHRINK_END
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	sheet_layout.add_child(scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	sheet_body=text_node("",20)
	content.add_child(sheet_body)
	sheet_buttons=VBoxContainer.new()
	sheet_buttons.add_theme_constant_override("separation",12)
	content.add_child(sheet_buttons)
	drawer.visible=false

func close_sheet() -> void:
	drawer.visible=false
	sheet=""

func command(name_: String, id: String="") -> void:
	close_sheet()
	host.sim.queue_command(name_,id)

func open_sheet(name_: String) -> void:
	sheet=name_
	drawer.visible=true
	sheet_title.text=name_
	for child in sheet_buttons.get_children():child.free()
	match sheet:
		"영업":
			var rooms:=row(sheet_buttons)
			make_button(rooms,"1호 배정",command.bind("room1"),"room1")
			make_button(rooms,"2호 배정",command.bind("room2"),"room2")
			make_button(sheet_buttons,"대기 손님 거절",command.bind("reject"),"reject")
			make_button(sheet_buttons,"접수대에서 식사 준비 / 집기",command.bind("prepare"),"prepare")
			var clean:=row(sheet_buttons)
			make_button(clean,"1호 청소",command.bind("clean1"),"clean1")
			make_button(clean,"2호 청소",command.bind("clean2"),"clean2")
		"관리":
			var cellar_controls:=row(sheet_buttons)
			make_button(cellar_controls,"지하 등불 켜기 / 끄기",func():host.sim.toggle_cellar_lamp(),"lamp")
			make_button(cellar_controls,"지하 덮개 열기 / 닫기",func():host.sim.toggle_hatch(),"hatch")
			make_button(sheet_buttons,"직원 고용 / 서빙 위임 전환",func():
				close_sheet()
				if host.sim.data.staff.hired:host.sim.toggle_staff()
				else:host.sim.queue_command("staff"),"staff")
			make_button(sheet_buttons,"접수대에서 도구 수리 · 2닢",command.bind("repair"),"repair")
			if host.sim.data.player.floor==1:
				make_button(sheet_buttons,"구금칸으로 이동" if host.sim.data.ops.built else "구금칸 설치 · 8닢",func():
					close_sheet()
					if host.sim.data.ops.built:host.sim.queue_move(host.sim.data.ops.cell)
					else:host.sim.queue_command("build"),"build")
			make_button(sheet_buttons,"직원에게 다가가 설명하기",command.bind("explain"),"explain")
		"의뢰":
			make_button(sheet_buttons,"의뢰 수락 / 보수 받기",command.bind("contract"),"contract")
			make_button(sheet_buttons,"의뢰 거절 / 손님 보호",command.bind("protect"),"protect")
			make_button(sheet_buttons,"경비 조사 허용",command.bind("inspect"),"inspect")
			make_button(sheet_buttons,"경비 뇌물 제안 · 12닢",command.bind("bribe"),"bribe")
		"메뉴":
			var saves:=row(sheet_buttons)
			make_button(saves,"저장",func():host.save_game(),"save")
			make_button(saves,"불러오기",func():host.load_game(),"load")
			make_button(sheet_buttons,"소리 켜기 / 끄기",func():host.muted=not host.muted,"sound")
			make_button(sheet_buttons,"직원 시야 표시 전환",func():host.show_vision=not host.show_vision,"vision")
			make_button(sheet_buttons,"선택 해제",func():host.sim.data.ops.selected="";close_sheet(),"deselect")
	refresh()

func refresh() -> void:
	var d: Dictionary=host.sim.data
	var minutes:=int(420+d.clock*6)
	hud.text="%d일 %02d:%02d · %d닢 · 미납 %d · %s" % [minutes/1440+1,(minutes%1440)/60,minutes%60,d.money,d.debt,{0:"1층",1:"지하",2:"2층"}.get(d.player.floor,"1층")]
	pause_button.text="계속" if d.paused else "정지"
	speed_button.text="%d배" % d.speed
	var busy: bool=not d.work.is_empty() or not d.dig.is_empty()
	var moving: bool=d.excavation.intent!=""
	floor_button.text="1층으로 내려가기" if d.player.floor==2 else ("1층으로 올라가기" if d.player.floor==1 else "지하로 내려가기")
	floor_button.disabled=busy or d.paused
	stop_button.text="이동 / 작업 중단" if busy or moving else "선택 해제"
	var id: String=host.Simulation.Intrigue.selected(host.sim)
	primary_action=Callable()
	secondary_action=Callable()
	primary.text="접수대로 이동"
	primary_action=func():host.sim.queue_move(host.Simulation.COUNTER)
	secondary.text="영업 관리"
	secondary_action=open_sheet.bind("영업")
	if d.player.floor==0:
		secondary.text="2층으로 올라가기"
		secondary_action=func():host.sim.queue_gallery()
	target.text="전체 보기 · 바닥 탭: 이동 / 화면 끌기: 둘러보기"
	if d.ops.drag!="":
		target.text="운반 중 · "+str(d.people[d.ops.drag].name)
		primary.text="내려놓기"
		primary_action=func():host.Simulation.Intrigue.drag_or_release(host.sim)
		secondary.text="구금하기" if d.ops.built else "구금칸 설치 · 8닢"
		secondary_action=func():host.sim.queue_command("cell")
	elif d.player.carry!="":
		var meal_guest: String=d.orders[d.player.carry].guest
		target.text="식사 운반 · "+str(d.people[meal_guest].name)
		primary.text="주문 손님에게 전달"
		primary_action=func():host.sim.queue_command("deliver",meal_guest)
	elif id!="":
		var person: Dictionary=d.people[id]
		var states: Dictionary={"waiting":"접수 대기","entering":"입실 중","staying":"투숙","down":"기절","captive":"구금","escaping":"탈출","leaving":"퇴장"}
		target.text="%s · %s" % [person.name,states.get(person.state,person.state)]
		primary.text="다가가 식사 전달" if d.player.carry!="" else "다가가기"
		primary_action=func():host.sim.queue_command("deliver" if host.sim.data.player.carry!="" else "approach",id)
		secondary.text="제압 시도 · 2초"
		secondary_action=func():host.sim.queue_command("subdue",id)
		if person.state in ["down","captive"]:
			primary.text="끌고 가기" if person.state=="down" else "석방하기"
			primary_action=func():host.sim.queue_command("drag",id)
			secondary.text="선택 해제"
			secondary_action=func():host.sim.data.ops.selected=""
	elif d.player.floor==2:
		target.text="2층 복도 · 난간 아래로 1층 홀이 보인다"
		primary.text="반대편 복도로 이동"
		primary_action=func():host.sim.queue_move(Vector2(-5.25,-4.25))
	elif d.player.floor==1:
		target.text="%s · 내구도 %d / 24" % ["삽" if d.stealth.quiet else "곡괭이",int(d.excavation.durability)]
		primary.text="가까운 흙벽 파기"
		primary_action=func():host.sim.dig_nearest()
		secondary.text="곡괭이로 전환" if d.stealth.quiet else "조용한 삽으로 전환"
		secondary_action=func():host.sim.toggle_dig_mode()
	primary.disabled=busy or d.paused
	secondary.disabled=busy or d.paused
	progress.visible=busy
	if not d.dig.is_empty():
		progress.value=100*(1-d.dig.remaining/(10.0 if d.dig.get("quiet",false) else 4.0))
		target.text="직접 굴착 중 · %.1f초 남음" % d.dig.remaining
	elif not d.work.is_empty():
		var total:=2.0 if d.work.type=="subdue" else (4.0 if d.work.type=="clean" else 3.0)
		progress.value=100*(1-d.work.remaining/total)
		target.text="작업 중 · %.1f초 남음" % d.work.remaining
	elif moving:target.text="이동 중 · 도착하면 선택한 행동 수행"
	alert.text="바닥 탭으로 이동 · 아래 버튼으로 행동"
	if not d.logs.is_empty():alert.text=d.logs.back().text
	if d.stealth.phase!="idle":alert.text="직원이 지하를 확인하는 중 · 소음 %.1f / 경계 %d" % [d.noise,int(d.stealth.suspicion)]
	if d.ops.inspector.state!="idle":alert.text="경비 상태: %s · 신고 %d건 / 의뢰 창에서 대응" % [inspection_label(d.ops.inspector.state),int(d.ops.reports)]
	if drawer.visible:refresh_sheet()

func refresh_sheet() -> void:
	var d: Dictionary=host.sim.data
	match sheet:
		"영업":
			var lines: Array[String]=[host.room_text(1),host.room_text(2),"", "접수 대기 %d명" % host.sim.waiting().size()]
			for id in host.sim.waiting():lines.append(str(d.people[id].name)+" · "+str(d.people[id].trait))
			lines.append("버튼을 누르면 접수대나 객실까지 걸어가 처리한다.")
			lines.append("식사를 든 뒤 손님을 선택하고 전달 버튼을 누른다.")
			sheet_body.text="\n".join(lines)
			controls.prepare.text="징수원 세금 납부 · 8닢" if d.collector else "접수대에서 식사 준비 / 집기"
		"관리":
			sheet_body.text="직원: %s\n고용 준비금 3닢 / 하루 임금 4닢\n도구 내구도 %d / 24\n직원 경계 %d · 확인 기억 %d\n\n고용과 수리는 접수대로 이동 후 처리한다." % ["서빙 위임 중" if d.staff.hired and d.staff.delegated else ("위임 해제" if d.staff.hired else "미고용"),int(d.excavation.durability),int(d.stealth.suspicion),int(d.stealth.memory)]
			sheet_body.text+="\n\n예정 납기\n%s 임금\n%s 임대료\n%s 세금" % [host.when_text(d.dues.wage),host.when_text(d.dues.rent),host.when_text(d.dues.tax)]
		"의뢰":
			var c: Dictionary=d.ops.contract
			var names: Dictionary={"offered":"수상한 의뢰 도착","active":"억류 의뢰 진행","ready":"조건 달성 · 보수 수령 가능","paid":"보수 수령 완료","protected":"손님 보호","declined":"의뢰 거절","failed":"의뢰 실패"}
			sheet_body.text="%s\n180초 안에 지하 구금 30초 / 보수 24닢\n" % names.get(c.state,c.state)
			if c.target!="":sheet_body.text+="대상: %s\n억류 %.0f / 30초 · 남은 %.0f초\n" % [d.people[c.target].name,c.held,maxf(0,c.deadline-d.clock)]
			sheet_body.text+="\n신고 %d건 / 경비: %s\n조사 허용·뇌물은 경비가 접수대에서 기다릴 때 사용한다." % [int(d.ops.reports),inspection_label(d.ops.inspector.state)]
		"메뉴":
			var lines: Array[String]=["세로 화면 · 클릭/탭 조작\n확대/축소는 화면의 + / − 버튼\n저장은 현재 기기에 보관된다.\n", "최근 기록"]
			for item in d.logs.slice(maxi(0,d.logs.size()-5)):lines.append("· "+str(item.text))
			sheet_body.text="\n".join(lines)

func blocks_point(point: Vector2) -> bool:
	if drawer.visible:return true
	for control in [header,footer,alert_panel,zoom_box]:
		if control.get_global_rect().has_point(point):return true
	return false

func inspection_label(state_: String) -> String:
	return str({"idle":"방문 없음","scheduled":"방문 예정","entering":"도착 중","waiting":"접수대 대기","search":"입구 조사","sweep":"지하 수색","return_below":"위층 복귀","leaving":"퇴장"}.get(state_,state_))
