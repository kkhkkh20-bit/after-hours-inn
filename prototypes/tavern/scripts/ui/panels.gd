class_name Panels
extends CanvasLayer
## The modal screens: inventory, recipe book, shop, relationships, day summary,
## pause, settings and dialogue.
##
## They share one CanvasLayer and one open/close path because only ever one is
## visible at a time - separate scenes for each would mean eight copies of the
## same show/hide/escape logic.

signal closed()
signal cook_requested(recipe_id: String)
signal next_day_requested()
signal quit_to_menu()

const W := 1280
const H := 720

var open_id: String = ""
var _current: Control = null


func _ready() -> void:
	layer = 30
	visible = false


func close() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	open_id = ""
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		Audio.play_sfx("ui_cancel")
		close()
		get_viewport().set_input_as_handled()


func _show(root: Control, id: String) -> void:
	if _current != null:
		_current.queue_free()
	_current = root
	add_child(root)
	open_id = id
	visible = true
	Audio.play_sfx("ui_click")


func _close_button(parent: Control, w: float, h: float) -> void:
	var b := UIKit.button("Close", 100, 30)
	b.position = Vector2(w - 116, h - 42)
	b.pressed.connect(close)
	parent.add_child(b)


# ============================================================= INVENTORY ====
func open_inventory() -> void:
	var root := UIKit.window("PANTRY", 820, 520)
	var body: NinePatchRect = root.get_meta("body")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 48)
	scroll.size = Vector2(792, 420)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var ids: Array = Game.inventory.keys()
	ids.sort()
	if ids.is_empty():
		var empty := UIKit.label("The pantry is bare. Visit the market.",
				18, UIKit.INK, false)
		grid.add_child(empty)
	for id in ids:
		grid.add_child(_ingredient_card(str(id), int(Game.inventory[id])))
	var total := UIKit.label("%d items" % Game.total_items(), 16,
			Color("#6a5340"), false)
	total.position = Vector2(16, 478)
	body.add_child(total)
	_close_button(body, 820, 520)
	_show(root, "inventory")


func _ingredient_card(id: String, count: int) -> Control:
	var ing := DB.ingredient(id)
	var card := UIKit.panel("panel_inset")
	card.custom_minimum_size = Vector2(150, 66)
	var tex := TextureRect.new()
	tex.texture = DB.ingredient_texture(id)
	tex.position = Vector2(6, 18)
	tex.custom_minimum_size = Vector2(24, 24)
	card.add_child(tex)
	var nm := UIKit.label(str(ing.get("name", id)), 14, UIKit.PAPER)
	nm.position = Vector2(34, 8)
	card.add_child(nm)
	var c := UIKit.label("x%d" % count, 16, UIKit.GOLD)
	c.position = Vector2(34, 26)
	card.add_child(c)
	var tags := HBoxContainer.new()
	tags.position = Vector2(34, 46)
	tags.add_theme_constant_override("separation", 2)
	card.add_child(tags)
	for t in ing.get("tags", []):
		tags.add_child(UIKit.icon("tag_" + str(t), 14))
	return card


# =========================================================== RECIPE BOOK ====
func open_recipes() -> void:
	var root := UIKit.window("RECIPE BOOK", 900, 560)
	var body: NinePatchRect = root.get_meta("body")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 48)
	scroll.size = Vector2(872, 456)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for id in DB.recipe_ids():
		list.add_child(_recipe_row(str(id)))
	var hint := UIKit.label("Locked recipes show what unlocks them.", 14,
			Color("#6a5340"), false)
	hint.position = Vector2(16, 514)
	body.add_child(hint)
	_close_button(body, 900, 560)
	_show(root, "recipes")


