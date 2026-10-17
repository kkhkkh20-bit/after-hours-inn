extends CanvasLayer
## All world actions use one fixed, scrollable local menu.
var host
var root: Control
var panel: PanelContainer
var column: VBoxContainer
var stats: Label
var controls: Dictionary={}
var kind=""
var target=""
var detail=""
var title_label: Label
var heading: Label
var anchor=Vector2.ZERO
var scroll: ScrollContainer
var task_label: Label
var cancel_button: Button
var top: Control
var next_live_refresh=0
var detail_label: Label
var inn_button: Button
var owner_button: Button
var fixed_header: HBoxContainer

func label_(text_: String,size_: int) -> Label:
	var l=Label.new();l.text=text_;l.add_theme_font_override("font",host.episode_font());l.add_theme_font_size_override("font_size",size_)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return l

func button_(text_: String,parent: Node,callback: Callable,height: float=88) -> Button:
	var b=Button.new();b.text=text_;b.custom_minimum_size=Vector2(0,height);b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_override("font",host.episode_font());b.add_theme_font_size_override("font_size",21)
	var style=StyleBoxFlat.new();style.bg_color=Color("314740");style.set_corner_radius_all(8);style.content_margin_left=12;style.content_margin_right=12
	b.add_theme_stylebox_override("normal",style)
	var press=style.duplicate();press.bg_color=Color("796344");b.add_theme_stylebox_override("pressed",press)
	b.pressed.connect(callback);parent.add_child(b);return b

func setup(owner_) -> void:
	host=owner_;layer=26
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	top=Control.new();top.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(top)
	var header=ColorRect.new();header.color=Color("14232bf2");header.position=Vector2(8,6);header.size=Vector2(704,150);header.mouse_filter=Control.MOUSE_FILTER_IGNORE;top.add_child(header)
	heading=label_("문 닫은 뒤",21);heading.position=Vector2(20,12);heading.size=Vector2(680,34);heading.autowrap_mode=TextServer.AUTOWRAP_OFF;top.add_child(heading)
	stats=label_("",20);stats.position=Vector2(250,12);stats.size=Vector2(450,34);stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;stats.autowrap_mode=TextServer.AUTOWRAP_OFF;top.add_child(stats)
	var bar=HBoxContainer.new();bar.position=Vector2(20,56);bar.add_theme_constant_override("separation",8);top.add_child(bar)
	for item in [["1층","surface"],["2층","rooms"],["3층","attic"],["지하","below"],["정지","pause"],["1배","speed"],["설정","system"]]:
		var value=str(item[1]);var b=button_(str(item[0]),bar,func():
			if host.builder.active:host.builder.close()
			var was_paused: bool=host.sim.data.paused
			close()
			if value=="system":open("system")
			elif value=="pause":host.sim.data.paused=not was_paused
			elif value=="speed":host.sim.data.speed=2 if host.sim.data.speed==1 else 1
			elif value=="all":host.set_layer(value)
			else:host.request_floor({"surface":0,"rooms":2,"attic":3,"below":1}[value]))
		b.custom_minimum_size=Vector2(88,88)
		b.add_theme_font_size_override("font_size",18)
		if value in ["surface","rooms","attic","below","all"]:controls["@view:"+value]=b
		if value=="pause":controls["@pause"]=b
		if value=="speed":controls["@speed"]=b
	inn_button=button_("여관 보기",top,func():host.builder.close();host.show_inn(),88);inn_button.position=Vector2(20,156);inn_button.size.x=210;controls["@inn"]=inn_button
	owner_button=button_("주인 찾기",top,func():host.builder.close();host.frame_owner(),88);owner_button.position=Vector2(244,156);owner_button.size.x=210;controls["@owner"]=owner_button
	task_label=label_("",19);task_label.position=Vector2(24,336);task_label.size=Vector2(490,34);top.add_child(task_label)
	cancel_button=button_("취소",top,func():close();host.context_action("owner","","stop"),88);cancel_button.position=Vector2(468,156);cancel_button.size.x=232;cancel_button.hide()
	panel=PanelContainer.new();root.add_child(panel);panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var s=StyleBoxFlat.new();s.bg_color=Color("162930");s.border_color=Color("b89d6e");s.set_border_width_all(2);s.set_corner_radius_all(12);s.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",s)
	var outer=VBoxContainer.new();outer.add_theme_constant_override("separation",10);panel.add_child(outer)
	fixed_header=HBoxContainer.new();fixed_header.add_theme_constant_override("separation",8);outer.add_child(fixed_header)
	title_label=label_("",23);fixed_header.add_child(title_label)
	var close_button=button_("닫기",fixed_header,close);close_button.custom_minimum_size.x=88
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
	column=VBoxContainer.new();column.add_theme_constant_override("separation",8);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	panel.hide()

