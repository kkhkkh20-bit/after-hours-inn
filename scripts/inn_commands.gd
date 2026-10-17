extends RefCounted
## UI selections do not cancel commands. Explicit replacement does.
static func reset_view(host) -> void:
	host.floor_journey=-1;host.journey_entry=""
	host.pending_context_action.clear();host.pending_chat="";host.auto_floor_goal.clear()
	if host.pointer!=null:host.pointer.reset()
	if host.object_context!=null:host.object_context.close()

static func cancel(host,quiet: bool=false) -> void:
	var s=host.sim
	host.floor_journey=-1;host.journey_entry=""
	var paused: bool=s.data.paused;s.data.paused=false
	if s.Sandbox.active(s):s.Prison.cancel(s)
	if s.Tycoon.active(s):s.Tycoon.cancel_booking(s)
	s.cancel_work();s.data.service_target="";s.data.deferred_command={}
	for order_ in s.data.orders.values():
		if order_.holder=="player" and order_.status in ["queued","ready"]:order_.holder=""
	if s.Sandbox.active(s):s.data.sandbox.tunnel_plan=[];s.data.sandbox.chute_job={};s.data.sandbox.erase("pending_tunnel")
	host.pending_context_action.clear();host.pending_chat="";host.auto_floor_goal.clear()
	s.data.paused=paused
	if not quiet:s.note("현재 작업을 취소했습니다.")

static func move(host,target: Vector2) -> bool:
	if host.sim.data.paused:host.sim.note("일시정지 중입니다. 상단 재개를 눌러주세요.");return false
	var route: Array=host.sim.move_route(target)
	if route.is_empty():
		if not host.sim.data.logs.is_empty():host.comfort.say(str(host.sim.data.logs.back().text))
		return false
	cancel(host,true)
	host.sim.data.excavation.path=route
	host.sim.data.excavation.intent="move"
	host.follow_owner(false)
	return true

static func status(host) -> String:
	var s=host.sim
	if host.dig_mode!="":return "공사 위치 선택 중"
	if not s.data.get("sandbox",{}).get("capture",{}).is_empty():return "감옥으로 붙잡아 호송 중"
	if not s.data.get("sandbox",{}).get("chute_job",{}).is_empty():return "객실 비밀 통로로 옮기는 중"
	if not s.data.get("booking_request",{}).is_empty():return "%s호 안내 중" %str(s.data.booking_request.room)
	if s.data.get("service_target","")!="":return "식사 준비·서빙 중"
	if not s.data.work.is_empty():return {"cook":"식사 조리 중","clean":"객실 청소 중","construction":"공사 중","dispose":"시설 가동 중","quick":"행동 중"}.get(s.data.work.get("type",""),"작업 중")
	if host.floor_journey>=0:return "계단·사다리로 "+{0:"1층",1:"지하",2:"2층"}.get(host.floor_journey,"")+" 이동 중"
	if s.data.excavation.intent!="":return "이동 중"
	return ""
