extends MeshInstance3D
var stamp=""
func update_route(host) -> void:
	var d: Dictionary=host.sim.data
	var path: Array=d.excavation.path
	visible=host.comfort.routes and not path.is_empty() and host.Selection.visible_floor(host,d.player.floor)
	if not visible:return
	var key=str(d.player.floor)+":"+str(path)+":"+str(d.player.pos.snapped(Vector2(.1,.1)))
	if key==stamp:return
	stamp=key
	var m=ImmediateMesh.new();m.surface_begin(Mesh.PRIMITIVE_LINES)
	var from: Vector3=host.world_point(d.player.pos,d.player.floor,.16)
	for point in path:
		var to: Vector3=host.world_point(point,d.player.floor,.16)
		m.surface_add_vertex(from);m.surface_add_vertex(to);from=to
	m.surface_end();mesh=m
	if material_override==null:
		var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("d2c17e");mat.no_depth_test=false;material_override=mat
