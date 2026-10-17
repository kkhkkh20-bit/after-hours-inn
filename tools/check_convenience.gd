extends SceneTree
var app
var checks: Array=[]
const SLOT="user://convenience-test.json"
func check(label_: String,value: bool) -> void:
	checks.append(value);print("PASS " if value else "FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame;await process_frame
	app.set_physics_process(false);app.start_campaign();app.journal.close();app.sim.data.paused=false;app.sim.data.next_guest=99999
	var s=app.sim;var q=app.comfort
	app.object_context.refresh();app.journal.refresh();await process_frame
	check("owner control no longer overlaps objective",not app.object_context.owner_button.get_global_rect().intersects(app.journal.goal.get_global_rect()))
	check("notice no longer overlaps active task",not app.journal.notice.get_global_rect().intersects(app.object_context.task_label.get_global_rect()))
	app.object_context.open("system");await process_frame;await process_frame
	check("local menu starts below top status lines",app.object_context.panel.position.y>=346)
	app.object_context.close()
	s.data.player.pos=Vector2(-.25,2.25);app.Commands.move(app,Vector2(-2.25,2.25));app.sync_view(0)
	check("movement path is visible on owner floor",app.walking_route.visible and app.travel_marker.visible)
	q.routes=false;app.sync_view(0);check("route preference hides path and destination",not app.walking_route.visible and not app.travel_marker.visible)
	q.routes=true;app.set_layer("below");check("ground destination does not leak into basement view",not app.travel_marker.visible)
	app.frame_owner();app.request_floor(2);app.dig_mode="shaft"
	var right=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;right.position=Vector2(400,600);root.push_input(right,true);await process_frame
	check("right click cancels floor destination and build mode",app.floor_journey==-1 and app.dig_mode=="" and s.data.excavation.intent=="")
	app.object_context.open("conversation","guest_1",app.Dialogue.begin(s,"guest_1"));q.tick(0)
	check("selected person has a distinct location ring",q.selection_ring.visible)
	app.object_context.close();q.tick(0);check("selection ring disappears when menu closes",not q.selection_ring.visible)
	app.context_action("person","guest_1","kill")
	check("irreversible action asks with exact target",app.object_context.kind=="confirm" and app.object_context.detail.contains(s.data.people.guest_1.name) and s.data.people.guest_1.state!="dead")
	app.object_context.close();app.context_action("confirm","","confirm_no")
	check("cancelling confirmation leaves guest alive",s.data.people.guest_1.state!="dead" and q.confirm_job.is_empty())
	app.object_context.open("comfort","",q.description("comfort"));app.object_context._perform("route_toggle");var routes=q.routes;app.object_context._perform("route_toggle")
	check("rapid repeated same action cannot toggle twice",q.routes==routes)
	app.object_context.close();q.routes=false;q.zoom=32;app.muted=true;app.view_angle=PI;q.remember()
	var copy=load("res://scripts/inn_comfort.gd").new();copy.setup(app)
	check("sound zoom angle and route preferences persist",not copy.routes and copy.zoom==32 and app.muted and app.view_angle==PI)
	q.routes=true;q.zoom=24;app.muted=false;app.view_angle=0;q.remember();app.frame_owner()
	app.request_floor(2);s.tick(1);var floor_=s.data.player.floor;var expected_goal=app.floor_journey;var pos=s.data.player.pos
	check("save writes a valid independent file",q.save(SLOT,false) and FileAccess.file_exists(SLOT))
	s.data.money=444;q.save(SLOT,false)
	check("replacement retains previous save backup",FileAccess.file_exists(SLOT+".bak"))
	app.Commands.cancel(app,true);s.data.money=1;app.load_game(SLOT)
	check("save restores money and multi-floor journey",s.data.money==444 and app.floor_journey==expected_goal and s.data.player.floor==floor_ and s.data.player.pos.distance_to(pos)<.01)
	var file=FileAccess.open(SLOT,FileAccess.WRITE);file.store_string("broken");file.close();app.load_game(SLOT)
	check("corrupt current file falls back to prior valid backup",s.data.money!=1 and app.floor_journey==expected_goal)
	app.Commands.cancel(app,true);s.data.paused=false;s.data.campaign.intro=false
	q.elapsed=59.9;q.tick(.2)
	check("sixty active seconds create separate autosave",FileAccess.file_exists(q.AUTO) and q.elapsed==0)
	app.object_context.open("system");q.background();app.object_context.close()
	check("background pause survives closing an open menu",s.data.paused and app.dialogue_previous_pause)
	app.load_game(q.AUTO);check("background autosave restores deliberate pause",s.data.paused)
	q.offer_resume();check("startup offers existing progress before running new game",app.object_context.kind=="resume" and s.data.paused and app.object_context.controls.has("load_auto"))
	app.object_context.close()
	s.data.paused=false;app.object_context.open("operations","",q.description("operations"));await process_frame
	check("operations panel exposes guest and five rooms",app.object_context.controls.has("guest_jump:guest_1") and app.context_items("operations","").filter(func(row):return str(row[0]).begins_with("room_jump:")).size()==5)
	app.object_context.close();app.context_action("operations","","guest_jump:guest_1")
	check("guest shortcut focuses correct person without issuing movement",app.object_context.target=="guest_1" and app.object_context.kind=="conversation")
	app.object_context.close();s.note("기록 확인용 알림");check("recent log retains messages",q.description("recent").contains("기록 확인용 알림"))
	q.say("갈 수 없는 위치");app.journal.refresh();check("direct action feedback is not covered by sales receipt",app.journal.notice.text=="갈 수 없는 위치")
	app.Commands.cancel(app,true);q.routes=true;q.zoom=24;app.muted=false;app.view_angle=0;q.remember()
	for path in [SLOT,SLOT+".bak",SLOT+".tmp"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CONVENIENCE CHECKS ",checks.filter(func(x):return x).size(),"/",checks.size());quit(0 if checks.all(func(x):return x) else 1)
