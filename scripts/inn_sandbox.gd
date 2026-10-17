extends RefCounted
const DAY=210.0
const OFFSET=Vector3(-3.25,-6.0,18.0)
const TYPES={"prison":{"name":"감옥","cost":6},"stash":{"name":"은닉 창고","cost":4},"furnace":{"name":"처리 화로","cost":10},"refuge":{"name":"은신처","cost":6}}
const ROOM_NAMES={1:"1호 · 조용한 안쪽",2:"2호 · 마당 옆",3:"3호 · 2층 서쪽",4:"4호 · 2층 가운데",5:"5호 · 2층 동쪽"}
static func active(s) -> bool:return s.data.has("sandbox")
static func start(s) -> void:
	s.data.sandbox={"entrances":[],"facilities":[],"route":{},"revision":0,"next_relation":30.0,"next_noise":0.0,"tunnel_plan":[],"job":{"state":"none","target":"","reward":18,"held":0.0},"disposed":0,"stored":0,"rescued":0}
	s.data.cells.clear();s.data.excavation.storeroom=false;s.data.money=60
	for n in [3,4,5]:s.data.rooms[str(n)]={"guest":"","dirty":false}
	s.data.staff.hired=true;s.data.staff.delegated=true;s.data.staff.ally=true;s.data.staff.floor=0
	s.data.staff.pos=s.COUNTER;s.data.next_guest=12;s.data.campaign.start_money=60
	s.data.campaign.worker="ally";s.data.campaign.next_dawn=DAY
	s.note("마라: 홀은 제가 볼게요. 지하 입구는 주인님이 편한 곳에 만드세요. 비밀은 지킬게요.")
static func floor_of(n: int) -> int:return 2 if n>=3 else 0
static func room_point(n: int) -> Vector2:
	return Vector2([-4.5,1.5,7.5][clampi(n-3,0,2)],-6.25) if n>=3 else Vector2(3.25,-2.25 if n==1 else 1.75)
static func underground(p: Vector2) -> Vector2i:return Vector2i(roundi(p.x+3.25),roundi(p.y-2.75))
static func above(p: Vector2) -> Vector2:return Vector2(p.x-3.25,p.y+2.75)
static func entrance(s,id: String) -> Dictionary:
	for e in s.data.sandbox.entrances:
		if e.id==id:return e
	return {}
static func nearest(s,at: Vector2,floor_: int) -> Dictionary:
	var chosen={};var best=INF
	for e in s.data.sandbox.entrances:
		var point: Vector2=e.top if floor_==0 else Vector2(e.bottom)
		var path: Array=s.path_to(at,point) if floor_==0 else s.Intrigue.basement_route(s,at,point)
		if not path.is_empty() and path.size()<best:chosen=e;best=path.size()
	return chosen
static func use_entrance(s,id: String) -> bool:
	if not s.data.work.is_empty() or not s.data.dig.is_empty():s.cancel_work()
	var e=entrance(s,id)
	if e.is_empty():return false
	if s.data.player.floor==2:s.note("먼저 1층으로 내려가세요.");return false
	var target: Vector2=e.top if s.data.player.floor==0 else Vector2(e.bottom)
	if not s.queue_move(target):return false
	s.data.excavation.intent="sandbox:portal";s.data.excavation.target=id
	return true
static func transit(s,id: String) -> void:
	var e=entrance(s,id)
	if e.is_empty():return
	var down=s.data.player.floor==0
	s.data.player.floor=1 if down else 0;s.data.player.pos=Vector2(e.bottom) if down else e.top
	e.open=true;s.Intrigue.sync_drag(s);s.note("%s으로 %s." %[e.name,"내려왔다" if down else "올라왔다"])
