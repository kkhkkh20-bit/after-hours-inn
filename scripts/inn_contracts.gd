extends RefCounted
const CASES=[
	{"name":"가짜 징수관 헤르만","crime":"피난민에게 군세를 사칭해 통행세를 강탈했다.","task":"생포하고 신뢰할 수 있는 정보를 얻기","kind":"intel","reward":60,"lead":"빼앗은 세금이 인질 장사꾼의 장부로 흘러갔다."},
	{"name":"인질 장사꾼 울프","crime":"민간인을 가두고 가족에게 몸값을 요구했다.","task":"생포하고 불법 자금을 회수하기","kind":"money","reward":75,"lead":"회계 장부에서 매복대에 돈을 보낸 흔적을 찾았다."},
	{"name":"매복대장 크라그","crime":"구호 마차를 습격하고 호위대를 살해하도록 지시했다.","task":"혐의 확인 후 암살, 또는 생포하고 정보 얻기","kind":"neutralize","reward":90,"lead":"국경의 범죄 조직 한 갈래를 끊었다. 새로운 사건이 기다린다."}
]

static func ensure(s) -> void:
	if not s.data.has("contracts"):s.data.contracts={"index":0,"completed":0,"intel":0,"recovered":0,"case":{},"claimed":[],"alert":0,"last":"현상수배 게시판에서 첫 의뢰를 받으세요."}

	for pair in [["intel_stock",0],["records",[]]]:
		if not s.data.contracts.has(pair[0]):s.data.contracts[pair[0]]=pair[1]

static func current(s) -> Dictionary:
	return s.data.get("contracts",{}).get("case",{})

static func target(s) -> String:return str(current(s).get("target",""))

static func accept(s) -> void:
	ensure(s)
	if not s.data.contracts.case.is_empty():return
	var template: Dictionary=CASES[int(s.data.contracts.index)%CASES.size()]
	var id=preload("res://scripts/inn_campaign.gd").special(s,"wanted",str(template.name),"하룻밤 조용히 묵을 방이 있소.")
	var p: Dictionary=s.data.people[id];p.visit="stay";p.rate=14;p.pos=s.GATE;p.case_target=true
	s.retarget_arrival(id)
	s.data.contracts.case=template.duplicate(true);s.data.contracts.case.merge({"target":id,"evidence":false,"ready":false,"paid":false,"status":"표적이 정문으로 들어옵니다."})
	s.data.contracts.last=str(template.name)+"의 행적을 확인하세요."
	s.note(s.data.contracts.last)

static func dossier(s,id: String) -> String:
	var c=current(s)
	if c.is_empty() or str(c.get("target",""))!=id:return "공식 의뢰의 표적이 아닙니다. 일반 손님을 의심할 근거는 없습니다."
	c.evidence=true
	return "%s\n혐의: %s\n조건: %s\n보상 %d닢" %[c.name,c.crime,c.task,c.reward]

static func profile(p: Dictionary) -> void:
	if not p.has("questioning"):p.questioning={"progress":0,"intel":false,"reliable":true,"money":false,"cooldown":0.0}

static func act(s,id: String,action: String) -> void:
	ensure(s)
	if not s.data.people.has(id) or s.data.people[id].state!="captive":return
	var p: Dictionary=s.data.people[id];profile(p);var q: Dictionary=p.questioning
	if action=="ransom":
		if q.money:s.note("이미 금품을 회수한 대상입니다.");return
		q.money=true;s.data.money+=20;s.data.contracts.recovered+=20;s.data.contracts.alert+=3
		p.life.mood=maxf(5,p.life.mood-15);s.note("20닢을 뜯어냈다. 상대의 원한과 조직의 추적 위험이 높아졌다.");return
	if action=="verify_intel":
		if not q.intel or q.reliable:return
		if int(s.data.contracts.intel_stock)>0:s.data.contracts.intel_stock-=1
		elif s.data.money>=5:s.data.money-=5
		else:s.note("정보 1건 또는 대조 비용 5닢이 필요합니다.");return
		q.reliable=true;record(s,id,"장부와 진술의 대조를 마쳐 신뢰성을 확인했다.",true,false);return
	if q.intel:s.note("새로 얻을 진술은 없습니다. 불확실한 정보는 대조할 수 있습니다.");return
	if s.data.clock<float(q.cooldown):s.note("심문 중입니다. 잠시 후 다시 이야기하세요.");return
	q.cooldown=s.data.clock+4
	if action=="coerce":
		p.life.trust=maxf(0,float(p.life.get("trust",25))-20)
		q.progress=mini(100,int(q.progress)+60);q.reliable=false;p.life.mood=maxf(5,p.life.mood-25);s.data.contracts.alert+=8
		s.note("강압적인 심문으로 진술을 얻었다. 신뢰성은 낮고 원한과 추적 위험이 커졌다.")
	else:
		p.life.trust=minf(100,float(p.life.get("trust",25))+8)
		q.progress=mini(100,int(q.progress)+35);s.note("장부와 행적을 차분히 추궁했다. 진술 %d/100." %q.progress)
	p.life.action="심문 후 휴식";p.life.rest_until=s.data.clock+4
	if int(q.progress)>=100:
		q.intel=true;s.data.contracts.intel+=1
		record(s,id,str(current(s).get("lead","숨겨진 거래와 인맥에 대한 단서를 얻었다.")),bool(q.reliable),false)