func _recipe_row(id: String) -> Control:
	var rec := DB.recipe(id)
	var known := Game.knows_recipe(id)
	var have := Game.has_ingredients_for(id)
	var row := UIKit.panel("panel_inset")
	row.custom_minimum_size = Vector2(856, 92)

	var dish := TextureRect.new()
	dish.texture = DB.dish_texture(id, "good" if known else "raw")
	dish.position = Vector2(8, 24)
	dish.custom_minimum_size = Vector2(32, 32)
	if not known:
		dish.modulate = Color(0.25, 0.22, 0.30)
	row.add_child(dish)

	var nm := UIKit.label(str(rec.get("name", id)) if known else "? ? ?",
			18, UIKit.PAPER if known else UIKit.DIM)
	nm.position = Vector2(48, 8)
	row.add_child(nm)

	if known:
		var desc := UIKit.label(str(rec.get("desc", "")), 13, UIKit.DIM)
		desc.position = Vector2(48, 28)
		desc.size = Vector2(470, 30)
		desc.clip_text = true
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc)
		var ing_row := HBoxContainer.new()
		ing_row.position = Vector2(48, 60)
		ing_row.add_theme_constant_override("separation", 4)
		row.add_child(ing_row)
		for ing_id in rec.get("ingredients", []):
			var box := HBoxContainer.new()
			var t := TextureRect.new()
			t.texture = DB.ingredient_texture(str(ing_id))
			t.custom_minimum_size = Vector2(16, 16)
			box.add_child(t)
			var lab := UIKit.label(
				"%d" % Game.item_count(str(ing_id)), 12,
				UIKit.GOOD if Game.item_count(str(ing_id)) > 0 else UIKit.BAD)
			box.add_child(lab)
			ing_row.add_child(box)
		var stages := UIKit.label(
			" > ".join(PackedStringArray(rec.get("prep", []))).to_upper(),
			12, Color("#9c8a76"))
		stages.position = Vector2(600, 34)
		row.add_child(stages)
		var val := UIKit.label("%d G" % int(rec.get("value", 0)), 16, UIKit.GOLD)
		val.position = Vector2(600, 10)
		row.add_child(val)
		var cook := UIKit.button("Cook", 96, 30)
		cook.position = Vector2(742, 26)
		cook.disabled = not have
		cook.pressed.connect(func():
			close()
			cook_requested.emit(id))
		row.add_child(cook)
		if not have:
			var miss := UIKit.label("missing items", 12, UIKit.BAD)
			miss.position = Vector2(742, 58)
			row.add_child(miss)
	else:
		var cond: Dictionary = rec.get("unlock", {})
		var text := "Discover by experimenting"
		if cond.has("reputation"):
			text = "Unlocks at %.1f reputation" % float(cond["reputation"])
		elif cond.has("friendship"):
			var pair: Array = cond["friendship"]
			text = "Unlocks at %s with %s" % [
				DB.level_name(int(pair[1])),
				str(DB.character(str(pair[0])).get("name", pair[0]))]
		var lock := UIKit.label(text, 14, Color("#8a7a94"))
		lock.position = Vector2(48, 36)
		row.add_child(lock)
	return row


# ================================================================= SHOP =====
func open_shop(source: String = "market") -> void:
	var title := "MARKET" if source == "market" else "MARROW'S HERBS"
	var root := UIKit.window(title, 860, 540)
	var body: NinePatchRect = root.get_meta("body")
	var gold := UIKit.label("%d G" % Game.gold, 18, UIKit.INK, false)
	gold.position = Vector2(740, 14)
	body.add_child(gold)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 48)
	scroll.size = Vector2(832, 430)
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for id in DB.ingredients_from(source, DayCycle.is_night()):
		grid.add_child(_shop_card(str(id), gold))
	_close_button(body, 860, 540)
	_show(root, "shop")


func _shop_card(id: String, gold_label: Label) -> Control:
	var ing := DB.ingredient(id)
	var cost := int(ing.get("cost", 10))
	var card := UIKit.panel("panel_inset")
	card.custom_minimum_size = Vector2(198, 96)
	var tex := TextureRect.new()
	tex.texture = DB.ingredient_texture(id)
	tex.position = Vector2(8, 30)
	tex.custom_minimum_size = Vector2(24, 24)
	card.add_child(tex)
	var nm := UIKit.label(str(ing.get("name", id)), 14, UIKit.PAPER)
	nm.position = Vector2(38, 8)
	card.add_child(nm)
	var pr := UIKit.label("%d G" % cost, 16, UIKit.GOLD)
	pr.position = Vector2(38, 28)
	card.add_child(pr)
	var owned := UIKit.label("have %d" % Game.item_count(id), 12, UIKit.DIM)
	owned.position = Vector2(38, 48)
	card.add_child(owned)
	var buy := UIKit.button("Buy", 76, 26)
	buy.position = Vector2(112, 62)
	buy.disabled = not Game.can_afford(cost)
	buy.pressed.connect(func():
		if Game.spend(cost):
			Game.add_item(id, 1)
			Audio.play_sfx("coin")
			owned.text = "have %d" % Game.item_count(id)
			gold_label.text = "%d G" % Game.gold
			buy.disabled = not Game.can_afford(cost))
	card.add_child(buy)
	var tags := HBoxContainer.new()
	tags.position = Vector2(8, 62)
	tags.add_theme_constant_override("separation", 2)
	card.add_child(tags)
	for t in ing.get("tags", []):
		tags.add_child(UIKit.icon("tag_" + str(t), 14))
	return card


