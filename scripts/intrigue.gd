extends RefCounted
## Direct actions, witnesses, contracts and a limited physical investigation.
## Everything is stored in the shared simulation; presentation owns no game facts.

static func defaults() -> Dictionary:
	return {"selected":"","drag":"","cell":Vector2(99,99),"built":false,"upkeep":0.0,
		"heat":0,"reports":0,"staff_alarm":"idle","alarm_path":[],"event_serial":0,
		"contract":{"state":"offered","target":"","deadline":0.0,"held":0.0,"reward":24},
		"inspector":{"state":"idle","pos":Vector2(0.25,3.25),"floor":0,"path":[],"at":0.0,"remaining":0.0,"resolved":false},"reputation":0}

static func register(person: Dictionary) -> void:
	var extra: Dictionary={"floor":0,"wake_at":0.0,"facing":Vector2.LEFT,"seen":{},"report_pending":false,"alarm":false,"incident":0}
	for key in extra:
		if not person.has(key):person[key]=extra[key]

static func migrate(sim) -> void:
	if not sim.data.has("ops"):sim.data.ops=defaults()
	for person in sim.data.people.values():register(person)

static func selected(sim) -> String:
	var id: String=sim.data.ops.selected
	if sim.data.people.has(id) and sim.data.people[id].state!="gone":return id
	return ""

static func select_near(sim) -> String:
	var id: String=selected(sim)
	if id!="":return id
	var nearest: String=""
	var distance: float=1.5
	for key in sim.data.people:
		var person: Dictionary=sim.data.people[key]
		if person.floor!=sim.data.player.floor or person.state=="gone":continue
		var delta: float=person.pos.distance_to(sim.data.player.pos)
		if delta<distance:nearest=key;distance=delta
	return nearest

static func close(sim, id: String) -> bool:
	return sim.data.people.has(id) and sim.data.people[id].floor==sim.data.player.floor and sim.data.people[id].pos.distance_to(sim.data.player.pos)<1.35

static func available(sim) -> bool:
	return not sim.data.paused and sim.data.work.is_empty() and sim.data.dig.is_empty()

static func clear_orders(sim, id: String) -> void:
	for oid in sim.data.orders:
		var meal: Dictionary=sim.data.orders[oid]
		if meal.guest!=id or meal.status in ["served","cancelled"]:continue
		meal.status="cancelled"
		meal.holder=""
		if sim.data.player.carry==oid:sim.data.player.carry=""
		if sim.data.staff.carry==oid:sim.data.staff.carry=""
		if sim.data.work.get("order","")==oid:sim.data.work={}

static func release_room(sim, id: String) -> void:
	var person: Dictionary=sim.data.people[id]
	var key:=str(int(person.room))
	if sim.data.rooms.has(key) and sim.data.rooms[key].guest==id:
		sim.data.rooms[key].guest=""
		sim.data.rooms[key].dirty=true
	person.room=0

static func subdue(sim) -> bool:
	if not available(sim) or sim.data.ops.drag!="" or sim.data.player.carry!="":return false
	var id:=select_near(sim)
	if id=="" or not close(sim,id):sim.note("선택한 손님 가까이에서 제압을 시도한다.");return false
	if sim.data.people[id].state not in ["waiting","staying","entering","dining"]:return false
	sim.data.work={"type":"subdue","target":id,"remaining":2.0}
	sim.note("제압 시도 2초. 목격되면 신고될 수 있다. 중단 버튼으로 취소.")
	return true

static func quick_action(sim, action: String) -> bool:
	if not available(sim) or sim.data.player.carry!="":return false
	var id:=select_near(sim)
	if id=="" or not close(sim,id):return false
	var person: Dictionary=sim.data.people[id]
	if person.state not in ["arriving","waiting","staying","entering","dining","restrained","down","captive"]:return false
	if sim.data.ops.drag!="" and sim.data.ops.drag!=id:return false
	if action=="grab" and person.state in ["down","captive","restrained"]:return false
	sim.data.work={"type":"quick","action":action,"target":id,"remaining":0.7 if action=="grab" else (1.5 if action=="sleep" else 2.0)}
	sim.note({"grab":"다가가 붙잡는 중…","sleep":"기절시키는 중…","kill":"위험 행동 진행 중…"}[action])
	return true