static func create_entrance(s,top: Vector2) -> bool:
	if s.data.player.floor!=0 or not s.surface_walkable(top):s.note("1층이나 마당의 걸을 수 있는 바닥을 골라주세요.");return false
	var bottom=underground(top)
	if absi(bottom.x)>s.CELLAR_LIMIT.x-1 or absi(bottom.y)>s.CELLAR_LIMIT.y-1:return false
	for e in s.data.sandbox.entrances:
		if e.top.distance_to(top)<2:s.note("다른 입구에서 조금 떨어진 곳을 고르세요.");return false
	if s.data.money<3:s.note("입구 공사비 3닢이 필요하다.");return false
	if not s.queue_move(top):return false
	s.data.sandbox.route={"kind":"entrance","point":top,"cell":bottom};s.data.excavation.intent="sandbox:build";return true
static func facility_at(s,point: Vector2) -> Dictionary:
	for f in s.data.sandbox.facilities:
		if f.pos.distance_to(point)<1.45:return f
	return {}
static func build(s,type_: String,cell: Vector2i) -> bool:
	if s.data.player.floor!=1 or not TYPES.has(type_):return false
	if not facility_at(s,Vector2(cell)).is_empty():s.note("다른 시설과 조금 떨어진 자리를 고르세요.");return false
	if not s.data.cells.has(s.cell_key(cell)):s.note("열린 바닥을 눌러 시설을 설치하세요.");return false
	if s.data.money<int(TYPES[type_].cost):s.note("시설 공사비가 부족하다.");return false
	if not s.queue_move(Vector2(cell)):return false
	s.data.sandbox.route={"kind":type_,"cell":cell};s.data.excavation.intent="sandbox:build";return true
static func perform(s,action: String,id: String) -> void:
	if action=="sandbox:portal":
		transit(s,id)
		if s.data.player.floor==1 and s.data.sandbox.has("pending_tunnel"):
			var target: Vector2i=s.data.sandbox.pending_tunnel;s.data.sandbox.erase("pending_tunnel");preload("res://scripts/inn_excavation.gd").dig_to(s,target)
		return
	if action=="sandbox:build":
		var job: Dictionary=s.data.sandbox.route.duplicate(true)
		if job.is_empty():return
		var cost=3 if job.kind=="entrance" else int(TYPES[job.kind].cost)
		if s.data.money<cost:return
		s.data.money-=cost;s.data.work={"type":"construction","job":job,"remaining":4.0 if job.kind=="entrance" else 5.0}
		s.note("%s 공사 중…" %("비밀 입구" if job.kind=="entrance" else TYPES[job.kind].name));return
	if action=="sandbox:facility":operate(s,id)
static func finish(s,job: Dictionary) -> void:
	var center: Vector2i=job.cell
	for x in range(center.x-1,center.x+2):
		for y in range(center.y-1,center.y+2):s.data.cells[s.cell_key(Vector2i(x,y))]=true
	if job.kind=="entrance":
		var id="entry_%d" %s.data.sandbox.entrances.size()
		s.data.sandbox.entrances.append({"id":id,"name":"비밀 입구 %d" %(s.data.sandbox.entrances.size()+1),"top":job.point,"bottom":center,"open":false})
		s.note("비밀 입구 완성. 입구를 누르면 내려갑니다. 다른 입구까지 흙벽을 이어 파보세요.")
	else:
		s.data.sandbox.facilities.append({"id":"facility_%d" %s.data.sandbox.facilities.size(),"type":job.kind,"pos":Vector2(center),"occupant":"","until":0.0})
		s.note(TYPES[job.kind].name+" 완성. 시설을 눌러 사용하세요.")
	s.data.sandbox.revision+=1
static func facility(s,id: String) -> Dictionary:
	for f in s.data.sandbox.facilities:
		if f.id==id:return f
	return {}
static func queue_facility(s,id: String) -> bool:
	var f=facility(s,id)
	if f.is_empty() or s.data.player.floor!=1:return false
	if not s.queue_move(f.pos):return false
	s.data.excavation.intent="sandbox:facility";s.data.excavation.target=id;return true
