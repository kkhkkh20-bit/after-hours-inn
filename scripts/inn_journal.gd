extends CanvasLayer
var host
var opened=false
var mode="ledger"
var root: Control
var panel: PanelContainer
var title: Label
var body: Label
var buttons: VBoxContainer
var goal: Label
var notice: Label
var progress: Label
var last_notice=""
var until=0
var last_key=""
var controls: Dictionary={}
var previous_paused=false

func label_(value: String,size_: int) -> Label:
	var l=Label.new();l.text=value;l.add_theme_font_override("font",host.episode_font());l.add_theme_font_size_override("font_size",size_);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return l

func setup(h) -> void:
	host=h;layer=24
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	goal=label_("",21);root.add_child(goal);goal.position=Vector2(22,121);goal.size=Vector2(675,64)
	notice=label_("",20);root.add_child(notice);notice.position=Vector2(22,187);notice.size=Vector2(675,70)
	progress=label_("",19);root.add_child(progress);progress.size=Vector2(210,40);progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;progress.hide()
	panel=PanelContainer.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=30;panel.offset_right=-30;panel.offset_top=270;panel.offset_bottom=-100
	var s=StyleBoxFlat.new();s.bg_color=Color("1a272b");s.border_color=Color("a48a5b");s.set_border_width_all(2);s.set_corner_radius_all(12);s.content_margin_left=26;s.content_margin_right=26;s.content_margin_top=28;s.content_margin_bottom=26;panel.add_theme_stylebox_override("panel",s)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",20);panel.add_child(col)
	title=label_("",31);col.add_child(title)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;col.add_child(scroll)
	body=label_("",24);scroll.add_child(body)
	buttons=VBoxContainer.new();buttons.add_theme_constant_override("separation",12);col.add_child(buttons)
	panel.hide();refresh()

func open(which: String="ledger") -> void:
	previous_paused=host.sim.data.paused;mode=which;opened=true;host.sim.data.paused=true;panel.show();last_key="";refresh()

func close() -> void:
	opened=false;panel.hide();host.sim.data.paused=previous_paused

func choose(action: String) -> void:
	match action:
		"begin":host.sim.data.campaign.intro=false;previous_paused=false;close()
		"continue":host.Campaign.next_day(host.sim);previous_paused=false;close();host.save_game()
		"retry":host.get_tree().reload_current_scene()
		"freeplay":host.sim.data.campaign.ending="";host.sim.data.campaign.freeplay=true;host.sim.data.campaign.summary=false;host.sim.data.campaign.day=4;host.sim.data.campaign.next_dawn=host.Sandbox.DAY*4;host.sim.data.campaign.start_money=host.sim.data.money;host.sim.data.campaign.start_served=host.sim.data.served;previous_paused=false;close()
		"rest":close();host.rest_until_dawn()
		"load":close();host.load_game()
		"save":host.save_game();last_key=""
		_:close()

