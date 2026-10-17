extends RefCounted
## Convenience policy: local preferences, explicit feedback and separate save slots.
const CONFIG="user://inn-comfort.cfg"
const AUTO="user://inn-auto-v179.json"
var host
var routes=true
var zoom=24.0
var focus_pause=true
var elapsed=0.0
var feedback=""
var feedback_until=0
var confirm_job: Dictionary={}
var confirmed=false
var last_action=""
var last_action_at=-1000
var pref_stamp=""
var pending_pref=""
var pref_changed_at=0
var selection_ring: MeshInstance3D

func setup(h) -> void:
	host=h
	var cfg=ConfigFile.new()
	if cfg.load(CONFIG)==OK:
		routes=bool(cfg.get_value("view","routes",true));zoom=clampf(float(cfg.get_value("view","zoom",24.0)),12,90)
		host.muted=bool(cfg.get_value("audio","muted",false));host.view_angle=float(cfg.get_value("view","angle",0));focus_pause=bool(cfg.get_value("play","focus_pause",true))
	pref_stamp=preferences_stamp()
func preferences_stamp() -> String:return str([routes,zoom,host.muted,host.view_angle,focus_pause])
func remember() -> void:
	var cfg=ConfigFile.new();cfg.set_value("view","routes",routes);cfg.set_value("view","zoom",zoom);cfg.set_value("view","angle",host.view_angle);cfg.set_value("audio","muted",host.muted);cfg.set_value("play","focus_pause",focus_pause)
	cfg.save(CONFIG);pref_stamp=preferences_stamp()
func say(value: String) -> void:
	feedback=value;feedback_until=Time.get_ticks_msec()+4800
func tick(dt: float) -> void:
	var current=preferences_stamp()
	if current!=pref_stamp:
		if current!=pending_pref:pending_pref=current;pref_changed_at=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-pref_changed_at>500:remember()
	if host.Campaign.active(host.sim) and not host.sim.data.paused and not host.sim.data.campaign.intro:
		elapsed+=dt
		if elapsed>=60:elapsed=0;save(AUTO,false)
	update_selection()
func metadata() -> Dictionary:
	return {"floor_journey":host.floor_journey,"entry":host.journey_entry,"pending":host.pending_context_action,"chat":host.pending_chat,"goal":host.auto_floor_goal,"paused":host.dialogue_previous_pause if host.dialogue_paused else (host.journal.previous_paused if host.journal.opened else host.sim.data.paused)}
func save(path: String,announce: bool=true) -> bool:
	host.sim.data.episode=host.episode.data.duplicate(true)
	var saved=host.sim.snapshot();saved["comfort"]=host.sim.encode(metadata())
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:say("저장할 수 없습니다. 저장 공간을 확인해주세요.");return false
	file.store_string(JSON.stringify(saved));file.flush();var error=file.get_error();file.close()
	if error!=OK:say("저장에 실패했습니다. 이전 저장은 유지됩니다.");return false
	var absolute=ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(absolute+".bak")
		if DirAccess.rename_absolute(absolute,absolute+".bak")!=OK:say("이전 저장을 보존할 수 없어 저장을 중단했습니다.");return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:
		if FileAccess.file_exists(path+".bak"):DirAccess.rename_absolute(absolute+".bak",absolute)
		say("저장 교체에 실패했습니다. 이전 기록을 복구했습니다.");return false
	if announce:say("저장 완료 · 진행 중인 작업도 기록했습니다.")
	return true
func read_save(path: String) -> Variant:
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return null
	return parser.data

func restore_meta(saved: Dictionary) -> void:
	var meta: Dictionary=host.sim.decode(saved.get("comfort",{}))
	host.floor_journey=int(meta.get("floor_journey",-1));host.journey_entry=str(meta.get("entry",""))
	host.pending_context_action=meta.get("pending",{});host.pending_chat=str(meta.get("chat",""));host.auto_floor_goal=meta.get("goal",{})
	host.sim.data.paused=bool(meta.get("paused",false))
	if host.sim.data.player.floor==0:host.show_inn()
	else:host.frame_owner()
	say("저장한 영업을 불러왔습니다.")
func offer_resume() -> void:
	if FileAccess.file_exists(AUTO) or FileAccess.file_exists("user://inn-tycoon-v15.json"):
		host.object_context.open("resume","","이전 영업 기록이 있습니다. 이어서 할까요?")

func background() -> void:
	if host!=null and host.object_context.kind=="resume":return
	if host==null or not host.Campaign.active(host.sim) or host.sim.data.campaign.intro:return
	if focus_pause:
		if host.dialogue_paused:host.dialogue_previous_pause=true
		if host.journal.opened:host.journal.previous_paused=true
		host.sim.data.paused=true;say("화면을 떠나 일시정지했습니다. 재개를 눌러 이어가세요.")
	save(AUTO,false)
func gate(kind: String,id: String,action: String) -> bool:
	if confirmed or kind=="resume":return false
	if action not in ["kill","release_inmate","load","load_auto"]:return false
	confirm_job={"kind":kind,"id":id,"action":action}
	var who=str(host.sim.data.people[id].name) if host.sim.data.people.has(id) else ""
	var prompt={"kill":who+"을 살해합니다. 되돌릴 수 없습니다.","release_inmate":who+"을 석방합니다. 감옥에서 풀려납니다.","load":"수동 저장을 불러옵니다. 현재 진행은 자동 저장에 남깁니다.","load_auto":"자동 저장 시점으로 돌아갑니다. 현재 진행은 수동 저장으로 먼저 남길 수 있습니다."}.get(action,"")
	host.object_context.open("confirm","",prompt);return true
