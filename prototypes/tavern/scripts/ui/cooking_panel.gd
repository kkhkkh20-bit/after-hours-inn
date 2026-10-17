class_name CookingPanel
extends CanvasLayer
## The cooking interface (GDD 31).
##
## Must feel like part of the kitchen, not a settings dialog: a wooden pass
## with a brass heat rail, the dish sitting on it, and one big prompt telling
## you what to do RIGHT NOW. The player should never have to read to know
## whether they are winning.

signal closed()
signal completed(result: Dictionary)

const W := 1280
const H := 720

var cooking: CookingSystem
var recipe_id: String = ""

var _root: Control
var _dish: TextureRect
var _stage_label: Label
var _hint: Label
var _gauge: TextureRect
var _needle: TextureRect
var _window_hi: ColorRect
var _progress: TextureRect
var _stage_dots: HBoxContainer
var _fx: AnimatedSprite2D
var _flip_flash: float = 0.0
var _beat_pulse: float = 0.0
var _shake: float = 0.0
var _panel: NinePatchRect

const GAUGE_X := 340.0
const GAUGE_W := 600.0
const GAUGE_Y := 400.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UIKit.scrim(0.72))

	_panel = UIKit.panel("panel_dark")
	_panel.position = Vector2(200, 130)
	_panel.size = Vector2(880, 460)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	_stage_label = UIKit.label("", 26, UIKit.PARCHMENT)
	_stage_label.position = Vector2(240, 160)
	_stage_label.size = Vector2(800, 32)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_stage_label)

	_stage_dots = HBoxContainer.new()
	_stage_dots.position = Vector2(560, 198)
	_stage_dots.add_theme_constant_override("separation", 6)
	_root.add_child(_stage_dots)

	# the dish, big and centred - the player watches this, not the numbers
	_dish = TextureRect.new()
	_dish.position = Vector2(608, 236)
	_dish.custom_minimum_size = Vector2(64, 64)
	_dish.size = Vector2(64, 64)
	_dish.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_root.add_child(_dish)

	_fx = AnimatedSprite2D.new()
	_fx.position = Vector2(640, 262)
	_fx.visible = false
	_root.add_child(_fx)

	# heat rail
	_gauge = TextureRect.new()
	_gauge.texture = DB.ui_texture("gauge")
	_gauge.position = Vector2(GAUGE_X, GAUGE_Y)
	_gauge.size = Vector2(GAUGE_W, 26)
	_gauge.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_gauge)

	_window_hi = ColorRect.new()
	_window_hi.color = Color(0.48, 0.78, 0.31, 0.34)
	_window_hi.position = Vector2(GAUGE_X, GAUGE_Y)
	_window_hi.size = Vector2(0, 26)
	_window_hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_window_hi)

	_needle = TextureRect.new()
	_needle.texture = DB.ui_texture("knob")
	_needle.position = Vector2(GAUGE_X, GAUGE_Y - 6)
	_needle.custom_minimum_size = Vector2(12, 16)
	_root.add_child(_needle)

	var cold := UIKit.label("COLD", 14, Color("#7fb4d8"))
	cold.position = Vector2(GAUGE_X - 56, GAUGE_Y + 4)
	_root.add_child(cold)
	var hot := UIKit.label("HOT", 14, Color("#ff7a45"))
	hot.position = Vector2(GAUGE_X + GAUGE_W + 12, GAUGE_Y + 4)
	_root.add_child(hot)

	_progress = UIKit.bar(_root, Vector2(GAUGE_X, GAUGE_Y + 44), GAUGE_W, 12,
			"bar_gold")

	_hint = UIKit.label("", 18, UIKit.GOLD)
	_hint.position = Vector2(240, GAUGE_Y + 74)
	_hint.size = Vector2(800, 26)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	var keys := UIKit.label("A / D  or  ← →   adjust heat        SPACE   act        ESC   abandon",
			14, UIKit.DIM)
	keys.position = Vector2(240, 548)
	keys.size = Vector2(800, 22)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(keys)

	cooking = CookingSystem.new()
	add_child(cooking)
	cooking.stage_started.connect(_on_stage)
	cooking.stage_scored.connect(_on_scored)
	cooking.beat.connect(_on_beat)
	cooking.flip_cue.connect(_on_flip_cue)
	cooking.finished.connect(_on_finished)
	cooking.heat_changed.connect(_on_heat)
	cooking.progress_changed.connect(_on_progress)
	visible = false


func begin(id: String) -> void:
	recipe_id = id
	visible = true
	_dish.texture = DB.dish_texture(id, "raw")
	cooking.start(id)
	_on_heat(cooking.heat)
	Audio.play_sfx("ui_confirm")


