class_name UIKit
extends RefCounted
## Shared UI construction helpers.
##
## Every panel, button and label in the game is built through here so the whole
## interface speaks one visual language (GDD 28: fantasy cookbook + restaurant
## ledger). If a screen needs a widget that is not here, add it here rather
## than styling it locally.

const FONT_PATH := "res://assets/ui/font/monsterplate.fnt"
const SLICE := 8

const INK := Color("#241a2e")
const PAPER := Color("#f4e9cd")
const PARCHMENT := Color("#e8d7ae")
const DIM := Color("#b09c85")
const GOLD := Color("#ffcf6b")
const GOOD := Color("#7ac74f")
const WARN := Color("#ffb037")
const BAD := Color("#e0503a")
const STAR := Color("#ffd75e")
const PANEL_EDGE := Color("#c9a878")

static var _font: Font = null


static func font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	return _font


## All text goes through this so nothing accidentally renders in the engine's
## default vector font next to pixel art.
static func label(text: String, size: int = 16,
		color: Color = PAPER, shadow: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	var f := font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0.09, 0.06, 0.14, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(kind: String = "panel_dark") -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = DB.ui_texture(kind)
	n.patch_margin_left = SLICE
	n.patch_margin_right = SLICE
	n.patch_margin_top = SLICE
	n.patch_margin_bottom = SLICE
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func button(text: String, w: float = 150.0, h: float = 30.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	var f := font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var tex_name := "button_normal"
		match state:
			"hover", "focus": tex_name = "button_hover"
			"pressed": tex_name = "button_pressed"
			"disabled": tex_name = "button_disabled"
		var sb := StyleBoxTexture.new()
		sb.texture = DB.ui_texture(tex_name)
		sb.texture_margin_left = SLICE
		sb.texture_margin_right = SLICE
		sb.texture_margin_top = SLICE
		sb.texture_margin_bottom = SLICE
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", PARCHMENT)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Audio.play_sfx("ui_click"))
	return b


static func icon(name: String, size: float = 16.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = DB.ui_texture(name)
	t.custom_minimum_size = Vector2(size, size)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A framed bar (patience, reputation, cooking progress). Returns the fill so
## the caller can resize it; `w` is the full inner width.
static func bar(parent: Control, pos: Vector2, w: float, h: float,
		fill_kind: String = "bar_good") -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = DB.ui_texture("bar_frame")
	bg.position = pos
	bg.size = Vector2(w, h)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := TextureRect.new()
	fill.texture = DB.ui_texture(fill_kind)
	fill.position = pos + Vector2(1, 1)
	fill.size = Vector2(w - 2, h - 2)
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	fill.set_meta("full_width", w - 2)
	return fill


static func set_bar(fill: TextureRect, frac: float,
		auto_colour: bool = false) -> void:
	var full := float(fill.get_meta("full_width", fill.size.x))
	fill.size.x = maxf(0.0, full * clampf(frac, 0.0, 1.0))
	if auto_colour:
		var key := "bar_good"
		if frac < 0.22:
			key = "bar_bad"
		elif frac < 0.5:
			key = "bar_warn"
		fill.texture = DB.ui_texture(key)


## Star row for the reputation display.
static func stars(parent: Control, pos: Vector2, value: float,
		max_stars: int = 5) -> Array:
	var out: Array = []
	for i in max_stars:
		var s := TextureRect.new()
		s.texture = DB.ui_texture("icon_star" if value >= float(i) + 0.5
				else "icon_star_empty")
		s.position = pos + Vector2(i * 17, 0)
		s.custom_minimum_size = Vector2(16, 16)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(s)
		out.append(s)
	return out


static func update_stars(nodes: Array, value: float) -> void:
	for i in nodes.size():
		(nodes[i] as TextureRect).texture = DB.ui_texture(
			"icon_star" if value >= float(i) + 0.5 else "icon_star_empty")


## Full-screen dim behind a modal.
static func scrim(alpha: float = 0.62) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.06, 0.04, 0.10, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


## A titled window centred in the 1280x720 frame.
static func window(title: String, w: float, h: float,
		kind: String = "panel_parchment") -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim())
	var p := panel(kind)
	p.position = Vector2(round((1280.0 - w) / 2.0), round((720.0 - h) / 2.0))
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(p)
	var t := label(title, 22, INK if kind == "panel_parchment" else PAPER,
			kind != "panel_parchment")
	t.position = Vector2(14, 10)
	p.add_child(t)
	root.set_meta("body", p)
	return root
