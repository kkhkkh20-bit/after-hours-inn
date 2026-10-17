extends CanvasLayer
const Rules=preload("res://scripts/inn_sandbox.gd")
var host
var backend=preload("res://scripts/inn_kenney_backend.gd").new()
var active=false
var camera_pan=false
var pan_button: Button
var root: Control
var tray: PanelContainer
var launch: Button
var status: Label
var buttons={}
var ghost: Node3D
var ghost_key=""
var cell=Vector2i.ZERO
var error=""
var saved_paused=false
var last_point=Vector2(360,680)

func button(text_: String,parent: Node,callback: Callable) -> Button:
	var b=Button.new();b.text=text_;b.custom_minimum_size=Vector2(212,82);b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_override("font",host.episode_font());b.add_theme_font_size_override("font_size",22)
	var style=StyleBoxFlat.new();style.bg_color=Color("31443f");style.set_corner_radius_all(12);style.set_border_width_all(2);style.border_color=Color("5b7065")
	b.add_theme_stylebox_override("normal",style);var selected=style.duplicate();selected.bg_color=Color("6d5a39");selected.border_color=Color("e3bf76");b.add_theme_stylebox_override("pressed",selected)
	b.toggle_mode=true;b.pressed.connect(callback);parent.add_child(b);return b
func setup(h) -> void:
	host=h;backend.configure(h);add_child(backend);layer=27;root=Control.new();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	launch=button("건설",root,open);launch.position=Vector2(532,1248);launch.custom_minimum_size=Vector2(164,88);launch.size=Vector2(164,88);launch.toggle_mode=false
	tray=PanelContainer.new();tray.position=Vector2(12,1010);tray.size=Vector2(696,338);root.add_child(tray)
	var bg=StyleBoxFlat.new();bg.bg_color=Color("182a2bf5");bg.set_corner_radius_all(18);bg.set_content_margin_all(16);tray.add_theme_stylebox_override("panel",bg)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);tray.add_child(column)
	var row=HBoxContainer.new();column.add_child(row)
	var title=Label.new();title.text="건설";title.add_theme_font_override("font",h.episode_font());title.add_theme_font_size_override("font_size",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
	pan_button=button("화면 이동",row,toggle_camera_pan);pan_button.custom_minimum_size=Vector2(120,60);pan_button.add_theme_font_size_override("font_size",19)
	var rotate=button("회전",row,func():backend.quarter=(backend.quarter+1)%4;ghost_key="";preview(last_point));rotate.custom_minimum_size=Vector2(112,60);rotate.toggle_mode=false
	var remove=button("철거",row,func():choose("remove"));remove.custom_minimum_size=Vector2(112,60);remove.toggle_mode=false
	var done=button("완료",row,close);done.custom_minimum_size=Vector2(120,60);done.toggle_mode=false
	status=Label.new();status.add_theme_font_override("font",h.episode_font());status.add_theme_font_size_override("font_size",20);status.custom_minimum_size=Vector2(640,48);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);column.add_child(grid)
	for item in [["build:prison","감옥\n6닢 · 3×3"],["build:furnace","화로\n10닢 · 3×3"],["build:stash","창고\n4닢 · 3×3"],["build:refuge","은신처\n6닢 · 3×3"],["dig","한 칸 파기\n무료"],["shaft","비밀 입구\n3닢 · 지상"]]:
		var key=str(item[0]);buttons[key]=button(item[1],grid,func():choose(key))
		buttons[key].icon=icon(key);buttons[key].add_theme_constant_override("icon_max_width",34)
	tray.hide()
func blocks(point: Vector2) -> bool:
	return (tray.visible and tray.get_global_rect().has_point(point)) or (launch.visible and launch.get_global_rect().has_point(point))
