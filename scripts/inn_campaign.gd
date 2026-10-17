extends RefCounted
## Three connected days. All decisions and outcomes are part of the saved simulation.
static func active(sim) -> bool:
	return sim.data.get("campaign",{}).get("active",false)

static func start(sim) -> void:
	sim.start_gentle_opening()
	sim.data.campaign={"active":true,"day":1,"next_dawn":480.0,"intro":true,"summary":false,"ending":"","deal":"waiting","cargo":false,"guard_day":0,"guard_done":0,"worker":"","broker":"","reputation":0,"talks":0,"bookings":0,"start_money":24,"start_served":0,"history":[],"rumors":[],"fugitive":"","protected":false,"ledger_found":false,"evidence_used":false,"collector":"","tax_paid":false}
	sim.note("국경이 닫힌 지 사흘. 여관의 열쇠까지 빼앗길 수는 없다.")

static func special(sim,role: String,name_: String,line: String) -> String:
	sim.data.serial+=1
	var id="guest_%d" %sim.data.serial
	sim.data.people[id]={"id":id,"name":name_,"trait":line,"rate":0,"visit":role,"role":role,"pos":Vector2(14.25,3.25),"state":"arriving","room":0,"path":sim.path_to(Vector2(14.25,3.25),Vector2(-1.25,1.25)),"arrival":sim.data.clock,"checkout":0.0,"order_at":0.0,"meals":0,"known":false}
	preload("res://scripts/intrigue.gd").register(sim.data.people[id])
	return id

static func tick(sim) -> void:
	if not active(sim):return
	var c: Dictionary=sim.data.campaign
	if c.ending!="" or c.summary:return
	if sim.data.cells.has("4,0") and not c.ledger_found:
		c.ledger_found=true;sim.data.money+=6
		sim.note("흙벽 뒤에서 이전 주인의 장부와 6닢을 찾았다. 교구의 반입 허가가 끼워져 있다.")
	if c.broker!="" and c.deal=="waiting" and sim.data.people[c.broker].state in ["leaving","gone"]:c.deal="missed";sim.note("회색 망토가 답을 듣지 못하고 떠났다.")
	if sim.data.served>=1 and c.worker=="":
		c.worker=special(sim,"worker","마라","손이 부족해 보이네요. 일할 사람은 필요 없으세요?")
		sim.note("홀에 일자리를 찾는 사람이 들어왔다.")
	if sim.data.ops.inspector.state=="waiting" and int(c.get("wait_day",0))<int(c.day):
		c.wait_day=c.day;sim.data.ops.inspector.remaining=75
	var elapsed=sim.data.clock-(float(c.day)-1)*480
	if elapsed>=180 and c.day==1 and c.broker=="":
		c.broker=special(sim,"broker","회색 망토","오늘 밤만 상자 하나 맡아주시오. 열어보지만 않으면 돼.")
		sim.note("회색 망토가 문 앞에서 주인을 찾는다.")
	if elapsed>=180 and c.day==3 and c.collector=="":
		c.collector=special(sim,"collector","군세 징수원","군세 여덟 닢을 받으러 왔소. 장부를 준비하시오.")
		sim.note("징수원이 여관의 납세 장부를 찾는다.")
	if elapsed>=120 and c.day==2 and c.fugitive=="":
		c.fugitive=special(sim,"fugitive","부상 입은 전령","돈은 없습니다. 해 뜰 때까지만 문을 잠글 방이 필요합니다.")
		sim.note("피곤한 전령이 문턱에 주저앉았다.")
	if elapsed>=330 and int(c.guard_day)<int(c.day) and sim.data.ops.inspector.state=="idle":
		c.guard_day=c.day; sim.data.ops.inspector.state="scheduled"; sim.data.ops.inspector.at=sim.data.clock
		sim.note("마당 문에서 순찰대의 발소리가 들린다.")
	if int(sim.data.ops.reports)>=3:
		c.ending="봉인된 여관"; sim.data.paused=true; return
	if sim.data.clock>=float(c.next_dawn): settle(sim)

static func rent(day: int) -> int:
	return [16,24,36][clampi(day-1,0,2)]

static func settle(sim) -> void:
	var c: Dictionary=sim.data.campaign
	if c.summary or c.ending!="":return
	var cost=rent(int(c.day))+(4 if sim.data.staff.hired else 0)+(8 if int(c.day)==3 and not c.tax_paid else 0)
	sim.charge(cost,"%d일차 임대료·급여%s" %[c.day,"·세금" if int(c.day)==3 else ""])
	var record={"day":c.day,"income":int(sim.data.money)-int(c.start_money)+cost,"served":int(sim.data.served)-int(c.start_served),"cost":cost+(8 if int(c.day)==3 and c.tax_paid else 0),"balance":sim.data.money,"debt":sim.data.debt}
	c.history.append(record); c.summary=true
	if sim.data.debt>20:c.ending="빚으로 넘어간 열쇠"
	elif int(c.day)>=3 and not c.get("freeplay",false):
		c.ending="여관의 진짜 주인" if c.evidence_used else ("국경의 은신처" if c.protected and c.deal=="accepted" else ("값비싼 침묵" if c.deal=="accepted" or sim.data.ops.reports>0 else "다시 켜진 등불"))
	sim.data.paused=true

