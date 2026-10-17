extends CanvasLayer
var host
var rules
var root: Control
var panel: PanelContainer
var scrim: ColorRect
var heading: Label
var body_label: Label
var options: VBoxContainer
var status: Label
var journal: Button
var fullscreen: Button
var close_button: Button
var last_key=""
var opened=false
var feedback=""
var ending_shown=false
var notice: Label
var last_notice=""
var notice_until=0

func label_(text_: String, size_: int) -> Label:
	var l=Label.new(); l.text=text_; l.add_theme_font_override("font",host.episode_font())
	l.add_theme_font_size_override("font_size",size_); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func button_(text_: String, call_: Callable) -> Button:
	var b=Button.new(); b.text=text_; b.custom_minimum_size.y=64; b.add_theme_font_override("font",host.episode_font())
	b.add_theme_font_size_override("font_size",21); b.focus_mode=Control.FOCUS_NONE; b.pressed.connect(call_)
	return b

func setup(owner_, campaign) -> void:
	host=owner_; rules=campaign; layer=20
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	status=label_("",20); root.add_child(status); status.position=Vector2(20,119); status.size=Vector2(560,32)
	notice=label_("",19); root.add_child(notice); notice.position=Vector2(20,163); notice.size=Vector2(440,80)
	journal=button_("장부",open); root.add_child(journal); journal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	journal.position=Vector2(600,160); journal.size=Vector2(100,64)
	fullscreen=button_("전체화면",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	root.add_child(fullscreen); fullscreen.position=Vector2(488,160); fullscreen.size=Vector2(104,64)
	scrim=ColorRect.new(); root.add_child(scrim); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.color=Color(0,0,0,0.38); scrim.mouse_filter=Control.MOUSE_FILTER_STOP; scrim.hide()
	panel=PanelContainer.new(); root.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=22; panel.offset_right=-22; panel.offset_top=205; panel.offset_bottom=-170
	var s=StyleBoxFlat.new(); s.bg_color=Color("101e25"); s.set_corner_radius_all(18)
	s.content_margin_left=24; s.content_margin_right=24; s.content_margin_top=24; s.content_margin_bottom=24; panel.add_theme_stylebox_override("panel",s)
	var column=VBoxContainer.new(); column.add_theme_constant_override("separation",20); panel.add_child(column)
	heading=label_("",30); column.add_child(heading)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	body_label=label_("",23); scroll.add_child(body_label)
	options=VBoxContainer.new(); options.add_theme_constant_override("separation",10); column.add_child(options)
	close_button=button_("닫기 · 영업 계속",close); column.add_child(close_button)
	panel.hide(); refresh()

func open() -> void:
	opened=true; scrim.show(); panel.show(); host.episode_pause(true); last_key=""; refresh()

func close() -> void:
	if not rules.data.briefed or (rules.data.ending!="" and not rules.data.freeplay): return
	opened=false; panel.hide(); scrim.hide(); host.episode_pause(false)

func perform(action: String) -> void:
	if action=="retry": host.get_tree().reload_current_scene(); return
	var result: Dictionary=rules.choose(action,host.episode_facts())
	feedback=result.get("message","")
	if result.ok:
		host.episode_coins(int(result.get("coins",0)))
		feedback=""; close()
	last_key=""; refresh()

func refresh() -> void:
	var facts: Dictionary=host.episode_facts()
	var current: String=host.episode_notice()
	if current!=last_notice:
		last_notice=current; notice_until=Time.get_ticks_msec()+3200
	notice.text=current if Time.get_ticks_msec()<notice_until else ""
	status.text="%s · 식사 %d/3 · 위험 %d%%" %[("자유 영업" if rules.data.freeplay else ("영업 결산" if rules.data.ending!="" else "남은 %d초" %maxi(0,int(240-rules.data.elapsed)))),facts.served,mini(100,int(facts.risk)+int(rules.data.risk))]
	close_button.visible=rules.data.briefed and (rules.data.ending=="" or rules.data.freeplay)
	journal.text="장부 !" if rules.pending() else "장부"
	journal.modulate=Color("f1bc76") if rules.pending() else Color.WHITE
	var width=host.get_viewport().get_visible_rect().size.x
	journal.position.x=width-120
	fullscreen.position.x=width-232
	if rules.data.ending!="" and not ending_shown and not rules.data.freeplay:
		ending_shown=true; open(); return
	if not opened: return
	heading.text=rules.title()
	body_label.text=rules.body(facts)+("

"+feedback if feedback!="" else "")
	var choices=rules.choices(); var key=JSON.stringify(choices)
	if key!=last_key:
		last_key=key
		for c in options.get_children(): c.free()
		for c in choices: options.add_child(button_(c[1],perform.bind(c[0])))
