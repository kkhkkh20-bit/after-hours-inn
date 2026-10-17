extends RefCounted
## Shared model for installed facilities and their placement ghosts.
static func build(h,type_: String) -> void:
	h.box(Vector3(2.8,.14,2.8),Vector3(0,.1,0),Color("76664d"))
	match type_:
		"prison":
			for x in [-1.3,1.3]:
				h.box(Vector3(.18,.65,2.65),Vector3(x,.45,0),Color("656b62"))
				h.box(Vector3(.22,1.9,.22),Vector3(x,1.05,-1.25),Color("8e9282"))
			h.box(Vector3(2.7,.65,.18),Vector3(0,.45,-1.3),Color("656b62"))
			for x in [-1.2,-.9,-.6,-.3,0,.3,.6,.9,1.2]:h.box(Vector3(.055,1.75,.055),Vector3(x,1.05,1.25),Color("99a69e"))
			for y in [.25,1.85]:h.box(Vector3(2.7,.085,.085),Vector3(0,y,1.25),Color("707f77"))
			for x in [-.72,.72]:
				h.box(Vector3(.75,.22,1.4),Vector3(x,.3,-.35),Color("594c3e"));h.box(Vector3(.68,.08,1.25),Vector3(x,.45,-.35),Color("b6a17d"));h.box(Vector3(.6,.09,.28),Vector3(x,.53,-.8),Color("d8cdb0"))
		"furnace":
			for x in [-.95,.95]:h.box(Vector3(.45,1.5,1.9),Vector3(x,.9,-.2),Color("77776a"))
			h.box(Vector3(2.3,.35,1.9),Vector3(0,1.65,-.2),Color("969281"))
			h.box(Vector3(.8,1.3,.8),Vector3(0,2.35,-.65),Color("676c63"));h.box(Vector3(1,.12,1),Vector3(0,3,-.65),Color("949382"))
			h.box(Vector3(1.45,.9,.1),Vector3(0,.8,-.7),Color("201f1c"));h.box(Vector3(1.35,.2,1.2),Vector3(0,.35,.1),Color("ed9045"))
			for x in [-.5,0,.5]:h.box(Vector3(.12,.13,1.3),Vector3(x,.48,.1),Color("493d30"))
			h.box(Vector3(2.7,.13,.6),Vector3(0,.2,1.1),Color("a09276"))
		"stash":
			for x in [-1.15,1.15]:h.box(Vector3(.16,1.9,.16),Vector3(x,1,-.9),Color("59422e"))
			for y in [.3,1,1.8]:h.box(Vector3(2.5,.1,.75),Vector3(0,y,-.9),Color("997746"))
			for x in [-.7,.1,.8]:
				for y in [.6,1.35]:
					h.box(Vector3(.58,.5,.6),Vector3(x,y,-.9),Color("b18a50"));h.box(Vector3(.07,.52,.64),Vector3(x,y,-.9),Color("615b43"))
			h.box(Vector3(.9,.7,.9),Vector3(-.5,.5,.6),Color("9c7643"));h.box(Vector3(.7,.5,.7),Vector3(.65,.4,.55),Color("795d37"))
		"refuge":
			h.box(Vector3(.16,1.4,2.6),Vector3(-1.25,.85,0),Color("5d594c"));h.box(Vector3(2.5,1.4,.16),Vector3(0,.85,-1.25),Color("5d594c"))
			h.model("furniture","bedSingle",Vector3(-.45,.16,0),Vector3(.8,.6,1.7));h.box(Vector3(.65,.65,.65),Vector3(.75,.45,-.65),Color("a1804e"))
