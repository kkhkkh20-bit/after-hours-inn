extends Node
## Loads every JSON content file once at boot and exposes it read-only.
##
## Content lives in data/*.json so that adding a recipe, ingredient, monster,
## event or dialogue line never requires touching a script. Anything that needs
## to branch on content branches on TAGS, not on ids.

var ingredients: Dictionary = {}
var recipes: Dictionary = {}
var characters: Dictionary = {}
var relationship_levels: Array = []
var events: Dictionary = {}
var lines: Dictionary = {}
var story: Dictionary = {}
## assets/manifest.json, written by tools/build_assets.py. Holds frame counts
## and sizes so the engine and the art pipeline can never disagree about how
## many frames a sheet has.
var manifest: Dictionary = {}
var _sheet_cache: Dictionary = {}

## Every tag the game understands. Used by the UI to pick icons and by the
## satisfaction model to score a dish against a customer.
const TAGS := ["meat", "vegetable", "sweet", "bitter", "hot", "cold", "spicy",
		"magical", "rare", "large"]

const QUALITY := ["raw", "undercooked", "good", "perfect", "overcooked", "burnt"]
## Index into QUALITY used for "is this at least X" comparisons. Deliberately
## not the array order: raw and burnt are both bad, perfect is the peak.
const QUALITY_SCORE := {
	"raw": 0.0, "undercooked": 0.45, "good": 0.85, "perfect": 1.0,
	"overcooked": 0.40, "burnt": 0.0,
}


func _ready() -> void:
	ingredients = _load("res://data/ingredients.json").get("ingredients", {})
	var r := _load("res://data/recipes.json")
	recipes = r.get("recipes", {})
	var c := _load("res://data/characters.json")
	characters = c.get("characters", {})
	relationship_levels = c.get("relationship_levels", [])
	events = _load("res://data/events.json").get("events", {})
	var d := _load("res://data/dialogue.json")
	lines = d.get("lines", {})
	story = d.get("story", {})
	manifest = _load("res://assets/manifest.json")
	_derive_recipe_tags()


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DB: missing content file %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DB: %s is not a JSON object" % path)
		return {}
	return parsed


## A recipe's flavour profile is the union of its ingredients' tags, unless the
## recipe overrides it. Derived once at load so scoring never walks ingredients.
func _derive_recipe_tags() -> void:
	for id in recipes:
		var rec: Dictionary = recipes[id]
		if rec.has("tags"):
			continue
		var tags := {}
		for ing_id in rec.get("ingredients", []):
			var ing: Dictionary = ingredients.get(ing_id, {})
			for t in ing.get("tags", []):
				tags[t] = tags.get(t, 0) + 1
		rec["tags"] = tags.keys()
		rec["tag_counts"] = tags


func ingredient(id: String) -> Dictionary:
	return ingredients.get(id, {})


func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func character(id: String) -> Dictionary:
	return characters.get(id, {})


func ingredient_ids() -> Array:
	return ingredients.keys()


func recipe_ids() -> Array:
	return recipes.keys()


func character_ids() -> Array:
	return characters.keys()


## Ingredients obtainable from a given source, honouring night-only gating.
func ingredients_from(source: String, is_night: bool = false) -> Array:
	var out: Array = []
	for id in ingredients:
		var ing: Dictionary = ingredients[id]
		if not (source in ing.get("source", [])):
			continue
		if ing.get("night_only", false) and not is_night:
			continue
		out.append(id)
	return out


## Relationship level (0-4) for a raw friendship score.
func level_for(points: float) -> int:
	var lv := 0
	for entry in relationship_levels:
		if points >= float(entry.get("threshold", 0)):
			lv = int(entry.get("level", 0))
	return lv


func level_name(level: int) -> String:
	for entry in relationship_levels:
		if int(entry.get("level", -1)) == level:
			return str(entry.get("name", "Unknown"))
	return "Unknown"


# ------------------------------------------------------------- assets -----
## Manifest record for an asset, e.g. asset("character", "dragon/walk").
func asset(kind: String, key: String) -> Dictionary:
	var by_kind: Dictionary = manifest.get("by_kind", {})
	return (by_kind.get(kind, {}) as Dictionary).get(key, {})


## Build a SpriteFrames animation from a generated horizontal strip. Every
## animated sprite in the game goes through here, so frame timing and looping
## behaviour stay consistent.
func sprite_frames(kind: String, key: String, anim_name: String = "default",
		fps: float = 8.0, loop: bool = true,
		into: SpriteFrames = null) -> SpriteFrames:
	var rec := asset(kind, key)
	if rec.is_empty():
		return into if into != null else SpriteFrames.new()
	var cache_key := "%s|%s" % [kind, key]
	var tex: Texture2D
	if _sheet_cache.has(cache_key):
		tex = _sheet_cache[cache_key]
	else:
		var path := str(rec.get("path", ""))
		if not ResourceLoader.exists(path):
			push_warning("DB: missing texture %s" % path)
			return into if into != null else SpriteFrames.new()
		tex = load(path)
		_sheet_cache[cache_key] = tex
	var sf := into if into != null else SpriteFrames.new()
	if sf.has_animation(anim_name):
		sf.clear(anim_name)
	else:
		sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)
	var fw := int(rec.get("fw", rec.get("w", tex.get_width())))
	var fh := int(rec.get("fh", rec.get("h", tex.get_height())))
	var count := int(rec.get("frames", 1))
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim_name, at)
	return sf


func texture(path: String) -> Texture2D:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	_sheet_cache[path] = t
	return t


## Single frame out of a strip - used for dish quality tiers and expressions.
func atlas_frame(kind: String, key: String, index: int) -> AtlasTexture:
	var rec := asset(kind, key)
	if rec.is_empty():
		return null
	var tex := texture(str(rec.get("path", "")))
	if tex == null:
		return null
	var fw := int(rec.get("fw", tex.get_width()))
	var fh := int(rec.get("fh", tex.get_height()))
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(clampi(index, 0, int(rec.get("frames", 1)) - 1) * fw,
			0, fw, fh)
	return at


## Texture for a dish at a quality tier.
func dish_texture(recipe_id: String, quality: String) -> AtlasTexture:
	var idx := QUALITY.find(quality)
	return atlas_frame("food", recipe_id, maxi(0, idx))


func ingredient_texture(id: String) -> Texture2D:
	var rec := asset("food", id)
	return texture(str(rec.get("path", "")))


func ui_texture(name: String) -> Texture2D:
	var rec := asset("ui", name)
	return texture(str(rec.get("path", "")))


func env_texture(name: String) -> Texture2D:
	var rec := asset("environment", name)
	return texture(str(rec.get("path", "")))


## Pick a dialogue line for a character in a situation, falling back down the
## relationship ladder and then to the shared `any` pool.
func pick_line(char_id: String, situation: String, level: int) -> String:
	for source in [char_id, "any"]:
		var by_char: Dictionary = lines.get(source, {})
		var by_sit: Dictionary = by_char.get(situation, {})
		if by_sit.is_empty():
			continue
		# walk down from the requested level to find the highest bracket we
		# have actually written lines for
		for l in range(level, -1, -1):
			var pool: Array = by_sit.get(str(l), [])
			if not pool.is_empty():
				return str(pool[randi() % pool.size()])
	return "..."
