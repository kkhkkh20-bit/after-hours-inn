extends RefCounted
## Authoritative inn state. No UI, meshes, physics server or wall-clock dependency.

const Intrigue = preload("res://scripts/intrigue.gd")
const COUNTER := Vector2(-1.75, -1.75)
const ENTRY := Vector2(0.25, 3.25)
const GATE := Vector2(22.25,3.25)
const HATCH := Vector2(-3.25, 2.75)
const STAIRS := Vector2(8.0, 5.0)
const CELLAR_LIMIT := Vector2i(22,12)
const SAVE_VERSION := 3
var travel_multiplier:=1.0
var obstacles: Array[Rect2] = []
var grid := AStarGrid2D.new()
var data: Dictionary

func _init() -> void:
	data = {"clock":0.0, "speed":1, "paused":false, "money":24, "next_guest":22.0,
		"serial":0, "order_serial":0, "people":{}, "orders":{},
		"rooms":{"1":{"guest":"", "dirty":false}, "2":{"guest":"", "dirty":false}},
		"player":{"pos":Vector2(0.25, 1.75), "floor":0, "carry":""},
		"staff":{"hired":false,"delegated":false,"pos":COUNTER,"carry":"","path":[],"mode":"idle","target":"","distance":0.0,"facing":Vector2.DOWN},
		"work":{}, "dues":{"wage":1200,"rent":1980,"tax":2160}, "debt":0,
		"collector":false,"tax_paid":false,"cells":{}, "dig":{}, "noise":0.0,
		"logs":[], "served":0, "departed":0}
	data.stealth = stealth_defaults()
	data.ops=Intrigue.defaults()
	data.excavation=excavation_defaults()
	for x in range(-3,2):
		for y in range(-2,3): data.cells[cell_key(Vector2i(x,y))] = true
	# A short existing cellar passage and storeroom establish what digging can extend.
	for x in range(2,9):
		for y in range(2,4):data.cells[cell_key(Vector2i(x,y))]=true
	for x in range(7,12):
		for y in range(0,4):data.cells[cell_key(Vector2i(x,y))]=true
	data.excavation.storeroom=true
	spawn_guest()
	note("손님이 도착했다. 영업 창에서 객실을 배정하자.")

func note(text: String) -> void:
	data.logs.append({"time":int(data.clock),"text":text})
	if data.logs.size() > 30: data.logs.pop_front()

func add_obstacle(rect: Rect2) -> void:
	obstacles.append(rect.grow(0.18))

func rebuild_grid() -> void:
	grid.region = Rect2i(0,0,76,40)
	grid.cell_size = Vector2(0.5,0.5)
	grid.offset = Vector2(-13.75,-7.75)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(76):
		for y in range(40):
			var id := Vector2i(x,y)
			grid.set_point_solid(id, not surface_walkable(grid.get_point_position(id)))

func surface_walkable(pos: Vector2) -> bool:
	if not Rect2(-13.8,-7.8,38.0,20.0).has_point(pos): return false
	for rect in obstacles:
		if rect.has_point(pos): return false
	return true

func walkable(pos: Vector2, floor_: int) -> bool:
	if floor_ == 0: return surface_walkable(pos)
	if floor_ == 2: return gallery_walkable(pos)
	if data.excavation.get("storeroom",false) and data.cells.has("10,0") and Rect2(7.5,-0.5,3.05,1).has_point(pos):return false
	# Sample the actor footprint, so shoulders cannot cross unopened earth.
	for shift in [Vector2.ZERO,Vector2(0.19,0),Vector2(-0.19,0),Vector2(0,0.19),Vector2(0,-0.19)]:
		if not data.cells.has(cell_key(Vector2i(roundi(pos.x+shift.x),roundi(pos.y+shift.y)))): return false
	return true

# The gallery and its stair share a continuous walking surface, above the hall.
static func gallery_walkable(pos: Vector2) -> bool:
	for x in [-6,0,6]:
		if Rect2(x-0.85,-8.5,1.7,2.5).has_point(pos):return false
	for x in [-3,3]:
		if Rect2(x-0.25,-8.5,0.5,2.2).has_point(pos):return false
	return Rect2(-9.0,-8.5,18.0,5.0).has_point(pos) or Rect2(7.0,-5.5,2.0,11.0).has_point(pos)

static func floor_height(pos: Vector2, floor_: int) -> float:
	if floor_ != 2:return 0.0
	return clampf((5.0-pos.y)/4.0,0.0,1.0)*3.2

func gallery_route(from: Vector2, to: Vector2) -> Array:
	var upstairs:=AStarGrid2D.new()
	upstairs.region=Rect2i(0,0,40,30)
	upstairs.cell_size=Vector2(0.5,0.5)
	upstairs.offset=Vector2(-9.75,-8.75)
	upstairs.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	upstairs.update()
	for x in range(40):
		for y in range(30):
			var id:=Vector2i(x,y)
			upstairs.set_point_solid(id,not gallery_walkable(upstairs.get_point_position(id)))
	var a:=Vector2i(floori((from.x+10)/0.5),floori((from.y+9)/0.5))
	var b:=Vector2i(floori((to.x+10)/0.5),floori((to.y+9)/0.5))
	if not upstairs.is_in_boundsv(a) or not upstairs.is_in_boundsv(b):return []
	if upstairs.is_point_solid(a) or upstairs.is_point_solid(b):return []
	return Array(upstairs.get_point_path(a,b))

func queue_gallery() -> bool:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty():return false
	if data.player.floor==1:note("먼저 지하에서 올라오자.");return false
	data.excavation.intent=""
	data.excavation.path=[]
	var route: Array=gallery_route(data.player.pos,STAIRS) if data.player.floor==2 else path_to(data.player.pos,STAIRS)
	if route.is_empty():return false
	data.excavation.path=route
	data.excavation.intent="gallery_down" if data.player.floor==2 else "gallery_up"
	data.ops.selected=""
	return true

