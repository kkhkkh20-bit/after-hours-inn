class_name HUD
extends CanvasLayer
## The main heads-up display, composed for 1280x720 (GDD 29).
##
## Layout contract - all of it must stay inside the 16:9 frame:
##   top-left    day + clock
##   top-right   gold + reputation stars
##   bottom-left action bar
##   bottom-right context prompt
##   centre-top  event banner (transient)

const W := 1280
const H := 720

var _day: Label
var _time: Label
var _gold: Label
var _stars: Array = []
var _prompt: Label
var _banner: Control
var _banner_label: Label
var _banner_t: float = 0.0
var _order_strip: VBoxContainer
var _order_sig: String = ""
var _order_bars: Array = []
var _root: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- top left: day / clock -------------------------------------------
	var tl := UIKit.panel("panel_dark")
	tl.position = Vector2(10, 8)
	tl.size = Vector2(190, 58)
	_root.add_child(tl)
	_day = UIKit.label("DAY 1", 20, UIKit.PAPER)
	_day.position = Vector2(12, 8)
	tl.add_child(_day)
	var clock := UIKit.icon("icon_clock", 16)
	clock.position = Vector2(12, 32)
	tl.add_child(clock)
	_time = UIKit.label("8:00 AM", 16, UIKit.DIM)
	_time.position = Vector2(32, 32)
	tl.add_child(_time)

	# ---- top right: gold / reputation ------------------------------------
	var tr := UIKit.panel("panel_dark")
	tr.position = Vector2(W - 210, 8)
	tr.size = Vector2(200, 62)
	_root.add_child(tr)
	var coin := UIKit.icon("icon_coin", 16)
	coin.position = Vector2(12, 9)
	tr.add_child(coin)
	_gold = UIKit.label("0 G", 20, UIKit.GOLD)
	_gold.position = Vector2(34, 6)
	tr.add_child(_gold)
	_stars = UIKit.stars(tr, Vector2(12, 33), Game.reputation)

	# ---- centre top: event banner ----------------------------------------
	_banner = UIKit.panel("panel_light")
	_banner.position = Vector2(W / 2 - 230, 74)
	_banner.size = Vector2(460, 40)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_label = UIKit.label("", 16, UIKit.PAPER)
	_banner_label.position = Vector2(12, 11)
	_banner_label.size = Vector2(436, 20)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)

	# ---- bottom left: action bar -----------------------------------------
	var bar := UIKit.panel("panel_dark")
	bar.position = Vector2(10, H - 54)
	bar.size = Vector2(430, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(8, 6)
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for spec in [["icon_bag", "Inventory", "open_inventory"],
			["icon_book", "Recipes", "open_recipes"],
			["icon_orders", "Orders", "open_orders"],
			["icon_restaurant", "Shop", "open_restaurant"]]:
		var b := UIKit.button(str(spec[1]), 100, 32)
		b.icon = DB.ui_texture(str(spec[0]))
		b.set_meta("action", str(spec[2]))
		b.pressed.connect(_on_action.bind(str(spec[2])))
		row.add_child(b)

	# ---- bottom right: context prompt ------------------------------------
	_prompt = UIKit.label("", 16, UIKit.PARCHMENT)
	_prompt.position = Vector2(W - 430, H - 44)
	_prompt.size = Vector2(420, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_prompt)

	# ---- right edge: live order tickets ----------------------------------
	_order_strip = VBoxContainer.new()
	_order_strip.position = Vector2(W - 200, 74)
	_order_strip.add_theme_constant_override("separation", 4)
	_root.add_child(_order_strip)

	Game.gold_changed.connect(_on_gold)
	Game.reputation_changed.connect(_on_rep)
	DayCycle.time_changed.connect(_on_time)
	Game.day_started.connect(_on_day)
	Events.event_fired.connect(_on_event)
	_refresh()


func _refresh() -> void:
	_day.text = "DAY %d" % Game.day
	_gold.text = "%s G" % _commas(Game.gold)
	_time.text = DayCycle.time_string()
	UIKit.update_stars(_stars, Game.reputation)


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)


func _on_gold(amount: int, delta: int) -> void:
	_gold.text = "%s G" % _commas(amount)
	if delta > 0:
		_gold.add_theme_color_override("font_color", UIKit.GOOD)
		get_tree().create_timer(0.45).timeout.connect(
			func(): _gold.add_theme_color_override("font_color", UIKit.GOLD))


func _on_rep(value: float) -> void:
	UIKit.update_stars(_stars, value)


func _on_time(_m: int) -> void:
	_time.text = DayCycle.time_string()


func _on_day(_d: int) -> void:
	_refresh()


func _on_event(id: String, ev: Dictionary) -> void:
	show_banner(str(ev.get("text", Events.event_name(id))))


func show_banner(text: String, seconds: float = 3.4) -> void:
	_banner_label.text = text
	_banner_t = seconds
	_banner.modulate.a = 1.0


func set_prompt(text: String) -> void:
	_prompt.text = text


signal action_pressed(action: String)


func _on_action(action: String) -> void:
	action_pressed.emit(action)


## Refresh the live ticket strip.
##
## Called every frame, so it must NOT rebuild unless the set of orders actually
## changed - tearing down and reallocating a dozen Controls per frame is the
## kind of thing that quietly eats a frame budget. Only the patience bars are
## updated continuously.
func set_orders(orders: Array) -> void:
	var sig := ""
	for o in orders:
		sig += "%s:%s|" % [str(o.get("name", "")), str(o.get("recipe", ""))]
	if sig == _order_sig:
		for i in mini(_order_bars.size(), orders.size()):
			UIKit.set_bar(_order_bars[i], float(orders[i].get("patience", 1.0)), true)
		return
	_order_sig = sig
	_order_bars.clear()
	for c in _order_strip.get_children():
		c.queue_free()
	for o in orders:
		var ticket := UIKit.panel("panel_parchment")
		ticket.custom_minimum_size = Vector2(190, 40)
		ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_order_strip.add_child(ticket)
		var dish := TextureRect.new()
		dish.texture = DB.dish_texture(str(o.get("recipe", "")), "good")
		dish.position = Vector2(4, 4)
		dish.custom_minimum_size = Vector2(32, 32)
		ticket.add_child(dish)
		var nm := UIKit.label(str(o.get("name", "")), 14, UIKit.INK, false)
		nm.position = Vector2(38, 5)
		ticket.add_child(nm)
		var dn := UIKit.label(str(DB.recipe(str(o.get("recipe", ""))).get("name", "")),
				12, Color("#6a5340"), false)
		dn.position = Vector2(38, 20)
		ticket.add_child(dn)
		var f := UIKit.bar(ticket, Vector2(38, 32), 140, 6, "bar_good")
		UIKit.set_bar(f, float(o.get("patience", 1.0)), true)
		_order_bars.append(f)
