extends RefCounted
const Sandbox=preload("res://scripts/inn_sandbox.gd")
const PRIVATE=Rect2(10.5,-5.5,7,4.2)
const PRIVATE_ENTRY=Vector2(12.75,-2.25)
static func active(s) -> bool:return s.data.has("tycoon")
static func start(s) -> void:
	s.data.tycoon={"reception":false,"cleaning":false,"kitchen":0,"rooms":{"1":0,"2":0,"3":0,"4":0,"5":0},"sales":0,"day_sales":0,"receipt":"","receipt_until":0.0,"next_reception":0.0,"cleaner":{"pos":Vector2(-0.25,-1.25),"floor":0,"path":[],"target":"","remaining":0.0}}
	set_easy(s,true)
	s.data.campaign.freeplay=true
	Sandbox.finish(s,{"kind":"entrance","point":PRIVATE_ENTRY,"cell":Sandbox.underground(PRIVATE_ENTRY)})
	s.data.sandbox.entrances[0].name="창고 안 비밀 입구"
	s.Layout.setup(s)
	s.data.player.pos=Vector2(-0.25,2.25)
	s.note("마라: 접수·식사·청소는 저희가 맡을게요. 손님을 눌러 직접 안내해도 돼요. 비밀 입구는 뒤편 창고에 있어요.")
static func wage(s) -> int:return (4 if s.data.staff.hired else 0)+(2 if s.data.tycoon.reception else 0)+(2 if s.data.tycoon.cleaning else 0)
static func income(s,amount: int,label_: String) -> void:
	s.data.tycoon.sales+=amount;s.data.tycoon.day_sales+=amount;s.data.tycoon.receipt=label_+" +%d닢" %amount;s.data.tycoon.receipt_until=s.data.clock+3
static func room_bonus(s,n: int) -> int:return int(s.data.tycoon.rooms[str(n)])*2
static func meal_price(s) -> int:return 4+int(s.data.tycoon.kitchen)
static func hire(s,kind: String) -> void:
	if kind not in ["reception","cleaning"] or s.data.tycoon[kind]:return
	if s.data.money<10:s.note("고용비 10닢이 필요합니다.");return
	s.data.money-=10;s.data.tycoon[kind]=true
	s.note("접수 알바 토마 고용. 일반 손님의 숙박비 수금·빈방 배정을 맡는다. 일당 2닢." if kind=="reception" else "청소 알바 리아 고용. 퇴실한 방을 돌아다니며 정리한다. 일당 2닢.")
static func upgrade_room(s,n: int) -> void:
	var level=int(s.data.tycoon.rooms[str(n)]);var cost=8+level*6
	if level>=3:s.note("이 방은 최고 등급입니다.");return
	if s.data.money<cost:s.note("객실 개선 비용 %d닢이 필요합니다." %cost);return
	s.data.money-=cost;s.data.tycoon.rooms[str(n)]=level+1;s.note("%d호 개선 · 숙박비 +%d닢" %[n,(level+1)*2])
static func upgrade_kitchen(s) -> void:
	var level=int(s.data.tycoon.kitchen);var cost=12+level*8
	if level>=3:s.note("주방은 최고 등급입니다.");return
	if s.data.money<cost:s.note("주방 개선 비용 %d닢이 필요합니다." %cost);return
	s.data.money-=cost;s.data.tycoon.kitchen=level+1;s.note("주방 개선 · 식사값 %d닢, 조리 시간 단축" %meal_price(s))
static func check_in(s,id: String,n: int=0) -> bool:
	if not s.data.people.has(id):return false
	var p: Dictionary=s.data.people[id]
	if p.state not in ["waiting","arriving"] or p.get("visit","")=="meal":return false
	if n==0:
		for key in s.data.rooms:
			if s.data.rooms[key].guest=="" and not s.data.rooms[key].dirty and s.data.rooms[key].get("reserved","")=="":n=int(key);break
	if n==0:s.note("빈방이 없어요. 청소나 퇴실을 기다립니다.");return false
	if not s.data.rooms.has(str(n)):return false
	if s.data.rooms[str(n)].guest!="" or s.data.rooms[str(n)].dirty or s.data.rooms[str(n)].get("reserved","") not in ["",id]:return false
	p.known=true
	var ok=s.assign_room(n,id)
	if ok:p.bubble="감사합니다. 방에서 쉬겠습니다.";p.bubble_until=s.data.clock+4
	return ok
