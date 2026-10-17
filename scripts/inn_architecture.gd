extends RefCounted
## Reusable low-poly cutaway set. No game state or AI lives here.
static func build(h) -> void:
	var timber:=Color("4b3629")
	var plaster:=Color("a48d6c")
	var stone:=Color("575a50")
	# The front is a deliberate section cut: no giant ground plane hiding the cellar.
	h.box(Vector3(38,0.5,5),Vector3(5,-0.4,-8.5),Color("313d3c"))
	h.box(Vector3(14,0.5,20),Vector3(17,-0.4,2),Color("424b43"))
	h.box(Vector3(4,0.5,18),Vector3(-12,-0.4,1),Color("34423e"))
	# Four foundation strips leave a real opening above the cellar ladder.
	h.box(Vector3(6.15,0.3,12.4),Vector3(-7.125,-0.16,0),timber)
	h.box(Vector3(12.65,0.3,12.4),Vector3(3.875,-0.16,0),timber)
	h.box(Vector3(1.6,0.3,8.15),Vector3(-3.25,-0.16,-2.125),timber)
	h.box(Vector3(1.6,0.3,2.65),Vector3(-3.25,-0.16,4.875),timber)
	for x in range(-10,10):
		for z in range(-6,6):
			if x in [-4,-3] and z in [2,3]:continue
			h.model("town","planks",Vector3(x+0.5,0.01,z+0.5),Vector3(1,0.06,1))
	# Rear half-timber wall; camera-facing walls are low sections.
	for pair in [[-8.0,4.0],[0.0,8.0],[8.0,4.0]]:
		h.box(Vector3(pair[1],2.9,0.2),Vector3(pair[0],1.5,-6),plaster,true)
	h.world_label("뒤편 샛문",Vector3(-5,0.3,-5.6),h.surface).pixel_size=0.008
	h.world_label("뒷마당 우회로",Vector3(5,0.3,-6.6),h.surface).pixel_size=0.008
	for x in range(-10,11,4):h.box(Vector3(0.2,3.2,0.25),Vector3(x,1.55,-6),timber)
	h.box(Vector3(0.2,2.9,12),Vector3(-10,1.5,0),plaster,true)
	for z in [-5,-1,3,6]:h.box(Vector3(0.22,3,0.22),Vector3(-10,1.5,z),timber)
	for pair in [[-4.25,3.5],[0.0,2.0],[4.75,2.5]]:
		h.box(Vector3(0.16,0.45,pair[1]),Vector3(10,0.22,pair[0]),stone,true)
	h.world_label("마당 쪽문",Vector3(10,0.3,2.8),h.surface).pixel_size=0.009
	for x in [-5.5,5.5]:h.box(Vector3(9,0.45,0.2),Vector3(x,0.22,6),stone,true)
	# Preserve the two existing ground-floor guest rooms and path targets.
	for z in range(-6,6):
		if z in [-3,1]:continue
		h.box(Vector3(0.15,1,1),Vector3(2,0.55,z+0.5),plaster,true)
	h.box(Vector3(8,1,0.15),Vector3(6,0.55,0),plaster,true)
	for z in [-2.0,2.0]:
		h.model("furniture","bedSingle",Vector3(5.6,0.08,z),Vector3(1.1,0.75,2),0,true)
		h.model("furniture","rugRectangle",Vector3(3.7,0.08,z),Vector3(1.4,0.025,2))
	h.model("furniture","table",Vector3(-1.7,0.08,-2.7),Vector3(2.7,0.95,0.9),0,true)
	h.model("furniture","books",Vector3(-2.4,1.04,-2.7),Vector3(0.5,0.17,0.35))
	h.model("furniture","bookcaseOpen",Vector3(-5.4,0.08,-3.4),Vector3(1.35,1.9,0.4),0,true)
	for x in [-7.5,-4.8]:
		h.model("furniture","tableRound",Vector3(x,0.08,0.4),Vector3(1.4,0.8,1.4),0,true)
		for z in [-0.7,1.6]:h.model("furniture","chair",Vector3(x,0.08,z),Vector3(0.52,1,0.58),PI if z<0 else 0,true)
	h.model("furniture","bench",Vector3(-8.5,0.08,3),Vector3(1.8,0.9,0.6),0,true)
	h.model("furniture","coatRackStanding",Vector3(0.7,0.08,3.2),Vector3(0.5,1.7,0.5))
	# Stone hearth and chimney provide one strong visual center.
	for x in [-8.7,-6.7]:h.box(Vector3(0.45,2.2,0.65),Vector3(x,1.1,-5.4),stone)
	h.box(Vector3(2.5,0.4,0.8),Vector3(-7.7,2.05,-5.4),stone)
	h.box(Vector3(2.1,0.12,1.1),Vector3(-7.7,0.12,-5.05),Color("34352f"))
	for x in [-8.1,-7.7,-7.3]:
		var fire: MeshInstance3D=h.box(Vector3(0.16,0.55,0.12),Vector3(x,0.4,-5.2),Color("f4a44b"))
		var mat: StandardMaterial3D=h.material(Color("eaa04f"));mat.emission_enabled=true;mat.emission=Color("ff963f");mat.emission_energy_multiplier=2
		var flame:=SphereMesh.new();flame.radial_segments=6;flame.rings=3;flame.radius=0.15;flame.height=0.65;fire.mesh=flame
		fire.material_override=mat
	h.light_at(Vector3(-7.7,1.1,-4.5),1.9)
	for pos in [Vector3(-3,0.08,-4.8),Vector3(3.4,0.08,-3.3),Vector3(3.4,0.08,3.2)]:
		h.model("town","lantern",pos,Vector3(0.2,1.8,0.2));h.light_at(pos+Vector3(0,1.9,0),0.9)
	# Courtyard: paving stays clear enough to walk; repeated stones reuse one mesh.
	for x in range(10,24):
		for z in range(-1,8):
			if (x*7+z*3)%5==0:continue
			h.box(Vector3(0.88,0.035,0.88),Vector3(x+0.5,-0.07,z+0.5),Color("686b5c").darkened(float(posmod(x+z,3))*0.045))
	for x in range(11,24,2):h.model("town","fence",Vector3(x,-0.1,-5.5),Vector3(0.15,1.1,2),PI/2)
	for z in [-4,-2,0,6,8]:h.model("town","fence",Vector3(23.5,-0.1,z),Vector3(0.15,1.1,2))
	for z in [1,5]:h.box(Vector3(0.3,2.5,0.3),Vector3(23.2,1.15,z),timber)
	h.box(Vector3(0.4,0.25,4.5),Vector3(23.2,2.4,3),timber)
	h.model("town","cart",Vector3(20.5,-0.12,-3),Vector3(1.7,1.3,3),0.4,true)
	for x in [11.5,14.0,21.5]:
		h.model("town","lantern",Vector3(x,-0.08,4.5),Vector3(0.2,2,0.2));h.light_at(Vector3(x,1.9,4.5),0.7)
	# Open lean-to, stacked wood and well use modest procedural meshes.
	for x in [11,14]:
		for z in [-5,-3.5]:h.box(Vector3(0.14,2,0.14),Vector3(x,1,z),timber)
	var canopy: MeshInstance3D=h.box(Vector3(3.5,0.12,2.2),Vector3(12.5,2.1,-4.25),Color("424a4b"));canopy.rotation.x=-0.13
	for i in range(8):
		var log_: MeshInstance3D=h.box(Vector3(0.22,0.22,1.1),Vector3(11.3+(i%4)*0.32,0.15+(i/4)*0.25,-4.3),Color("715438"));log_.rotation.z=0.12
	for x in [18.8,20.2]:h.box(Vector3(0.15,2.1,0.15),Vector3(x,1,7.5),timber)
	h.box(Vector3(1.7,0.6,1.2),Vector3(19.5,0.2,7.5),stone,true)
	h.box(Vector3(1.9,0.12,1.6),Vector3(19.5,2.1,7.5),Color("4d5150"))
	for pos in [Vector3(-13,-0.1,-7),Vector3(18,-0.1,-7),Vector3(24,-0.1,10)]:h.model("town","tree",pos,Vector3(2.5,5,2.5))
	# Owner's back office: a walled service room away from restaurant traffic.
	h.box(Vector3(7,0.15,4.2),Vector3(14,-0.03,-3.4),Color("514936"))
	for x in range(11,17):
		for z in [-5,-4,-3,-2]:h.model("town","planks",Vector3(x+0.5,0.05,z+0.5),Vector3(1,0.06,1))
	# Two doors: courtyard service door and a rear bypass door. Guests have a separate navigation grid.
	for pair in [[11.5,2.0],[15.6,3.0]]:
		h.box(Vector3(pair[1],2.0,0.15),Vector3(pair[0],1,-5.4),Color("68563d"),true)
	for x in [10.5,17.4]:h.box(Vector3(0.15,1.8,4),Vector3(x,0.9,-3.4),Color("5c4b36"),true)
	for pair in [[11.1,1.2],[15.3,4.0]]:h.box(Vector3(pair[1],0.9,0.15),Vector3(pair[0],0.45,-1.3),Color("776346"),true)
	h.model("furniture","bookcaseOpen",Vector3(16.6,0.08,-4.2),Vector3(1,1.5,0.4))
	for x in [14.5,15.4]:h.box(Vector3(0.65,0.65,0.65),Vector3(x,0.36,-4.3),Color("84663e"))
	h.world_label("주인 전용 창고 · 손님 출입 금지",Vector3(14,1.7,-2.8),h.surface).pixel_size=0.013
	h.world_label("뒤편 전용 출입로",Vector3(13.4,0.4,-6.4),h.surface).pixel_size=0.011
	# Earth under the section, low enough not to conceal the playable cellar.
	h.box(Vector3(20,0.18,7),Vector3(1,-4.45,4),Color("393026"))