static func update_quick_action(sim, dt: float) -> void:
	if sim.data.work.get("type","")!="quick":return
	sim.data.work.remaining-=dt
	if sim.data.work.remaining>0:return
	var job: Dictionary=sim.data.work.duplicate(); sim.data.work={}
	var id: String=job.target
	if not close(sim,id) or sim.data.people[id].state not in ["arriving","waiting","staying","entering","dining","restrained","down","captive"]:
		sim.note("대상이 멀어져 행동을 멈췄다.");return
	clear_orders(sim,id)
	var p: Dictionary=sim.data.people[id]
	p.incident+=1; p.path=[]
	if p.floor==1:
		sim.data.noise+=1.5 if job.action=="grab" else 3.0
		sim.data.stealth.source=p.pos
	match job.action:
		"grab":
			p.state="restrained"; sim.data.ops.drag=id
			sim.note("붙잡았다. 이동하거나 상대를 눌러 다음 행동을 고른다.")
		"sleep":
			p.state="down"; p.wake_at=sim.data.clock+45
			sim.note("잠시 기절했다. 45초 뒤 깨어난다.")
		"kill":
			p.state="dead"; release_room(sim,id)
			sim.note("상대가 사망했다. 시신과 목격 위험이 남는다.")
	witness(sim,id,"attack")

static func drag_or_release(sim) -> bool:
	if not available(sim):return false
	var ops: Dictionary=sim.data.ops
	if ops.drag!="":
		sync_drag(sim)
		var held: String=ops.drag
		ops.drag=""
		if sim.data.people[held].state=="restrained": flee(sim,held); sim.note("붙잡은 상대를 놓았다. 달아나 신고하려 한다."); return true
		sim.note("대상을 바닥에 내려놓았다. 회복 시간은 계속 흐른다.")
		return true
	var id:=select_near(sim)
	if id=="" or not close(sim,id):sim.note("대상을 선택하고 끌기 또는 석방을 누른다.");return false
	var person: Dictionary=sim.data.people[id]
	if person.state=="captive":
		flee(sim,id)
		sim.note("구금을 풀었다. 상대는 출구로 달아나 신고하려 한다.")
		return true
	if person.state not in ["down","dead"] or sim.data.player.carry!="":return false
	ops.drag=id
	sync_drag(sim)
	sim.note("대상을 끌고 간다. 이동이 느려지며 층 이동 버튼으로 함께 내려간다.")
	return true

static func sync_drag(sim) -> void:
	var id: String=sim.data.ops.drag
	if id=="" or not sim.data.people.has(id):return
	sim.data.people[id].pos=sim.data.player.pos
	sim.data.people[id].floor=sim.data.player.floor

static func build_or_hold(sim) -> bool:
	if not available(sim) or sim.data.player.floor!=1:return false
	var ops: Dictionary=sim.data.ops
	if not ops.built:
		if sim.data.player.pos.length()<1.9:sim.note("입구에서 두 칸 이상 떨어진 열린 땅에 구금칸을 만든다.");return false
		if sim.data.money<8:sim.note("구금칸 설치 비용 8닢이 부족하다.");return false
		ops.cell=Vector2(roundi(sim.data.player.pos.x),roundi(sim.data.player.pos.y))
		if not sim.walkable(ops.cell,1):return false
		sim.data.money-=8
		ops.built=true
		ops.upkeep=sim.data.clock+30
		sim.note("구금칸 설치. 유지비 30초마다 1닢 / 운반 후 구금하기를 누른다.")
		return true
	if sim.data.player.pos.distance_to(ops.cell)>1.2:sim.note("구금하기를 선택하면 구금칸으로 이동한다.");return false
	for person in sim.data.people.values():
		if person.state=="captive":sim.note("구금칸은 한 명만 수용한다.");return false
	var id: String=ops.drag
	if id=="":return false
	var person: Dictionary=sim.data.people[id]
	if person.state=="dead":sim.note("시신은 구금할 수 없다. 내려놓을 위치를 선택하자.");return false
	person.pos=ops.cell
	person.floor=1
	person.state="captive"
	ops.drag=""
	release_room(sim,id)
	sim.note("지하에 구금했다. 대상을 선택해 석방할 수 있다. 유지비가 없으면 탈출한다.")
	return true

static func basement_route(sim, from: Vector2, to: Vector2) -> Array:
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(-sim.CELLAR_LIMIT,sim.CELLAR_LIMIT*2+Vector2i.ONE)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(-sim.CELLAR_LIMIT.x,sim.CELLAR_LIMIT.x+1):
		for y in range(-sim.CELLAR_LIMIT.y,sim.CELLAR_LIMIT.y+1):grid.set_point_solid(Vector2i(x,y),not sim.walkable(Vector2(x,y),1))
	var a:=Vector2i(roundi(from.x),roundi(from.y))
	var b:=Vector2i(roundi(to.x),roundi(to.y))
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b):return []
	return Array(grid.get_point_path(a,b))

