class_name MainMenu
extends CanvasLayer
## Title screen. Logo over a lit restaurant window, with the cast idling in
## front of it so the first thing the player sees is the actual game's art.

signal start_new()
signal continue_game()

const W := 1280
const H := 720

var _root: Control


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var sky := ColorRect.new()
	sky.color = Color("#171029")
	sky.size = Vector2(W, H)
	_root.add_child(sky)

	# a strip of night town behind the logo
	var world := Node2D.new()
	add_child(world)
	for x in range(0, W, 32):
		for y in range(H - 160, H, 32):
			var t := Sprite2D.new()
			t.texture = DB.env_texture("cobble_%d" % ((x / 32 + y / 32) % 4))
			t.centered = false
			t.position = Vector2(x, y)
			t.modulate = Color(0.5, 0.54, 0.82)
			world.add_child(t)
	for spec in [["house_0", 150], ["house_2", 330], ["witch_shop", 1080]]:
		var s := Sprite2D.new()
		s.texture = DB.env_texture(str(spec[0]))
		s.centered = false
		if s.texture != null:
			s.position = Vector2(int(spec[1]) - s.texture.get_width() / 2.0,
					H - 150 - s.texture.get_height())
		s.modulate = Color(0.55, 0.58, 0.85)
		world.add_child(s)

	# the cast, idling, lit warmly against the cold night
	var cast := [["dragon", 700], ["vampire", 850], ["slime", 960],
			["ghost", 1040], ["cook", 560]]
	for entry in cast:
		var a := Actor.new()
		a.setup(str(entry[0]))
		a.position = Vector2(int(entry[1]), H - 130)
		a.play("idle")
		world.add_child(a)

	var glow := PointLight2D.new()
	glow.texture = _radial()
	glow.position = Vector2(760, H - 220)
	glow.color = Color("#ffcf6b")
	glow.energy = 1.15
	glow.texture_scale = 5.0
	add_child(glow)

	var logo := TextureRect.new()
	logo.texture = DB.ui_texture("logo")
	logo.position = Vector2(W / 2 - 210, 70)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.custom_minimum_size = Vector2(420, 150)
	_root.add_child(logo)

	var menu := VBoxContainer.new()
	menu.position = Vector2(120, 296)
	menu.add_theme_constant_override("separation", 10)
	_root.add_child(menu)

	var cont := UIKit.button("Continue", 250, 40)
	cont.disabled = not SaveManager.has_save(0)
	cont.pressed.connect(func(): continue_game.emit())
	menu.add_child(cont)

	var new_b := UIKit.button("New Game", 250, 40)
	new_b.pressed.connect(func(): start_new.emit())
	menu.add_child(new_b)

	var set_b := UIKit.button("Settings", 250, 40)
	set_b.pressed.connect(func(): settings_requested.emit())
	menu.add_child(set_b)

	var quit_b := UIKit.button("Quit", 250, 40)
	quit_b.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit_b)

	if SaveManager.has_save(0):
		var p := SaveManager.peek(0)
		var info := UIKit.label("Day %d  -  %d G  -  %.1f stars"
				% [int(p.get("day", 1)), int(p.get("gold", 0)),
				float(p.get("reputation", 0.0))], 14, UIKit.DIM)
		info.position = Vector2(122, 268)
		_root.add_child(info)

	var tag := UIKit.label("They are not dangerous. They are hungry.", 16,
			UIKit.PARCHMENT)
	tag.position = Vector2(120, 512)
	_root.add_child(tag)

	var version := UIKit.label("1280 x 720  -  16:9  -  original pixel art", 12,
			Color("#5a5168"))
	version.position = Vector2(14, H - 26)
	_root.add_child(version)

	Audio.play_music("title")
	cont.grab_focus() if not cont.disabled else new_b.grab_focus()


signal settings_requested()


func _radial() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
