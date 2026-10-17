extends RefCounted
## Rendering-independent rules. All public actions require the owner's physical presence.
const FLOORS = [390.0, 620.0, 850.0]
const STAIR_X = 96.0
var owner = {"pos": Vector2(360, 620), "floor": 1, "face": 1}
var staff = {"pos": Vector2(490, 620), "floor": 1, "face": -1, "route": []}
var guests = [
	{"name": "상인", "pos": Vector2(270, 620), "floor": 1, "face": 1, "room": 0, "down": false, "route": []},
	{"name": "수상한 손님", "pos": Vector2(540, 390), "floor": 0, "face": -1, "room": 1, "down": false, "route": []}
]
var route: Array = []
var pending = ""
var pending_guest = -1
var coins = 24
var wood = 8
var hired = false
var delegated = true
var lamps = [true, true, true]
var hatch_open = false
var dig_count = 0
var dig_work = 0.0
var digging = false
var clock = 0.0
var service_clock = 0.0
var patrol_clock = 0.0
var wage_clock = 0.0
var suspicion = 0.0
var last_noise = 0.0
var noise_age = 99.0
var noise_origin = Vector2.ZERO
var staff_investigation = 0.0
var investigation_count = 0
var investigation_origin = Vector2.ZERO
var guard_clock = 0.0
var guard_visits = 0
var orders = 1
var served = 0
var dragging = -1
var evidence = false
var paused = false
var footstep_clock = 0.0
var event_log: Array[String] = ["전쟁 중인 국경 여관. 오늘은 누구를 들일까.", "직원 고용 후 지하를 파거나 손님 동선을 살펴보세요."]

func log_event(s: String) -> void:
	event_log.push_front(s)
	if event_log.size() > 12: event_log.resize(12)

func light_at(p: Vector2, floor_id: int) -> float:
	var amount = 0.18
	if lamps[floor_id]:
		var locations = [Vector2(385, 318), Vector2(385, 548), Vector2(215, 778)]
		amount += 0.8 * maxf(0.0, 1.0 - p.distance_to(locations[floor_id]) / 360.0)
	return clampf(amount, 0.0, 1.0)

func can_see(observer: Dictionary, p: Vector2, f: int) -> bool:
	if observer.floor != f: return false
	var dx: float = p.x - observer.pos.x
	var distance: float = observer.pos.distance_to(p)
	if distance > 240.0: return false
	if distance > 30.0 and dx * float(observer.face) < 0: return false
	return distance < 30.0 or light_at(p, f) > 0.30

func witnessed() -> bool:
	if hired and can_see(staff, owner.pos, owner.floor): return true
	for g in guests:
		if not g.down and can_see(g, owner.pos, owner.floor): return true
	return false

func heard_loudness(power: float, source_floor: int, listener_floor: int) -> float:
	var result = power * pow(0.50, abs(source_floor - listener_floor))
	if (source_floor == 2) != (listener_floor == 2):
		result *= 1.0 if hatch_open else 0.30
	return result

func emit_noise(power: float) -> void:
	last_noise = power
	noise_age = 0.0
	noise_origin = owner.pos
	if hired and heard_loudness(power, owner.floor, staff.floor) >= 0.20:
		suspicion = minf(100, suspicion + power * 5)
		if staff_investigation <= 0:
			staff_investigation = 7.0
			investigation_count += 1
			investigation_origin = owner.pos
			# Staff follows an actual route. A shut hatch remains a barrier.
			if owner.floor == 2 and not hatch_open:
				staff.route = path_to(staff.pos, staff.floor, Vector2(STAIR_X, FLOORS[1]), 1)
			else:
				staff.route = path_to(staff.pos, staff.floor, owner.pos, owner.floor)
			log_event("직원: 방금 무슨 소리지? 출입구를 확인한다.")

func path_to(from: Vector2, from_floor: int, to: Vector2, to_floor: int) -> Array:
	var points: Array = []
	if from_floor != to_floor:
		points.append(Vector2(STAIR_X, from.y))
		var direction = 1 if to_floor > from_floor else -1
		for f in range(from_floor + direction, to_floor + direction, direction):
			points.append(Vector2(STAIR_X, FLOORS[f]))
	points.append(to)
	return points

