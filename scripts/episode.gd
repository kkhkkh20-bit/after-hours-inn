extends RefCounted
## Deterministic short episode, shared verbatim by both renderers.
var data: Dictionary={"elapsed":0.0,"deal":"waiting","inspection":"waiting","risk":0,"paid":false,"ending":"","briefed":false,"freeplay":false}
const RENT=36
const DEADLINE=240.0

func pending() -> bool:
	return data.deal=="offered" or data.inspection=="offered"

func tick(dt: float, facts: Dictionary) -> void:
	if data.ending!="" or not data.briefed: return
	data.elapsed+=maxf(0,dt)
	if data.elapsed>=40 and data.deal=="waiting": data.deal="offered"
	if data.elapsed>=100 and data.deal=="offered":
		data.deal="refused"; data.risk+=18
	if data.elapsed>=125 and data.inspection=="waiting": data.inspection="offered"
	if data.elapsed>=180 and data.inspection=="offered":
		data.inspection="evaded"; data.risk+=35
	if int(facts.get("risk",0))+int(data.risk)>=100: data.ending="체포"
	elif data.elapsed>=DEADLINE: data.ending="임대료 체납"

func choices() -> Array:
	if not data.briefed: return [["start","문을 연다"]]
	if data.ending!="": return [["retry","다시 시작"],["freeplay","결과를 남기고 자유 플레이"]]
	if data.inspection=="offered":
		return [["honest","장부 공개 · 4닢 / 은닉 발각 시 14닢"],["bribe","조사 무마 · 12닢"],["hide","지하를 창고라고 주장"]]
	if data.deal=="offered":
		return [["pay","보호비 지급 · 8닢"],["report","경비에 신고 · 4닢"],["trade","밀수 조직과 거래 · +16닢"],["refuse","거절 · 경계 증가"]]
	if data.elapsed>=180: return [["settle","접수대에서 임대료 납부 · 36닢"]]
	return []

func choose(action: String, facts: Dictionary) -> Dictionary:
	var allowed=[]
	for c in choices(): allowed.append(c[0])
	if action not in allowed: return {"ok":false,"message":"지금 할 수 없는 선택이다."}
	var cost: int={"pay":8,"report":4,"bribe":12,"honest":14 if facts.get("bodies",0)>0 else 4,"settle":RENT}.get(action,0)
	if int(facts.money)<cost: return {"ok":false,"message":"돈이 부족하다. 영업으로 수입을 확보해야 한다."}
	if action=="settle":
		if not facts.near_counter: return {"ok":false,"message":"접수대까지 이동한 다음 납부하자."}
		if int(facts.served)<3: return {"ok":false,"message":"식사 3회 제공이 필요하다. 직원의 서빙도 포함된다."}
		if data.inspection in ["waiting","offered"]: return {"ok":false,"message":"먼저 경비 조사에 대응해야 한다."}
		data.paid=true
		data.ending="밀수의 대가" if data.deal=="trade" else ("불안한 생존" if int(data.risk)+int(facts.risk)>=40 else "여관을 지킨 밤")
	match action:
		"start": data.briefed=true
		"pay": data.deal="paid"; data.risk+=8
		"report": data.deal="reported"; data.risk=maxi(0,data.risk-8)
		"trade": data.deal="trade"; data.risk+=25
		"refuse": data.deal="refused"; data.risk+=18
		"bribe": data.inspection="bribed"; data.risk=maxi(0,data.risk-12)
		"honest":
			data.inspection="searched"
			data.risk+=25 if facts.get("bodies",0)>0 else -10
			data.risk=maxi(0,data.risk)
		"hide":
			if not facts.hatch and int(facts.risk)+int(data.risk)<55:
				data.inspection="hidden"; data.risk+=8
			else:
				if int(facts.money)<18: data.ending="체포"
				else: cost=18
				data.inspection="discovered"; data.risk+=28
		"freeplay": data.freeplay=true
	return {"ok":true,"coins":16 if action=="trade" else -cost,"message":"선택을 기록했다."}

func title() -> String:
	if data.ending!="": return data.ending
	if not data.briefed: return "마지막 국경 여관"
	if data.inspection=="offered": return "경비의 장부 조사"
	if data.deal=="offered": return "낯선 손님의 보호비 요구"
	return "새벽까지 여관을 지켜라"

func body(facts: Dictionary) -> String:
	if not data.briefed:
		return "전쟁으로 국경이 닫혔다.
당신에게 남은 것은 이 여관뿐이다.

4분 뒤 징수원이 도착한다.
식사 3회와 임대료 36닢을 준비하라.

바닥을 눌러 걷고, 접수대에서 영업한다.
직원에게 맡긴 동안 지하를 넓힐 수 있다.
수상한 제안과 조사는 오른쪽 장부에서 결정한다."
	if data.ending!="":
		var endings={"체포":"숨길 수 없는 정황이 쌓였다. 경비가 여관 문을 봉인했다.","임대료 체납":"새벽 종이 울렸다. 기한을 넘긴 여관의 열쇠를 넘겼다.","밀수의 대가":"열쇠는 지켰다. 이제 조직은 이 여관을 자기 아지트라 부른다.","불안한 생존":"임대료는 냈다. 누군가는 당신이 감춘 것을 기억한다.","여관을 지킨 밤":"장부를 정리하고 문을 잠갔다. 오늘 밤은 살아남았다."}
		return str(endings.get(data.ending,""))+"

식사 %d회 · 남은 돈 %d닢
위험 %d%% · 확장 %d칸

다른 선택으로 다시 시작할 수 있다." %[facts.served,facts.money,mini(100,int(facts.risk)+int(data.risk)),facts.get("dug",0)]
	if data.inspection=="offered": return "경비가 지하 용도를 묻는다.

열린 덮개, 숨긴 사람, 쌓인 의심은 변명에 영향을 준다.
대응하지 않으면 55초 뒤 수상한 여관으로 기록된다."
	if data.deal=="offered": return "낯선 손님이 보호비를 요구한다.
대신 밀수품을 잠시 맡아주면 돈을 주겠다고 한다.

60초 안에 결정하라. 거절해도 영업은 계속되지만 위험이 오른다."
	return "남은 시간 %d초
식사 %d / 3회 · 임대료 %d / 36닢

손님 접수와 식사로 수입을 만든다.
직원 고용은 자유 시간을 주지만 임금이 든다.
지하 확장·제압·운반은 선택 사항이다.

마지막 1분에 접수대로 돌아와 납부하라." %[maxi(0,int(DEADLINE-data.elapsed)),facts.served,facts.money]