# ======================================================== RELATIONSHIPS =====
func open_relationships() -> void:
	var root := UIKit.window("REGULARS", 820, 540)
	var body: NinePatchRect = root.get_meta("body")
	var list := VBoxContainer.new()
	list.position = Vector2(14, 48)
	list.add_theme_constant_override("separation", 6)
	body.add_child(list)
	for id in DB.character_ids():
		if Game.day < int(DB.character(str(id)).get("unlock_day", 1)) \
				and Game.friendship_points(str(id)) <= 0.0:
			continue
		list.add_child(_relationship_row(str(id)))
	_close_button(body, 820, 540)
	_show(root, "relationships")


func _relationship_row(id: String) -> Control:
	var ch := DB.character(id)
	var lvl := Game.friendship_level(id)
	var row := UIKit.panel("panel_inset")
	row.custom_minimum_size = Vector2(776, 80)

	var portrait := TextureRect.new()
	portrait.texture = DB.atlas_frame("character",
			"%s/expressions" % str(ch.get("sprite", "slime")), 1)
	portrait.position = Vector2(6, 2)
	portrait.custom_minimum_size = Vector2(64, 76)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var nm := UIKit.label("%s, %s" % [str(ch.get("name", id)),
			str(ch.get("title", ""))], 18, UIKit.PAPER)
	nm.position = Vector2(78, 6)
	row.add_child(nm)
	var lv := UIKit.label(DB.level_name(lvl), 14, UIKit.GOLD)
	lv.position = Vector2(78, 28)
	row.add_child(lv)
	var desc := UIKit.label(str(ch.get("desc", "")), 12, UIKit.DIM)
	desc.position = Vector2(78, 46)
	desc.size = Vector2(500, 30)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc)

	# progress to the next level, not raw points - the player never needs the
	# number, only the sense of getting somewhere
	var pts := Game.friendship_points(id)
	var next_at := 68.0
	for entry in DB.relationship_levels:
		if int(entry.get("level", 0)) == lvl + 1:
			next_at = float(entry.get("threshold", 68))
	var f := UIKit.bar(row, Vector2(596, 34), 160, 10, "bar_heart")
	UIKit.set_bar(f, clampf(pts / maxf(1.0, next_at), 0.0, 1.0))
	for i in 5:
		var h := UIKit.icon("icon_heart" if i < lvl else "icon_heart_empty", 14)
		h.position = Vector2(596 + i * 16, 12)
		row.add_child(h)
	return row


# ========================================================== DAY SUMMARY =====
func open_summary(s: Dictionary) -> void:
	var root := UIKit.window("DAY %d - CLOSED" % int(s.get("day", 1)), 620, 480)
	var body: NinePatchRect = root.get_meta("body")
	var y := 62
	for spec in [["Customers served", str(s.get("served", 0)), UIKit.INK],
			["Perfect dishes", str(s.get("perfect", 0)), Color("#3f7a2f")],
			["Disappointed", str(s.get("failed", 0)), Color("#8f3a2a")],
			["Walked out", str(s.get("walkouts", 0)), Color("#8f3a2a")]]:
		var k := UIKit.label(str(spec[0]), 18, Color("#4a3a2a"), false)
		k.position = Vector2(28, y)
		body.add_child(k)
		var v := UIKit.label(str(spec[1]), 18, spec[2], false)
		v.position = Vector2(430, y)
		body.add_child(v)
		y += 32
	y += 10
	var gl := UIKit.label("Earned today", 20, Color("#4a3a2a"), false)
	gl.position = Vector2(28, y)
	body.add_child(gl)
	var gv := UIKit.label("%d G" % int(s.get("gold", 0)), 22, Color("#8a6a10"), false)
	gv.position = Vector2(430, y)
	body.add_child(gv)
	y += 40

	var rd := float(s.get("rep_delta", 0.0))
	var rl := UIKit.label("Reputation", 20, Color("#4a3a2a"), false)
	rl.position = Vector2(28, y)
	body.add_child(rl)
	var rv := UIKit.label("%s%.2f" % ["+" if rd >= 0 else "", rd], 20,
			Color("#3f7a2f") if rd >= 0 else Color("#8f3a2a"), false)
	rv.position = Vector2(430, y)
	body.add_child(rv)
	UIKit.stars(body, Vector2(28, y + 30), float(s.get("reputation", 0.0)))

	var next := UIKit.button("Next Day", 160, 36)
	next.position = Vector2(230, 410)
	next.pressed.connect(func():
		close()
		next_day_requested.emit())
	body.add_child(next)

	var save_b := UIKit.button("Save", 100, 30)
	save_b.position = Vector2(28, 414)
	save_b.pressed.connect(func():
		SaveManager.save_game(0)
		save_b.text = "Saved")
	body.add_child(save_b)
	_show(root, "summary")
	Audio.play_sfx("levelup")