func _process(delta: float) -> void:
	if not visible:
		return
	if not cooking.active:
		return
	# continuous heat control - held keys feel better than repeat events here
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.05:
		cooking.nudge_heat(axis * delta * 0.85)
	if _flip_flash > 0.0:
		_flip_flash -= delta
		_hint.modulate.a = 0.55 + 0.45 * sin(_flip_flash * 26.0)
	else:
		_hint.modulate.a = 1.0
	if _beat_pulse > 0.0:
		_beat_pulse -= delta * 4.0
		_dish.scale = Vector2.ONE * (1.0 + _beat_pulse * 0.10)
	else:
		_dish.scale = Vector2.ONE
	if _shake > 0.0:
		_shake -= delta * 3.0
		_panel.position = Vector2(200, 130) + Vector2(
			randf_range(-1, 1) * _shake * 5.0, randf_range(-1, 1) * _shake * 5.0)
	else:
		_panel.position = Vector2(200, 130)
	var win := cooking.target_window()
	if win.x >= 0.0:
		_window_hi.visible = true
		_window_hi.position.x = GAUGE_X + GAUGE_W * clampf(win.x, 0.0, 1.0)
		_window_hi.size.x = GAUGE_W * clampf(win.y - win.x, 0.0, 1.0)
	else:
		_window_hi.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		cooking.cancel()
		visible = false
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var acc := cooking.tap()
		if acc > 0.85:
			_burst("sparkle")
		elif acc > 0.0:
			_burst("puff")
		_flip_flash = 0.0
		get_viewport().set_input_as_handled()


func _on_stage(stage: String, index: int, total: int) -> void:
	_stage_label.text = _stage_title(stage)
	_hint.text = _stage_hint(stage)
	for c in _stage_dots.get_children():
		c.queue_free()
	for i in total:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(14, 6)
		d.color = UIKit.GOLD if i <= index else Color("#4a3a52")
		_stage_dots.add_child(d)
	match stage:
		"fry", "boil":
			Audio.play_sfx("sizzle")
		"bake":
			Audio.play_sfx("fire_whoosh")


func _stage_title(stage: String) -> String:
	var rec := str(DB.recipe(recipe_id).get("name", recipe_id))
	return "%s  -  %s" % [rec.to_upper(), stage.to_upper()]


func _stage_hint(stage: String) -> String:
	match stage:
		"chop": return "Tap SPACE on the beat"
		"mix": return "Follow the moving band"
		"fry": return "Hold the heat in the window - flip when told"
		"boil": return "Hold the heat steady"
		"bake": return "Set the heat, then LEAVE IT ALONE"
		"season": return "Tap SPACE at exactly the right moment"
		"plate": return "Tap SPACE to plate it"
	return ""


func _on_scored(_stage: String, score: float) -> void:
	if score < 0.3:
		_shake = 1.0
		_burst("smoke")
	elif score > 0.85:
		_burst("sparkle")


func _on_beat(_i: int) -> void:
	_beat_pulse = 1.0
	Audio.play_sfx("ui_click", 1.6, 0.35)


func _on_flip_cue() -> void:
	_hint.text = "FLIP!  (SPACE)"
	_flip_flash = 1.4
	Audio.play_sfx("ui_confirm", 1.25)


func _on_heat(v: float) -> void:
	_needle.position.x = GAUGE_X + GAUGE_W * clampf(v, 0.0, 1.0) - 6.0


func _on_progress(v: float) -> void:
	UIKit.set_bar(_progress, v)
	# The dish visibly cooks while you work - the whole point of GDD 17.
	var win := cooking.target_window()
	var tier := "raw"
	if v > 0.25:
		tier = "undercooked"
	if v > 0.6:
		tier = "good"
	if win.x >= 0.0 and cooking.heat > win.y + 0.16 and v > 0.45:
		tier = "overcooked"
	_dish.texture = DB.dish_texture(recipe_id, tier)


func _burst(fx_name: String) -> void:
	var sf := DB.sprite_frames("vfx", fx_name, "play", 14.0, false)
	if sf.get_frame_count("play") == 0:
		return
	_fx.sprite_frames = sf
	_fx.visible = true
	_fx.play("play")
	if not _fx.animation_finished.is_connected(_hide_fx):
		_fx.animation_finished.connect(_hide_fx)


func _hide_fx() -> void:
	_fx.visible = false


func _on_finished(result: Dictionary) -> void:
	var q := str(result.get("quality", "good"))
	_dish.texture = DB.dish_texture(recipe_id, q)
	_stage_label.text = q.to_upper()
	_hint.text = _verdict(q)
	if q == "perfect":
		Audio.play_sfx("perfect")
		_burst("sparkle")
	elif q in ["burnt", "raw"]:
		Audio.play_sfx("fail")
		_burst("smoke")
		Game.stats["burnt"] = int(Game.stats.get("burnt", 0)) + 1
	else:
		Audio.play_sfx("plate")
	# hold the result on screen briefly so the feedback lands
	await get_tree().create_timer(1.15).timeout
	visible = false
	completed.emit(result)


func _verdict(q: String) -> String:
	match q:
		"perfect": return "PERFECT. That is going to make someone's night."
		"good": return "Good plate. Send it."
		"undercooked": return "Undercooked. It will do. Barely."
		"overcooked": return "Overcooked. Someone will notice."
		"burnt": return "Burnt. Bin it or be brave."
		"raw": return "Raw. You cannot serve this."
	return ""
