extends RefCounted
## Shared upper-floor layout, versioned migration and decorative architecture.
const TOP_STAIRS=Vector2(8,.75)
static func next_floor(from: int,target: int) -> int:
	if from==3:return 2
	if from==2:return 3 if target==3 else 0
	return 2
static func stair(from: int,target: int) -> Vector2:
	return TOP_STAIRS if from==3 or (from==2 and target==3) else Vector2(8,5)
static func migrate(s) -> void:
	if s.data.sandbox.get("upper_version",0)>=1:return
	for key in s.data.rooms:
		var n=int(key);var r: Dictionary=s.data.rooms[key]
		r.secret_bottom=s.Sandbox.underground(s.Sandbox.room_point(n))
		s.Layout.carve(s,Vector2i(s.data.sandbox.get("receiving",Vector2i.ZERO)),Vector2i(r.secret_bottom))
		var id=str(r.get("guest",""))
		if id!="" and s.data.people.has(id):
			var p: Dictionary=s.data.people[id]
			if p.state in ["staying","entering"]:p.floor=s.Sandbox.floor_of(n);p.pos=s.Sandbox.room_point(n);p.path=[];p.travel="";p.state="staying";p.destination=p.pos;p.destination_floor=p.floor
	# Old room-service tickets are replaced by a trip to the ground-floor restaurant.
	for order_id in s.data.orders:
		var o: Dictionary=s.data.orders[order_id]
		if o.status in ["served","cancelled"] or not s.data.people.has(o.guest):continue
		var guest: Dictionary=s.data.people[o.guest]
		if int(guest.get("room",0))<=0 or guest.get("meal_trip",false):continue
		o.status="cancelled";o.holder="";guest.order_at=s.data.clock+3;guest.meals=maxi(0,int(guest.meals)-1)
		if s.data.work.get("order","")==order_id:s.data.work={}
		if s.data.get("service_target","")==o.guest:s.data.service_target=""
		if s.data.staff.carry==order_id:s.data.staff.carry="";s.data.staff.floor=0;s.data.staff.pos=s.COUNTER;s.data.staff.path=[]
		if s.data.player.carry==order_id:s.data.player.carry=""
	if s.data.has("tycoon"):
		var w: Dictionary=s.data.tycoon.cleaner;w.path=[];w.target="";w.travel=""
	s.data.sandbox.upper_version=1;s.data.sandbox.revision+=1
static func dine(s,p: Dictionary) -> void:
	for point in s.Layout.TABLES:
		var used=s.data.people.values().any(func(other):return other.id!=p.id and other.state not in ["gone","dead","leaving"] and (other.get("dining_table",Vector2(99,99)).distance_to(point)<.5 or (other.get("visit","")=="meal" and other.pos.distance_to(point)<.8)))
		if used:continue
		p.meal_trip=true;p.return_at=0;p.dining_table=point;p.state="to_dining";s.Sandbox.move_person(s,p,point,0);return
	p.order_at=s.data.clock+5

static func build(h) -> void:
	h.gallery=Node3D.new();h.add_child(h.gallery);h.gallery_deck=Node3D.new();h.gallery.add_child(h.gallery_deck)
	h.attic=Node3D.new();h.add_child(h.attic)
	for floor_ in [2,3]:
		h.world_root=h.gallery if floor_==2 else h.attic
		var y=3.2 if floor_==2 else 6.4
		var front=1.0 if floor_==2 else -3.25
		h.box(Vector3(18,.18,front+8.5),Vector3(0,y-.1,(front-8.5)/2),Color("786348") if floor_==2 else Color("675240"))
		for x in range(-9,9):
			for z in range(-8,int(ceil(front))):h.model("town","planks",Vector3(x+.5,y,z+.5),Vector3(1,.035,1))
		h.box(Vector3(18,.7,.18),Vector3(0,y+.35,-8.5),Color("ad9878"))
		for x in [-9,-3,3,9]:
			h.box(Vector3(.16,1.6,.16),Vector3(x,y+.8,-8.5),Color("574231"))
			if x in [-3,3]:h.box(Vector3(.14,.85,2.2),Vector3(x,y+.45,-7.4),Color("a58d6b"))
		for i in range(3 if floor_==2 else 2):
			var x=-6+i*6
			h.model("furniture","bedSingle",Vector3(x,y+.05,-7.25),Vector3(1.3,.85,2.1))
			h.model("furniture","rugRectangle",Vector3(x+1.55,y+.05,-6.6),Vector3(1.3,.025,2))
			h.model("furniture","bookcaseOpen",Vector3(x-1.9,y+.05,-8),Vector3(.7,1.2,.4))
			h.model("furniture","table",Vector3(x+1.7,y+.05,-8),Vector3(.65,.7,.5))
			h.model("town","lantern",Vector3(x+1.9,y+.05,-8.05),Vector3(.16,1.3,.16));h.light_at(Vector3(x+1.8,y+1.6,-7.2),.9)
			h.box(Vector3(3.6,.55,.14),Vector3(x-.9,y+.28,-5.2),Color("9b8262"))

		if floor_==2:
			h.model("furniture","rugRectangle",Vector3(0,y+.03,-2.2),Vector3(10,.025,2.2))
			h.model("furniture","bench",Vector3(-6,y+.05,-.4),Vector3(2.1,.9,.6))
			h.model("furniture","table",Vector3(-3,y+.05,-.4),Vector3(1.2,.7,.6))
			h.model("furniture","books",Vector3(-3,y+.78,-.4),Vector3(.5,.13,.3))
		else:
			h.model("furniture","bookcaseOpen",Vector3(5,y+.05,-7),Vector3(1.6,1.5,.5))
			h.model("furniture","bench",Vector3(5,y+.05,-4.2),Vector3(2,.9,.6))
		for x in [-9,9]:h.box(Vector3(.14,.65,front+8.5),Vector3(x,y+.35,(front-8.5)/2),Color("66513b"))
		h.box(Vector3(15,.09,.09),Vector3(-1.5,y+.8,front),Color("ab9068"))
		for x in [-9,-5,-1,3,6]:h.box(Vector3(.08,.8,.08),Vector3(x,y+.4,front),Color("8e7350"))
	h.world_root=h.surface
	stairs(h,0,5)
	h.upper_stair_visual=Node3D.new();h.add_child(h.upper_stair_visual);h.world_root=h.upper_stair_visual;stairs(h,3.2,.75)
	h.world_root=h.surface
static func stairs(h,base: float,start_z: float) -> void:
	for i in range(16):
		var y=base+(i+1)*.2;var z=start_z-.125-i*.25
		h.box(Vector3(1.85,.12,.26),Vector3(8,y-.06,z),Color("91704f"))
		if i%4==0:
			for x in [7.05,8.95]:h.box(Vector3(.07,.75,.07),Vector3(x,y+.35,z),Color("886c4a"))
	for x in [7.05,8.95]:
		var rail=h.box(Vector3(.065,.065,5.12),Vector3(x,base+2.3,start_z-2),Color("b49a71"));rail.rotation.x=atan(.8)
