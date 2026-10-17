extends RefCounted
## Persistent prisoners, care and a physical capture/escort command.
static func cells(s) -> Array:
	return s.data.sandbox.facilities.filter(func(f):return f.type=="prison")

static func ensure(s) -> void:
	for f in cells(s):
		for pair in [["capacity",6],["care",true],["guard",true],["locked",true],["attempts",0],["caught",0],["escaped",0],["event","이상 없음"]]:
			if not f.has(pair[0]):f[pair[0]]=pair[1]
		f.members=[]
		for id in s.data.people:
			var p: Dictionary=s.data.people[id]
			if p.state!="captive" or p.get("prison","")!=f.id:continue
			f.members.append(id)
			if not p.has("life"):p.life={"hunger":25.0,"energy":75.0,"mood":65.0,"action":"주변 살피기","next_escape":s.data.clock+90,"attempts":0,"next_move":0.0,"destination":p.pos,"rest_until":0.0}
		f.occupant="" if f.members.is_empty() else f.members[0]

static func security(f: Dictionary) -> int:
	return 99 if f.guard and f.locked else (65 if f.guard else (45 if f.locked else 0))

static func available_cell(s) -> Dictionary:
	ensure(s)
	for f in cells(s):
		if f.members.size()<int(f.capacity):return f
	return {}

static func admit(s,f: Dictionary,id: String) -> bool:
	ensure(s)
	if f.is_empty() or f.members.size()>=int(f.capacity) or not s.data.people.has(id):return false
	var p: Dictionary=s.data.people[id]
	if p.state in ["dead","gone","captive"]:return false
	s.Intrigue.clear_orders(s,id);s.Intrigue.release_room(s,id)
	p.state="captive";p.floor=1;p.pos=f.pos;p.path=[];p.prison=f.id;p.escorted=false;p.wake_at=0.0
	if s.data.ops.drag==id:s.data.ops.drag=""
	ensure(s);p.pos=slot(f,f.members.find(id));p.life.destination=p.pos
	f.event=p.name+" 수감";s.data.sandbox.revision+=1
	s.note("%s 수감 완료. 식사·휴식·경비를 자동 관리합니다." %p.name);return true

static func slot(f: Dictionary,index: int) -> Vector2:
	return f.pos+Vector2((index%4-1.5)*.5,(floorf(float(index)/4)-.5)*.5)

static func request(s,id: String) -> bool:
	if s.data.paused or not s.data.people.has(id):return false
	var p: Dictionary=s.data.people[id]
	if p.state in ["dead","gone","captive","escaping","leaving"]:s.note("지금은 수감할 수 없는 대상입니다.");return false
	var f=available_cell(s)
	if f.is_empty():s.note("감옥이 가득 찼습니다. 감옥을 늘리거나 증설하세요.");return false
	cancel(s);s.Tycoon.cancel_booking(s);s.cancel_work();s.data.service_target="";s.data.deferred_command={}
	s.data.sandbox.capture={"target":id,"cell":f.id,"stage":"approach","deadline":s.data.clock+180}
	s.note("대상에게 다가가 붙잡고 감옥으로 호송합니다. 바닥을 누르거나 취소하면 중단합니다.");return true

static func cancel(s) -> void:
	var job: Dictionary=s.data.sandbox.get("capture",{})
	if job.is_empty():return
	var id=str(job.target)
	if s.data.people.has(id) and s.data.people[id].state=="restrained":
		var p: Dictionary=s.data.people[id];p.state="down";p.escorted=false;p.wake_at=s.data.clock+60
	if s.data.ops.drag==id:s.data.ops.drag=""
	s.data.sandbox.capture={}

static func escort(s) -> void:
	var job: Dictionary=s.data.sandbox.get("capture",{})
	if job.is_empty():return
	var id=str(job.target);var f=s.Sandbox.facility(s,str(job.cell))
	if not s.data.people.has(id) or f.is_empty() or s.data.clock>float(job.deadline):cancel(s);return
	var p: Dictionary=s.data.people[id]
	if p.state in ["dead","gone","leaving","escaping","captive"]:cancel(s);return
	if not s.data.work.is_empty() or not s.data.dig.is_empty() or s.data.excavation.intent!="":return
	if job.stage=="approach":
		if s.data.player.floor!=p.floor:
			if s.data.player.floor==2 or (s.data.player.floor==0 and p.floor==2):s.queue_gallery()
			else:s.queue_floor()
			return
		if not s.Intrigue.close(s,id):s.queue_command("approach",id);return
		s.data.ops.selected=id
		if p.state in ["down","restrained"]:
			p.state="restrained";p.escorted=true;p.path=[];s.data.ops.drag=id;job.stage="escort"
		elif s.Intrigue.quick_action(s,"grab"):job.stage="grab"
		return
	if job.stage=="grab":
		if p.state!="restrained":cancel(s);return
		p.escorted=true;s.data.ops.drag=id;job.stage="escort"
	if s.data.ops.drag!=id:cancel(s);return
	if s.data.player.floor==2:s.queue_gallery();return
	if s.data.player.floor==0:
		var e=s.Sandbox.nearest(s,s.data.player.pos,0)
		if e.is_empty():cancel(s);s.note("지하로 이어지는 입구가 없습니다.");return
		s.Sandbox.use_entrance(s,e.id);return
	if s.data.player.pos.distance_to(f.pos)>1.1:s.queue_move(f.pos);return
	if admit(s,f,id):s.data.sandbox.capture={}
	else:cancel(s);s.note("선택한 감옥의 수용 인원이 바뀌어 호송을 중단했습니다.")

