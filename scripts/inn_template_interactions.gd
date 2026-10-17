extends RefCounted
## Interactable signals route one selection through one live target.
var host
var nodes={}
var marker: ClickMarker
var marker_target=Vector2.ZERO
var marker_floor=0
var fading=false
var last_choice={}
func setup(h) -> void:
	host=h;marker=ClickMarker.new();marker.name="ClickDestination"
	var mesh=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=.3;ring.outer_radius=.43;ring.rings=16;ring.ring_segments=24;mesh.mesh=ring;mesh.position.y=.02
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("efcb7a");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.no_depth_test=true;mesh.material_override=mat;marker.add_child(mesh);marker.geometry=mesh;h.add_child(marker)
func dispatch(choice: Dictionary) -> void:
	var key=str(choice.kind)+":"+str(choice.id)
	if not nodes.has(key):
		var anchor=Node.new();host.add_child(anchor);var component=Interactable.new();anchor.add_child(component)
		component.interacted.connect(func():host._activate_selection_now(last_choice));nodes[key]=component
	var component: Interactable=nodes[key];component.enabled=true
	if choice.kind=="person":component.enabled=host.sim.data.people.has(str(choice.id)) and host.sim.data.people[str(choice.id)].state!="gone"
	last_choice=choice.duplicate(true);component.interact()
func destination(at: Vector2) -> void:
	marker_target=at;marker_floor=int(host.sim.data.player.floor);fading=false;marker.show_at(host.world_point(at,marker_floor,.08))
func update() -> void:
	if not marker.visible:return
	if not host.Selection.visible_floor(host,marker_floor):marker.hide();return
	if not fading and (host.sim.data.excavation.intent=="" or host.sim.data.player.pos.distance_to(marker_target)<.18):fading=true;marker.fade_out()
