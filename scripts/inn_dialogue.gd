extends RefCounted
const Campaign=preload("res://scripts/inn_campaign.gd")

static func begin(sim,id: String) -> String:
	var p: Dictionary=sim.data.people[id]
	if not p.get("known",false):
		p.known=true; p.dialogue_stage="request"
		if Campaign.active(sim):sim.data.campaign.talks+=1
	else:p.dialogue_stage="request"
	return line(sim,id)

static func line(sim,id: String) -> String:
	var p: Dictionary=sim.data.people[id]
	if p.get("dialogue_stage","")=="rooms":return "어느 방을 쓰면 되겠소?"
	if p.get("dialogue_stage","")=="rumor":
		return {"worker":"시키는 건 하겠어요. 다만, 아래층에서 이상한 소리가 나면 저도 확인은 해야겠죠.","broker":"약입니다. 누구에게 가는지는 묻지 마시오. 국경군은 약도 군수품이라 부르니까.","fugitive":"후퇴 명령을 전했을 뿐인데 탈영병이 됐습니다. 순찰대에는 제 이름을 말하지 말아주십시오."}.get(p.get("role",""),["이전 주인이 장부를 지하 동쪽 기둥 너머에 숨겼다더군. 순찰대가 오기 전에 찾아보는 게 좋겠소.","이 근방에 약을 실어 나르는 사람이 있다던데요. 관문을 통과할 수가 없대요.","같은 지붕 아래 있다고 같은 편은 아니오. 객실 문은 잠가두시오.","아픈 사람은 늘어나는데 약값은 세 배가 됐어요."][(int(id.get_slice("_",1))-1)%4])
	if p.state=="dead":return "숨이 끊어졌다. 이곳에 그대로 둘 수는 없다."
	if p.state=="down":return "잠시 의식을 잃었다. 깨어나기 전에 판단해야 한다."
	if p.state=="restrained":return "놓으시오. 대체 왜 이러는 거요?"
	if p.get("role","")=="collector":return "군세 여덟 닢이오. 오늘 새벽 전까지 내시오. 이미 낸 세금은 결산에서 다시 받지 않겠소."
	if p.get("role","")=="worker":return "일할 사람 구하시죠? 여덟 닢이면 시작할게요. 서빙은 제가 맡고, 하루 품삯은 네 닢입니다."
	if p.get("role","")=="broker":return "오늘 밤, 지하에 상자 하나만 맡아주시오. 열두 닢이오. 순찰대가 물으면 식재료라고 하시오."
	if p.get("role","")=="fugitive" and not p.get("protected",false):return "돈은 없습니다. 해 뜰 때까지만 문을 잠글 방이 필요합니다. 저를 찾는 사람이 오더라도 모른다고 해주십시오."
	if p.state in ["staying","dining"]:
		for order_ in sim.data.orders.values():
			if order_.guest==id and order_.status not in ["served","cancelled"]:return "따뜻한 식사 좀 부탁하겠소. 오늘 제대로 먹은 게 없어서."
		return "잘 먹었소. 잠시 쉬었다 가겠소." if p.get("visit","")=="meal" else "방은 잘 쓰고 있소. 아침까지 방해만 없으면 좋겠군."
	if p.get("visit","")=="meal":return "묵을 곳은 있습니다. 수프 한 그릇이면 돼요. 따뜻한 걸로 주시겠어요?"
	return ["조용한 방 하나 있소? 마당 소리가 안 들리는 안쪽이면 좋겠소. 숙박비는 %d닢 드리리다.","해 뜨기 전에 떠나야 하오. 문 가까운 방이면 좋겠소. %d닢이면 되겠소?","사람들 눈에 덜 띄는 방이 필요하오. 누구와 같이 왔냐는 건 묻지 마시오. %d닢 드리리다.","오래 걸었더니 다리가 말을 안 듣네요. 방 하나와 따뜻한 식사 부탁해요. %d닢이에요."][(int(id.get_slice("_",1))-1)%4] %int(p.rate)