# =============================================================== PAUSE ======
func open_pause() -> void:
	var root := UIKit.window("PAUSED", 420, 380, "panel_dark")
	var body: NinePatchRect = root.get_meta("body")
	var y := 60
	for spec in [["Resume", "resume"], ["Regulars", "relationships"],
			["Save / Load", "saves"], ["Settings", "settings"],
			["Quit to Menu", "menu"]]:
		var b := UIKit.button(str(spec[0]), 260, 34)
		b.position = Vector2(80, y)
		var act := str(spec[1])
		b.pressed.connect(func(): _pause_action(act))
		body.add_child(b)
		y += 44
	_show(root, "pause")


func _pause_action(action: String) -> void:
	match action:
		"resume":
			close()
		"relationships":
			open_relationships()
		"saves":
			open_saves()
		"settings":
			open_settings()
		"menu":
			close()
			quit_to_menu.emit()


# ========================================================== SAVE / LOAD =====
## Three slots. Slot 0 is the autosave the day rollover and the title screen's
## Continue both use; 1 and 2 are the player's own.
func open_saves() -> void:
	var root := UIKit.window("SAVE / LOAD", 640, 420)
	var body: NinePatchRect = root.get_meta("body")
	var y := 58
	for slot in SaveManager.SLOTS:
		body.add_child(_save_row(slot, y))
		y += 100
	var note := UIKit.label("Slot 1 is autosaved at the end of each day.", 13,
			Color("#6a5340"), false)
	note.position = Vector2(20, 372)
	body.add_child(note)
	_close_button(body, 640, 420)
	_show(root, "saves")


func _save_row(slot: int, y: int) -> Control:
	var card := UIKit.panel("panel_inset")
	card.position = Vector2(20, y)
	card.size = Vector2(600, 88)

	var title := UIKit.label("SLOT %d%s" % [slot + 1,
			"  (auto)" if slot == 0 else ""], 18, UIKit.PAPER)
	title.position = Vector2(14, 10)
	card.add_child(title)

	var info := UIKit.label("empty", 14, UIKit.DIM)
	info.position = Vector2(14, 34)
	card.add_child(info)

	var stars_row := Control.new()
	stars_row.position = Vector2(14, 56)
	stars_row.size = Vector2(100, 18)
	card.add_child(stars_row)

	var refresh := func():
		var p := SaveManager.peek(slot)
		for c in stars_row.get_children():
			c.queue_free()
		if p.is_empty():
			info.text = "empty"
			return
		info.text = "Day %d   -   %s G   -   %s" % [int(p.get("day", 1)),
				int(p.get("gold", 0)), str(p.get("saved_at", ""))]
		UIKit.stars(stars_row, Vector2.ZERO, float(p.get("reputation", 0.0)))
	refresh.call()

	var save_b := UIKit.button("Save", 110, 32)
	save_b.position = Vector2(360, 28)
	save_b.pressed.connect(func():
		SaveManager.save_game(slot)
		Audio.play_sfx("ui_confirm")
		refresh.call())
	card.add_child(save_b)

	var load_b := UIKit.button("Load", 110, 32)
	load_b.position = Vector2(478, 28)
	load_b.disabled = not SaveManager.has_save(slot)
	load_b.pressed.connect(func():
		if SaveManager.load_game(slot):
			Audio.play_sfx("ui_confirm")
			close()
			save_loaded.emit())
	card.add_child(load_b)
	return card


signal save_loaded()


