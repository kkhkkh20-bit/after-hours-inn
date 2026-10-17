extends RefCounted
## Portrait overview: stable camera, readable zones, touch-only operation.
var host
var layer: CanvasLayer
var root: Control
var pins: Dictionary={}
var quiet_hidden: Dictionary={}
func setup(h) -> void:
	host=h;layer=CanvasLayer.new();layer.layer=23;host.add_child(layer)
	root=Control.new();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(root)
	for key in ["arrival","front","reception","dining"]:
		var b=Button.new();b.custom_minimum_size=Vector2(166,64);b.size=Vector2(166,64);b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_override("font",host.episode_font());b.add_theme_font_size_override("font_size",20)
		var style=StyleBoxFlat.new();style.bg_color=Color("243d3bf2");style.border_color=Color("b8a478");style.set_border_width_all(2);style.set_corner_radius_all(10);style.set_content_margin_all(10);b.add_theme_stylebox_override("normal",style)
		b.pressed.connect(activate.bind(key));root.add_child(b);pins[key]=b
func activate(key: String) -> void:
	var s=host.sim
	if key=="arrival":host.comfort.act("","","operations");return
	if key in ["front","reception"]:
		var waiting=s.waiting()
		if not waiting.is_empty():host.activate_selection({"kind":"person","id":str(waiting[0])});return
		host.object_context.open("counter");return
	var guests=s.data.people.values().filter(func(p):return p.state=="dining")
	if not guests.is_empty():host.activate_selection({"kind":"person","id":guests[0].id})
	else:host.object_context.open("automation","","식사·접수·청소는 알바가 자동으로 처리합니다.")
func blocks(point: Vector2) -> bool:
	if not root.visible:return false
	for b in pins.values():
		if b.visible and b.get_global_rect().has_point(point):return true
	return false
func update() -> void:
	var s=host.sim
	root.visible=host.inn_view and host.view_layer=="surface" and not host.object_context.panel.visible and not host.journal.opened and not host.episode_ui.opened
	var arrival=s.data.people.values().filter(func(p):return p.state=="arriving").size()
	var meals=s.data.people.values().filter(func(p):return p.state=="dining").size()
	pins.arrival.text="마당 · %d명 도착" %arrival
	pins.front.text="여관 정문"
	pins.reception.text="접수 · %d명 문의" %s.waiting().size()
	pins.dining.text="식당 · %d명 식사" %meals
	var points={"arrival":Vector2(22.25,5),"front":Vector2(.25,6.5),"reception":Vector2(-1.7,-2.7),"dining":Vector2(-13,1)}
	if root.visible and not host.pointer.pressed:
		var viewport=host.get_viewport().get_visible_rect().size
		for key in pins:
			var pos=host.camera.unproject_position(host.world_point(points[key],0,1))
			pins[key].position=Vector2(clampf(pos.x-83,12,viewport.x-178),clampf(pos.y-32,328,viewport.y-90))
	# Facility prose is available on selection; the map is not covered by labels.
	if host.view_layer=="surface":
		for label in host.world_hints:
			if is_instance_valid(label):
				if not quiet_hidden.has(label.get_instance_id()):quiet_hidden[label.get_instance_id()]={"node":label,"visible":label.visible}
				label.visible=label==host.owner_beacon
		for id in host.labels:
			if not is_instance_valid(host.labels[id]):continue
			var p: Dictionary=s.data.people[id]
			var selected=host.object_context.panel.visible and host.object_context.target==id
			host.labels[id].visible=selected and p.state!="gone"
			host.labels[id].text=str(p.name);host.labels[id].pixel_size=.012
	else:
		for row in quiet_hidden.values():
			if is_instance_valid(row.node):row.node.visible=row.visible
		quiet_hidden.clear()
