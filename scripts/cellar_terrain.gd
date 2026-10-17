extends RefCounted
## Continuous faceted earth and timber shoring; logical cells stay invisible.
static func rough(x: float, z: float) -> float:
	return float(posmod(roundi(x*2)*37+roundi(z*2)*61,19))/18.0

static func build(h) -> void:
	for child in h.terrain.get_children():child.free()
	h.world_root=h.terrain
	h.earth_faces=[]
	var edge: Dictionary={}
	var v:=PackedVector3Array()
	var colors:=PackedColorArray()
	for key in h.sim.data.cells:
		var cell: Vector2i=h.Simulation.parse_cell(key)
		var center:=Vector3(cell.x,0.03,cell.y)
		for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
			var next:=Vector2(-offset.y,offset.x)
			var a:=center+Vector3(offset.x,0,offset.y)
			var b:=center+Vector3(next.x,0,next.y)
			a.y+=(rough(a.x,a.z)-0.5)*0.04
			b.y+=(rough(b.x,b.z)-0.5)*0.04
			var c:=Color("6a5940").darkened(rough(a.x,b.z)*0.1)
			for point in [center,b,a]:v.append(point);colors.append(c)
		for shift in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i=cell+shift
			if h.sim.data.cells.has(h.Simulation.cell_key(neighbor)):continue
			edge[h.Simulation.cell_key(neighbor)]=true
			var n:=Vector3(shift.x,0,shift.y)
			var tangent:=Vector3(-shift.y,0,shift.x)*0.5
			var base:=center+n*0.5
			var a:=base-tangent
			var b:=base+tangent
			var height:=0.35 if shift.y>0 else 2.15
			if shift.x>0:height=0.7
			var top_a:=a+Vector3(0,height+rough(a.x,a.z)*0.3,0)+n*0.2
			var top_b:=b+Vector3(0,height+rough(b.x,b.z)*0.3,0)+n*0.2
			var mid:=a.lerp(b,0.5)+Vector3(0,height*0.45,0)+n*(0.02+rough(base.x,base.z)*0.12)
			var col:=Color("72593d").darkened(rough(a.x,b.z)*0.22)
			for triangle in [[b,a,mid],[a,top_a,mid],[top_a,top_b,mid],[top_b,b,mid]]:
				for point in triangle:v.append(point);colors.append(col.lightened(rough(point.x,point.z)*0.06))
			var outer_a:=top_a+n*0.55
			var outer_b:=top_b+n*0.55
			for point in [top_a,outer_b,top_b,top_a,outer_a,outer_b]:v.append(point);colors.append(Color("3e3227"))
			var bounds:=AABB(a,Vector3.ZERO).expand(b).expand(top_a+n*0.1).expand(top_b+n*0.1).grow(0.07)
			h.earth_faces.append({"cell":neighbor,"bounds":bounds})
			# Sparse low-poly rubble breaks the contour without filling walkable cells.
			if posmod(cell.x*7+cell.y*11+shift.x,3)==0:
				var rock:=MeshInstance3D.new()
				var shape:=SphereMesh.new();shape.radial_segments=6;shape.rings=3;shape.radius=0.2;shape.height=0.4
				rock.mesh=shape;rock.material_override=h.material(Color("746951"))
				h.terrain.add_child(rock)
				rock.position=base+n*0.12+Vector3(0,0.12,0)
				rock.scale=Vector3(1.1+rough(base.z,base.x),0.6,0.8)
	h.earth_mesh(v,colors)
	# Braced portal at the entry and a second one across the connecting tunnel.
	for x in [-2.5,1.3]:h.box(Vector3(0.16,2.1,0.16),Vector3(x,1.05,-2.2),Color("624b31"))
	h.box(Vector3(4,0.2,0.2),Vector3(-0.6,2.1,-2.2),Color("745737"))
	for x in [3.5,6.5]:
		if not h.sim.data.cells.has(h.Simulation.cell_key(Vector2i(roundi(x),2))):continue
		for z in [1.55,3.4]:h.box(Vector3(0.13,1.9,0.13),Vector3(x,0.95,z),Color("624b31"))
		h.box(Vector3(0.18,0.18,2.1),Vector3(x,1.9,2.45),Color("745737"))
	h.model("town","lantern",Vector3(-1,0.08,-1),Vector3(0.14,1.7,0.14))
	if h.sim.data.excavation.get("storeroom",false) and h.sim.data.cells.has("10,0"):
		h.model("furniture","bookcaseOpen",Vector3(10,0.05,-0.2),Vector3(1.5,1.6,0.35))
		for x in [8,9,10]:
			h.box(Vector3(0.7,0.65,0.65),Vector3(x,0.36,0),Color("735238"))
			h.box(Vector3(0.08,0.7,0.68),Vector3(x,0.36,0),Color("463e2d"))
	h.earth_edges=edge
	h.dig_cursor=h.box(Vector3(0.92,0.025,0.92),Vector3(99,0.07,99),Color("bda05c"))
	h.world_root=h.surface
	h.last_cell_count=h.sim.data.cells.size()