static func flee(sim, id: String) -> void:
	var person: Dictionary=sim.data.people[id]
	clear_orders(sim,id)
	release_room(sim,id)
	if sim.data.ops.drag==id:sim.data.ops.drag=""
	person.state="escaping" if person.floor!=0 else "leaving"
	person.report_pending=true
	person.path=sim.gallery_route(person.pos,sim.STAIRS) if person.floor==2 else (basement_route(sim,person.pos,Vector2.ZERO) if person.floor==1 else sim.path_to(person.pos,sim.ENTRY))
	if sim.data.has("sandbox") and person.floor==1:
		var e=preload("res://scripts/inn_sandbox.gd").nearest(sim,person.pos,1)
		if not e.is_empty():person.path=basement_route(sim,person.pos,Vector2(e.bottom));person.escape_top=e.top

static func sees(sim, watcher: Dictionary, point: Vector2, floor_: int, cone: bool=true) -> bool:
	if int(watcher.get("floor",0))!=floor_:return false
	var delta: Vector2=point-watcher.pos
	if delta.length()>4.8:return false
	if cone and delta.length()>0.1 and watcher.facing.dot(delta.normalized())<cos(deg_to_rad(65)):return false
	if floor_==1 and delta.length()>1.25 and not sim.basement_lit(point):return false
	if floor_==0:return sim.sight_end(watcher.pos,delta.normalized()).distance_to(watcher.pos)+0.11>=delta.length()
	for step in range(1,ceili(delta.length()*10)):
		if not sim.walkable(watcher.pos+delta.normalized()*float(step)*0.1,floor_):return false
	return true

static func witness(sim, id: String, _kind: String) -> void:
	var victim: Dictionary=sim.data.people[id]
	var token:="incident:"+id+":"+str(int(victim.incident))
	for key in sim.data.people.keys():
		var person: Dictionary=sim.data.people[key]
		if key==id or person.state not in ["waiting","staying","entering","dining"] or person.seen.has(token):continue
		if sees(sim,person,victim.pos,victim.floor):
			person.seen[token]=true
			sim.note("%s이 수상한 행동을 목격했다. 출구로 향한다." % person.name)
			flee(sim,key)
	if victim.floor==0 and sim.staff_sees(victim.pos):
		var staff: Dictionary=sim.data.staff
		if not staff.has("seen"):staff.seen={}
		if not staff.seen.has(token):
			staff.seen[token]=true
			sim.data.stealth.memory+=1
			sim.data.stealth.suspicion=maxf(sim.data.stealth.suspicion,80)
			if sim.data.ops.staff_alarm=="idle":sim.data.ops.staff_alarm="pending"
			sim.note("직원이 목격했다. 하던 일을 마친 뒤 문으로 가 경비를 부른다.")

static func report(sim, source: String) -> void:
	var ops: Dictionary=sim.data.ops
	ops.reports+=1
	ops.heat=mini(100,int(ops.heat)+30)
	var inspector: Dictionary=ops.inspector
	if inspector.state=="idle":
		inspector.state="scheduled"
		inspector.at=sim.data.clock+15
		inspector.resolved=false
		sim.note("%s의 신고. 경비가 15초 뒤 조사하러 온다." % source)

static func staff_alarm_step(sim, dt: float) -> bool:
	var ops: Dictionary=sim.data.ops
	if ops.staff_alarm=="idle":return false
	var worker: Dictionary=sim.data.staff
	if ops.staff_alarm=="pending":
		worker.path=sim.path_to(worker.pos,sim.ENTRY)
		ops.staff_alarm="go"
		sim.data.stealth.phase="idle"
	worker.mode="alarm"
	sim.follow(worker,dt*1.4)
	if worker.path.is_empty():
		report(sim,"직원")
		ops.staff_alarm="idle"
		worker.mode="return"
	return true

