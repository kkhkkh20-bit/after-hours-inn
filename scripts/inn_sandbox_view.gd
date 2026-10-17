extends RefCounted
const Rules=preload("res://scripts/inn_sandbox.gd")
static func build(h) -> void:
	h.sim.Prison.ensure(h.sim)
	if h.sandbox_visual!=null:h.sandbox_visual.free()
	h.sandbox_visual=Node3D.new();h.add_child(h.sandbox_visual)
	var root: Node3D=h.sandbox_visual
	for e in h.sim.data.sandbox.entrances:
		for floor_ in [0,1]:
			var p: Vector2=e.top if floor_==0 else Vector2(e.bottom)
			var at: Vector3=h.world_point(p,floor_)
			var node=Node3D.new();root.add_child(node);node.set_meta("floor",floor_);node.position=at;h.world_root=node
			h.box(Vector3(1.25,0.06,1.25),Vector3(0,0.025,0),Color("171f22"))
			for x in [-0.64,0.64]:h.box(Vector3(0.08,0.1,1.4),Vector3(x,0.09,0),Color("b28c51"))
			var lid=h.box(Vector3(1.1,0.08,1.0),Vector3(0,0.12,-0.12),Color("645039"));lid.rotation.x=-1.1 if e.open else 0.0
			if floor_==1:
				h.light_at(Vector3(0,2.1,0.3),1.4)
				for x in [-0.4,0.4]:h.box(Vector3(0.07,1.6,0.07),Vector3(x,0.8,-0.3),Color("a98b58"))
				for y in range(5):h.box(Vector3(0.8,0.07,0.07),Vector3(0,y*0.3+0.2,-0.3),Color("c9ac6a"))
			var title=h.world_label(e.name+(" · 올라가기" if floor_==1 else " · 내려가기"),Vector3(0,0.35,0.9),node);title.pixel_size=0.009;title.set_meta("builder_label",floor_==1)
	for f in h.sim.data.sandbox.facilities:
		var node=Node3D.new();root.add_child(node);node.set_meta("floor",1);node.position=h.world_point(f.pos,1);h.world_root=node
		node.rotation.y=int(f.get("rotation",0))*PI/2
		preload("res://scripts/inn_facility_art.gd").build(h,f.type)
		if f.type=="prison":
			node.set_meta("prison",f.id)
			var guard=h.actor(Vector3.ZERO,Color("485d64"));guard.reparent(node);guard.name="PrisonGuard";guard.position=Vector3(1.5,0,1.5)
		h.light_at(Vector3(0,2.1,0.4),1.1)
		var name_=Rules.TYPES[f.type].name
		if f.occupant!="":name_+=" · 사용 중"
		var title=h.world_label(name_,Vector3(0,0.25,1.25),node);title.pixel_size=0.01;title.name="FacilityTitle";title.set_meta("builder_label",true)
	for key in h.sim.data.rooms:
		var n=int(key);var room_: Dictionary=h.sim.data.rooms[key]
		if not room_.has("secret_bottom"):continue
		var point: Vector2=Rules.room_point(n)
		h.world_root=root
		var lid=h.box(Vector3(.65,.045,.65),h.world_point(point+Vector2(.55,0),Rules.floor_of(n),.06),Color("41544d"));lid.set_meta("floor",Rules.floor_of(n))
		h.world_label("비밀 통로",h.world_point(point+Vector2(.7,0),Rules.floor_of(n),.25),root).set_meta("floor",Rules.floor_of(n))
		h.world_label("%s호 통로 아래" %key,h.world_point(Vector2(room_.secret_bottom),1,.2),root).set_meta("floor",1)
	# Visible continuous section, distinct from the ground floor without hiding it.
	h.world_root=root
	var label=h.world_label("지하 · 흙벽 클릭은 한 칸 굴착 / 주인 클릭으로 시설 추가",h.world_point(Vector2(8,6),1,0.3),root);label.pixel_size=0.012
	h.world_label("마당 · 우회 통로와 비밀 입구",Vector3(16,0.2,8.3),root).pixel_size=0.011
	h.world_label("식당",Vector3(-6,0.25,3.8),root).pixel_size=0.01
	for n in [1,2,3,4,5]:
		var at: Vector3=h.world_point(Rules.room_point(n),Rules.floor_of(n),0.2)
		var label_=h.world_label("%d호" %n,at+Vector3(0,0.1,1),root);label_.pixel_size=0.011
	h.world_root=h.surface;h.sandbox_revision=int(h.sim.data.sandbox.revision)

	if h.sim.data.sandbox.get("wide_version",0)>=1:
		h.world_root=root
		for row in [[Vector2(-14,-7),"서쪽 수감동"],[Vector2(12,-7),"중앙 심문동"],[Vector2(38,-7),"동쪽 보안동"],[Vector2(12,15),"남쪽 확장동"]]:
			var center: Vector2=row[0]
			h.world_label(str(row[1]),h.world_point(center+Vector2(0,4),1,.25),root).pixel_size=.016
			for x in [-7,7]:
				for y in [-4,4]:h.box(Vector3(.15,1.6,.15),h.world_point(center+Vector2(x,y),1,.8),Color("66523a"))
			h.light_at(h.world_point(center,1,2),1.0)
		h.box(Vector3(2,.12,1),h.world_point(Vector2(12,-3),1,.85),Color("766046"))
		for x in [-.8,.8]:
			for z in [-.3,.3]:h.box(Vector3(.12,.8,.12),h.world_point(Vector2(12+x,-3+z),1,.4),Color("514434"))
		h.box(Vector3(.65,.45,.65),h.world_point(Vector2(12,-2),1,.225),Color("6d5b43"))
		h.world_root=h.surface
