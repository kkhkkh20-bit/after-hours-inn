extends RefCounted
const Episode=preload("episode.gd")
var checks=0
var failures=0
func check(ok: bool, name_: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("EPISODE: "+name_)
func run() -> int:
	var facts={"money":60,"served":3,"near_counter":true,"risk":0,"bodies":0,"hatch":false,"dug":2}
	var e=Episode.new()
	e.tick(200,facts); check(e.data.elapsed==0,"briefing blocks deadline")
	check(not e.choose("settle",facts).ok,"cannot settle before allowed")
	check(e.choose("start",facts).ok,"open inn")
	e.tick(41,facts); check(e.pending(),"extortion arrives")
	var low=facts.duplicate(); low.money=0
	check(not e.choose("pay",low).ok and e.data.deal=="offered","insufficient funds atomic")
	check(e.choose("report",facts).coins==-4,"report fee")
	e.tick(85,facts); check(e.data.inspection=="offered","inspection arrives")
	check(e.choose("honest",facts).coins==-4,"clean books fee")
	e.tick(55,facts)
	var far=facts.duplicate(); far.near_counter=false
	check(not e.choose("settle",far).ok,"settlement requires physical counter")
	var unserved=facts.duplicate(); unserved.served=2
	check(not e.choose("settle",unserved).ok,"meal milestone required")
	check(e.choose("settle",facts).coins==-36,"rent deducted once")
	check(e.data.ending=="여관을 지킨 밤","clean survival ending")
	check(not e.choose("settle",facts).ok,"no duplicate rent")
	var time=e.data.elapsed; e.tick(900,facts); check(e.data.elapsed==time,"ending stops deadline")
	check(e.choose("freeplay",facts).ok and e.data.freeplay,"freeplay after ending")
	e=Episode.new(); e.choose("start",facts); e.tick(41,facts)
	check(e.choose("trade",facts).coins==16,"faction advances money")
	e.tick(85,facts); check(e.choose("hide",facts).ok and e.data.inspection=="hidden","closed hatch low-risk cover story")
	e.tick(55,facts); e.choose("settle",facts); check(e.data.ending=="밀수의 대가","faction consequence ending")
	e=Episode.new(); e.choose("start",facts); e.tick(126,facts)
	var exposed=facts.duplicate(); exposed.hatch=true
	check(e.choose("hide",exposed).coins==-18 and e.data.inspection=="discovered","open hatch lie exposed")
	e=Episode.new(); e.choose("start",facts); e.tick(241,facts)
	check(e.data.ending=="임대료 체납","unpaid deadline fails")
	e=Episode.new(); e.choose("start",facts); var danger=facts.duplicate(); danger.risk=100
	e.tick(1,danger); check(e.data.ending=="체포","maximum risk arrest")
	e=Episode.new(); e.choose("start",facts); e.tick(41,facts); e.choose("refuse",facts)
	e.tick(85,facts); var hidden=facts.duplicate(); hidden.bodies=1
	check(e.choose("honest",hidden).coins==-14,"captive discovered during search")
	var saved=JSON.parse_string(JSON.stringify(e.data)); var restored=Episode.new(); restored.data=saved
	check(restored.data.inspection=="searched" and restored.data.elapsed==e.data.elapsed,"episode save roundtrip")
	print("EPISODE CHECKS: %d checks, %d failures" %[checks,failures])
	return failures