func refresh() -> void:
	var sim=host.sim
	if not host.Campaign.active(sim):root.hide();return
	root.show()
	var c: Dictionary=sim.data.campaign
	goal.text=host.Campaign.goal(sim)
	var message=host.episode_notice()
	if message!=last_notice:last_notice=message;until=Time.get_ticks_msec()+4200
	notice.text=message if Time.get_ticks_msec()<until and not opened else ""
	progress.visible=not opened and (not sim.data.work.is_empty() or not sim.data.dig.is_empty())
	if progress.visible:
		var job: Dictionary=sim.data.work if not sim.data.work.is_empty() else sim.data.dig
		progress.text="%s · %.1f초" %[{"cook":"식사 준비","clean":"객실 정리","quick":"행동 중","subdue":"제압 중","construction":"시설 공사","dispose":"화로 가동"}.get(job.get("type",""),"굴착 중"),maxf(0,job.get("remaining",0.0))]
		progress.position=host.camera.unproject_position(host.world_point(sim.data.player.pos,sim.data.player.floor,2.4))-Vector2(105,20)
	if host.Tycoon.active(sim) and sim.data.tycoon.receipt_until>sim.data.clock and not opened:notice.text=sim.data.tycoon.receipt
	if (c.summary or c.ending!="") and not opened:open("summary");return
	if not opened:return
	var choices=[]
	if c.intro:
		title.text="문 닫은 뒤 · 여관 타이쿤"
		body.text="전쟁 중 국경 마을의 여관 주인.\n\n손님을 받고 숙박비와 식사값을 벌어 여관을 키운다.\n\n손님 클릭 → 요구 듣기 → 돈 받고 방 안내.\n마라가 식사를 맡고, 접수·청소 알바를 고용하면\n주인이 다른 일을 해도 여관은 계속 돌아간다.\n\n접수대에서 알바 고용·주방 개선.\n객실을 눌러 개선하면 숙박 수입이 늘어난다.\n하루는 약 3분 30초. 매일 매출·임대료·급여를 결산한다.\n사흘에 끝나지 않고 영업을 이어간다.\n\n비밀 입구는 손님 출입이 막힌 뒤편 전용 창고 안.\n입구를 내려가 감옥·은신처·창고·화로를 짓거나\n다른 비밀 출구까지 직접 통로를 판다.\n비밀 의뢰를 받는 것은 당신의 선택이다."
		choices=[["begin","여관 문을 연다"]]
		if FileAccess.file_exists("user://inn-tycoon-v15.json"):choices.push_front(["load","저장한 영업 이어서 하기"])
	elif c.summary or c.ending!="":
		title.text=c.ending if c.ending!="" else "%d일차 · 새벽 결산" %c.day
		var endings={"여관의 진짜 주인":"이전 주인의 장부는 빚만 남긴 게 아니었다. 반입 허가와 여관의 이름도 남겼다. 이제 그 이름을 지키는 건 당신이다.","다시 켜진 등불":"문을 두드린 사람을 가려 받으며 사흘을 버텼다. 열쇠는 아직 당신 주머니에 있다.","국경의 은신처":"약과 사람을 숨겼다. 이곳을 여관이라 부르는 사람도, 피난처라 부르는 사람도 있다. 다음 순찰 전까지는.","값비싼 침묵":"오늘의 수입에는 장부에 쓸 수 없는 돈이 섞여 있다. 문은 열려 있고, 빚진 침묵도 남았다.","빚으로 넘어간 열쇠":"손님은 떠났고, 장부에는 갚지 못한 돈이 남았다. 채권자가 열쇠를 가져갔다.","봉인된 여관":"문밖에 증인이 너무 많았다. 경비가 등불을 끄고 문을 봉인했다."}
		body.text=(str(endings.get(c.ending,"아침이 왔다. 문을 열기 전에 장부를 정리한다.")))+"\n\n"
		for row in c.history:body.text+="%d일차 · 식사 %d회 · 지출 %d닢 · 잔액 %d닢\n" %[row.day,row.served,row.cost,row.balance]
		body.text+="\n현재 %d닢 · 미납 %d닢\n들어본 소문 %d개 · 평판 %d" %[sim.data.money,sim.data.debt,c.rumors.size(),c.reputation]
		choices=[["retry","다른 선택으로 다시 시작"],["freeplay","결과를 남기고 자유 영업"]] if c.ending!="" else [["continue","다음 날 문을 연다 · 자동 저장"]]
	else:
		title.text="여관 장부 · %d일차" %c.day
		body.text=host.Campaign.goal(sim)+"\n\n보유 %d닢 · 미납 %d닢\n식사 제공 %d회 · 객실 안내 %d회\n평판 %d · 신고 %d회\n\n오늘 임대료 %d닢%s%s\n영업은 08시부터 다음 날 08시까지, 약 3분 30초.\n새벽에 하루를 결산한다.\n\n사람을 누르면 주인이 다가가 말을 건다.\n요구를 들은 뒤 방과 식사를 제안할 수 있다.\n마라는 내 편이다. 기본으로 서빙을 맡기고 지하 일을 할 수 있다.\n\n지하에서도 지상의 영업을 볼 수 있다.\n흙벽은 한 번 눌러 파고, 열린 바닥에는 시설을 짓는다.\n입구는 마당·건물 아래 여러 곳에 만들 수 있다.\n\n선택 의뢰: 회색 망토와 생포 의뢰를 이야기한다.\n누구를 가두고 왜 가두는지는 목표에 표시된다." %[sim.data.money,sim.data.debt,sim.data.served,c.bookings,c.reputation,sim.data.ops.reports,host.Campaign.rent(int(c.day))," · 일당 4닢" if sim.data.staff.hired else ""," · 세금 8닢" if int(c.day)==3 and not c.tax_paid else ""]
		choices=[["save","현재 상태 저장"],["close","장부를 닫는다"]]
		if host.Tycoon.active(sim):
			body.text="오늘 매출 %d닢 · 누적 매출 %d닢\n객실 이용 %d/5 · 식사 제공 %d회\n\n임대료 %d닢 · 알바 일당 %d닢\n\n접수: %s / 청소: %s / 식사: 마라\n\n정상 영업으로 돈을 벌어 객실·주방을 개선하세요.\n비밀 의뢰와 지하는 선택입니다.\n전용 창고에는 일반 손님이 들어오지 않습니다." %[sim.data.tycoon.day_sales,sim.data.tycoon.sales,sim.data.rooms.values().filter(func(r):return r.guest!="").size(),sim.data.served,host.Campaign.rent(int(c.day)),host.Tycoon.wage(sim),"자동" if sim.data.tycoon.reception else "주인","자동" if sim.data.tycoon.cleaning else "주인"]
		if host.Campaign.can_rest(sim):choices.push_front(["rest","마라에게 맡기고 새벽까지 쉰다"])
	var key=JSON.stringify(choices)
	if key!=last_key:
		last_key=key;controls.clear()
		for old in buttons.get_children():buttons.remove_child(old);old.queue_free()
		for item in choices:
			var b=Button.new();b.text=item[1];b.custom_minimum_size.y=76;b.add_theme_font_override("font",host.episode_font());b.add_theme_font_size_override("font_size",23);b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(choose.bind(item[0]));buttons.add_child(b);controls[item[0]]=b
