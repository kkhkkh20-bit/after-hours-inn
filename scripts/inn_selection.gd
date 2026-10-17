extends RefCounted
## Screen-space body capsules; direct hits beat expanded touch targets.
static func visible_floor(host,floor_: int) -> bool:
	if host.view_layer=="below":return floor_==1
	if host.view_layer=="rooms":return floor_==2
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
	if distance>maxf(44,radius):return {}
	return {"kind":kind,"id":id,"distance":distance,"direct":distance<=radius,"point":head.lerp(foot,0.5),"depth":host.camera.global_position.distance_to(at)}

static func candidates(host,screen: Vector2) -> Array:
	var result: Array=[]
	for id in host.sim.data.people:
		var p: Dictionary=host.sim.data.people[id]
		if p.state=="gone":continue
		var hit=body(host,screen,p.pos,p.floor,"person",id)
		if not hit.is_empty():result.append(hit)
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
	if result.any(func(c):return c.direct):result=result.filter(func(c):return c.direct)
	result.sort_custom(func(a,b):
		if absf(a.distance-b.distance)>3:return a.distance<b.distance
		return a.depth<b.depth)
	if result.size()>1 and result[0].direct and result[0].distance+6<result[1].distance:return [result[0]]
	return result