# ============================================================ SETTINGS ======
func open_settings() -> void:
	var root := UIKit.window("SETTINGS", 520, 400, "panel_dark")
	var body: NinePatchRect = root.get_meta("body")
	var y := 64
	for spec in [["Sound", "sfx"], ["Music", "music"], ["Ambience", "ambience"]]:
		var l := UIKit.label(str(spec[0]), 18, UIKit.PAPER)
		l.position = Vector2(28, y)
		body.add_child(l)
		var sl := HSlider.new()
		sl.position = Vector2(150, y + 2)
		sl.size = Vector2(320, 20)
		sl.custom_minimum_size = Vector2(320, 20)
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		var key := str(spec[1])
		sl.value = float(SaveManager.settings.get(key, 0.6))
		sl.value_changed.connect(func(v):
			SaveManager.settings[key] = v
			SaveManager.apply_settings()
			SaveManager.save_settings())
		body.add_child(sl)
		y += 46

	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.position = Vector2(28, y)
	fs.button_pressed = bool(SaveManager.settings.get("fullscreen", false))
	var f := UIKit.font()
	if f != null:
		fs.add_theme_font_override("font", f)
	fs.add_theme_font_size_override("font_size", 16)
	fs.add_theme_color_override("font_color", UIKit.PAPER)
	fs.toggled.connect(func(on):
		SaveManager.settings["fullscreen"] = on
		SaveManager.apply_settings()
		SaveManager.save_settings())
	body.add_child(fs)
	y += 46

	var note := UIKit.label("Display is locked to 1280x720 (16:9).", 13, UIKit.DIM)
	note.position = Vector2(28, y)
	body.add_child(note)
	_close_button(body, 520, 400)
	_show(root, "settings")


# ============================================================ UPGRADES ======
func open_upgrades() -> void:
	var root := UIKit.window("RESTAURANT", 700, 460)
	var body: NinePatchRect = root.get_meta("body")
	var y := 62
	var specs := [
		["tables", "Extra Table", "Seat one more customer at a time.", 260],
		["stove", "Better Range", "Wider heat window - easier to hit perfect.", 340],
		["decor", "Furnishings", "Raises the room's atmosphere.", 200],
	]
	for spec in specs:
		var id := str(spec[0])
		var lvl := Game.upgrade_level(id)
		var cost := int(spec[3]) * (lvl + 1)
		var card := UIKit.panel("panel_inset")
		card.position = Vector2(20, y)
		card.size = Vector2(660, 96)
		body.add_child(card)
		var nm := UIKit.label("%s  (level %d)" % [str(spec[1]), lvl], 18, UIKit.PAPER)
		nm.position = Vector2(14, 10)
		card.add_child(nm)
		var d := UIKit.label(str(spec[2]), 14, UIKit.DIM)
		d.position = Vector2(14, 34)
		card.add_child(d)
		var c := UIKit.label("%d G" % cost, 18, UIKit.GOLD)
		c.position = Vector2(14, 60)
		card.add_child(c)
		var b := UIKit.button("Upgrade", 130, 32)
		b.position = Vector2(500, 48)
		b.disabled = not Game.can_afford(cost) or (id == "tables" and lvl >= 5)
		b.pressed.connect(func():
			if Game.spend(cost):
				Game.apply_upgrade(id)
				Audio.play_sfx("levelup")
				close()
				open_upgrades())
		card.add_child(b)
		y += 106
	_close_button(body, 700, 460)
	_show(root, "upgrades")


# ============================================================ DIALOGUE ======
func open_story(key: String) -> void:
	var st: Dictionary = DB.story.get(key, {})
	if st.is_empty():
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(UIKit.scrim(0.82))
	var p := UIKit.panel("panel_parchment")
	p.position = Vector2(190, 430)
	p.size = Vector2(900, 200)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(p)
	var lines: Array = st.get("lines", [])
	var idx := {"i": 0}
	var text := UIKit.label("", 20, UIKit.INK, false)
	text.position = Vector2(24, 24)
	text.size = Vector2(852, 120)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(text)
	var more := UIKit.label("SPACE to continue", 14, Color("#6a5340"), false)
	more.position = Vector2(720, 162)
	p.add_child(more)
	text.text = str(lines[0]) if not lines.is_empty() else ""

	var advance := func():
		idx["i"] = int(idx["i"]) + 1
		if int(idx["i"]) >= lines.size():
			close()
		else:
			text.text = str(lines[int(idx["i"])])
			Audio.play_sfx("ui_click", 1.0, 0.4)
	root.set_meta("advance", advance)
	_show(root, "story")


func _input(event: InputEvent) -> void:
	if open_id == "story" and _current != null \
			and event.is_action_pressed("interact"):
		var cb: Variant = _current.get_meta("advance", null)
		if cb is Callable:
			(cb as Callable).call()
		get_viewport().set_input_as_handled()