func path_to(from: Vector2, to: Vector2) -> Array:
	var a := Vector2i(floori((from.x+14)/0.5),floori((from.y+8)/0.5))
	var b := Vector2i(floori((to.x+14)/0.5),floori((to.y+8)/0.5))
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b): return []
	if grid.is_point_solid(a) or grid.is_point_solid(b): return []
	return Array(grid.get_point_path(a,b))

func move_player(offset: Vector2) -> void:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty(): return
	if offset.length()>0.001:
		data.excavation.path=[]
		data.excavation.intent=""
	var remaining := offset
	while remaining.length() > 0.0001:
		var step := remaining.limit_length(0.08)
		var p: Vector2 = data.player.pos
		if walkable(p+Vector2(step.x,0),data.player.floor): p.x += step.x
		if walkable(p+Vector2(0,step.y),data.player.floor): p.y += step.y
		data.player.pos = p
		remaining -= step
	Intrigue.sync_drag(self)

func calendar_text() -> String:
	var minutes=int(480+data.clock*3)
	return "%d일차 %02d:%02d · %s" %[1+minutes/1440,(minutes%1440)/60,minutes%60,"낮" if minutes%1440>=360 and minutes%1440<1200 else "밤"]

func request_room(number: int,id: String) -> bool:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty():note("현재 작업을 마치거나 주인을 눌러 취소하자.");return false
	if not data.people.has(id) or data.rooms[str(number)].guest!="":return false
	if preload("res://scripts/inn_campaign.gd").active(self) and not data.people[id].get("known",false):note("먼저 손님에게 말을 걸어 원하는 것을 듣자.");return false
	if data.rooms[str(number)].dirty:
		data.booking_request={"room":number,"guest":id}
		note("%d호를 정리한 뒤 손님을 안내한다." %number)
		return queue_command("clean"+str(number))
	return queue_command("admit"+str(number),id)

func update_booking() -> void:
	if data.get("booking_request",{}).is_empty():return
	var job: Dictionary=data.booking_request
	if not data.people.has(job.guest) or data.people[job.guest].state not in ["waiting","arriving"]:
		data.booking_request={};return
	if not data.rooms[str(job.room)].dirty and data.work.is_empty() and data.excavation.intent=="":
		data.booking_request={}; queue_command("admit"+str(job.room),job.guest)

func gentle_opening() -> bool:
	return data.get("opening",{}).get("active",false)

func start_gentle_opening() -> void:
	data.opening={"active":true,"natural":true}
	data.people.clear(); data.serial=0; data.logs.clear()
	spawn_guest(); data.next_guest=48.0
	note("손님을 누르고 방을 골라주세요. 주인이 알아서 다가갑니다.")

func spawn_guest() -> void:
	if waiting().filter(func(id): return data.people[id].get("role","") not in ["worker","broker"]).size() >= (1 if gentle_opening() and data.served<1 else 2): return

	var natural: bool=data.get("opening",{}).get("natural",false)
	var meal_only=natural and (int(data.serial)+1)%3==2
	if natural and data.rooms.values().all(func(room_): return room_.guest!=""):meal_only=true
	if meal_only and data.people.values().filter(func(p): return p.get("visit","")=="meal" and p.state!="gone").size()>=2:return
	data.serial += 1
	var id := "guest_%d" % data.serial
	var templates := [["행상 로웬","조용한 방을 원한다",10],["전령 에다","식사를 서둘러 달라고 한다",8],["병사 브란","낯선 사람을 경계한다",12],["약초상 메린","먼 길을 걸어 피곤해한다",9]]
	var sample: Array = templates[(int(data.serial)-1)%templates.size()]
	data.people[id] = {"id":id,"name":sample[0],"trait":sample[1],"rate":sample[2],
		"visit":"meal" if meal_only else "stay","pos":ENTRY,"state":"waiting","room":0,"path":[],"arrival":data.clock,
		"checkout":0.0,"order_at":0.0,"meals":0}
	Intrigue.register(data.people[id])
	if data.get("opening",{}).get("natural",false):
		var seats=[Vector2(-3.75,1.75),Vector2(-6.25,2.75),Vector2(-1.25,0.75)]
		var p: Dictionary=data.people[id]
		p.pos=Vector2(14.25,3.25); p.state="arriving"
		p.path=path_to(p.pos,seats[(int(data.serial)-1)%seats.size()])
	if data.serial > 1: note("%s 도착: %s" % [sample[0],sample[1]])

func waiting() -> Array:
	var result: Array = []
	for id in data.people:
		if data.people[id].state in ["waiting","arriving"]: result.append(id)
	return result

func room_target(number: int) -> Vector2:
	return Vector2(3.25, -2.25 if number==1 else 1.75)

func near_counter() -> bool:
	return data.player.floor == 0 and data.player.pos.distance_to(COUNTER)<2.0

func assign_room(number: int, guest_id: String="") -> bool:
	var direct=guest_id!="" and data.people.has(guest_id) and data.people[guest_id].floor==data.player.floor and data.player.pos.distance_to(data.people[guest_id].pos)<1.35
	if data.paused or (not direct and not near_counter()):
		note("접수대 가까이에서 객실을 배정해야 한다.")
		return false
	var key := str(number)
	if not data.rooms.has(key): return false
	var room_: Dictionary = data.rooms[key]
	if room_.guest != "" or room_.dirty:
		note("%d호는 사용 중이거나 청소가 필요하다." % number)
		return false
	if waiting().is_empty():
		note("입실을 기다리는 손님이 없다.")
		return false
	var id: String = guest_id if guest_id!="" else waiting()[0]
	if id not in waiting(): return false
	var person: Dictionary = data.people[id]
	var path := path_to(person.pos,room_target(number))
	if path.is_empty():
		note("객실까지 갈 수 없다. 통로를 확인해야 한다.")
		return false
	room_.guest = id
	person.room = number
	person.state = "entering"
	person.path = path
	person.checkout = (floorf(data.clock/480.0)+1)*480.0 if data.get("opening",{}).get("natural",false) else data.clock+105.0
	if preload("res://scripts/inn_campaign.gd").active(self):
		data.campaign.bookings+=1
		if person.get("known",false):
			var preferred=1 if person.get("role","")=="fugitive" or (int(id.get_slice("_",1))-1)%4 in [0,2] else 2
			data.campaign.reputation+=1 if number==preferred else -1
			if number==preferred and int(person.rate)>0:data.money+=2;note("방이 마음에 든 손님이 2닢을 더 건넸다.")
	data.money += int(person.rate)
	note("%s → %d호. 숙박비 %d닢을 받았다." % [person.name,number,person.rate])
	return true