static func next_day(sim) -> void:
	var c: Dictionary=sim.data.campaign
	if not c.summary or c.ending!="":return
	c.day+=1; c.next_dawn+=480; c.summary=false; c.start_money=sim.data.money; c.start_served=sim.data.served
	sim.data.paused=false
	sim.note("%d일차. 빈방을 정리하고 다시 손님을 맞는다." %c.day)

static func goal(sim) -> String:
	var c: Dictionary=sim.data.campaign
	if c.ending!="":return c.ending
	if sim.data.ops.inspector.state=="waiting":return "순찰대가 주인의 설명을 기다립니다"
	if c.deal=="waiting" and c.broker!="":return "회색 망토가 은밀한 제안을 기다립니다"
	if int(c.day)==2 and c.fugitive!="" and not c.protected and sim.data.people[c.fugitive].state not in ["gone","leaving"]:return "부상 입은 전령을 도울지 결정하세요"
	if c.talks==0:return "도착한 손님을 눌러 인사하세요"
	if c.bookings==0:return "손님의 요구를 듣고 객실을 제안하세요"
	if sim.data.served==0:return "손님에게 말을 걸어 식사를 준비하세요"
	if c.worker!="" and not sim.data.staff.hired:return "마라와 이야기하면 영업을 맡길 수 있습니다" if sim.data.people[c.worker].state not in ["gone","leaving"] else "접수대에서 일할 사람을 다시 구할 수 있습니다"
	return "다음 날 08시 결산 · 새벽 납부 %d닢" %[rent(int(c.day))+(4 if sim.data.staff.hired else 0)+(8 if int(c.day)==3 and not c.tax_paid else 0)]

static func hire(sim,id: String) -> bool:
	if sim.data.money<8:sim.note("고용비 8닢이 부족하다.");return false
	sim.data.money-=8; sim.data.staff.hired=true; sim.data.staff.delegated=true; sim.data.staff.pos=sim.data.people[id].pos
	sim.data.people[id].state="gone"; sim.data.campaign.reputation+=1
	sim.note("마라가 서빙을 맡는다. 일당 4닢은 새벽 결산에 지급한다.")
	return true

static func broker_choice(sim,accept: bool) -> void:
	var c: Dictionary=sim.data.campaign
	if c.deal!="waiting":return
	c.deal="accepted" if accept else "refused"
	if accept:
		c.cargo=true; sim.data.money+=12; c.reputation-=1
		sim.note("상자를 지하에 들였다. 12닢을 받았다. 순찰대에게 설명할 일이 생겼다.")
	else:c.reputation+=2; sim.note("거래를 거절했다. 그자는 여관 이름을 기억하겠다고 했다.")
	var id: String=c.broker
	sim.data.people[id].state="leaving"; sim.data.people[id].path=sim.path_to(sim.data.people[id].pos,sim.GATE)

static func guard_answer(sim,answer: String) -> void:
	var c: Dictionary=sim.data.campaign
	var fugitive_here=c.fugitive!="" and sim.data.people.has(c.fugitive) and sim.data.people[c.fugitive].state not in ["gone","leaving"]
	var hidden=c.cargo or (c.protected and fugitive_here)
	if answer=="guard_pay" and sim.data.money<8:sim.note("건넬 돈 8닢이 부족하다.");return
	if answer=="guard_evidence" and c.ledger_found:
		c.evidence_used=true;c.reputation+=3;sim.note("반입 허가를 확인한 경비가 상자를 돌려놓았다. 이전 주인의 장부가 여관을 지켰다.")
	elif answer=="guard_pay":sim.data.money-=8; sim.note("경비가 돈을 챙겼다. 이번에는 더 묻지 않는다.")
	elif answer=="guard_lie" and hidden and sim.data.excavation.hatch_open:
		sim.charge(12,"거짓 진술 적발"); c.reputation-=2; c.cargo=false
		sim.note("열린 지하 입구를 보고 경비가 상자를 압수했다. 벌금 12닢.")
	elif answer=="guard_honest" and hidden:
		sim.charge(8,"금지 물품 신고"); c.cargo=false; c.reputation-=1
		sim.note("숨긴 사정을 밝혔다. 경비는 돈을 받고 눈을 감았다.")
	else:c.reputation+=1; sim.note("경비가 설명을 듣고 돌아선다.")
	c.guard_done=c.day; sim.data.ops.inspector.resolved=true
	preload("res://scripts/intrigue.gd").end_inspection(sim)

static func pay_tax(sim) -> bool:
	var c: Dictionary=sim.data.campaign
	if c.tax_paid:return true
	if sim.data.money<8:sim.note("세금 8닢이 부족하다. 새벽까지 납부를 기다린다.");return false
	sim.data.money-=8;c.tax_paid=true
	var id: String=c.collector
	if id!="":sim.data.people[id].state="leaving";sim.data.people[id].path=sim.path_to(sim.data.people[id].pos,sim.GATE)
	sim.note("징수원에게 군세 8닢을 납부했다. 새벽에 다시 청구하지 않는다.")
	return true

static func can_rest(sim) -> bool:
	if not active(sim):return false
	var c: Dictionary=sim.data.campaign
	return sim.data.staff.hired and sim.data.clock-(float(c.day)-1)*480>=360 and int(c.guard_done)>=int(c.day) and not c.summary and c.ending=="" and sim.data.work.is_empty() and sim.data.dig.is_empty()
