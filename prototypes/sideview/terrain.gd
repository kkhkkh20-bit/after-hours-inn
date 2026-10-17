extends RefCounted
const SIZE = 32
const WIDTH = 84
const HEIGHT = 54
const SURFACE = 21
var cells: Dictionary = {}
var inventory = {"dirt":0,"stone":0,"wood":18,"platform":24,"torch":8}
var torches: Array[Vector2i] = [Vector2i(20,17),Vector2i(25,10),Vector2i(17,24),Vector2i(25,3),Vector2i(25,-4)]
var mining_cell = Vector2i(-999,-999)
var mining_progress = 0.0
var revision = 0

func _init() -> void:
	for x in range(WIDTH):
		for y in range(SURFACE,HEIGHT):
			cells[Vector2i(x,y)] = "stone" if y > 35 or (x*7+y*13)%17 == 0 else "dirt"
	# Small starter cellar: five tiles below ground, not a ready-made deep mine.
	for x in range(14,22):
		for y in range(23,26): cells.erase(Vector2i(x,y))
	for y in range(21,26):
		cells.erase(Vector2i(14,y)); cells.erase(Vector2i(15,y))
	for x in range(8,39):
		if x not in [14,15]: cells[Vector2i(x,21)]="wood"
	for floor_ in [0,7,14]:
		for x in range(8,39): cells[Vector2i(x,floor_)]="platform"
	for base in [20,13,6]:
		for i in range(7): cells[Vector2i(13+i,base-i)]="platform"
	for y in range(-6,21):
		cells[Vector2i(7,y)]="wood"; cells[Vector2i(39,y)]="wood"
	cells.erase(Vector2i(39,19)); cells.erase(Vector2i(39,20))

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/SIZE),floori(p.y/SIZE))
func center(c: Vector2i) -> Vector2:
	return Vector2(c*SIZE)+Vector2.ONE*SIZE/2
func valid(c: Vector2i) -> bool:
	return c.x>=1 and c.x<WIDTH-1 and c.y>=-9 and c.y<HEIGHT-1
func within_reach(c: Vector2i,p: Vector2) -> bool:
	return p.distance_to(center(c)) <= SIZE*4.2
func solid(c: Vector2i) -> bool:
	return cells.has(c) and cells[c] != "platform"
func mine(c: Vector2i,p: Vector2,delta: float) -> bool:
	if not valid(c) or not within_reach(c,p) or not cells.has(c):
		mining_progress=0; mining_cell=Vector2i(-999,-999); return false
	if c != mining_cell: mining_cell=c; mining_progress=0
	mining_progress += delta
	var kind: String = cells[c]
	var required = 0.85 if kind == "stone" else 0.48
	if mining_progress < required: return false
	inventory[kind] += 1; cells.erase(c); mining_progress=0; revision+=1
	return true
func can_place(c: Vector2i,p: Vector2,kind: String,body: Rect2) -> bool:
	if not valid(c) or not within_reach(c,p) or cells.has(c) or inventory.get(kind,0)<=0: return false
	if kind != "torch" and Rect2(Vector2(c*SIZE),Vector2.ONE*SIZE).intersects(body): return false
	if kind == "torch": return not torches.has(c) and (cells.has(c+Vector2i.DOWN) or cells.has(c+Vector2i.LEFT) or cells.has(c+Vector2i.RIGHT))
	return cells.has(c+Vector2i.DOWN) or cells.has(c+Vector2i.UP) or cells.has(c+Vector2i.LEFT) or cells.has(c+Vector2i.RIGHT)
func place(c: Vector2i,p: Vector2,kind: String,body: Rect2) -> bool:
	if not can_place(c,p,kind,body): return false
	inventory[kind]-=1
	if kind == "torch": torches.append(c)
	else: cells[c]=kind
	revision+=1; return true
func light_at(p: Vector2) -> float:
	var value = 0.14 if p.y > SURFACE*SIZE+SIZE else 0.35
	for c in torches: value=maxf(value,0.9*(1.0-clampf(p.distance_to(center(c))/240.0,0,1)))
	return value
func encode() -> Dictionary:
	var blocks: Array = []
	for c in cells: blocks.append([c.x,c.y,cells[c]])
	var flames: Array = []
	for c in torches: flames.append([c.x,c.y])
	return {"version":1,"cells":blocks,"inventory":inventory.duplicate(),"torches":flames}
func decode(d: Dictionary) -> bool:
	if d.get("version",0)!=1 or not d.get("cells") is Array or not d.get("inventory") is Dictionary: return false
	var candidate: Dictionary = {}
	for row in d.cells:
		if not row is Array or row.size()!=3 or not row[2] in ["dirt","stone","wood","platform"]: return false
		var c = Vector2i(int(row[0]),int(row[1]))
		if c.x<0 or c.x>=WIDTH or c.y<-9 or c.y>=HEIGHT: return false
		candidate[c]=row[2]
	var flames: Array[Vector2i] = []
	for row in d.get("torches",[]):
		if not row is Array or row.size()!=2: return false
		var c = Vector2i(int(row[0]),int(row[1]))
		if not valid(c): return false
		flames.append(c)
	for k in inventory:
		if not d.inventory.get(k,0) is float and not d.inventory.get(k,0) is int: return false
		if d.inventory.get(k,0)<0: return false
	cells=candidate; torches=flames
	for k in inventory: inventory[k]=int(d.inventory.get(k,0))
	revision+=1; return true