static func tick(s) -> void:
	ensure(s)
	if int(s.data.contracts.alert)>=20 and s.data.clock>=float(s.data.contracts.get("next_trace",0)) and s.data.ops.inspector.state=="idle":
		s.data.contracts.next_trace=s.data.clock+180;s.data.contracts.alert-=15
		s.data.ops.inspector.state="scheduled";s.data.ops.inspector.at=s.data.clock+45;s.data.ops.inspector.resolved=false
		s.note("조직을 추적하던 순찰대가 실종 소문을 들었다. 45초 뒤 방문한다.")
	var c=current(s)
	if c.is_empty() or c.paid:return
	if not s.data.people.has(c.target):c.status="표적을 찾을 수 없습니다. 의뢰를 다시 추적하세요.";return
	var p: Dictionary=s.data.people[c.target];profile(p)
	var intel=bool(p.questioning.intel) and bool(p.questioning.reliable)
	c.ready=bool(c.evidence) and ((p.state=="captive" and intel) if c.kind=="intel" else ((p.state=="captive" and bool(p.questioning.money)) if c.kind=="money" else (p.state=="dead" or p.state=="gone" and p.get("death_at",-1)>=0 or p.state=="captive" and intel)))
	if c.ready:c.status="조건 완료 · 게시판에서 보상을 받으세요."
	elif p.state in ["gone","leaving","escaping"]:c.status="표적이 도주 중입니다. 다시 추적할 수 있습니다."
	elif not c.evidence:c.status="표적의 혐의를 먼저 확인하세요."
	elif p.state=="captive":c.status="수감 완료 · "+str(c.task)
	elif p.state=="dead":c.status="이 의뢰는 생포가 필요했습니다. 다시 추적할 수 있습니다."
	else:c.status="표적을 눌러 감옥에 가두거나 의뢰 조건을 확인하세요."

static func claim(s) -> void:
	tick(s);var c=current(s)
	if c.is_empty() or not c.ready or c.paid:return
	if c.target in s.data.contracts.claimed:return
	c.paid=true;s.data.contracts.claimed.append(c.target);s.data.money+=int(c.reward);s.data.contracts.completed+=1
	s.data.contracts.last=c.lead;s.note("의뢰 완료 · %d닢. %s" %[c.reward,c.lead])

static func next(s) -> void:
	ensure(s)
	if not current(s).get("paid",false):return
	s.data.contracts.index+=1;s.data.contracts.case={}

static func retry(s) -> void:
	var c=current(s)
	if c.is_empty() or c.paid or not s.data.people.has(c.target):return
	var p: Dictionary=s.data.people[c.target]
	if p.state not in ["gone","dead"]:return
	var replace_dead=p.state=="dead"
	s.data.contracts.case={};accept(s)
	if replace_dead:
		var c2=current(s);c2.name=str(c2.name)+"의 공범";s.data.people[c2.target].name=c2.name

static func summary(s) -> String:
	ensure(s)
	var c=current(s)
	var base="범죄 의뢰 %d건 해결 · 정보 %d건\n회수 자금 %d닢 · 조직 추적 %d\n" %[s.data.contracts.completed,s.data.contracts.intel,s.data.contracts.recovered,s.data.contracts.alert]
	if c.is_empty():return base+"\n"+str(CASES[int(s.data.contracts.index)%CASES.size()].crime)+"\n게시판에서 의뢰를 받으면 표적이 손님으로 들어옵니다."
	return base+"\n%s\n혐의: %s\n목표: %s · 보상 %d닢\n%s" %[c.name,c.crime,c.task,c.reward,"보상 수령 완료 · 다음 사건으로" if c.paid else c.status]+checklist(s)