static func tick(s,dt: float) -> void:
	if not active(s):return
	ensure(s)
	var t: Dictionary=s.data.tycoon
	if t.reception and s.data.clock>=float(t.next_reception):
		t.next_reception=s.data.clock+2.5
		for id in s.data.people:
			var p: Dictionary=s.data.people[id]
			if p.state=="waiting" and p.get("role","")=="" and p.get("visit","")!="meal" and s.data.get("booking_request",{}).get("guest","")!=id and (not t.get("easy",false) or s.data.clock-float(p.get("arrival",s.data.clock))>=18):
				if s.data.rooms.values().all(func(r):return r.guest!="" or r.get("reserved","")!=""):
					s.Layout.route_depart(s,p);s.note("토마가 만실을 안내하고 %s을 정문으로 돌려보냈다." %p.name);break
				if check_in(s,id):s.note("토마가 %s의 숙박비를 받고 %d호로 안내했다." %[p.name,p.room])
				break
	if s.data.clock>=float(t.get("next_missing_check",0)):
		t.next_missing_check=s.data.clock+8
		for id in s.data.people:
			var lost: Dictionary=s.data.people[id]
			if not lost.get("was_registered",false) or lost.get("missing_reported",false) or s.data.clock<maxf(lost.get("checkout",0),lost.get("death_at",s.data.clock)+45):continue
			for other in s.data.people.values():
				if other.id==id or other.state not in ["waiting","staying","dining"] or other.get("faction","")=="" or other.get("faction","")!=lost.get("faction",""):continue
				lost.missing_reported=true;other.bubble=lost.name+"은 어디 있습니까? 퇴실할 때가 지났는데요.";other.bubble_until=s.data.clock+7
				s.Intrigue.report(s,other.name+"의 동료 실종 신고");break
	if not t.cleaning:return
	var w: Dictionary=t.cleaner
	if w.target=="":
		for n in s.data.rooms:
			if s.data.rooms[n].dirty and s.data.rooms[n].guest=="" and s.data.get("booking_request",{}).get("room",0)!=int(n):
				w.target=n;w.remaining=2.0;Sandbox.move_person(s,w,Sandbox.room_point(int(n)),Sandbox.floor_of(int(n)));break
	if w.target=="":return
	if not w.path.is_empty():s.follow(w,dt*3.4);return
	if Sandbox.arrive(s,w):return
	w.remaining-=dt
	if w.remaining<=0:
		s.data.rooms[w.target].dirty=false;s.note("리아가 %s호 청소를 마쳤다. 다시 손님을 받을 수 있다." %w.target);w.target=""
static func goal(s) -> String:
	var t: Dictionary=s.data.tycoon
	if t.get("easy",false):return "쉬운 운영 · 접수·식사·청소 자동 · 손님을 눌러 직접 안내도 가능"
	if not t.reception:return "손님을 눌러 요구 확인 · 접수대에서 접수 알바 고용"
	if not t.cleaning:return "접수·식사 자동 운영 중 · 청소 알바를 고용하면 객실도 반복 판매"
	return "자동 운영 중 · 손님·객실·주방을 눌러 관리"

static func ensure(s) -> void:
	if s.data.sandbox.get("starter_version",0)<1:s.Layout.setup(s)
	for n in s.data.rooms:
		var room_: Dictionary=s.data.rooms[n]
		if not room_.has("reserved"):room_.reserved=""
		if room_.reserved!="" and (not s.data.people.has(room_.reserved) or s.data.people[room_.reserved].state in ["gone","leaving","dead"] or room_.guest!=""):room_.reserved=""
	var job: Dictionary=s.data.get("booking_request",{})
	if not job.is_empty():
		job.room=int(job.get("room",0))
		if not job.has("deadline"):job.deadline=s.data.clock+90
	for n in s.data.rooms:
		var r: Dictionary=s.data.rooms[n]
		if r.reserved!="" and (job.is_empty() or str(int(job.get("room",0)))!=n or job.get("guest","")!=r.reserved):r.reserved=""

static func cancel_booking(s) -> void:
	var job: Dictionary=s.data.get("booking_request",{})
	if not job.is_empty():
		var n=str(int(job.get("room",0)))
		if s.data.rooms.has(n) and s.data.rooms[n].get("reserved","")==job.get("guest",""):s.data.rooms[n].reserved=""
	s.data.booking_request={}