func reject_guest() -> void:
	if data.paused or not near_counter() or waiting().is_empty(): return
	var person: Dictionary = data.people[waiting()[0]]
	person.state = "leaving"
	person.path = path_to(person.pos,ENTRY)
	note("%s의 숙박을 거절했다." % person.name)

func create_order(id: String) -> String:
	data.order_serial += 1
	var order_id := "meal_%d" % data.order_serial
	data.orders[order_id] = {"id":order_id,"guest":id,"status":"queued","holder":"","created":data.clock,"remaining":3.0,"paid":false}
	data.people[id].meals += 1
	note("%s: 따뜻한 식사를 주문했다." % data.people[id].name)
	return order_id

func can_receive(id: String) -> bool:
	return data.people.has(id) and data.people[id].state in ["staying","dining"]

func start_cooking(order_id: String, holder: String) -> bool:
	var order_: Dictionary = data.orders[order_id]
	if order_.status != "queued" or order_.holder not in ["",holder] or data.money < 1 or not can_receive(order_.guest): return false
	data.money -= 1
	order_.status = "cooking"
	order_.holder = holder
	order_.remaining = 3.0
	return true

func pickup(order_id: String, holder: String) -> bool:
	var order_: Dictionary = data.orders[order_id]
	if order_.status != "ready" or order_.holder not in ["",holder] or not can_receive(order_.guest): return false
	if (data.player.carry if holder == "player" else data.staff.carry) != "": return false
	order_.status = "carried"
	order_.holder = holder
	if holder == "player": data.player.carry = order_id
	else: data.staff.carry = order_id
	return true

func deliver(order_id: String, holder: String) -> bool:
	if not data.orders.has(order_id): return false
	var order_: Dictionary = data.orders[order_id]
	if order_.status != "carried" or order_.holder != holder or order_.paid or not can_receive(order_.guest): return false
	var position_: Vector2 = data.player.pos if holder=="player" else data.staff.pos
	if holder=="player" and data.player.floor != 0: return false
	if position_.distance_to(data.people[order_.guest].pos)>1.2: return false
	order_.paid = true
	order_.status = "served"
	order_.holder = ""
	if holder=="player": data.player.carry=""
	else: data.staff.carry=""
	data.money += 4
	data.served += 1
	if data.people[order_.guest].get("visit","")=="meal": data.people[order_.guest].checkout=data.clock+8
	note("%s에게 식사 전달. 4닢을 받았다." % data.people[order_.guest].name)
	return true

func interact() -> void:
	if data.paused: return
	if not data.work.is_empty() or not data.dig.is_empty():
		note("작업 중이다. 화면의 중단 버튼을 누를 수 있다.")
		return
	if data.player.floor==1:
		dig_nearest()
		return
	if Intrigue.inspector_action(self):return
	if data.ops.drag!="":note("끌고 있는 대상을 먼저 내려놓아야 한다.");return
	if explain_noise(): return
	if data.player.carry != "":
		if not deliver(data.player.carry,"player"): note("주문한 손님 가까이로 가야 한다.")
		return
	if near_counter():
		if data.collector:
			if data.money>=8:
				data.money-=8
				data.collector=false
				data.tax_paid=true
				note("징수원에게 세금 8닢을 냈다.")
			else: note("세금 8닢이 부족하다. 징수원이 기다린다.")
			return
		for id in data.orders:
			if pickup(id,"player"):
				note("식사를 들었다. 주문한 손님에게 가져가자.")
				return
		for id in data.orders:
			if start_cooking(id,"player"):
				data.work={"type":"cook","order":id,"remaining":3.0}
				note("식사 준비 중. 재료비 1닢 / 3초.")
				return
		note("지금 준비할 주문이 없다.")
		return
	if data.player.floor==0:
		for key in data.rooms:
			if data.rooms[key].dirty and data.player.pos.distance_to(room_target(int(key)))<1.6:
				data.work={"type":"clean","room":key,"remaining":4.0}
				note("%s호 청소 중. 4초가 걸린다." % key)
				return
	note("영업 창에서 식사 준비와 객실 청소를 선택한다.")

func toggle_staff() -> void:
	if data.paused: return
	if not data.staff.hired:
		if not near_counter():
			note("관리 창에서 직원을 고용할 수 있다.")
			return
		if data.money<3:
			note("고용 준비금 3닢이 부족하다.")
			return
		data.money-=3
		data.staff.hired=true
		data.staff.delegated=true
		note("직원 고용. 준비금 3닢 / 매일 20시 임금 4닢. 서빙을 맡겼다.")
	else:
		data.staff.delegated=not data.staff.delegated
		note("직원에게 식사 준비·서빙을 맡겼다." if data.staff.delegated else "직원 위임을 해제했다. 진행 중인 주문은 마무리한다.")

func tick(delta: float) -> void:
	if data.paused: return
	var remaining := delta
	while remaining>0.00001:
		var step := minf(remaining,0.1)
		_step(step)
		remaining-=step

