extends RefCounted
static func dig_to(s,target: Vector2i) -> bool:
	if s.data.player.floor==0:
		var e=s.Sandbox.nearest(s,s.data.player.pos,0)
		if e.is_empty():s.note("먼저 구멍 파기로 지하 입구를 만들어주세요.");return false
		if not s.Sandbox.use_entrance(s,e.id):return false
		s.data.sandbox.pending_tunnel=target;s.note("입구로 이동해 내려간 뒤 목적지까지 자동으로 팝니다.");return true
	if s.data.player.floor==2:
		if not s.queue_gallery():return false
		s.data.sandbox.pending_from_upper=target;s.note("1층으로 내려가 지하 목적지까지 자동으로 팝니다.");return true
	if absi(target.x)>s.CELLAR_LIMIT.x-1 or absi(target.y)>s.CELLAR_LIMIT.y-1:s.note("굴착 범위를 벗어났다. 조금 가까운 곳을 골라주세요.");return false
	if s.data.ops.drag!="":s.note("운반 중인 대상을 먼저 내려놓으세요.");return false
	s.cancel_work()
	var origin=Vector2i(roundi(s.data.player.pos.x),roundi(s.data.player.pos.y))
	var frontier=[origin];var seen={s.cell_key(origin):true};var best=origin;var best_distance=2147483647
	var index=0
	while index<frontier.size():
		var cell: Vector2i=frontier[index];index+=1
		var distance=absi(cell.x-target.x)+absi(cell.y-target.y)
		if distance<best_distance:best=cell;best_distance=distance
		for shift in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+shift;var key=s.cell_key(next)
			if not seen.has(key) and s.data.cells.has(key) and s.walkable(Vector2(next),1):seen[key]=true;frontier.append(next)
	if not s.queue_move(Vector2(best)):return false
	var at=best;var plan=[]
	while at.x!=target.x:at.x+=1 if target.x>at.x else -1;plan.append(at)
	while at.y!=target.y:at.y+=1 if target.y>at.y else -1;plan.append(at)
	s.data.sandbox.tunnel_plan=plan
	s.data.sandbox.dig_target=target
	s.note("목적지까지 %d칸. 주인이 이동하고 자동으로 통로를 팝니다. 주인의 취소 메뉴로 중단할 수 있습니다." %plan.size())
	return true
static func shaft(s,top: Vector2) -> bool:
	if s.data.player.floor==0:return s.Sandbox.create_entrance(s,top)
	if s.data.player.floor==2:
		if not s.queue_gallery():return false
		s.data.sandbox.pending_shaft=top;return true
	var cell=s.Sandbox.underground(top)
	if not s.surface_walkable(top):s.note("위쪽이 벽이나 가구에 막힌 자리입니다. 빈 바닥을 골라주세요.");return false
	for e in s.data.sandbox.entrances:
		if e.top.distance_to(top)<2:s.note("이미 입구가 있는 자리입니다.");return false
	if s.data.money<3:s.note("입구 공사비 3닢이 필요합니다.");return false
	if not dig_to(s,cell):return false
	s.data.sandbox.pending_exit={"top":top,"cell":cell}
	s.note("선택한 지상 위치까지 통로를 파고, 끝에서 출구를 자동으로 만듭니다. 공사비 3닢.")
	return true
static func tick(s) -> void:
	if s.data.player.floor==0 and s.data.excavation.intent=="":
		if s.data.sandbox.has("pending_from_upper"):
			var target: Vector2i=s.data.sandbox.pending_from_upper;s.data.sandbox.erase("pending_from_upper");dig_to(s,target);return
		if s.data.sandbox.has("pending_shaft"):
			var top: Vector2=s.data.sandbox.pending_shaft;s.data.sandbox.erase("pending_shaft");shaft(s,top);return
	var pending: Dictionary=s.data.sandbox.get("pending_exit",{})
	if pending.is_empty() or s.data.player.floor!=1:return
	if not s.data.sandbox.get("tunnel_plan",[]).is_empty() or not s.data.dig.is_empty() or not s.data.work.is_empty() or s.data.excavation.intent!="":return
	if not s.data.cells.has(s.cell_key(pending.cell)):return
	if s.data.player.pos.distance_to(Vector2(pending.cell))>0.8:
		s.queue_move(Vector2(pending.cell));return
	s.data.sandbox.pending_exit={}
	s.data.sandbox.route={"kind":"entrance","point":pending.top,"cell":pending.cell}
	s.Sandbox.perform(s,"sandbox:build","")
