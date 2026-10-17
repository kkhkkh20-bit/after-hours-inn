extends RefCounted
const Rules=preload("res://scripts/inn_sandbox.gd")
static func build(h) -> void:
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
			var title=h.world_label(e.name+ (" · 열림" if e.open else " · 숨김"),Vector3(0,0.35,0.9),node);title.pixel_size=0.009
	for f in h.sim.data.sandbox.facilities:
		var node=Node3D.new();root.add_child(node);node.set_meta("floor",1);node.position=h.world_point(f.pos,1);h.world_root=node
		h.box(Vector3(2.4,0.08,2.4),Vector3(0,0.07,0),Color("534638"))
		match f.type:
			"prison":
				for x in [-1.1,-0.7,-0.3,0.1,0.5,0.9]:h.box(Vector3(0.06,1.6,0.06),Vector3(x,0.85,-1.1),Color("687474"))
				for z in [-0.7,-0.2,0.3,0.8]:h.box(Vector3(0.06,1.6,0.06),Vector3(-1.1,0.85,z),Color("687474"))
				h.box(Vector3(2.3,0.09,0.09),Vector3(0,1.6,-1.1),Color("9a9d91"))
				h.model("furniture","bedSingle",Vector3(0.5,0.1,0),Vector3(0.65,0.35,1.5))
			"stash":
				for x in [-0.7,0.2,0.7]:
					h.box(Vector3(0.65,0.65,0.7),Vector3(x,0.42,-0.4),Color("8b693b"));h.box(Vector3(0.08,0.7,0.75),Vector3(x,0.45,-0.4),Color("373e39"))
			"furnace":
				for x in [-0.8,0.8]:h.box(Vector3(0.4,1.3,1.3),Vector3(x,0.7,-0.4),Color("535653"))
				h.box(Vector3(2,0.4,1.5),Vector3(0,1.45,-0.4),Color("66685c"));h.box(Vector3(0.6,2.4,0.6),Vector3(0,2.3,-0.9),Color("454c4b"))
				h.box(Vector3(1.1,0.4,0.6),Vector3(0,0.4,-0.3),Color("e69043"))
			"refuge":
				h.model("furniture","bedSingle",Vector3(-0.45,0.1,0),Vector3(0.8,0.6,1.7));h.box(Vector3(0.6,0.6,0.6),Vector3(0.7,0.35,-0.6),Color("91774a"))
		h.light_at(Vector3(0,2.1,0.4),1.1)
		var name_=Rules.TYPES[f.type].name
		if f.occupant!="":name_+=" · 사용 중"
		var title=h.world_label(name_,Vector3(0,0.25,1.25),node);title.pixel_size=0.01
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