static func options(sim,id: String) -> Array:
	var p: Dictionary=sim.data.people[id]
	if p.get("dialogue_stage","")=="rooms":
		var result=[]
		for n in [1,2]:
			var room_: Dictionary=sim.data.rooms[str(n)]
			result.append(["book"+str(n),("안쪽 조용한 방" if n==1 else "마당과 가까운 방")+(" · 사용 중" if room_.guest!="" else (" · 정리 후 안내" if room_.dirty else "")),room_.guest==""])
		result.append(["talk_back","다시 이야기한다"]);return result
	if p.get("dialogue_stage","")=="rumor":return [["talk_back","알겠습니다. 그래서…"]]
	if p.state=="dead":return [["drag","시신을 옮긴다"]]
	if p.state in ["down","captive","restrained"]:return [["actions","조치를 결정한다"],["drag","끌기 / 놓아주기"]]
	if p.get("role","")=="collector":return [["pay_tax","여덟 닢, 여기 있습니다."],["farewell","새벽 전에 준비하겠습니다."]]
	if p.get("role","")=="worker":return [["hire_worker","좋아요. 서빙을 맡아주세요."],["ask_story","일하기 전에 알아둘 게 있나요?"],["farewell","생각해보겠습니다."]]
	if p.get("role","")=="broker":return [["accept_cargo","상자를 맡겠습니다. +12닢"],["ask_story","상자에 무엇이 들었습니까?"],["refuse_cargo","우리 여관에서는 안 됩니다."]]
	if p.get("role","")=="fugitive" and not p.get("protected",false):return [["shelter","방을 드리겠습니다. 돈은 됐어요."],["feed_fugitive","식사라도 드시고 가세요."],["ask_story","누가 당신을 찾습니까?"],["dismiss","여기는 안 됩니다."]]
	var result=[]
	if p.state in ["waiting","arriving"] and p.get("visit","")!="meal":result.append(["offer_room","방을 보여드리겠습니다."])
	else:
		if p.get("visit","")=="meal" and p.state=="arriving" or sim.data.orders.values().any(func(o):return o.guest==id and o.status not in ["served","cancelled"]):result.append(["serve_meal","따뜻한 식사를 내오겠습니다."])
	result.append(["ask_story","길에서는 별일 없었습니까?"])
	if sim.data.served>=1:result.append(["actions","조용히 다른 조치를 한다"])
	result.append(["farewell","편히 계세요."])
	return result

static func choose(sim,id: String,action: String) -> String:
	var p: Dictionary=sim.data.people[id]
	match action:
		"offer_room":p.dialogue_stage="rooms";return "reopen"
		"talk_back":p.dialogue_stage="request";return "reopen"
		"ask_story":
			p.dialogue_stage="rumor"
			if Campaign.active(sim) and id not in sim.data.campaign.rumors:sim.data.campaign.rumors.append(id)
			return "reopen"
		"book1","book2":
			var n=1 if action=="book1" else 2
			if sim.request_room(n,id):p.chosen_room=n
			return "close"
		"serve_meal":sim.request_direct_service(id);return "close"
		"pay_tax":Campaign.pay_tax(sim);return "close"
		"hire_worker":Campaign.hire(sim,id);return "close"
		"accept_cargo":Campaign.broker_choice(sim,true);return "close"
		"refuse_cargo":Campaign.broker_choice(sim,false);return "close"
		"feed_fugitive":
			p.protected=true;p.visit="meal";p.state="dining";p.order_at=sim.data.clock+0.1;p.checkout=sim.data.clock+90;sim.data.campaign.protected=true;sim.data.campaign.reputation+=1
			return "close"
		"shelter":
			p.protected=true;p.visit="stay";p.state="waiting";p.path=[];p.arrival=sim.data.clock;p.rate=0;sim.data.campaign.protected=true;sim.data.campaign.reputation+=3
			p.dialogue_stage="rooms";return "reopen"
	return "pass"
