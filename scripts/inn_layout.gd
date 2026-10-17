extends RefCounted
## Shared geometry and one-time playable setup. No rendering dependencies.
const FRONT=Vector2(.25,5.25)
const PORCH=Vector2(.25,8.25)
const TABLES=[Vector2(-7.75,2.25),Vector2(-4.75,2.25),Vector2(-7.75,-1.25),Vector2(-4.75,-1.25),Vector2(-19.25,2.25),Vector2(-14.25,2.25),Vector2(-19.25,-1.25),Vector2(-14.25,-1.25)]
const QUEUE=[Vector2(-1.75,-.25),Vector2(-.25,-.25),Vector2(-3.25,-.25)]

static func carve(s,a: Vector2i,b: Vector2i) -> void:
	var p=a
	while true:
		for dx in range(-1,2):
			for dy in range(-1,2):s.data.cells[s.cell_key(p+Vector2i(dx,dy))]=true
		if p==b:break
		if p.x!=b.x:p.x+=1 if b.x>p.x else -1
		else:p.y+=1 if b.y>p.y else -1

static func setup(s) -> void:
	if s.data.sandbox.get("starter_version",0)>=1:return
	var center: Vector2i=s.Sandbox.underground(s.Tycoon.PRIVATE_ENTRY)
	s.data.money=maxi(300,int(s.data.money));s.data.campaign.start_money=s.data.money
	var definitions=[["prison",Vector2i(-5,-3)],["stash",Vector2i(0,-4)],["refuge",Vector2i(5,-3)],["furnace",Vector2i(5,3)]]
	for pair in definitions:
		var at: Vector2i=center+pair[1];carve(s,center,at)
		if not s.data.sandbox.facilities.any(func(f):return f.type==pair[0]):s.Sandbox.finish(s,{"kind":pair[0],"cell":at})
	for key in s.data.rooms:
		var room_: Dictionary=s.data.rooms[key]
		room_.secret_bottom=s.Sandbox.underground(s.Sandbox.room_point(int(key)))
		carve(s,center,room_.secret_bottom)
	s.data.sandbox.receiving=center+Vector2i(0,2);carve(s,center,s.data.sandbox.receiving)
	s.data.sandbox.starter_version=1;s.data.sandbox.revision+=1

static func route_in(s,from: Vector2,to: Vector2) -> Array:
	var result: Array=[];var at=from
	for point in [Vector2(22.25,8.25),PORCH,FRONT,to]:
		var leg: Array=s.guest_path(at,point)
		if leg.is_empty():return []
		result.append_array(leg);at=point
	return result

static func route_depart(s,p: Dictionary) -> void:
	p.state="leaving";p.full_rejected=true;p.bubble="오늘은 만실이군요. 다음에 오겠습니다.";p.bubble_until=s.data.clock+6
	p.path=s.guest_path(p.pos,FRONT)
	var at=FRONT
	for point in [PORCH,Vector2(22.25,8.25),s.GATE]:
		p.path.append_array(s.guest_path(at,point));at=point

static func room_of_body(s,id: String) -> int:
	if not s.data.people.has(id):return 0
	var p: Dictionary=s.data.people[id]
	if p.state!="dead" or int(p.floor) not in [0,2]:return 0
	for key in s.data.rooms:
		var n=int(key)
		if int(p.floor)!=s.Sandbox.floor_of(n):continue
		var point: Vector2=s.Sandbox.room_point(n)
		var area=Rect2(2.2,-5.8 if n==1 else .2,4.5,3.6) if n<3 else Rect2(point+Vector2(-2,-2),Vector2(4,3.5))
		if area.has_point(p.pos):return n
	return 0

static func send_body(s,id: String) -> bool:
	var n=room_of_body(s,id)
	if n==0:s.note("객실 안의 시신만 비밀 통로로 보낼 수 있습니다.");return false
	if s.data.paused or int(s.data.player.floor)!=int(s.data.people[id].floor):return false
	var approach=s.approach_point(s.data.people[id].pos)
	if approach==null:return false
	if not s.queue_move(approach):return false
	s.data.sandbox.chute_job={"target":id,"room":n,"deadline":s.data.clock+25}
	s.note("객실 비밀 통로로 옮길 준비를 합니다.");return true

static func tick(s) -> void:
	var job: Dictionary=s.data.sandbox.get("chute_job",{})
	if job.is_empty():return
	var id=str(job.target)
	if s.data.clock>float(job.deadline) or room_of_body(s,id)!=int(job.room):s.data.sandbox.chute_job={};return
	if not s.data.excavation.path.is_empty() or not s.data.work.is_empty():return
	var p: Dictionary=s.data.people[id]
	if s.data.player.floor!=p.floor or s.data.player.pos.distance_to(p.pos)>1.5:s.data.sandbox.chute_job={};return
	s.Intrigue.witness(s,id,"attack")
	s.Intrigue.release_room(s,id);s.data.ops.drag="" if s.data.ops.drag==id else s.data.ops.drag
	p.floor=1;p.pos=Vector2(s.data.rooms[str(int(job.room))].secret_bottom);p.path=[]
	s.data.sandbox.chute_job={};s.data.sandbox.revision+=1
	s.note("객실 비밀 통로로 지하에 옮겼습니다. 시신은 남아 있으며 화로로 운반해 처리할 수 있습니다.")

static func expand(s) -> void:
	if s.data.sandbox.get("wide_version",0)>=1:return
	var hub=Vector2i(12,-6)
	for center in [Vector2i(-14,-7),hub,Vector2i(38,-7),Vector2i(12,15)]:
		for x in range(center.x-8,center.x+9):
			for y in range(center.y-5,center.y+6):s.data.cells[s.cell_key(Vector2i(x,y))]=true
		carve(s,hub,center)
	carve(s,hub,s.data.sandbox.entrances[0].bottom)
	for at in [Vector2i(-18,-8),Vector2i(-11,-8),Vector2i(38,-8)]:
		if not s.data.sandbox.facilities.any(func(f):return f.type=="prison" and f.pos.distance_to(Vector2(at))<2):s.Sandbox.finish(s,{"kind":"prison","cell":at})
	s.data.sandbox.wide_version=1;s.data.sandbox.revision+=1

static func seat_display(pos: Vector2) -> Vector2:
	var best=-7.5;var distance=INF
	for x in [-19.0,-14.0,-7.5,-4.8]:
		if absf(pos.x-x)<distance:distance=absf(pos.x-x);best=x
	return Vector2(best,1.6 if pos.y>0 else -.7)