func act(kind: String,id: String,action: String) -> bool:
	match action:
		"confirm_yes":
			var job=confirm_job.duplicate();confirm_job.clear()
			if job.is_empty():return true
			if job.action=="load":save(AUTO,false)
			confirmed=true
			if job.action=="load_auto":host.load_game(AUTO)
			else:host.context_action(job.kind,job.id,job.action)
			confirmed=false;return true
		"confirm_no":confirm_job.clear();say("선택을 취소했습니다.");return true
		"new_session":say("새 영업을 시작합니다. 기존 수동 저장은 유지됩니다.");return true
		"comfort","operations","recent","help":
			host.object_context.open(action,"",description(action));return true
		"load_auto":host.load_game(AUTO);return true
		"route_toggle":routes=not routes;remember()
		"sound_toggle":host.muted=not host.muted;remember()
		"focus_toggle":focus_pause=not focus_pause;remember()
		"zoom_in","zoom_out":zoom=clampf(host.camera.size+(-4 if action=="zoom_in" else 4),12,90);host.camera.size=zoom;remember()
		_:
			if action.begins_with("guest_jump:"):
				var target=action.trim_prefix("guest_jump:")
				if not host.sim.data.people.has(target) or host.sim.data.people[target].state=="gone":say("그 손님은 이미 떠났습니다.");return true
				var p: Dictionary=host.sim.data.people[target];focus(p.pos,int(p.floor));host.activate_selection({"kind":"person","id":target});return true
			if action.begins_with("room_jump:"):
				var n=int(action.trim_prefix("room_jump:"));focus(host.Sandbox.room_point(n),host.Sandbox.floor_of(n));host.object_context.open("room",str(n));return true
			return false
	host.object_context.open("comfort","",description("comfort"));return true
func focus(pos: Vector2,floor_: int) -> void:
	host.set_layer({0:"surface",1:"below",2:"rooms",3:"attic"}[floor_]);var point=host.world_point(pos,floor_);var base=host.focus_position();host.camera_offset=Vector2(point.x-base.x,point.z-base.z);host.camera_focus=point;host.camera.size=zoom;host.camera.position=point+host.camera_arm();host.camera.look_at(point)
func items(kind: String) -> Array:
	match kind:
		"resume":
			var rows: Array=[]
			if FileAccess.file_exists(AUTO):rows.append(["load_auto","자동 저장한 영업 이어하기"])
			if FileAccess.file_exists("user://inn-tycoon-v15.json"):rows.append(["load","수동 저장한 영업 이어하기"])
			rows.append(["new_session","새 영업 시작"]);return rows
		"confirm":return [["confirm_yes","확인 · 실행"],["confirm_no","취소 · 돌아가기"]]
		"comfort":return [["zoom_in","가까이 보기"],["zoom_out","넓게 보기"],["route_toggle","이동 경로 표시 · "+("켬" if routes else "끔")],["sound_toggle","소리 · "+("끔" if host.muted else "켬")],["focus_toggle","화면을 떠나면 정지 · "+("켬" if focus_pause else "끔")],["help","조작 도움말"]]
		"operations":
			var rows: Array=[]
			for id in host.sim.data.people:
				var p: Dictionary=host.sim.data.people[id]
				if p.state in ["gone","dead","captive"]:continue
				rows.append(["guest_jump:"+id,str(p.name)+" · "+{"waiting":"숙박 문의","arriving":"도착 중","dining":"식사","lodging":"숙박","staying":"숙박","entering":"방 이동","restrained":"붙잡힘","down":"기절","sheltered":"은신","escaping":"도주 중","leaving":"퇴실 중"}.get(p.state,"머무는 중")])
			for key in host.sim.data.rooms:
				var r: Dictionary=host.sim.data.rooms[key];rows.append(["room_jump:"+key,key+"호 · "+("청소 필요" if r.dirty else ("예약 중" if r.get("reserved","")!="" else ("이용 중" if r.guest!="" else "빈방")))])
			return rows
	return []
func description(kind: String) -> String:
	if kind=="comfort":return "표시·소리 설정은 다음 실행에도 유지됩니다."
	if kind=="operations":return "손님이나 객실을 누르면 해당 위치를 보여줍니다. 영업 작업은 직원이 계속 처리합니다."
	if kind=="help":return "빈 바닥: 이동\n사람: 요구와 행동 선택\n계단·사다리: 한 번 눌러 층 이동\n1층·2층·3층·지하: 주인이 실제로 이동\n전체: 둘러보기
여관 보기: 정문·마당·영업 한눈에\n드래그: 자유 관찰\n주인 버튼: 내 위치로 복귀\n상단 취소 버튼: 현재 작업 중지
PC에서는 우클릭으로도 취소\n설정: 자동 저장·수동 저장·화면 조절"
	if kind=="recent":
		var lines: Array=[]
		for row in host.sim.data.logs:lines.push_front("[%d초] %s" %[int(row.time),row.text])
		return "\n".join(lines) if not lines.is_empty() else "아직 기록된 알림이 없습니다."
	return ""
func update_selection() -> void:
	if selection_ring==null:
		selection_ring=MeshInstance3D.new();var mesh_=TorusMesh.new();mesh_.inner_radius=.48;mesh_.outer_radius=.59;selection_ring.mesh=mesh_;var mat=host.material(Color("7edbd5"));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.no_depth_test=true;selection_ring.material_override=mat;host.add_child(selection_ring)
	selection_ring.visible=false
	var ui=host.object_context
	if not ui.panel.visible or ui.kind not in ["conversation","person","actions","other","inmate","questioning"] or not host.sim.data.people.has(ui.target):return
	var p: Dictionary=host.sim.data.people[ui.target]
	selection_ring.visible=host.Selection.visible_floor(host,int(p.floor)) and p.state!="gone";selection_ring.position=host.world_point(p.pos,int(p.floor),.12)