func open(type_: String,id_: String="",detail_: String="") -> void:
	if type_ in ["person","conversation","actions","other"] and (not host.sim.data.people.has(id_) or host.sim.data.people[id_].state=="gone"):return
	if panel.visible:close()
	kind=type_;target=id_;detail=detail_;detail_label=null
	var persistent={}
	for key in controls:
		if str(key).begins_with("@"):persistent[key]=controls[key]
	var pause_control=controls.get("@pause");var speed_control=controls.get("@speed");controls=persistent
	if pause_control!=null:controls["@pause"]=pause_control
	if speed_control!=null:controls["@speed"]=speed_control
	anchor=host.context_anchor(kind,target)
	host.context_opened(kind)
	for c in column.get_children():column.remove_child(c);c.queue_free()
	title_label.text=host.context_title(kind,target)
	if detail!="":
		var note=label_(detail,22);note.custom_minimum_size.x=300;note.add_theme_color_override("font_color",Color("f4dbad"));column.add_child(note);detail_label=note
	draw_actions(host.context_items(kind,target))
	next_live_refresh=0
	panel.show();scroll.scroll_vertical=0
	call_deferred("place")
	refresh()

func draw_actions(entries: Array) -> void:
	for c in column.get_children():
		if c is Button:column.remove_child(c);c.queue_free()
	for key in controls.keys():
		if not str(key).begins_with("@"):controls.erase(key)
	for index in entries.size():
		var entry=entries[index];var action=str(entry[0]);var b=button_("",column,_perform.bind(action))
		b.set_meta("action",action);b.disabled=entry.size()>2 and not entry[2]
		var l=label_(str(entry[1]),21);l.name="Caption";b.add_child(l);l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);l.offset_left=12;l.offset_right=-12;l.offset_top=6;l.offset_bottom=-6;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		if index==0:
			var primary=b.get_theme_stylebox("normal").duplicate();primary.bg_color=Color("42644e");b.add_theme_stylebox_override("normal",primary)
		l.modulate=Color("939a96") if b.disabled else Color.WHITE
		controls[action]=b

func sync_live_actions(force: bool=false) -> void:
	if not panel.visible or kind not in ["contracts","questioning","prison","prison_roster","inmate","prison_overview","prison_policy","prison_settings","operations","comfort"]:return
	if not force and Time.get_ticks_msec()<next_live_refresh:return
	next_live_refresh=Time.get_ticks_msec()+250
	var entries: Array=host.context_items(kind,target)
	var before=[]
	for child in column.get_children():
		if child is Button:before.append(str(child.get_meta("action","")))
	var after=entries.map(func(row):return str(row[0]))
	if before!=after:
		if host.pointer.pressed or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):return
		var scroll_at=scroll.scroll_vertical;var old_position=panel.position
		draw_actions(entries);scroll.scroll_vertical=scroll_at
		call_deferred("reflow_live",old_position,kind,target)
	else:
		for row in entries:
			var b: Button=controls[str(row[0])];b.disabled=row.size()>2 and not row[2]
			var caption: Label=b.get_node("Caption");caption.text=str(row[1]);caption.modulate=Color("939a96") if b.disabled else Color.WHITE

func reflow_live(old_position: Vector2,expected_kind: String,expected_target: String) -> void:
	if not panel.visible or kind!=expected_kind or target!=expected_target:return
	place()
	var viewport=host.get_viewport().get_visible_rect().size
	panel.position=Vector2(clampf(old_position.x,12,maxf(12,viewport.x-panel.size.x-12)),clampf(old_position.y,390,maxf(170,viewport.y-panel.size.y-16)))

