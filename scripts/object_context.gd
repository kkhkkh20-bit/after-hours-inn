extends CanvasLayer
## Object-local actions. There is no persistent action toolbar.
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

func label_(text_: String,size_: int) -> Label:
	var l=Label.new(); l.text=text_; l.add_theme_font_override("font",host.episode_font()); l.add_theme_font_size_override("font_size",size_)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.mouse_filter=Control.MOUSE_FILTER_IGNORE; l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; return l

func setup(owner_) -> void:
	host=owner_; layer=10
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	var header=ColorRect.new(); header.color=Color(0.035,0.065,0.085,0.90); header.position=Vector2(12,10); header.size=Vector2(696,102); header.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(header)
	var name_=label_("문 닫은 뒤",26); name_.position=Vector2(24,17); name_.size=Vector2(660,40); name_.autowrap_mode=TextServer.AUTOWRAP_OFF; root.add_child(name_)
	stats=label_("",21); stats.position=Vector2(24,66); stats.size=Vector2(670,34); root.add_child(stats)
	panel=PanelContainer.new(); root.add_child(panel); panel.custom_minimum_size.x=268; panel.size.x=268
	var s=StyleBoxFlat.new(); s.bg_color=Color("162930"); s.border_color=Color("b89d6e"); s.set_border_width_all(2); s.set_corner_radius_all(12)
	s.content_margin_left=10; s.content_margin_right=10; s.content_margin_top=10; s.content_margin_bottom=10; panel.add_theme_stylebox_override("panel",s)
	column=VBoxContainer.new(); column.add_theme_constant_override("separation",7); panel.add_child(column); panel.hide()

func open(type_: String,id_: String="",detail_: String="") -> void:
	kind=type_; target=id_; detail=detail_; controls.clear()
	for c in column.get_children(): column.remove_child(c); c.queue_free()
	title_label=label_(host.context_title(kind,target),23); title_label.custom_minimum_size.x=240; title_label.autowrap_mode=TextServer.AUTOWRAP_OFF; column.add_child(title_label)
	if detail!="":
		var note=label_(detail,19); note.custom_minimum_size.x=240; column.add_child(note)
	for entry in host.context_items(kind,target):
		var b=Button.new(); b.text=entry[1]; b.custom_minimum_size=Vector2(248,76); b.focus_mode=Control.FOCUS_NONE
		b.disabled=entry.size()>2 and not entry[2]
		b.add_theme_font_override("font",host.episode_font()); b.add_theme_font_size_override("font_size",23)
		var normal=StyleBoxFlat.new(); normal.bg_color=Color("633c38" if entry[0]=="kill" else ("354b58" if entry[0]=="sleep" else "34473f")); normal.set_corner_radius_all(7); b.add_theme_stylebox_override("normal",normal)
		var press=StyleBoxFlat.new(); press.bg_color=Color("8a6f45"); press.set_corner_radius_all(7); b.add_theme_stylebox_override("pressed",press)
		b.pressed.connect(_perform.bind(entry[0])); column.add_child(b); controls[entry[0]]=b
	var close_=Button.new(); close_.text="닫기"; close_.custom_minimum_size.y=64; close_.add_theme_font_override("font",host.episode_font()); close_.pressed.connect(close); column.add_child(close_)
	panel.reset_size(); panel.size=Vector2(268,0); panel.show(); refresh()

func _perform(action: String) -> void:
	var k=kind; var id_=target; close(); host.context_action(k,id_,action)

func close() -> void:
	panel.hide(); kind=""; target=""

func refresh() -> void:
	stats.text=host.context_stats()
	if not panel.visible: return
	var at: Vector2=host.context_anchor(kind,target)
	var viewport=host.get_viewport().get_visible_rect().size
	var x=at.x+32
	if x+panel.size.x>viewport.x-12: x=at.x-panel.size.x-32
	panel.position=Vector2(clampf(x,12,maxf(12,viewport.x-panel.size.x-12)),clampf(at.y-panel.size.y*0.42,200,maxf(200,viewport.y-panel.size.y-20)))

func blocks(point: Vector2) -> bool:
	return point.y<152 or (panel.visible and panel.get_global_rect().has_point(point))