static func operate(s,id: String) -> void:
	var f=facility(s,id)
	if f.is_empty():return
	var held: String=s.data.ops.drag
	match f.type:
		"prison":
			if held=="":s.note("붙잡거나 기절시킨 대상을 데려와 감옥에 넣으세요. 구금 중에는 심문·석방할 수 있습니다.");return
			var p: Dictionary=s.data.people[held]
			if p.state=="dead":s.note("감옥에는 살아 있는 사람만 넣을 수 있다.");return
			if f.occupant!="":s.note("이 감옥은 이미 사용 중이다.");return
			p.state="captive";p.pos=f.pos;p.floor=1;p.prison=id;p.path=[];s.data.ops.drag="";f.occupant=held;s.Intrigue.release_room(s,held)
			s.note("%s을 구금했다. 인물을 눌러 심문하거나 풀어줄 수 있다." %p.name)
		"furnace":
			if held=="" or s.data.people[held].state!="dead":s.note("시신을 운반해 왔을 때만 처리할 수 있다. 가동하면 12초 동안 연기와 소음이 난다.");return
			if f.until>s.data.clock:s.note("화로가 아직 가동 중이다.");return
			s.data.work={"type":"dispose","facility":id,"target":held,"remaining":12.0};f.until=s.data.clock+12;s.data.sandbox.smoke_until=s.data.clock+20
			s.note("처리 화로 가동. 연기와 소리가 바깥에 새어 나간다.")
		"stash":
			if s.data.campaign.cargo:
				s.data.campaign.cargo=false;s.data.sandbox.stored+=1;f.occupant="cargo";s.data.money+=6;s.note("의뢰 상자를 은닉했다. 추가 보수 6닢. 조사에서 드러날 위험이 줄었다.")
			else:s.note("회색 망토의 상자를 받은 뒤 이 창고에 숨길 수 있다.")
		"refuge":
			if held!="":
				var p: Dictionary=s.data.people[held]
				if p.state=="dead":s.note("은신처는 살아 있는 사람을 보호하는 곳이다.");return
				p.state="sheltered";p.pos=f.pos;p.floor=1;p.path=[];p.protected=true;s.data.ops.drag="";s.data.campaign.protected=true;s.data.sandbox.rescued+=1;s.note("%s을 은신처에 보호했다. 인물을 눌러 이야기를 듣거나 돌려보낼 수 있다." %p.name)
			else:s.note("쫓기는 사람을 숨길 장소다. 전령에게 말을 걸어 함께 이동한 뒤 이곳에 데려올 수 있다.")
	s.data.sandbox.revision+=1
static func release(s,id: String) -> void:
	var p: Dictionary=s.data.people[id]
	var e=nearest(s,p.pos,1)
	if e.is_empty():s.note("지상으로 이어진 입구가 없다.");return
	p.pos=e.top;p.floor=0;p.state="leaving";p.path=s.path_to(p.pos,s.GATE);p.report_pending=false
	for f in s.data.sandbox.facilities:
		if f.occupant==id:f.occupant=""
	s.note(p.name+"을 풀어주었다.");s.data.sandbox.revision+=1
static func move_person(s,p: Dictionary,target: Vector2,floor_: int) -> void:
	p.destination=target;p.destination_floor=floor_
	if int(p.floor)==floor_:p.path=s.gallery_route(p.pos,target) if floor_==2 else s.guest_path(p.pos,target);p.travel=""
	elif int(p.floor)==0:p.path=s.guest_path(p.pos,s.STAIRS);p.travel="up"
	else:p.path=s.gallery_route(p.pos,s.STAIRS);p.travel="down"
static func arrive(s,p: Dictionary) -> bool:
	var travel: String=p.get("travel","")
	if travel=="":return false
	p.travel="";p.floor=2 if travel=="up" else 0;p.pos=s.STAIRS
	p.path=s.gallery_route(p.pos,p.destination) if p.floor==2 else s.guest_path(p.pos,p.destination);return true