func place() -> void:
	var viewport=host.get_viewport().get_visible_rect().size
	var width=minf(620,viewport.x-24) if kind=="supplies" else minf(350,viewport.x*.70)
	column.custom_minimum_size.x=width-32
	var header_height=maxf(88,fixed_header.get_combined_minimum_size().y)+42
	var wanted=column.get_combined_minimum_size().y+header_height
	panel.size=Vector2(width,minf(wanted,maxf(280,viewport.y-400)))
	scroll.custom_minimum_size=Vector2(width-32,minf(wanted-header_height,maxf(180,viewport.y-400-header_height)))
	var x=(viewport.x-width)/2 if kind=="supplies" else anchor.x+34
	if kind!="supplies" and x+width>viewport.x-12:x=anchor.x-width-34
	panel.position=Vector2(clampf(x,12,maxf(12,viewport.x-width-12)),clampf(anchor.y-panel.size.y*.40,390,maxf(170,viewport.y-panel.size.y-16)))

func _perform(action: String) -> void:
	if not controls.has(action) or controls[action].disabled:return
	var now=Time.get_ticks_msec();var key=kind+":"+target+":"+action
	if key==host.comfort.last_action and now-host.comfort.last_action_at<300:return
	host.comfort.last_action=key;host.comfort.last_action_at=now
	var k=kind;var id_=target;close();host.context_action(k,id_,action)

func close() -> void:
	if panel.visible:host.context_closed(kind)
	panel.hide();kind="";target=""

func refresh() -> void:
	sync_live_actions()
	if panel.visible and detail_label!=null:
		if kind=="prison":detail_label.text=host.sim.Prison.summary(host.sim,target)
		elif kind=="prison_overview":detail_label.text=host.sim.Prison.overview(host.sim)
		elif kind=="inmate":detail_label.text=host.sim.Prison.inmate_summary(host.sim,target)
		elif kind=="contracts":detail_label.text=host.sim.Contracts.summary(host.sim)
		elif kind=="questioning":detail_label.text=host.sim.Contracts.questioning(host.sim,target)
	var viewport=host.get_viewport().get_visible_rect().size
	top.position.x=maxf(0,(viewport.x-720)/2)
	heading.text="%d일 · %s" %[int(host.sim.data.campaign.day) if host.Campaign.active(host.sim) else 1,host.view_name()] if host.Campaign.active(host.sim) else "문 닫은 뒤"
	if controls.has("@pause"):controls["@pause"].text="재개" if host.sim.data.paused else "정지"
	if controls.has("@speed"):controls["@speed"].text="%d배" %host.sim.data.speed
	for view in ["surface","rooms","attic","below","all"]:
		if controls.has("@view:"+view):controls["@view:"+view].modulate=Color("f5d79b") if host.view_layer==view else Color.WHITE
	stats.text="%d닢 · %s" %[host.sim.data.money,host.sim.calendar_text().get_slice(" · ",0).get_slice(" ",1)]
	top.visible=not ((host.journal!=null and host.journal.opened) or (host.episode_ui!=null and host.episode_ui.opened))
	owner_button.text="주인 찾기"
	inn_button.text="여관 운영 중" if host.inn_view else "여관 보기"
	var job: String=host.command_status()
	task_label.text=("진행: "+job) if job!="" else ("정문 → 접수 → 객실 / 식당 · 알바 자동 운영" if host.view_layer=="surface" else "객실·시설을 눌러 관리 · 주인 찾기로 직접 이동")
	cancel_button.visible=true;cancel_button.disabled=job==""
	cancel_button.text="취소 · 작업 중지" if job!="" else "취소"
	if panel.visible and kind in ["person","conversation","actions","other","inmate","questioning"]:
		if not host.sim.data.people.has(target) or host.sim.data.people[target].state=="gone" or (kind in ["inmate","questioning"] and host.sim.data.people[target].state!="captive"):close()

func blocks(point: Vector2) -> bool:
	return point.y<150 or (inn_button.visible and inn_button.get_global_rect().has_point(point)) or (owner_button.visible and owner_button.get_global_rect().has_point(point)) or (cancel_button.visible and cancel_button.get_global_rect().has_point(point)) or (panel.visible and panel.get_global_rect().has_point(point))
