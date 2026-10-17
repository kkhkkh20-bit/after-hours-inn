class_name CustomerBubble
extends Node2D
## The floating order / speech bubble above a customer.
##
## Two modes share one bubble: a compact order card (dish icon, taste tags,
## patience bar) and a speech line. Order info has to be readable in under a
## second mid-service, so the dish icon does the work and the text is flavour.

const W := 96
const H := 44

var _panel: NinePatchRect
var _label: Label
var _dish: TextureRect
var _tags: HBoxContainer
var _bar_bg: TextureRect
var _bar_fill: TextureRect
var _root: Control
var _say_t: float = 0.0
var _mode: String = ""


func _ready() -> void:
	_root = Control.new()
	_root.custom_minimum_size = Vector2(W, H)
	_root.position = Vector2(-W / 2.0, -H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = NinePatchRect.new()
	_panel.texture = DB.ui_texture("bubble")
	_panel.patch_margin_left = 8
	_panel.patch_margin_right = 8
	_panel.patch_margin_top = 8
	_panel.patch_margin_bottom = 12
	_panel.size = Vector2(W, H)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_dish = TextureRect.new()
	_dish.position = Vector2(4, 2)
	_dish.size = Vector2(32, 32)
	_dish.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_root.add_child(_dish)

	_tags = HBoxContainer.new()
	_tags.position = Vector2(38, 4)
	_tags.add_theme_constant_override("separation", 1)
	_root.add_child(_tags)

	_bar_bg = TextureRect.new()
	_bar_bg.texture = DB.ui_texture("bar_frame")
	_bar_bg.position = Vector2(38, 22)
	_bar_bg.size = Vector2(52, 8)
	_bar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_bar_bg)

	_bar_fill = TextureRect.new()
	_bar_fill.texture = DB.ui_texture("bar_good")
	_bar_fill.position = Vector2(39, 23)
	_bar_fill.size = Vector2(50, 6)
	_bar_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_bar_fill)

	_label = Label.new()
	_label.position = Vector2(6, 4)
	_label.size = Vector2(W - 12, H - 14)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_font_override("font", load("res://assets/ui/font/InnKorean.otf"))
	_label.add_theme_color_override("font_color", Color("#2a1f16"))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_label)

	hide_all()


func _process(delta: float) -> void:
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0 and _mode == "say":
			hide_all()


func hide_all() -> void:
	_mode = ""
	_root.visible = false
	_dish.visible = false
	_tags.visible = false
	_bar_bg.visible = false
	_bar_fill.visible = false
	_label.visible = false


func show_order(recipe_id: String, ch: Dictionary) -> void:
	_mode = "order"
	_root.visible = true
	_label.visible = false
	_dish.visible = true
	_tags.visible = true
	_bar_bg.visible = true
	_bar_fill.visible = true
	# Show the dish at "good" so the player sees the goal, not a raw plate.
	_dish.texture = DB.dish_texture(recipe_id, "good")
	for c in _tags.get_children():
		c.queue_free()
	# Only the customer's top preferences are shown - a full tag dump is noise.
	var prefers: Dictionary = ch.get("prefers", {})
	var sorted: Array = prefers.keys()
	sorted.sort_custom(func(a, b): return float(prefers[a]) > float(prefers[b]))
	for i in mini(3, sorted.size()):
		var t := TextureRect.new()
		t.texture = DB.ui_texture("tag_" + str(sorted[i]))
		t.custom_minimum_size = Vector2(16, 16)
		_tags.add_child(t)


func say(text: String) -> void:
	_mode = "say"
	_root.visible = true
	_dish.visible = false
	_tags.visible = false
	_bar_bg.visible = false
	_bar_fill.visible = false
	_label.visible = true
	_label.text = text
	_say_t = clampf(1.8 + float(text.length()) * 0.035, 2.0, 5.0)


func set_patience(frac: float) -> void:
	if _mode != "order":
		return
	_bar_fill.size.x = maxf(0.0, 50.0 * frac)
	# Colour is the fastest read in the room - it changes before the bar is
	# visibly short.
	var key := "bar_good"
	if frac < 0.2:
		key = "bar_bad"
	elif frac < 0.5:
		key = "bar_warn"
	_bar_fill.texture = DB.ui_texture(key)