static func goal(s) -> String:
	var c=current(s)
	if c.is_empty():return "접수대 → 현상수배 · 범죄자 추적"
	var hint="생포 / 암살" if c.kind=="neutralize" else "생포 의뢰"
	if c.paid:hint="게시판 → 다음 사건"
	elif c.ready:hint="게시판 → 보상 수령"
	elif not c.evidence:hint="게시판 → 혐의 확인"
	elif s.data.people.get(c.target,{}).get("state","") in ["gone","dead"]:hint="게시판 → 재추적"
	elif s.data.people.get(c.target,{}).get("state","")=="captive":hint="수감자 → 금품 회수" if c.kind=="money" else "수감자 → 심문"
	return str(c.name)+" · "+hint

static func questioning(s,id: String) -> String:
	var p: Dictionary=s.data.people[id];profile(p)
	var q: Dictionary=p.questioning
	return "진술 %d/100 · %s\n금품 회수 %s · 신뢰도 %s" %[q.progress,"정보 확보" if q.intel else "심문 중","완료" if q.money else "미회수","확인됨" if q.reliable else "대조 필요"]

static func record(s,id: String,message: String,reliable: bool,stock: bool=true) -> void:
	ensure(s)
	var source=str(s.data.people.get(id,{}).get("name","장부"))
	s.data.contracts.records.append({"time":s.data.clock,"source":source,"text":message,"reliable":reliable})
	if s.data.contracts.records.size()>20:s.data.contracts.records.pop_front()
	if stock:s.data.contracts.intel_stock+=1;s.data.contracts.intel+=1
	s.note(source+": "+message)

static func archive(s) -> String:
	ensure(s)
	var result="대조에 쓸 정보 %d건\n" %int(s.data.contracts.intel_stock)
	for index in range(s.data.contracts.records.size()-1,-1,-1):
		var row: Dictionary=s.data.contracts.records[index]
		result+="\n%s · %s\n%s\n" %[row.source,"확인된 정보" if row.reliable else "대조 필요",row.text]
	return result if not s.data.contracts.records.is_empty() else result+"\n아직 정보가 없습니다. 심문하거나 정보원을 확보하세요."

static func checklist(s) -> String:
	var c=current(s)
	if c.is_empty():return "의뢰 수락 → 혐의 확인 → 생포/암살 → 조건 달성 → 보상"
	var p: Dictionary=s.data.people.get(c.target,{})
	var q: Dictionary=p.get("questioning",{})
	return "\n%s 혐의 확인\n%s 생포/제압\n%s 정보·자금·암살 조건\n%s 보상 수령" %["완료" if c.evidence else "대기","완료" if p.get("state","") in ["captive","dead"] else "대기","완료" if c.ready or c.paid else "대기","완료" if c.paid else "대기"]

static func next_action(s) -> Array:
	var c=current(s)
	if c.is_empty():return ["case_accept","의뢰 수락 · 표적 손님 유도"]
	if c.paid:return ["case_next","다음 사건으로"]
	if c.ready:return ["case_claim","조건 완료 · %d닢 받기" %int(c.reward)]
	if not c.evidence:return ["case_dossier","먼저 표적의 혐의 확인"]
	var p: Dictionary=s.data.people.get(c.target,{})
	if p.get("state","") in ["gone","dead"]:return ["case_next","공범·도주 표적 재추적"]
	if p.get("state","")=="captive":
		if c.kind=="money":return ["case_ransom","수감자에게 자금 회수"]
		var q: Dictionary=p.get("questioning",{})
		if q.get("intel",false) and not q.get("reliable",true):return ["case_verify","정보 대조로 조건 완료"]
		var wait=maxi(0,ceili(float(q.get("cooldown",0))-s.data.clock))
		return ["case_question","심문 중 · %d초" %wait if wait>0 else "계속 심문해서 정보 얻기",wait==0]
	if s.data.sandbox.get("capture",{}).get("target","")==c.target:return ["case_focus","감옥으로 호송 중 · 위치 보기"]
	if p.get("state","") in ["leaving","escaping"]:return ["case_focus","도주 중인 표적 위치 보기"]
	return ["case_capture","표적 생포 · 감옥까지 자동 호송"]