func _step(dt: float) -> void:
	data.clock+=dt
	data.noise=maxf(0,data.noise-dt*0.5)
	if data.clock>=data.next_guest:
		data.next_guest=data.clock+(48.0+float(int(data.serial)%3)*9.0 if data.get("opening",{}).get("natural",false) else 32.0)
		spawn_guest()
	for id in data.people.keys():
		var person: Dictionary=data.people[id]
		if person.state=="waiting" and data.clock-person.arrival>(150 if gentle_opening() else 65):
			person.state="leaving"
			person.path=path_to(person.pos,GATE if data.get("opening",{}).get("natural",false) else ENTRY)
			note("%s이 기다리다 떠난다." % person.name)
		if person.state in ["arriving","entering","leaving"]:
			follow(person,dt*1.15)
			if person.path.is_empty():
				if person.state=="arriving":
					person.state="dining" if person.get("visit","")=="meal" else "waiting"; person.arrival=data.clock
					if person.state=="dining": person.order_at=data.clock+0.5; person.checkout=data.clock+90
				elif person.state=="entering":
					person.state="staying"
					person.order_at=data.clock+3
				else:
					person.state="gone"
					data.departed+=1
		if person.state in ["staying","dining"]:
			if data.clock>=person.checkout:
				checkout(id)
			elif data.clock>=person.order_at and person.meals<(1 if person.get("visit","")=="meal" else 2):
				create_order(id)
				person.order_at=data.clock+45
	for order_id in data.orders:
		var order_: Dictionary=data.orders[order_id]
		if order_.status=="cooking":
			order_.remaining-=dt
			if order_.holder=="player" and not data.work.is_empty(): data.work.remaining=order_.remaining
			if order_.remaining<=0:
				order_.status="ready"
				if order_.holder=="player":
					data.work={}
					pickup(order_id,"player")
					note("식사가 준비됐다. 주문한 손님에게 전달하자.")
	update_excavation(dt)
	Intrigue.tick(self,dt)
	update_work(dt)
	update_awareness(dt)
	update_worker(dt)
	update_money()
	update_direct_service()
	update_booking()

func follow(person: Dictionary, amount: float) -> void:
	while amount>0 and not person.path.is_empty():
		var target: Vector2=person.path[0]
		if person.has("facing") and person.pos.distance_to(target)>0.001: person.facing=(target-person.pos).normalized()
		var distance: float=person.pos.distance_to(target)
		if distance<=amount:
			if person.has("distance"): person.distance+=distance
			person.pos=target
			person.path.pop_front()
			amount-=distance
		else:
			if person.has("distance"): person.distance+=amount
			person.pos=person.pos.move_toward(target,amount)
			amount=0

func checkout(id: String) -> void:
	var person: Dictionary=data.people[id]
	if int(person.room)>0:
		data.rooms[str(int(person.room))].guest=""
		data.rooms[str(int(person.room))].dirty=true
	person.state="leaving"
	person.path=path_to(person.pos,GATE if data.get("opening",{}).get("natural",false) else ENTRY)
	for oid in data.orders:
		var order_: Dictionary=data.orders[oid]
		if order_.guest==id and order_.status not in ["served","cancelled"]:
			order_.status="cancelled"
			if data.player.carry==oid: data.player.carry=""
			if data.staff.carry==oid: data.staff.carry=""
			if data.work.get("order","")==oid: data.work={}
			order_.holder=""
	note("%s이 식사를 마치고 떠난다." %person.name if person.get("visit","")=="meal" else "%s 퇴실. %d호 청소가 필요하다." % [person.name,person.room])

func update_worker(dt: float) -> void:
	var worker: Dictionary=data.staff
	if not worker.hired: return
	if data.clock<data.stealth.refuse_until:
		worker.mode="refuse"
		return
	if worker.carry!="":
		var order_: Dictionary=data.orders[worker.carry]
		if not can_receive(order_.guest): return
		var target: Vector2=data.people[order_.guest].pos
		if worker.pos.distance_to(target)<1.1:
			deliver(worker.carry,"staff")
			worker.mode="idle"
			worker.target=""
			worker.path=[]
		else:
			if worker.path.is_empty(): worker.path=path_to(worker.pos,target)
			follow(worker,dt*1.25)
		return
	if worker.target!="" and data.orders.has(worker.target):
		var order_: Dictionary=data.orders[worker.target]
		if order_.status in ["served","cancelled"]:
			worker.target=""
			worker.mode="idle"
			worker.path=[]
		elif worker.pos.distance_to(COUNTER)>0.15:
			if worker.path.is_empty(): worker.path=path_to(worker.pos,COUNTER)
			follow(worker,dt*1.25)
			return
		elif order_.status=="queued":
			if start_cooking(worker.target,"staff"): worker.mode="cooking"
			return
		elif order_.status=="ready":
			pickup(worker.target,"staff")
			worker.path=[]
			worker.mode="delivery"
			return
		else: return
	if Intrigue.staff_alarm_step(self,dt):return
	if investigate(dt): return
	if not worker.delegated:
		return_staff(dt)
		return
	for oid in data.orders:
		var order_: Dictionary=data.orders[oid]
		if order_.status in ["queued","ready"] and order_.holder=="" and can_receive(order_.guest):
			order_.holder="staff"
			worker.target=oid
			worker.mode="counter"
			worker.path=path_to(worker.pos,COUNTER)
			return
	return_staff(dt)

func return_staff(dt: float) -> void:
	var worker: Dictionary=data.staff
	if worker.pos.distance_to(COUNTER)>0.15:
		if worker.path.is_empty(): worker.path=path_to(worker.pos,COUNTER)
		worker.mode="return"
		follow(worker,dt*1.25)
	else: worker.mode="idle"

