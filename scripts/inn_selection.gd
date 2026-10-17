extends RefCounted
## Screen-space body capsules; direct hits beat expanded touch targets.
static func visible_floor(host,floor_: int) -> bool:
	if host.view_layer=="below":return floor_==1
	if host.view_layer=="rooms":return floor_==2
	if host.view_layer=="attic":return floor_==3
	if host.view_layer=="surface":return floor_==0
	return true

static func body(host,screen: Vector2,pos: Vector2,floor_: int,kind: String,id: String) -> Dictionary:
	if not visible_floor(host,floor_):return {}
	var at: Vector3=host.world_point(pos,floor_,1.0)
	if host.camera.is_position_behind(at):return {}
	var foot: Vector2=host.camera.unproject_position(host.world_point(pos,floor_,0.05))
	var head: Vector2=host.camera.unproject_position(host.world_point(pos,floor_,1.9))
	var projected_height: float=foot.distance_to(head)
	var radius: float=maxf(10.0,projected_height*0.20)
	var closest: Vector2=Geometry2D.get_closest_point_to_segment(screen,foot,head)
	var distance: float=screen.distance_to(closest)
	var name_rect=Rect2(head-Vector2(48,10),Vector2(96,24))
	var on_name=name_rect.has_point(screen)
	if host.view_layer=="surface" and kind=="person" and not (host.object_context.panel.visible and host.object_context.target==id):on_name=false
	var touch: bool=host.pointer.fingers.size()>0
	if distance>maxf(28 if touch else radius,radius) and not on_name:return {}
	return {"kind":kind,"id":id,"distance":minf(distance,screen.distance_to(head)) if on_name else distance,"body":distance<=radius,"direct":distance<=radius or on_name,"point":head.lerp(foot,0.5),"depth":host.camera.global_position.distance_to(at)}

static func candidates(host,screen: Vector2) -> Array:
	var result: Array=[]
	for id in host.sim.data.people:
		var p: Dictionary=host.sim.data.people[id]
		if p.state=="gone":continue
		var hit=body(host,screen,p.pos,p.floor,"person",id)
		if not hit.is_empty():result.append(hit)
	if host.sim.Sandbox.active(host.sim) and visible_floor(host,1):
		for f in host.sim.Prison.cells(host.sim):
			var world: Vector3=host.world_point(f.pos+Vector2(0,1.25),1,.25)
			var label=host.camera.unproject_position(world)
			if not host.camera.is_position_behind(world) and Rect2(label-Vector2(85,15),Vector2(170,30)).has_point(screen):result.append({"kind":"prison","id":f.id,"distance":0.0,"direct":true,"point":label,"depth":host.camera.global_position.distance_to(world)})
	var p: Dictionary=host.sim.data.player
	var hit=body(host,screen,p.pos,p.floor,"owner","")
	if not hit.is_empty():result.append(hit)
	if host.sim.data.staff.hired:
		p=host.sim.data.staff;hit=body(host,screen,p.pos,int(p.get("floor",0)),"staff","")
		if not hit.is_empty():result.append(hit)
	p=host.sim.data.ops.inspector
	if p.state not in ["idle","scheduled"]:
		hit=body(host,screen,p.pos,p.floor,"inspector","")
		if not hit.is_empty():result.append(hit)
	if result.any(func(c):return c.get("body",false)):
		result=result.filter(func(c):return c.get("body",false))
	if result.any(func(c):return c.direct):result=result.filter(func(c):return c.direct)
	result.sort_custom(func(a,b):
		if absf(a.distance-b.distance)>3:return a.distance<b.distance
		return a.depth<b.depth)
	if result.size()>1 and result[0].distance+6<result[1].distance:return [result[0]]
	return result
