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
	for item in [["식당","surface"],["객실","rooms"],["지하","below"],["전체","all"],["정지","pause"],["1배","speed"],["설정","system"]]:
		var value=str(item[1]);var b=button_(str(item[0]),bar,func():
			var was_paused: bool=host.sim.data.paused
			close()
			if value=="system":open("system")
			elif value=="pause":host.sim.data.paused=not was_paused
			elif value=="speed":host.sim.data.speed=2 if host.sim.data.speed==1 else 1
			else:host.set_layer(value))
		b.custom_minimum_size.x=88
		b.add_theme_font_size_override("font_size",18)
		if value=="pause":controls["@pause"]=b
		if value=="speed":controls["@speed"]=b
	task_label=label_("",19);task_label.position=Vector2(24,236);task_label.size=Vector2(490,34);top.add_child(task_label)
	cancel_button=button_("취소",top,func():close();host.context_action("owner","","stop"),64);cancel_button.position=Vector2(565,220);cancel_button.size.x=130;cancel_button.hide()
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
	kind=type_;target=id_;detail=detail_;
	var pause_control=controls.get("@pause");var speed_control=controls.get("@speed");controls.clear()
	if pause_control!=null:controls["@pause"]=pause_control
	if speed_control!=null:controls["@speed"]=speed_control
	anchor=host.context_anchor(kind,target)
	host.context_opened(kind)
	for c in column.get_children():column.remove_child(c);c.queue_free()
	title_label.text=host.context_title(kind,target)
	if detail!="":
		var note=label_(detail,22);note.custom_minimum_size.x=300;note.add_theme_color_override("font_color",Color("f4dbad"));column.add_child(note)
	for entry in host.context_items(kind,target):
		var action=str(entry[0]);var b=button_("",column,_perform.bind(action))
		b.disabled=entry.size()>2 and not entry[2]
		var l=label_(str(entry[1]),21);b.add_child(l);l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);l.offset_left=12;l.offset_right=-12;l.offset_top=6;l.offset_bottom=-6;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		if b.disabled:l.modulate=Color("939a96")
		controls[action]=b
	panel.show();scroll.scroll_vertical=0
	call_deferred("place")
	refresh()

func place() -> void:
	var viewport=host.get_viewport().get_visible_rect().size
	var width=minf(350,viewport.x*.70)
	column.custom_minimum_size.x=width-32
	var header_height=maxf(88,fixed_header.get_combined_minimum_size().y)+42
	var wanted=column.get_combined_minimum_size().y+header_height
	panel.size=Vector2(width,minf(wanted,maxf(280,viewport.y-300)))
	scroll.custom_minimum_size=Vector2(width-32,minf(wanted-header_height,maxf(180,viewport.y-300-header_height)))
	var x=anchor.x+34
	if x+width>viewport.x-12:x=anchor.x-width-34
	panel.position=Vector2(clampf(x,12,maxf(12,viewport.x-width-12)),clampf(anchor.y-panel.size.y*.40,170,maxf(170,viewport.y-panel.size.y-16)))

func _perform(action: String) -> void:
	if not controls.has(action) or controls[action].disabled:return
	var k=kind;var id_=target;close();host.context_action(k,id_,action)

func close() -> void:
	if panel.visible:host.context_closed(kind)
	panel.hide();kind="";target=""

func refresh() -> void:
	var viewport=host.get_viewport().get_visible_rect().size
	top.position.x=maxf(0,(viewport.x-720)/2)
	heading.text="%d일 · %s" %[int(host.sim.data.campaign.day) if host.Campaign.active(host.sim) else 1,host.view_name()] if host.Campaign.active(host.sim) else "문 닫은 뒤"
	if controls.has("@pause"):controls["@pause"].text="재개" if host.sim.data.paused else "정지"
	if controls.has("@speed"):controls["@speed"].text="%d배" %host.sim.data.speed
	stats.text="%d닢 · %s" %[host.sim.data.money,host.sim.calendar_text().get_slice(" · ",0).get_slice(" ",1)]
	top.visible=not ((host.journal!=null and host.journal.opened) or (host.episode_ui!=null and host.episode_ui.opened))
	var job: String=host.command_status()
	task_label.text=job;cancel_button.visible=job!=""
	if panel.visible and kind in ["person","conversation","actions","other"]:
		if not host.sim.data.people.has(target) or host.sim.data.people[target].state=="gone":close()

func blocks(point: Vector2) -> bool:
	return point.y<158 or (cancel_button.visible and cancel_button.get_global_rect().has_point(point)) or (panel.visible and panel.get_global_rect().has_point(point))