func update_work(dt: float) -> void:
	if not data.work.is_empty() and data.work.type=="clean":
		data.work.remaining-=dt
		if data.work.remaining<=0:
			data.rooms[data.work.room].dirty=false
			note("객실 청소를 마쳤다.")
			data.work={}
	if not data.dig.is_empty():
		data.dig.remaining-=dt
		data.noise=minf(8,data.noise+dt*(0.65 if data.dig.get("quiet",false) else 1.7))
		data.stealth.source=data.player.pos
		if data.dig.remaining<=0:
			data.cells[data.dig.cell]=true
			note("땅굴 한 칸을 넓혔다. 위층의 시간도 계속 흐른다.")
			data.dig={}

func cancel_work() -> void:
	if data.paused: return
	if data.work.get("type","")=="cook":
		var order_: Dictionary=data.orders[data.work.order]
		order_.status="queued"
		order_.holder=""
		data.money+=1
	data.work={}
	data.dig={}
	data.excavation.path=[]
	data.excavation.intent=""
	note("작업을 중단했다.")

func change_floor() -> bool:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty(): return false
	if data.player.floor==0 and data.player.pos.distance_to(HATCH)<1.2:
		observe_hatch()
		data.excavation.hatch_open=true
		data.player.floor=1
		data.player.pos=Vector2.ZERO
		Intrigue.sync_drag(self)
		note("지하로 내려왔다. 입구 이동 버튼으로 복귀 / 흙벽을 클릭하면 굴착한다.")
		return true
	if data.player.floor==1 and data.player.pos.length()<1.1:
		observe_hatch()
		data.excavation.hatch_open=true
		data.player.floor=0
		data.player.pos=HATCH
		Intrigue.sync_drag(self)
		note("위층으로 돌아왔다.")
		return true
	note("층 이동 버튼을 누르면 입구로 걸어간다.")
	return false

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func parse_cell(key: String) -> Vector2i:
	var parts:=key.split(",")
	return Vector2i(int(parts[0]),int(parts[1]))

func start_dig(cell: Vector2i) -> bool:
	if data.paused or data.ops.drag!="" or data.player.floor!=1 or not data.work.is_empty() or not data.dig.is_empty(): return false
	if absi(cell.x)>CELLAR_LIMIT.x or absi(cell.y)>CELLAR_LIMIT.y or data.cells.has(cell_key(cell)): return false
	if data.excavation.durability<=0:
		note("도구가 닳았다. 관리 창에서 2닢에 수리한다.")
		return false
	if data.money<1:
		note("굴착 도구 비용 1닢이 부족하다.")
		return false
	var current := Vector2i(roundi(data.player.pos.x),roundi(data.player.pos.y))
	if absi(current.x-cell.x)+absi(current.y-cell.y)!=1:
		note("내 바로 옆 흙벽만 팔 수 있다.")
		return false
	data.money-=1
	data.excavation.path=[]
	data.excavation.intent=""
	data.excavation.durability-=1
	data.dig={"cell":cell_key(cell),"remaining":10.0 if data.stealth.quiet else 4.0,"quiet":data.stealth.quiet}
	note("조용한 굴착 10초. 중단 버튼." if data.stealth.quiet else "빠른 굴착 4초. 소리가 크다. 중단 버튼.")
	return true

func update_money() -> void:
	if preload("res://scripts/inn_campaign.gd").active(self):return
	var minute := int(480+data.clock*3) if data.get("opening",{}).get("natural",false) else int(420+data.clock*6)
	if minute>=data.dues.wage:
		data.dues.wage+=1440
		if data.staff.hired: charge(4,"직원 임금")
	if minute>=data.dues.rent:
		data.dues.rent+=1440
		charge(12,"임대료")
	if minute>=data.dues.tax and not data.collector:
		data.dues.tax+=1440
		data.collector=true
		data.tax_paid=false
		note("징수원이 왔다. 영업 창에서 세금 8닢을 낸다.")

func charge(amount: int, label_: String) -> void:
	var paid:=mini(amount,data.money)
	data.money-=paid
	data.debt+=amount-paid
	note("%s %d닢 지급%s" % [label_,paid," / 미납 기록" if paid<amount else ""])