func _process(_delta: float) -> void:
	if host==null:return
	if host.supplies.inventory!=null:host.supplies.update()
	launch.visible=not active and not host.journal.opened and not host.object_context.panel.visible
	if active and host.dig_mode=="":close()
	host.object_context.inn_button.visible=not active;host.object_context.owner_button.visible=not active
	if active:host.object_context.cancel_button.hide();host.object_context.task_label.hide()
	else:host.object_context.task_label.show()
	host.journal.goal.visible=not active;host.journal.notice.visible=not active
	if active:
		for label in host.world_hints:
			if is_instance_valid(label):label.visible=label==host.owner_beacon or label.get_meta("builder_label",false)
func open() -> void:choose("build:prison")
func choose(mode: String) -> void:
	if mode=="tunnel":mode="dig"
	var first=not active
	if first:
		host.object_context.close()
		saved_paused=host.sim.data.paused;host.Commands.cancel(host,true)
	camera_pan=false;pan_button.set_pressed_no_signal(false);active=true;host.sim.data.paused=true;host.object_context.close();host.dig_mode=mode;tray.show();launch.hide();host.comfort.say("건설 중 · 시간 정지 / 완료하면 운영 재개")
	if host.dig_cancel!=null:host.dig_cancel.hide()
	var target_layer="surface" if mode=="shaft" else "below"
	if first or host.view_layer!=target_layer:
		host.set_layer(target_layer)
		var at=Vector2(host.sim.data.player.pos) if host.sim.data.player.floor==1 else Vector2(16,-5)
		if mode=="shaft":at=Vector2(12,1)
		var desired=Vector3(at.x,0,at.y)+(Rules.OFFSET if mode!="shaft" else Vector3.ZERO)
		var base=host.focus_position();host.camera_offset=Vector2(desired.x-base.x,desired.z-base.z)
		host.camera.size=21;host.camera_focus=desired;host.camera.position=desired+host.camera_arm();host.camera.look_at(desired);host.template_camera.capture()
	host.mobile_scene.update()
	for key in buttons:buttons[key].set_pressed_no_signal(key==mode)
	preview(last_point)
func close() -> void:
	if not active:return
	active=false;host.dig_mode="";tray.hide()
	backend.selector.hide();ghost=null
	host.sim.data.paused=saved_paused
	host.comfort.say("건설 종료 · 시설을 눌러 관리하세요.")
	# Keep the camera exactly where building finished; no jump back to the owner.
	var at=host.camera_focus;var base=host.focus_position();host.camera_offset=Vector2(at.x-base.x,at.z-base.z)
	host.camera.position=at+host.camera_arm();host.camera.look_at(at);host.template_camera.capture()
func hit(point: Vector2) -> Variant:
	var y=.08 if host.dig_mode=="shaft" else Rules.OFFSET.y+.08
	return Plane(Vector3.UP,y).intersects_ray(host.camera.project_ray_origin(point),host.camera.project_ray_normal(point))
func preview(point: Vector2) -> void:
	if camera_pan:return
	if not active or blocks(point) or point.y<166:return
	last_point=point
	var at: Variant=hit(point)
	if at==null:return
	var local: Vector3=at-(Vector3.ZERO if host.dig_mode=="shaft" else Rules.OFFSET)
	cell=Vector2i(roundi(local.x),roundi(local.z));error=""
	var mode: String=host.dig_mode
	if mode.begins_with("build:"):error=Rules.placement_error(host.sim,mode.get_slice(":",1),cell)
	elif mode=="dig":
		if host.sim.data.cells.has(host.sim.cell_key(cell)):error="이미 열린 바닥입니다."
		else:
			var adjacent=false
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if host.sim.data.cells.has(host.sim.cell_key(cell+d)):adjacent=true
			if not adjacent:error="열린 바닥 옆 흙을 고르세요."
	elif mode=="shaft":error=shaft_error(Vector2(cell))
	elif mode=="remove":error=backend.removal_error(cell)
	status.text=error if error!="" else ("시설 터치로 철거 · 절반 환급" if mode=="remove" else "바닥 터치로 즉시 설치 · 화면 고정" if mode.begins_with("build:") or mode=="shaft" else "흙 터치로 한 칸 굴착 · 화면 고정")
	status.modulate=Color("edab91") if error!="" else Color("bee2b2")
	var key="%s:%s:%s" %[mode,cell,error]
	if is_instance_valid(ghost) and key==ghost_key:return
	ghost_key=key
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.4,.95,.65,.48) if error=="" else Color(1,.25,.2,.48);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost=backend.preview_model(mode,Vector3(cell.x,y_offset(),cell.y)+(Vector3.ZERO if mode=="shaft" else Rules.OFFSET),mat)

