extends RefCounted
const Sandbox=preload("res://scripts/inn_sandbox.gd")
const PRIVATE=Rect2(10.5,-5.5,7,4.2)
const PRIVATE_ENTRY=Vector2(12.75,-2.25)
static func active(s) -> bool:return s.data.has("tycoon")
static func start(s) -> void:
	s.data.tycoon={"reception":false,"cleaning":false,"kitchen":0,"rooms":{"1":0,"2":0,"3":0,"4":0,"5":0},"sales":0,"day_sales":0,"receipt":"","receipt_until":0.0,"next_reception":0.0,"cleaner":{"pos":Vector2(-0.25,-1.25),"floor":0,"path":[],"target":"","remaining":0.0}}
	s.data.campaign.freeplay=true
	Sandbox.finish(s,{"kind":"entrance","point":PRIVATE_ENTRY,"cell":Sandbox.underground(PRIVATE_ENTRY)})
	s.data.sandbox.entrances[0].name="창고 안 비밀 입구"
	s.data.player.pos=Vector2(12.75,-0.25)
	s.note("마라: 식사는 제가 맡을게요. 접수·청소 알바를 고용하면 여관을 비우셔도 돼요. 비밀 입구는 손님이 못 들어오는 뒤편 창고에 있어요.")
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
			if s.data.rooms[key].guest=="" and not s.data.rooms[key].dirty:n=int(key);break
	if n==0:s.note("빈방이 없어요. 청소나 퇴실을 기다립니다.");return false
	if s.data.rooms[str(n)].guest!="" or s.data.rooms[str(n)].dirty:return false
	p.known=true
	var ok=s.assign_room(n,id)
	if ok:p.bubble="감사합니다. 방에서 쉬겠습니다.";p.bubble_until=s.data.clock+4
	return ok
static func tick(s,dt: float) -> void:
	if not active(s):return
	var t: Dictionary=s.data.tycoon
	if t.reception and s.data.clock>=float(t.next_reception):
		t.next_reception=s.data.clock+2.5
		for id in s.data.people:
			var p: Dictionary=s.data.people[id]
			if p.state=="waiting" and p.get("role","")=="" and p.get("visit","")!="meal":
				if check_in(s,id):s.note("토마가 %s의 숙박비를 받고 %d호로 안내했다." %[p.name,p.room])
				break
	if not t.cleaning:return
	var w: Dictionary=t.cleaner
	if w.target=="":
		for n in s.data.rooms:
			if s.data.rooms[n].dirty and s.data.rooms[n].guest=="":
				w.target=n;w.remaining=2.0;Sandbox.move_person(s,w,Sandbox.room_point(int(n)),Sandbox.floor_of(int(n)));break
	if w.target=="":return
	if not w.path.is_empty():s.follow(w,dt*3.4);return
	if Sandbox.arrive(s,w):return
	w.remaining-=dt
	if w.remaining<=0:
		s.data.rooms[w.target].dirty=false;s.note("리아가 %s호 청소를 마쳤다. 다시 손님을 받을 수 있다." %w.target);w.target=""
static func goal(s) -> String:
	var t: Dictionary=s.data.tycoon
	if not t.reception:return "손님 클릭 → 요구 듣기 → 숙박비 받고 방 배정 · 접수대에서 알바 고용"
	if not t.cleaning:return "접수·식사 자동 운영 중 · 청소 알바를 고용하면 퇴실한 방도 자동 회전"
	return "여관 자동 운영 중 · 객실·주방을 개선하거나 주인 전용 창고에서 비밀 활동"