static func reserve(s,n: int,id: String) -> bool:
	ensure(s)
	if s.data.paused:s.note("영업을 재개한 뒤 방을 안내해주세요.");return false
	if not s.data.people.has(id) or not s.data.rooms.has(str(n)):return false
	var p: Dictionary=s.data.people[id];var r: Dictionary=s.data.rooms[str(n)]
	if p.state not in ["waiting","arriving","staying","dining"] or p.get("visit","")=="meal":s.note("지금 객실을 안내할 수 없는 손님입니다.");return false
	if int(p.room)==n:s.note("이미 이 방을 이용 중입니다.");return false
	if r.guest!="" or r.reserved not in ["",id]:s.note("그 방은 사용 중이거나 다른 손님이 예약했습니다.");return false
	cancel_booking(s)
	s.cancel_work();s.data.service_target="";s.data.deferred_command={}
	r.reserved=id
	s.data.booking_request={"room":n,"guest":id,"deadline":s.data.clock+90,"relocation":int(p.room)>0}
	s.note("%d호를 예약했습니다. %s" %[n,"청소 후 손님을 안내합니다." if r.dirty else "주인이 손님에게 다가가 안내합니다."])
	return true

static func booking_step(s) -> void:
	ensure(s)
	var job: Dictionary=s.data.get("booking_request",{})
	if job.is_empty():return
	var id=str(job.guest);var n=str(int(job.room))
	if not s.data.people.has(id) or not s.data.rooms.has(n) or s.data.people[id].state in ["gone","leaving","dead","down","captive"] or s.data.clock>float(job.deadline):
		cancel_booking(s);s.note("객실 안내를 취소했습니다. 예약을 해제합니다.");return
	var p: Dictionary=s.data.people[id];var r: Dictionary=s.data.rooms[n]
	if r.guest==id:cancel_booking(s);return
	if r.guest!="" or r.reserved!=id:cancel_booking(s);s.note("객실 상태가 바뀌었습니다. 다시 선택해주세요.");return
	if not s.data.work.is_empty() or s.data.excavation.intent!="":return
	if r.dirty:
		if int(s.data.player.floor)==1:s.queue_floor();return
		s.queue_command("clean"+n);return
	if int(s.data.player.floor)!=int(p.floor):
		if int(s.data.player.floor)==1:s.queue_floor()
		else:s.queue_gallery()
		return
	s.queue_command("confirm_room",id)

static func confirm(s,id: String) -> bool:
	var job: Dictionary=s.data.get("booking_request",{})
	if job.is_empty() or job.get("guest","")!=id or not s.data.people.has(id):return false
	var n=int(job.room);var r: Dictionary=s.data.rooms[str(n)];var p: Dictionary=s.data.people[id]
	if r.guest!="" or r.dirty or r.get("reserved","")!=id:return false
	var route: Array=s.guest_path(p.pos,s.STAIRS if n>=3 else s.room_target(n))
	if route.is_empty():cancel_booking(s);s.note("객실 통로가 막혀 안내할 수 없습니다.");return false
	var old=int(p.room);var previous_state=str(p.state);var old_room: Dictionary={}
	if old>0:
		old_room=s.data.rooms[str(old)].duplicate(true)
		s.data.rooms[str(old)].guest="";s.data.rooms[str(old)].dirty=true;p.room=0;p.relocating=true;p.state="waiting"
	var ok=check_in(s,id,n)
	if not ok:
		if old>0:s.data.rooms[str(old)]=old_room;p.room=old;p.state=previous_state;p.relocating=false
		cancel_booking(s);s.note("안내하지 못했습니다. 방을 다시 선택해주세요.");return false
	r.reserved="";s.data.booking_request={}
	return true

static func set_easy(s,enabled: bool) -> void:
	s.data.tycoon.easy=enabled
	if enabled:
		s.data.tycoon.reception=true;s.data.tycoon.cleaning=true
		s.data.staff.hired=true;s.data.staff.delegated=true;s.data.staff.ally=true

static func settlement_cost(s,full_cost: int) -> int:
	return mini(full_cost,6) if active(s) and s.data.tycoon.get("easy",false) and int(s.data.campaign.day)<=3 else full_cost

static func recommended_room(s,id: String) -> int:
	if not s.data.people.has(id):return 0
	var best=INF;var chosen=0
	var rival: Dictionary=s.data.people.get(s.data.people[id].get("rival",""),{})
	for key in s.data.rooms:
		var room_: Dictionary=s.data.rooms[key];var n=int(key)
		if room_.guest!="" or room_.get("reserved","") not in ["",id]:continue
		var score=float(n)*0.1+(100 if room_.dirty else 0)
		if not rival.is_empty() and int(rival.get("room",0))>0 and Sandbox.floor_of(int(rival.room))==Sandbox.floor_of(n):score+=20.0/(1.0+Sandbox.room_point(n).distance_to(Sandbox.room_point(int(rival.room))))
		if score<best:best=score;chosen=n
	return chosen
