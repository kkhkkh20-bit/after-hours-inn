extends RefCounted
## Standable surfaces and the visible ladder form a small traversal graph.
## The route drives the existing CharacterBody2D; it never teleports it.
var terrain
var hatch_open=false
var graph=AStar2D.new()
var nodes: Dictionary={}
var cells_by_id: Dictionary={}
var edge_kinds: Dictionary={}
var revision=-1

func world(c: Vector2i) -> Vector2:
	return Vector2(c.x*32+16,c.y*32-27)
func _solid(c: Vector2i) -> bool:
	return terrain.solid(c) or (not hatch_open and c.y==21 and c.x in [14,15])
func clear_at(p: Vector2) -> bool:
	var rect=Rect2(p-Vector2(11.5,26.5),Vector2(23,53))
	for x in range(floori(rect.position.x/32),floori(rect.end.x/32)+1):
		for y in range(floori(rect.position.y/32),floori(rect.end.y/32)+1):
			if _solid(Vector2i(x,y)) and rect.intersects(Rect2(x*32,y*32,32,32)): return false
	return true
func _surface(c: Vector2i) -> bool:
	return terrain.cells.has(c) or (not hatch_open and c.y==21 and c.x in [14,15])
func _ladder(c: Vector2i) -> bool:
	return c.x==15 and c.y>=14 and c.y<=30
func _segment_clear(a: Vector2,b: Vector2,jump: bool=false) -> bool:
	for i in range(1,13):
		var t=i/12.0
		var p=a.lerp(b,t)
		if jump: p.y-=sin(t*PI)*78
		if not clear_at(p): return false
	return true
func rebuild(map,open_hatch: bool,carrying: bool=false) -> void:
	terrain=map; hatch_open=open_hatch; revision=map.revision
	graph.clear(); nodes.clear(); cells_by_id.clear(); edge_kinds.clear()
	for x in range(1,terrain.WIDTH-1):
		for y in range(2,terrain.HEIGHT-1):
			var c=Vector2i(x,y)
			if (_surface(c) or _ladder(c)) and clear_at(world(c)):
				var id=nodes.size(); nodes[c]=id; cells_by_id[id]=c; graph.add_point(id,world(c))
	for c in nodes:
		for d in [Vector2i.LEFT,Vector2i.RIGHT]:
			var next=c+d
			if nodes.has(next) and (_surface(c) or _ladder(c)) and (_surface(next) or _ladder(next)) and _segment_clear(world(c),world(next)):
				_connect(c,next,"walk")
		if _ladder(c):
			for d in [Vector2i.UP,Vector2i.DOWN]:
				var next=c+d
				if nodes.has(next) and _ladder(next) and _segment_clear(world(c),world(next)):
					_connect(c,next,"ladder")
		if not _surface(c): continue
		for dx in range(-2 if carrying else -3,3 if carrying else 4):
			for dy in range(-1 if carrying else -2,1):
				if dy==0 and absi(dx)<2: continue
				if dx==0 and dy==0: continue
				if dy==0:
					var gap=false
					for offset in range(1,absi(dx)):
						if not _surface(c+Vector2i(signi(dx)*offset,0)): gap=true
					if not gap: continue
				var next=c+Vector2i(dx,dy)
				if nodes.has(next) and _surface(next) and _segment_clear(world(c),world(next),true): _connect(c,next,"jump")
		# Safe short falls, including dropping through a one-way platform.
		for dx in range(-1,2):
			for dy in range(1,5):
				var next=c+Vector2i(dx,dy)
				if nodes.has(next) and _surface(next) and _segment_clear(world(c),world(next)):
					if terrain.cells.get(c,"")!="platform" and dx==0: continue
					_connect(c,next,"drop"); break
func _connect(a: Vector2i,b: Vector2i,kind: String) -> void:
	var from_id: int=nodes[a]; var to_id: int=nodes[b]
	if graph.are_points_connected(from_id,to_id,false): return
	graph.connect_points(from_id,to_id,false); edge_kinds[Vector2i(from_id,to_id)]=kind
func route(from: Vector2,clicked: Vector2) -> Array:
	if nodes.is_empty(): return []
	var start=graph.get_closest_point(from)
	var goal=-1; var best=95.0
	for id in cells_by_id:
		var distance=graph.get_point_position(id).distance_to(clicked-Vector2(0,27))
		if distance<best: best=distance; goal=id
	if goal<0 or graph.get_point_position(start).distance_to(from)>110: return []
	var path=graph.get_id_path(start,goal)
	var result: Array=[]
	for i in range(path.size()):
		result.append({"point":graph.get_point_position(path[i]),"kind":"walk" if i==0 else edge_kinds.get(Vector2i(path[i-1],path[i]),"walk")})
	return result

func route_near(from: Vector2,focus: Vector2,reach: float) -> Array:
	var result: Array=[]; var best=INF
	for c in nodes:
		if not _surface(c): continue
		var p=world(c)
		if p.distance_to(focus)>reach: continue
		var candidate=route(from,p+Vector2(0,27))
		if candidate.is_empty(): continue
		var cost=0.0; var previous=from
		for step in candidate: cost+=previous.distance_to(step.point); previous=step.point
		if cost<best: best=cost; result=candidate
	return result
