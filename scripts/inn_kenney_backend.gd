extends "res://third_party/kenney_city_builder/builder.gd"
## Reuse Kenney's MeshLibrary, preview instantiation, placement and demolition.
const Rules=preload("res://scripts/inn_sandbox.gd")
const KEYS=["prison","furnace","stash","refuge"]
var host
var quarter=0
class Sound:
	var host
	func play(_path: String,_volume: float=-20) -> void:
		if host.room_chime!=null and not host.muted:host.room_chime.play()
func configure(h) -> void:
	host=h;Audio=Sound.new();Audio.host=h
	gridmap=GridMap.new();gridmap.cell_size=Vector3.ONE;gridmap.cell_center_x=false;gridmap.cell_center_y=false;gridmap.cell_center_z=false;add_child(gridmap);gridmap.hide()
	selector=Node3D.new();add_child(selector);selector_container=Node3D.new();selector.add_child(selector_container)
	view_camera=h.camera;cash_display=Label.new();add_child(cash_display);cash_display.hide()
	for key in KEYS:
		var model=Node3D.new();h.add_child(model);var old=h.world_root;h.world_root=model;preload("res://scripts/inn_facility_art.gd").build(h,key);h.world_root=old
		own(model,model)
		var packed=PackedScene.new();packed.pack(model);model.free()
		var resource=Structure.new();resource.model=packed;resource.price=int(Rules.TYPES[key].cost);structures.append(resource)
	for action in ["build","demolish"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
func own(node: Node,owner_: Node) -> void:
	for child in node.get_children():child.owner=owner_;own(child,owner_)
func _ready() -> void:
	super._ready();set_process(false);selector.hide()
func _process(_delta: float) -> void:pass
func update_cash() -> void:pass # The inn HUD owns cash formatting.
func sync_registry() -> void:
	gridmap.clear()
	for f in host.sim.data.sandbox.facilities:
		var i=KEYS.find(str(f.type))
		if i>=0:
			var basis_=Basis(Vector3.UP,int(f.get("rotation",0))*PI/2)
			gridmap.set_cell_item(Vector3i(roundi(f.pos.x),0,roundi(f.pos.y)),i,gridmap.get_orthogonal_index_from_basis(basis_))
func stamp(type_: String,cell: Vector2i) -> bool:
	var error=Rules.placement_error(host.sim,type_,cell)
	if error!="":host.sim.note(error);return false
	sync_registry();index=KEYS.find(type_);map.cash=host.sim.data.money
	Input.action_press("build");super.action_build(Vector3i(cell.x,0,cell.y));Input.action_release("build")
	host.sim.data.money=map.cash;Rules.finish(host.sim,{"kind":type_,"cell":cell})
	host.sim.data.sandbox.facilities.back().rotation=quarter
	return true
func removal_error(cell: Vector2i) -> String:
	var f=Rules.facility_at(host.sim,Vector2(cell))
	if f.is_empty():return "철거할 시설을 누르세요."
	if f.get("occupant","")!="" or not f.get("members",[]).is_empty():return "사용 중인 시설은 비워야 철거할 수 있어요."
	return ""
func remove(cell: Vector2i) -> bool:
	var error=removal_error(cell)
	if error!="":host.sim.note(error);return false
	var f=Rules.facility_at(host.sim,Vector2(cell));sync_registry()
	Input.action_press("demolish");super.action_demolish(Vector3i(roundi(f.pos.x),0,roundi(f.pos.y)));Input.action_release("demolish")
	host.sim.data.money+=int(Rules.TYPES[f.type].cost)/2;host.sim.data.sandbox.facilities.erase(f);host.sim.data.sandbox.revision+=1
	host.comfort.say("시설 철거 · 공사비 절반 환급");return true
func preview_model(mode: String,at: Vector3,mat: Material) -> Node3D:
	selector.show();selector.position=at;selector.rotation.y=quarter*PI/2
	selector_container.visible=mode.begins_with("build:")
	if selector_container.visible:
		index=KEYS.find(mode.get_slice(":",1));super.update_structure()
		for child in selector_container.find_children("*","MeshInstance3D",true,false):child.material_override=mat
	if not selector.has_node("Footprint"):
		var footprint=MeshInstance3D.new();footprint.name="Footprint";var mesh=BoxMesh.new();footprint.mesh=mesh;selector.add_child(footprint)
	var footprint=selector.get_node("Footprint");footprint.mesh.size=Vector3(2.9 if mode.begins_with("build:") or mode=="remove" else .94,.035,2.9 if mode.begins_with("build:") or mode=="remove" else .94);footprint.position.y=.12;footprint.material_override=mat
	return selector
