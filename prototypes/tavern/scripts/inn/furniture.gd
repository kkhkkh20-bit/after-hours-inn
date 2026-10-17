extends Node2D
var kind: String = "bed"
func _draw() -> void:
	if kind == "bed":
		draw_rect(Rect2(-24,-65,48,74),Color("34272c"))
		draw_rect(Rect2(-20,-61,40,66),Color("93653f"))
		draw_rect(Rect2(-16,-55,32,55),Color("c5b9a0"))
		draw_rect(Rect2(-16,-33,32,35),Color("657e79"))
		draw_rect(Rect2(-13,-53,26,16),Color("f5e7cb"))
		draw_line(Vector2(-16,-25),Vector2(16,-25),Color("95afa1"),3)
	elif kind == "stairs":
		for i in 6:
			draw_rect(Rect2(-43,-i*10,86,9),Color("a77d53").darkened(i*.055))
	elif kind == "desk":
		draw_rect(Rect2(-58,-39,116,46),Color("422e27"))
		draw_rect(Rect2(-58,-43,116,32),Color("ab794c"))
		draw_rect(Rect2(0,-40,30,22),Color("ebdcb6"))
		draw_line(Vector2(6,-32),Vector2(25,-32),Color("765a47"),2)