static func attempt(s,f: Dictionary,p: Dictionary) -> void:
	p.life.attempts+=1;f.attempts+=1
	var roll=absi(hash(p.id+":"+str(int(p.life.attempts))))%100
	if roll<security(f):
		f.caught+=1;f.event=p.name+" 탈출 시도 저지";p.life.action="경비에게 제지됨";p.life.mood=maxf(10,p.life.mood-3)
		p.life.rest_until=s.data.clock+4;s.note(f.event)
	else:
		f.escaped+=1;f.event=p.name+" 탈출 · 출구로 이동 중"
		s.Intrigue.flee(s,p.id);s.data.sandbox.revision+=1;s.note(f.event)

static func tick(s,dt: float) -> void:
	ensure(s);escort(s)
	for f in cells(s):
		for index in f.members.size():
			var p: Dictionary=s.data.people[f.members[index]];var life: Dictionary=p.life
			life.hunger=clampf(life.hunger+dt*.15,0,100)
			life.energy=clampf(life.energy-dt*.10,0,100)
			life.mood=clampf(life.mood+dt*(.035 if life.hunger<60 and life.energy>20 else -.14),0,100)
			var phase=fmod(s.data.clock+index*9,60.0)
			if s.data.clock<float(life.rest_until):life.energy=minf(100,life.energy+dt);continue
			if phase<13 or life.energy<20:
				life.action="수면";life.energy=minf(100,life.energy+dt*1.5)
			elif f.care and (phase<25 or life.hunger>55):
				life.action="식사";life.hunger=maxf(0,life.hunger-dt*2)
			else:
				life.action="대화" if f.members.size()>1 and phase<40 else ("문 살피기" if life.mood<35 else "배회")
				if s.data.clock>=float(life.next_move):
					life.next_move=s.data.clock+3
					var angle=float(index)+s.data.clock*.4
					life.destination=slot(f,index)+Vector2(cos(angle),sin(angle))*.18
				p.pos=p.pos.move_toward(life.destination,dt*.35)
			if life.mood<25 and phase>55:
				life.action="다툼";f.event="수감자 사이에 말다툼 · 경비 관찰 중"
			if s.data.clock>=float(life.next_escape):
				life.next_escape=s.data.clock+90
				if life.mood<35 or int(p.id.get_slice("_",1))%3==0 or security(f)==0:attempt(s,f,p)

static func summary(s,id: String) -> String:
	ensure(s);var f=s.Sandbox.facility(s,id)
	if f.is_empty():return "감옥을 찾을 수 없습니다."
	return "수감 %d/%d명 · 보안 %d/100\n자동 돌봄 %s · 잠금 %s · 경비 %s\n탈출 시도 %d · 저지 %d · 탈출 %d\n%s" %[f.members.size(),f.capacity,security(f),"켜짐" if f.care else "꺼짐","켜짐" if f.locked else "꺼짐","근무" if f.guard else "없음",f.attempts,f.caught,f.escaped,f.event]

static func inmate_summary(s,id: String) -> String:
	ensure(s)
	if not s.data.people.has(id) or s.data.people[id].state!="captive":return "현재 수감 중인 인물이 아닙니다."
	var p: Dictionary=s.data.people[id];var l: Dictionary=p.get("life",{})
	if l.is_empty():return "수감 중"
	return "%s · %s\n배고픔 %d/100 · 기력 %d/100\n기분 %d/100 · 탈출 시도 %d회" %[p.name,l.action,int(l.hunger),int(l.energy),int(l.mood),l.attempts]

static func manage(s,id: String,action: String) -> void:
	ensure(s)
	if action in ["feed_inmate","rest_inmate","release_inmate"]:
		if not s.data.people.has(id) or s.data.people[id].state!="captive":return
		var p: Dictionary=s.data.people[id]
		if action=="release_inmate":s.Sandbox.release(s,id);return
		if not p.has("life"):return
		if action=="feed_inmate":p.life.hunger=maxf(0,p.life.hunger-45);p.life.mood=minf(100,p.life.mood+5);p.life.action="식사"
		else:p.life.rest_until=s.data.clock+12;p.life.action="휴식"
		return
	var f=s.Sandbox.facility(s,id)
	if f.is_empty():return
	if action=="care_toggle":f.care=not f.care
	elif action=="security_toggle":f.guard=not f.guard;f.locked=f.guard
	elif action=="prison_expand":
		if int(f.capacity)>=12 or s.data.money<8:return
		s.data.money-=8;f.capacity=mini(12,int(f.capacity)+2);s.note("감옥 정원 %d명으로 증설했습니다." %f.capacity)