static func encode(value: Variant) -> Variant:
	if value is Vector2: return {"_vector2":[value.x,value.y]}
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[str(key)]=encode(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value: result.append(encode(item))
		return result
	return value

static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("_vector2"): return Vector2(value._vector2[0],value._vector2[1])
		var result: Dictionary={}
		for key in value: result[key]=decode(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value: result.append(decode(item))
		return result
	return value

func snapshot() -> Dictionary:
	return {"version":SAVE_VERSION,"state":encode(data)}

func restore(saved: Variant) -> bool:
	if not saved is Dictionary or saved.get("version",0)!=SAVE_VERSION or not saved.get("state") is Dictionary: return false
	var candidate: Dictionary=decode(saved.state)
	if data.has("campaign") and not candidate.has("campaign"):candidate.campaign={"active":false}
	if data.has("booking_request") and not candidate.has("booking_request"):candidate.booking_request={}
	if data.has("opening") and not candidate.has("opening"): candidate.opening={"active":false,"natural":false}
	if data.has("service_target") and not candidate.has("service_target"): candidate.service_target=""
	# Existing 0.3 saves acquire awareness defaults; in-flight jobs remain valid.
	if not candidate.has("stealth"): candidate.stealth=stealth_defaults()
	if not candidate.has("ops"):candidate.ops=Intrigue.defaults()
	if not candidate.has("excavation"):
		candidate.excavation=excavation_defaults()
		for x in range(-3,2):
			for y in range(-2,3):candidate.cells[cell_key(Vector2i(x,y))]=true
	for key in data:
		if not candidate.has(key): return false
	if not candidate.staff.has("facing"): candidate.staff.facing=Vector2.DOWN
	if not candidate.player.pos is Vector2 or not candidate.rooms is Dictionary: return false
	for key in ["serial","order_serial","speed","money","debt","served","departed"]: candidate[key]=int(candidate[key])
	candidate.player.floor=int(candidate.player.floor)
	for person in candidate.people.values():
		for key in ["room","rate","meals"]: person[key]=int(person[key])
	if not candidate.excavation.has("lamp_on"):candidate.excavation.lamp_on=true
	if not candidate.excavation.has("storeroom"):candidate.excavation.storeroom=false
	data=candidate
	Intrigue.migrate(self)
	return true

# Awareness PoC: sound travels through the single basement hatch, never by
# comparing coincident coordinates on different floors. No telepathic NPCs.
func stealth_defaults() -> Dictionary:
	return {"suspicion":0.0,"memory":0,"phase":"idle","listen":0.0,
		"cooldown":0.0,"refuse_until":0.0,"heard":0.0,"source":Vector2.ZERO,
		"quiet":false,"explain_until":0.0,"warning":0,"confirmed":false}

func toggle_dig_mode() -> void:
	if data.paused or not data.dig.is_empty(): return
	data.stealth.quiet=not data.stealth.quiet
	note("조용한 굴착: 10초 / 작은 소리" if data.stealth.quiet else "빠른 굴착: 4초 / 큰 소리")

func heard_at(position_: Vector2) -> float:
	# Deep work is attenuated by the tunnel distance, then the surface route.
	var route:=path_to(position_,HATCH)
	if route.is_empty(): return 0.0
	var travel:=0.0
	var previous:=position_
	for point in route:
		travel+=previous.distance_to(point)
		previous=point
	var below_route: Array=Intrigue.basement_route(self,data.stealth.source,Vector2.ZERO)
	var below_distance:=0.0
	var last: Vector2=data.stealth.source
	for point in below_route:
		below_distance+=last.distance_to(point)
		last=point
	if below_route.is_empty():below_distance=data.stealth.source.length()
	var attenuation:=1.0 if data.excavation.hatch_open else 0.35
	return maxf(0,data.noise-below_distance*0.35-travel*0.30)*attenuation

func sight_end(origin: Vector2, direction: Vector2) -> Vector2:
	var end:=origin
	for i in range(1,49):
		var point:=origin+direction*float(i)*0.1
		if not surface_walkable(point): break
		end=point
	return end

func staff_sees(point: Vector2) -> bool:
	if not data.staff.hired: return false
	var offset: Vector2=point-data.staff.pos
	if offset.length()>4.8: return false
	if offset.length()>0.1 and data.staff.facing.dot(offset.normalized())<cos(deg_to_rad(50)): return false
	return sight_end(data.staff.pos,offset.normalized()).distance_to(data.staff.pos)+0.11>=offset.length()

func observe_hatch() -> void:
	if not staff_sees(HATCH): return
	data.stealth.suspicion=minf(100,data.stealth.suspicion+12)
	note("직원이 계단을 쓰는 모습을 봤다. 소리와 연결할 수 있다.")

func update_awareness(dt: float) -> void:
	var s: Dictionary=data.stealth
	s.heard=heard_at(data.staff.pos) if data.staff.hired else 0.0
	if not data.staff.hired: return
	if s.heard>0.7:
		s.suspicion=minf(100,s.suspicion+dt*(s.heard-0.7)*6)
	elif s.phase=="idle": s.suspicion=maxf(minf(60,float(s.memory)*15),s.suspicion-dt*1.4)
	if s.phase=="idle" and s.heard>0.7 and s.suspicion>=10 and data.clock>=s.cooldown and data.clock>=s.refuse_until:
		s.phase="alert"
		s.warning+=1
		s.confirmed=false
		note("직원이 소리에 주의를 기울인다. 하던 일을 마치면 확인하러 온다.")

func investigate(dt: float) -> bool:
	var s: Dictionary=data.stealth
	var worker: Dictionary=data.staff
	if s.phase=="idle": return false
	if s.phase=="alert":
		worker.path=path_to(worker.pos,HATCH)
		if worker.path.is_empty():
			s.phase="idle"
			s.cooldown=data.clock+5
			return false
		s.phase="approach"
		worker.mode="investigate"
		worker.target=""
		note("직원이 지하 입구로 걸어온다. 중단 버튼으로 멈출 수 있다.")
	if s.phase=="approach":
		follow(worker,dt*1.1)
		if worker.path.is_empty():
			s.phase="listen"
			s.listen=0.0
			worker.facing=Vector2.DOWN
			note("직원이 계단 앞에서 귀를 기울인다.")
	elif s.phase=="listen":
		s.listen+=dt
		if s.listen>1.2 and s.heard>1.8 and not data.dig.is_empty() and not s.confirmed:
			s.confirmed=true
			s.memory+=1
			s.suspicion=maxf(s.suspicion,75)
			s.refuse_until=data.clock+20
			s.phase="idle"
			s.cooldown=data.clock+35
			worker.path=[]
			note("직원이 계단 아래의 작업 소리를 확인했다. 20초간 일을 거부한다. 기억은 남는다.")
		elif s.listen>=6:
			finish_investigation()
	return true

func finish_investigation() -> void:
	data.stealth.phase="idle"
	data.stealth.suspicion=maxf(minf(60,float(data.stealth.memory)*15),data.stealth.suspicion-20)
	data.stealth.cooldown=data.clock+18
	data.staff.path=[]
	data.staff.mode="return"
	note("직원이 확인을 마치고 업무로 돌아간다.")

func explain_noise() -> bool:
	var s: Dictionary=data.stealth
	if s.phase not in ["approach","listen"] or data.player.floor!=0: return false
	if data.player.pos.distance_to(data.staff.pos)>1.6 or not staff_sees(data.player.pos): return false
	if data.clock<s.explain_until:
		note("같은 설명은 곧바로 다시 통하지 않는다.")
		return true
	s.explain_until=data.clock+45
	finish_investigation()
	note("물자를 확인했다고 짧게 설명했다. 이전에 확인한 사실은 지워지지 않는다.")
	return true

func excavation_defaults() -> Dictionary:
	return {"durability":24,"path":[],"intent":"","cell":"","hatch_open":false,"target":"","lamp_on":true,"storeroom":false}

func queue_floor() -> bool:
	if data.player.floor==2:return queue_gallery()
	if data.paused or not data.work.is_empty() or not data.dig.is_empty():return false
	data.excavation.path=[]
	data.excavation.intent=""
	var target: Vector2=HATCH if data.player.floor==0 else Vector2.ZERO
	if data.player.pos.distance_to(target)<0.8:return change_floor()
	var route: Array=path_to(data.player.pos,target) if data.player.floor==0 else Intrigue.basement_route(self,data.player.pos,target)
	if route.is_empty():note("입구까지 갈 수 있는 통로가 없다.");return false
	data.excavation.path=route
	data.excavation.intent="floor"
	note("입구까지 걸어간 뒤 층을 바꾼다. 다른 곳 탭 / 중단 버튼으로 취소.")
	return true

func queue_dig(cell: Vector2i) -> bool:
	if data.paused or data.player.floor!=1 or data.ops.drag!="" or not data.work.is_empty() or not data.dig.is_empty():return false
	if absi(cell.x)>CELLAR_LIMIT.x or absi(cell.y)>CELLAR_LIMIT.y or data.cells.has(cell_key(cell)):return false
	var current:=Vector2i(roundi(data.player.pos.x),roundi(data.player.pos.y))
	if absi(current.x-cell.x)+absi(current.y-cell.y)==1:return start_dig(cell)
	var best: Array=[]
	for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var stand: Vector2i=cell+offset
		if not data.cells.has(cell_key(stand)):continue
		var route: Array=Intrigue.basement_route(self,data.player.pos,Vector2(stand))
		if not route.is_empty() and (best.is_empty() or route.size()<best.size()):best=route
	if best.is_empty():note("열린 통로와 맞닿은 흙벽을 골라야 한다.");return false
	if data.excavation.durability<=0 or data.money<1:note("도구 내구도와 비용을 확인하자. 관리 창에서 도구 수리.");return false
	data.excavation.path=best
	data.excavation.intent="dig"
	data.excavation.cell=cell_key(cell)
	note("선택한 흙벽 옆으로 이동한 뒤 직접 판다. 중단 버튼으로 취소.")
	return true

func dig_nearest() -> bool:
	var best:=Vector2i(99,99)
	var distance:=INF
	for key in data.cells:
		var cell:=parse_cell(key)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if data.cells.has(cell_key(next)) or absi(next.x)>CELLAR_LIMIT.x or absi(next.y)>CELLAR_LIMIT.y:continue
			var delta: float=data.player.pos.distance_squared_to(Vector2(next))
			if delta<distance:distance=delta;best=next
	return queue_dig(best)

func update_excavation(dt: float) -> void:
	var job: Dictionary=data.excavation
	if job.intent=="":return
	if not data.work.is_empty() or not data.dig.is_empty():job.path=[];job.intent="";return
	var walker: Dictionary={"pos":data.player.pos,"path":job.path}
	follow(walker,dt*travel_multiplier*(1.15 if data.ops.drag!="" else (2.2 if data.player.carry!="" else 2.9)))
	data.player.pos=walker.pos
	Intrigue.sync_drag(self)
	if walker.path.is_empty():
		var action: String=job.intent
		job.intent=""
		if action=="gallery_up":
			data.player.floor=2
			data.player.pos=STAIRS
			Intrigue.sync_drag(self)
			queue_move(Vector2(8,-4.25))
			note("계단을 따라 2층으로 올라간다. 난간 너머가 1층 홀이다.")
		elif action=="gallery_down":
			data.player.floor=0
			data.player.pos=STAIRS
			Intrigue.sync_drag(self)
			note("계단을 내려와 1층 홀로 돌아왔다.")
		elif action=="floor":change_floor()
		elif action=="dig":start_dig(parse_cell(job.cell))
		elif action.begins_with("command:"):
			var command: String=action.trim_prefix("command:"); var id: String=str(job.get("target",""))
			if command in ["admit1","admit2","greet","dismiss","subdue","grab","sleep","kill","drag","deliver"] and data.people.has(id) and not Intrigue.close(self,id): queue_command(command,id)
			else: perform_command(command,id)

func repair_tools() -> bool:
	if data.paused or not near_counter():note("관리 창에서 도구 수리를 선택한다.");return false
	if data.excavation.durability>=24:note("곡괭이와 삽은 아직 튼튼하다.");return false
	if data.money<2:note("도구 수리비 2닢이 부족하다.");return false
	data.money-=2
	data.excavation.durability=24
	note("곡괭이와 삽을 수리했다. 내구도 24.")
	return true

func queue_move(target: Vector2) -> bool:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty():return false
	var closest:=Vector2.ZERO
	var distance:=INF
	if data.player.floor==1:
		for key in data.cells:
			var point:=Vector2(parse_cell(key))
			var delta:=point.distance_squared_to(target)
			if delta<distance:distance=delta;closest=point
	else:
		for x in range(grid.region.size.x):
			for y in range(grid.region.size.y):
				var id:=Vector2i(x,y)
				var point:=grid.get_point_position(id)
				if data.player.floor==2:
					if not gallery_walkable(point):continue
				elif grid.is_point_solid(id):continue
				var delta:=point.distance_squared_to(target)
				if delta<distance:distance=delta;closest=point
	var route: Array=gallery_route(data.player.pos,closest) if data.player.floor==2 else (path_to(data.player.pos,closest) if data.player.floor==0 else Intrigue.basement_route(self,data.player.pos,closest))
	if route.is_empty():note("그곳까지 이어지는 통로가 없다.");return false
	data.excavation.path=route
	data.excavation.intent="move"
	return true

func queue_command(command: String, id: String="") -> bool:
	if data.paused or not data.work.is_empty() or not data.dig.is_empty():return false
	var target: Vector2=COUNTER
	if command in ["subdue","grab","sleep","kill","drag","deliver","approach","admit1","admit2","greet","dismiss"]:
		if not data.people.has(id) or data.people[id].floor!=data.player.floor or data.people[id].state=="gone":note("현재 층에서 대상을 다시 선택하자.");return false
		target=data.people[id].pos
	elif command=="hatch":target=Vector2.ZERO if data.player.floor==1 else HATCH
	elif command=="lamp":
		if data.player.floor!=1:return false
		target=Vector2(-1,-1)
	elif command in ["explain","listen_staff"]:target=data.staff.pos
	elif command in ["cell","build"]:
		if data.player.floor!=1:note("구금칸은 지하에서 사용할 수 있다.");return false
		target=data.ops.cell if data.ops.built else data.player.pos
	elif command in ["clean1","clean2"]:target=room_target(1 if command=="clean1" else 2)
	elif data.player.floor!=0:note("먼저 1층 접수대로 돌아가야 한다.");return false
	data.excavation.target=id
	if data.player.pos.distance_to(target)<0.85:
		data.excavation.intent=""
		perform_command(command,id)
		return true
	if not queue_move(target):return false
	data.excavation.intent="command:"+command
	data.excavation.target=id
	note("대상에게 다가갑니다. 다른 바닥을 누르면 이동을 바꿉니다.")
	return true

func perform_command(command: String, id: String="") -> void:
	if id!="":data.ops.selected=id
	match command:
		"hatch":toggle_hatch()
		"lamp":toggle_cellar_lamp()
		"admit1":assign_room(1,id)
		"admit2":assign_room(2,id)
		"greet":
			if data.people.has(id) and Intrigue.close(self,id): note(str(data.people[id].name)+": "+str(data.people[id].trait))
		"dismiss":
			if data.people.has(id) and Intrigue.close(self,id):
				Intrigue.release_room(self,id); Intrigue.clear_orders(self,id); data.people[id].state="leaving"; data.people[id].path=path_to(data.people[id].pos,ENTRY)
		"room1":assign_room(1)
		"room2":assign_room(2)
		"reject":reject_guest()
		"clean1","clean2":
			var room_=str(1 if command=="clean1" else 2)
			if data.player.floor==0 and data.rooms[room_].guest=="" and data.rooms[room_].dirty and data.player.pos.distance_to(room_target(int(room_)))<1.6:
				data.work={"type":"clean","room":room_,"remaining":4.0}; note(room_+"호 정리 중 · 4초")
		"prepare","deliver":interact()
		"staff":toggle_staff()
		"repair":repair_tools()
		"contract":Intrigue.contract_action(self)
		"protect":Intrigue.contract_action(self,true)
		"inspect":Intrigue.inspector_action(self)
		"bribe":Intrigue.inspector_action(self,true)
		"grab","sleep","kill":Intrigue.quick_action(self,command)
		"subdue":Intrigue.subdue(self)
		"drag":Intrigue.drag_or_release(self)
		"cell","build":Intrigue.build_or_hold(self)
		"explain":explain_noise()

func toggle_cellar_lamp() -> bool:
	if data.paused or data.player.floor!=1:note("지하에서 등불을 조작하자.");return false
	data.excavation.lamp_on=not data.excavation.get("lamp_on",true)
	note("지하 등불을 켰다. 열린 덮개로 빛이 샌다." if data.excavation.lamp_on else "등불을 껐다. 가까운 곳 외에는 식별하기 어렵다.")
	return true

func toggle_hatch() -> bool:
	if data.paused:return false
	var target: Vector2=Vector2.ZERO if data.player.floor==1 else HATCH
	if data.player.floor==2 or data.player.pos.distance_to(target)>1.5:note("입구 가까이에서 덮개를 조작하자.");return false
	data.excavation.hatch_open=not data.excavation.hatch_open
	note("덮개를 열었다. 빛과 소리가 위층으로 전달된다." if data.excavation.hatch_open else "덮개를 닫았다. 위층으로 새는 빛과 소리가 줄었다.")
	return true

func basement_lit(point: Vector2) -> bool:
	if not data.excavation.get("lamp_on",true):return data.excavation.hatch_open and point.length()<1.6
	if point.distance_to(Vector2(-1,-1))>4.5:return false
	var delta:=point-Vector2(-1,-1)
	for i in range(1,ceili(delta.length()*8)):
		if not walkable(Vector2(-1,-1)+delta.normalized()*float(i)/8,1):return false
	return true

func request_direct_service(id: String) -> bool:
	if data.people.has(id) and data.people[id].get("visit","")=="meal" and data.people[id].state=="arriving":
		data.service_target=id;note("손님이 자리를 잡으면 식사를 내온다.");return true
	if not can_receive(id) or data.player.floor!=0: note("먼저 손님에게 방을 배정하자."); return false
	data.service_target=id
	return true

func update_direct_service() -> void:
	var id: String=data.get("service_target","")
	if data.people.has(id) and data.people[id].get("visit","")=="meal" and data.people[id].state=="arriving":return
	if id=="" or data.paused: return
	if not can_receive(id) or data.player.floor!=0: data.service_target=""; return
	if not data.work.is_empty() or data.excavation.intent!="": return
	if data.player.carry!="":
		var carried: String=data.player.carry
		if data.orders[carried].guest!=id: data.service_target=""; note("먼저 들고 있는 식사를 전달하자."); return
		if Intrigue.close(self,id): deliver(carried,"player"); data.service_target=""
		else: queue_command("deliver",id)
		return
	if not near_counter(): queue_move(COUNTER); return
	for oid in data.orders:
		var o: Dictionary=data.orders[oid]
		if o.guest!=id: continue
		if pickup(oid,"player"): return
		if o.status=="cooking" and o.holder=="player": return
		if start_cooking(oid,"player"):
			data.work={"type":"cook","order":oid,"remaining":3.0}; return
	# The delegated employee may already be handling this guest's order.
	data.service_target=""; note("직원이 맡았거나 지금 준비할 주문이 없다.")