func walk_to(p: Vector2, f: int) -> bool:
	if f < 0 or f > 2: return false
	if (f == 2) != (owner.floor == 2) and not hatch_open:
		log_event("지하 덮개가 닫혀 있다. 먼저 덮개를 열자.")
		return false
	if f == 2 and p.x > 295 + dig_count * 54:
		log_event("아직 흙으로 막힌 곳이다. 굴착 지점을 선택하자.")
		return false
	pending = ""
	digging = false
	route = path_to(owner.pos, owner.floor, Vector2(clampf(p.x, 62, 654), FLOORS[f]), f)
	return true

func request(action: String, guest_index: int = -1) -> bool:
	var p: Vector2 = owner.pos
	var f: int = owner.floor
	match action:
		"serve", "hire", "delegate": p = Vector2(510, 620); f = 1
		"hatch":
			# Accessible from either side; never close during a crossing.
			if (owner.pos.y > 625 and owner.pos.y < 845) or _crossing(staff) or _crossing(guests[1]):
				log_event("누군가 계단을 이용 중이다."); return false
			f = 2 if owner.floor == 2 else 1
			p = Vector2(STAIR_X, FLOORS[f])
		"lamp": p = Vector2(215 if f == 2 else 385, FLOORS[f])
		"dig":
			if dig_count >= 6: log_event("이번 실험의 굴착 한계다."); return false
			p = Vector2(275 + dig_count * 54, 850); f = 2
		"ambush", "drag", "room":
			if guest_index < 0 or guest_index >= guests.size(): return false
			p = guests[guest_index].pos; f = guests[guest_index].floor
			if action == "ambush": p.x -= 32 * guests[guest_index].face
			if action == "drag" and dragging >= 0: p = owner.pos; f = owner.floor
		_: return false
	if not walk_to(p, f): return false
	pending = action
	pending_guest = guest_index
	return true

func _crossing(actor: Dictionary) -> bool:
	return actor.pos.y > 625 and actor.pos.y < 845

func perform(action: String, gi: int = -1) -> bool:
	match action:
		"serve":
			if orders <= 0: log_event("현재 밀린 주문이 없다."); return false
			orders -= 1; served += 1; coins += 4
			log_event("따뜻한 식사 제공. +4닢")
		"hire":
			if hired: log_event("이미 직원이 있다."); return false
			if coins < 8: log_event("고용비 8닢이 필요하다."); return false
			coins -= 8; hired = true; wage_clock = 0
			log_event("직원 고용. 접객을 맡긴다. 급여는 90초마다 6닢.")
		"delegate":
			if not hired: return false
			delegated = not delegated
			log_event("직원 접객 " + ("재개" if delegated else "중지"))
		"hatch":
			if _crossing(staff) or _crossing(guests[1]): return false
			hatch_open = not hatch_open
			log_event("덮개를 " + ("열었다. 지하 이동 가능, 소리가 더 샌다." if hatch_open else "닫았다. 지하 소리가 줄어든다."))
		"lamp":
			lamps[owner.floor] = not lamps[owner.floor]
			log_event("현재 층 등불 " + ("켬" if lamps[owner.floor] else "끔. 가까이에서는 여전히 들킨다."))
		"dig":
			if wood <= 0: log_event("지지대용 목재가 부족하다."); return false
			digging = true; dig_work = 0
			log_event("굴착 시작. 4초·목재 1개. 작업 소음에 주의.")
		"room":
			guests[gi].room = 1 - int(guests[gi].room)
			log_event(guests[gi].name + " → " + str(101 + guests[gi].room) + "호 배정")
		"ambush":
			if gi < 0 or guests[gi].down: return false
			var g: Dictionary = guests[gi]
			if owner.floor != g.floor or owner.pos.distance_to(g.pos) > 38:
				log_event("손님이 이동했다. 다시 기회를 보자."); return false
			if can_see(g, owner.pos, owner.floor):
				suspicion = minf(100, suspicion + 18); emit_noise(1)
				log_event("접근을 눈치챘다! 뒤를 돌거나 어두운 틈을 기다리자."); return false
			var seen = hired and can_see(staff, owner.pos, owner.floor)
			for other in guests:
				if other != g and not other.down and can_see(other, owner.pos, owner.floor): seen = true
			g.down = true; g.route = []; evidence = true
			emit_noise(0.45)
			if seen: suspicion = minf(100, suspicion + 40)
			log_event("손님을 기절시켰다. " + ("목격자가 있다!" if seen else "다른 사람의 시선은 피했다."))
		"drag":
			if dragging >= 0: dragging = -1; log_event("내려놓았다."); return true
			if gi < 0 or not guests[gi].down or owner.pos.distance_to(guests[gi].pos) > 38: return false
			dragging = gi; log_event("운반 시작. 이동이 느려지고 목격될 수 있다.")
	return true

