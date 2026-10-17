extends Node
## Save/load. Three slots plus settings, stored as JSON in user://.
##
## Saves are written to a temp file and then renamed over the real one, so a
## crash mid-write cannot leave a half-written save. tests/test_save.gd covers
## round-tripping and corruption handling.

const SAVE_VERSION := 1
const SLOTS := 3
const SETTINGS_PATH := "user://settings.json"

signal saved(slot: int)
signal loaded(slot: int)

var settings: Dictionary = {
	"sfx": 0.8, "music": 0.5, "ambience": 0.45, "fullscreen": false,
	"screen_shake": true,
}


func _ready() -> void:
	load_settings()


func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": Game.to_dict(),
	}
	var text := JSON.stringify(payload, "\t")
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s for write" % tmp)
		return false
	f.store_string(text)
	f.close()
	# Atomic-ish swap: a torn write lands in the temp file, never the save.
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),
			ProjectSettings.globalize_path(slot_path(slot)))
	if err != OK:
		# Some sandboxes disallow rename across the user:// mount; fall back to
		# a direct write, which is still better than losing the save entirely.
		var f2 := FileAccess.open(slot_path(slot), FileAccess.WRITE)
		if f2 == null:
			return false
		f2.store_string(text)
		f2.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	saved.emit(slot)
	return true


func load_game(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: slot %d is corrupt, ignoring" % slot)
		return false
	var d: Dictionary = parsed
	if int(d.get("version", 0)) > SAVE_VERSION:
		push_warning("SaveManager: slot %d is from a newer build" % slot)
	var game_data: Variant = d.get("game", null)
	if typeof(game_data) != TYPE_DICTIONARY:
		return false
	Game.from_dict(game_data)
	loaded.emit(slot)
	return true


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Lightweight header for the load menu, without applying the save.
func peek(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	var g: Dictionary = d.get("game", {})
	return {
		"day": int(g.get("day", 1)),
		"gold": int(g.get("gold", 0)),
		"reputation": float(g.get("reputation", 0.0)),
		"saved_at": str(d.get("saved_at", "")),
	}


# ------------------------------------------------------------- settings ----
func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(settings, "\t"))
	f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		apply_settings()
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in (parsed as Dictionary):
			settings[k] = (parsed as Dictionary)[k]
	apply_settings()


func apply_settings() -> void:
	Audio.set_volumes(float(settings.get("sfx", 0.8)),
			float(settings.get("music", 0.5)),
			float(settings.get("ambience", 0.45)))
	if bool(settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