static func contract_action(sim, protect: bool=false) -> bool:
	if not available(sim) or not sim.near_counter():sim.note("접수대 가까이에서 의뢰를 결정한다.");return false
	var contract: Dictionary=sim.data.ops.contract
	if contract.state=="offered":
		if protect:
			contract.state="declined"
			sim.data.ops.reputation+=1
			sim.note("비밀 의뢰를 거절했다. 정상 영업을 계속한다.")
			return true
		var target: String=selected(sim)
		if target=="" or sim.data.people[target].state not in ["waiting","staying","entering","dining"]:
			target=""
			for id in sim.data.people:
				if sim.data.people[id].state in ["waiting","staying","entering","dining"]:target=id;break
		if target=="":sim.note("의뢰 대상이 될 손님이 아직 없다.");return false
		contract.target=target
		contract.state="active"
		contract.deadline=sim.data.clock+180
		sim.data.ops.selected=target
		sim.note("의뢰: %s을 지하에 30초 붙잡아 두라. 제한 180초 / 보수 24닢." % sim.data.people[target].name)
		return true
	if protect and contract.state=="active":
		var person: Dictionary=sim.data.people[contract.target]
		if person.state not in ["waiting","staying","entering","dining"]:sim.note("먼저 위해를 가한 뒤 보호 보수를 받을 수는 없다.");return false
		contract.state="protected"
		sim.data.money+=8
		sim.data.ops.reputation+=2
		sim.note("의뢰를 폭로하고 손님을 보호했다. 감사금 8닢을 받았다.")
		return true
	if contract.state=="ready":
		contract.state="paid"
		sim.data.money+=int(contract.reward)
		sim.note("접수대에서 비밀 의뢰 보수 24닢을 받았다. 구금자는 아직 지하에 있다.")
		return true
	return false

static func inspector_action(sim, bribe: bool=false) -> bool:
	var inspector: Dictionary=sim.data.ops.inspector
	if not sim.near_counter() or inspector.state!="waiting" or not available(sim):return false
	if bribe:
		if sim.data.ops.reports>=2:sim.note("신고가 여럿이라 경비가 뇌물을 거절했다.");return true
		if sim.data.money<12:sim.note("뇌물 12닢이 부족하다.");return true
		sim.data.money-=12
		inspector.resolved=true
		end_inspection(sim)
		sim.note("12닢을 건네 이번 방문을 돌려보냈다. 목격 기억은 남는다.")
	else:
		inspector.state="search"
		inspector.path=sim.path_to(inspector.pos,sim.HATCH)
		if sim.data.has("sandbox"):inspection_entry(sim)
		inspector.remaining=12
		sim.note("경비가 지하 입구 주변을 조사한다. 깊은 지하 전체를 수색하는 것은 아니다.")
	return true

static func end_inspection(sim) -> void:
	var inspector: Dictionary=sim.data.ops.inspector
	sim.data.ops.heat=maxi(0,int(sim.data.ops.heat)-20)
	if inspector.floor==1:
		inspector.state="return_below"
		inspector.path=basement_route(sim,inspector.pos,inspector.get("bottom",Vector2.ZERO))
	else:
		inspector.state="leaving"
		inspector.path=sim.path_to(inspector.pos,sim.GATE)

static func discover(sim) -> bool:
	var inspector: Dictionary=sim.data.ops.inspector
	if inspector.resolved:return false
	for id in sim.data.people:
		var person: Dictionary=sim.data.people[id]
		if person.state not in ["down","captive","dead","restrained"]:continue
		if sees(sim,inspector,person.pos,person.floor,false):
			inspector.resolved=true
			if person.state=="dead":
				sim.charge(40,"시신 발견 조사"); sim.data.ops.heat=mini(100,int(sim.data.ops.heat)+25)
				sim.note("경비가 시신을 발견했다. 중범죄 조사 비용과 기록이 남는다.")
				end_inspection(sim); return true
			sim.charge(20,"불법 구금 적발 벌금")
			flee(sim,id)
			# Already part of this case: this released person's exit is not a new case.
			person.report_pending=false
			sim.note("경비가 대상을 발견해 풀어줬다. 벌금과 미납은 기록된다.")
			end_inspection(sim)
			return true
	return false

static func update_inspector(sim, dt: float) -> void:
	var inspector: Dictionary=sim.data.ops.inspector
	if inspector.state=="scheduled" and sim.data.clock>=inspector.at:
		inspector.state="entering"
		inspector.pos=sim.GATE
		inspector.floor=0
		inspector.path=sim.path_to(inspector.pos,sim.COUNTER)
		sim.note("신고를 받은 경비가 도착했다. 의뢰 창에서 조사 허용 또는 뇌물을 선택한다.")
	if inspector.state in ["entering","search","sweep","return_below","leaving"]:
		sim.follow(inspector,dt*1.15)
		if inspector.state in ["entering","search","sweep"] and discover(sim):return
		if inspector.path.is_empty():
			match inspector.state:
				"entering":inspector.state="waiting";inspector.remaining=20
				"search":
					inspector.floor=1
					inspector.pos=inspector.get("bottom",Vector2.ZERO)
					inspector.state="sweep"
					inspector.path=basement_route(sim,inspector.pos,inspector.pos+Vector2(1,0))
				"return_below":
					inspector.floor=0
					inspector.pos=inspector.get("top",sim.HATCH)
					inspector.state="leaving"
					inspector.path=sim.path_to(inspector.pos,sim.GATE)
				"leaving":inspector.state="idle"
	if inspector.state=="waiting":
		inspector.remaining-=dt
		if inspector.remaining<=0:inspector_action_for_timeout(sim)
	elif inspector.state=="sweep":
		inspector.remaining-=dt
		if inspector.remaining<=0:
			inspector.resolved=true
			end_inspection(sim)
			sim.note("경비가 입구 주변에서 증거를 찾지 못하고 돌아간다.")