func _advance(actor: Dictionary, points: Array, delta: float, speed: float) -> void:
	if points.is_empty(): return
	var target: Vector2 = points[0]
	if not hatch_open and absf(target.y-actor.pos.y)>1 and (target.y > 625 or actor.pos.y > 625):
		points.clear()
		return
	var old: Vector2 = actor.pos
	actor.pos = old.move_toward(target, delta * speed)
	if absf(target.x - old.x) > 1: actor.face = 1 if target.x > old.x else -1
	for f in range(3):
		if absf(actor.pos.y - FLOORS[f]) < 1: actor.floor = f
	if actor.pos.distance_to(target) < 0.5: points.pop_front()

func tick(delta: float) -> void:
	if paused: return
	clock += delta; noise_age += delta; service_clock += delta; patrol_clock += delta; guard_clock += delta
	var was_moving = not route.is_empty()
	_advance(owner, route, delta, 70 if dragging >= 0 else 130)
	if was_moving:
		footstep_clock += delta
		if footstep_clock >= 0.6:
			footstep_clock = 0
			emit_noise(0.30 if dragging >= 0 else 0.12)
	if route.is_empty() and pending != "":
		var action = pending; var gi = pending_guest; pending = ""
		perform(action, gi)
	if was_moving and dragging >= 0:
		guests[dragging].pos = owner.pos + Vector2(-18 * owner.face, 0)
		guests[dragging].floor = owner.floor
		if witnessed(): suspicion = minf(100, suspicion + delta * 8)
	if hired:
		wage_clock += delta
		if wage_clock >= 90:
			wage_clock -= 90
			if coins >= 6: coins -= 6; log_event("직원 급여 -6닢")
			else: hired = false; log_event("급여 부족. 직원이 떠났다.")
		_advance(staff, staff.route, delta, 75)
		if staff_investigation > 0:
			staff_investigation = maxf(0, staff_investigation - delta)
			if evidence and witnessed(): suspicion = minf(100, suspicion + delta * 2)
			if staff_investigation == 0: staff.route = path_to(staff.pos, staff.floor, Vector2(490,620), 1)
	if service_clock >= 8:
		service_clock -= 8
		if hired and delegated and staff_investigation <= 0 and staff.floor == 1 and staff.route.is_empty() and orders > 0:
			orders -= 1; coins += 4; served += 1; log_event("직원이 식사를 제공했다. +4닢")
		orders = mini(4, orders + 1)
		if orders == 4: suspicion = minf(100, suspicion + 1)
	for index in range(guests.size()):
		var g: Dictionary = guests[index]
		if g.down: continue
		_advance(g, g.route, delta, 55)
		if g.route.is_empty():
			g["idle_time"] = g.get("idle_time",0.0) + delta
			if g.idle_time >= (11 if index == 0 else 7):
				g.idle_time = 0.0
				if g.floor == 0: g.route = path_to(g.pos, 0, Vector2(270+index*65,620), 1)
				else: g.route = path_to(g.pos, 1, Vector2(410 + g.room * 170,390), 0)
	if digging:
		dig_work += delta
		if int(dig_work * 2) != int((dig_work - delta) * 2): emit_noise(0.9)
		if dig_work >= 4:
			dig_count += 1; wood -= 1; digging = false
			log_event("통로를 넓혔다. 목재 -1. 더 깊은 벽을 다시 선택할 수 있다.")
	if guard_clock >= 75:
		guard_clock -= 75; guard_visits += 1
		if suspicion >= 35 or (evidence and guests[1].floor < 2):
			coins = maxi(0, coins - 10)
			log_event("경비 조사: 수상한 정황으로 벌금 10닢. 다음에는 목격을 줄이자.")
		else: log_event("경비가 영업장을 확인하고 떠났다.")
		suspicion = maxf(0, suspicion - 15)
