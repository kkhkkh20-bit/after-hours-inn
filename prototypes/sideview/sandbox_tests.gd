extends RefCounted
const Terrain = preload("res://terrain.gd")
var checks=0
var failures=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func run() -> int:
	var t=Terrain.new()
	var c=Vector2i(23,30); var p=t.center(c)-Vector2(0,50)
	var old_count=t.cells.size(); var old_dirt=t.inventory.dirt
	check(not t.mine(c,p,0.1),"mining instant")
	check(t.cells.has(c),"partial mining erased solid")
	for i in range(20): t.mine(c,p,0.05)
	check(not t.cells.has(c),"mining failed")
	check(t.cells.size()==old_count-1,"mining affected multiple blocks")
	check(t.inventory.dirt==old_dirt+1,"dirt not collected")
	check(not t.mine(Vector2i(70,45),p,2),"reach limit bypass")
	var body=Rect2(p-Vector2(11,19),Vector2(22,38))
	check(t.place(c,p,"dirt",body),"replacing mined block failed")
	check(t.inventory.dirt==old_dirt,"placement cost missing")
	check(not t.place(c,p,"dirt",body),"placed into occupied cell")
	var empty=Vector2i(19,24)
	check(not t.place(empty,t.center(empty),"wood",Rect2(t.center(empty)-Vector2(11,19),Vector2(22,38))),"placed into owner")
	check(not t.place(Vector2i(60,5),p,"wood",body),"remote construction")
	check(not t.place(Vector2i(19,24),t.center(Vector2i(19,24)),"wood",Rect2()),"floating block without support")
	var snap=t.encode(); var copy=Terrain.new()
	check(copy.decode(JSON.parse_string(JSON.stringify(snap))),"save roundtrip invalid")
	check(copy.cells==t.cells and copy.inventory==t.inventory,"save lost terrain or inventory")
	var size_before=copy.cells.size()
	check(not copy.decode({"version":1,"cells":[[1,2,"invalid"]],"inventory":{}}),"invalid block accepted")
	check(copy.cells.size()==size_before,"invalid save mutated map")
	var torch=Vector2i(20,17); var light=t.light_at(t.center(torch))
	t.torches.erase(torch)
	check(t.light_at(t.center(torch))<light,"torch state not reflected in light")
	print("SANDBOX TERRAIN CHECKS: ",checks," checks; ",failures," failures")
	return failures