static func inspector_action_for_timeout(sim) -> void:
	var inspector: Dictionary=sim.data.ops.inspector
	inspector.state="search"
	inspector.remaining=12
	inspector.path=sim.path_to(inspector.pos,sim.HATCH)
	if sim.data.has("sandbox"):inspection_entry(sim)
	sim.note("응답이 없어 경비가 입구 주변 조사에 들어간다.")

static func tick(sim, dt: float) -> void:
	var ops: Dictionary=sim.data.ops
	sync_drag(sim)
	update_quick_action(sim,dt)
	if sim.data.work.get("type","")=="subdue":
		sim.data.work.remaining-=dt
		if sim.data.work.remaining<=0:
			var id: String=sim.data.work.target
			sim.data.work={}
			if close(sim,id) and sim.data.people[id].state in ["waiting","staying","entering","dining"]:
				clear_orders(sim,id)
				var person: Dictionary=sim.data.people[id]
				person.incident+=1
				person.state="down"
				person.wake_at=sim.data.clock+45
				person.path=[]
				witness(sim,id,"attack")
				sim.note("%s이 쓰러졌다. 45초 뒤 회복한다. 대상을 선택하고 끌고 가기를 누른다." % person.name)
			else:sim.note("대상이 멀어져 제압에 실패했다.")
	for id in sim.data.people.keys():
		var person: Dictionary=sim.data.people[id]
		if person.state=="dead" or (person.state=="restrained" and not person.get("escorted",false)):witness(sim,id,"body")
		if person.state=="down":
			witness(sim,id,"body")
			if sim.data.clock>=person.wake_at:
				flee(sim,id)
				sim.note("%s이 깨어나 도망친다." % person.name)
		elif person.state=="escaping":
			sim.follow(person,dt*1.4)
			if person.path.is_empty():
				person.pos=sim.STAIRS if person.floor==2 else person.get("escape_top",sim.HATCH)
				person.floor=0
				person.state="leaving"
				person.path=sim.path_to(person.pos,sim.ENTRY)
		if person.state=="gone" and person.report_pending:
			person.report_pending=false
			report(sim,str(person.name))
	if ops.built and sim.data.clock>=ops.upkeep:
		ops.upkeep=sim.data.clock+30
		for id in sim.data.people:
			if sim.data.people[id].state=="captive":
				if sim.data.money>=1:sim.data.money-=1
				else:flee(sim,id);sim.note("구금 유지비가 없어 상대가 탈출했다.")
	var contract: Dictionary=ops.contract
	if contract.state=="active":
		var target: Dictionary=sim.data.people[contract.target]
		if sim.data.clock>contract.deadline:
			contract.state="failed"
			sim.note("의뢰 제한 시간이 지났다.")
		elif target.state=="captive":
			contract.held+=dt
			if contract.held>=30:contract.state="ready";sim.note("억류 의뢰 조건 달성. 의뢰 창에서 보수를 받는다.")
		elif target.state in ["gone","escaping","leaving","dead"] or sim.data.clock>contract.deadline:
			contract.state="failed"
			sim.note("의뢰를 실패했다. 대상이 떠났거나 제한 시간이 지났다.")
	update_inspector(sim,dt)

static func inspection_entry(sim) -> void:
	var guard: Dictionary=sim.data.ops.inspector
	var entries: Array=sim.data.sandbox.entrances.filter(func(e):return e.open)
	if entries.is_empty():
		guard.resolved=true;end_inspection(sim);sim.note("경비가 홀과 마당을 살폈지만 숨겨진 입구는 찾지 못했다.");return
	var e: Dictionary=entries[0];guard.top=e.top;guard.bottom=Vector2(e.bottom);guard.path=sim.path_to(guard.pos,e.top)