static func staff_step(s,dt: float) -> bool:
	var w: Dictionary=s.data.staff
	if not w.hired:return false
	if w.carry!="" and s.data.orders.has(w.carry):
		var p: Dictionary=s.data.people[s.data.orders[w.carry].guest]
		if w.get("floor",0)!=p.floor:
			if not w.get("transfer",false):w.path=s.gallery_route(w.pos,s.STAIRS) if int(w.get("floor",0))==2 else s.path_to(w.pos,s.STAIRS);w.transfer=true
			s.follow(w,dt*3.3)
			if w.path.is_empty():w.floor=p.floor;w.pos=s.STAIRS;w.transfer=false
			return true
		return false
	if int(w.get("floor",0))==2:
		var n: String=w.get("clean_room","")
		if n!="" and s.data.rooms[n].dirty:
			if w.path.is_empty():w.path=s.gallery_route(w.pos,room_point(int(n)))
			s.follow(w,dt*3.3)
			if w.path.is_empty():s.data.rooms[n].dirty=false;w.clean_room="";s.note("마라가 %s호를 정리했다." %n)
			return true
		if w.path.is_empty():w.path=s.gallery_route(w.pos,s.STAIRS)
		s.follow(w,dt*3.3)
		if w.path.is_empty():w.floor=0;w.pos=s.STAIRS;w.path=[]
		return true
	if not s.data.has("tycoon") and w.target=="" and w.carry=="" and s.data.orders.values().all(func(o):return o.status not in ["queued","ready"]):
		for n in s.data.rooms:
			if s.data.rooms[n].dirty and s.data.rooms[n].guest=="":
				var point=room_point(int(n))
				if floor_of(int(n))!=int(w.get("floor",0)):
					if not w.get("clean_transfer",false):w.path=s.path_to(w.pos,s.STAIRS);w.clean_transfer=true
					s.follow(w,dt*3.3)
					if w.path.is_empty():w.floor=2;w.pos=s.STAIRS;w.clean_transfer=false;w.clean_room=n
					return true
				if w.pos.distance_to(point)<0.9:s.data.rooms[n].dirty=false;s.note("마라가 %s호를 정리했다." %n);w.path=[]
				else:
					if w.path.is_empty():w.path=s.path_to(w.pos,point)
					s.follow(w,dt*2.8)
				return true
	return false
static func tick(s,dt: float) -> void:
	if not active(s):return
	if s.data.work.get("type","") in ["construction","dispose"]:
		s.data.work.remaining-=dt;s.data.noise=minf(8,s.data.noise+dt*0.6);s.data.stealth.source=s.data.player.pos
		if s.data.work.remaining<=0:
			var job: Dictionary=s.data.work.duplicate(true);s.data.work={}
			if job.type=="construction":finish(s,job.job)
			else:s.data.people[job.target].state="gone";s.data.ops.drag="";s.data.sandbox.disposed+=1;s.note("처리를 마쳤다. 바깥에서 연기를 본 사람이 있을 수 있다.");s.data.ops.heat+=10
	for f in s.data.sandbox.facilities:
		if f.type=="prison" and f.occupant!="" and (not s.data.people.has(f.occupant) or s.data.people[f.occupant].state!="captive"):f.occupant="";s.data.sandbox.revision+=1
	var job: Dictionary=s.data.sandbox.job
	if job.state=="accepted" and s.data.people.has(job.target) and s.data.people[job.target].state=="captive":
		job.held+=dt
		if job.held>=15:job.state="paid";s.data.money+=int(job.reward);s.note("생포 의뢰 완료. 18닢을 받았다. 포로를 풀어줄지는 당신의 선택이다.")
	if s.data.player.floor==1 and s.data.work.is_empty() and s.data.dig.is_empty() and s.data.excavation.intent=="" and not s.data.sandbox.get("tunnel_plan",[]).is_empty():
		var cell: Vector2i=s.data.sandbox.tunnel_plan.pop_front()
		if s.data.cells.has(s.cell_key(cell)):s.queue_move(Vector2(cell))
		else:
			if not s.queue_dig(cell):s.data.sandbox.tunnel_plan=[];s.note("굴착을 멈췄다. 목적지를 다시 지정하세요.")
	preload("res://scripts/inn_excavation.gd").tick(s)
	if s.data.clock>=float(s.data.sandbox.next_relation):s.data.sandbox.next_relation=s.data.clock+8;relationships(s)
	if s.data.noise>3 and s.data.clock>=float(s.data.sandbox.get("next_noise",0)):
		s.data.sandbox.next_noise=s.data.clock+6
		for p in s.data.people.values():
			if p.floor in [0,2] and p.state=="staying" and not p.get("heard_work",false) and sound_at(s,p.pos,p.floor)>0.75:
				p.heard_work=true;p.bubble="방 아래 공사 소리 좀 줄여주시겠소?";p.bubble_until=s.data.clock+6;s.note(p.name+"의 객실 가까이에서 큰 공사 소리가 났다. 소음 불편일 뿐 범죄 의심이나 신고는 아니다.")