func y_offset() -> float:return .06
func shaft_error(at: Vector2) -> String:
	if not host.sim.surface_walkable(at):return "1층이나 마당의 빈 바닥을 고르세요."
	for e in host.sim.data.sandbox.entrances:
		if e.top.distance_to(at)<2:return "다른 입구와 너무 가깝습니다."
	return "공사비 3닢이 필요합니다." if host.sim.data.money<3 else ""
func place(point: Vector2) -> void:
	if camera_pan or blocks(point) or point.y<166:return
	preview(point)
	if error!="":host.sim.note(error);return
	var mode: String=host.dig_mode
	var okay=false
	if mode.begins_with("build:"):okay=backend.stamp(mode.get_slice(":",1),cell)
	elif mode=="dig":okay=Rules.dig_cell(host.sim,cell)
	elif mode=="remove":okay=backend.remove(cell)
	elif mode=="shaft":
		if shaft_error(Vector2(cell))=="":
			host.sim.data.money-=3;Rules.finish(host.sim,{"kind":"entrance","point":Vector2(cell),"cell":Rules.underground(Vector2(cell))});okay=true
	else:okay=preload("res://scripts/inn_excavation.gd").dig_to(host.sim,cell)
	if okay:
		host.sync_view(0);host.journal.refresh()
		if mode.begins_with("build:") or mode=="shaft":close()
		else:preview(point)

func icon(key: String) -> Texture2D:
	var shapes={
		"build:prison":"<path d='M7 8h34v34H7z M15 9v32m9-32v32m9-32v32M7 18h34'/>",
		"build:furnace":"<path d='M12 23h25v20H12z M22 5h11v18M9 43h31'/><path d='M20 35q-2-5 4-10q1 6 5 9q3 6-5 7q-7-1-4-6' fill='#e9b76c'/>",
		"build:stash":"<path d='M7 9h34v34H7z M7 25h34M18 9v16m12 0v18M7 38h34'/>",
		"build:refuge":"<path d='M7 14v29m34-29v29M7 34h34M12 23h29v11H12zM12 23v-8h9v8'/>",
		"dig":"<path d='M8 15q15-17 33 4M24 12L10 43'/>",
		"shaft":"<path d='M7 7h34v34H7zM19 12v27m10-27v27m-10-6h10m-10-9h10m-10-9h10'/>"}
	var svg='<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g fill="none" stroke="#dfc48d" stroke-width="3" stroke-linejoin="round">'+str(shapes.get(key,""))+'</g></svg>'
	var img=Image.new();img.load_svg_from_string(svg);return ImageTexture.create_from_image(img)

func toggle_camera_pan() -> void:
	camera_pan=not camera_pan;pan_button.set_pressed_no_signal(camera_pan)
	if camera_pan:
		backend.selector.hide();status.text="화면 이동 중 · 드래그 후 화면 이동 버튼을 다시 누르세요."
	else:
		host.camera_focus=host.focus_position()+Vector3(host.camera_offset.x,0,host.camera_offset.y)
		host.camera.position=host.camera_focus+host.camera_arm();host.camera.look_at(host.camera_focus);host.template_camera.capture()
		ghost_key="";preview(last_point)