static func relationships(s) -> void:
	var list=s.data.people.values().filter(func(p):return p.state in ["waiting","staying","dining"] and p.get("role","")=="")
	for i in range(list.size()):
		var a: Dictionary=list[i]
		for j in range(i+1,list.size()):
			var b: Dictionary=list[j]
			if a.floor!=b.floor:continue
			if a.get("last_feud",-50)>s.data.clock or b.get("last_feud",-50)>s.data.clock:continue
			var hostile=(a.get("faction","")=="국경군" and b.get("faction","")=="약초상단") or (b.get("faction","")=="국경군" and a.get("faction","")=="약초상단")
			if not hostile or a.pos.distance_to(b.pos)>4.5 or a.get("last_feud",-50)>s.data.clock-25:continue
			a.last_feud=s.data.clock;b.last_feud=s.data.clock;a.rival=b.id;b.rival=a.id
			a.bubble="그 약은 군수품이다. 내놓으시오." if a.get("faction","")=="국경군" else "환자에게 갈 약이오. 손대지 마시오.";b.bubble="그 약은 군수품이다. 내놓으시오." if b.get("faction","")=="국경군" else "환자에게 갈 약이오. 손대지 마시오.";a.bubble_until=s.data.clock+7;b.bubble_until=s.data.clock+7
			s.note("%s과 %s이 언성을 높인다. 다른 방으로 옮기거나 인물을 눌러 중재할 수 있다." %[a.name,b.name])
			if a.get("feuds",0)>=2:s.data.money=maxi(0,int(s.data.money)-3);s.note("다툼 중 잔이 깨졌다. 손해 3닢.")
			a.feuds=int(a.get("feuds",0))+1;return

static func sound_at(s,point: Vector2,floor_: int=0) -> float:
	# This underground layer is six metres below the inn. Distance in the exploded
	# drawing never affects acoustics; only the actual location and depth do.
	var depth=float(s.data.sandbox.get("depth",6.0))+(3.2 if floor_==2 else 0.0)
	if depth>7.5:return 0.0
	var horizontal=Sandbox_above(s.data.stealth.source).distance_to(point)
	if horizontal>3.2:return 0.0
	var result=maxf(0,s.data.noise-depth*0.95-horizontal*0.8)
	# A covered room floor muffles tool work; this can cause a noise complaint,
	# never a crime report or an investigation by itself.
	return result*0.65

static func Sandbox_above(point: Vector2) -> Vector2:return above(point)

static func connect_tunnel(s,from_id: String,to_id: String) -> void:
	var a=entrance(s,from_id);var b=entrance(s,to_id)
	if a.is_empty() or b.is_empty():return
	if s.data.player.floor==0:
		if use_entrance(s,from_id):s.data.sandbox.pending_tunnel=b.bottom
	else:preload("res://scripts/inn_excavation.gd").dig_to(s,b.bottom)
