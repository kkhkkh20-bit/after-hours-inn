@tool
class_name ClickMarker
extends Node3D
## A marker on the ground at the click point: it appears with a short "bounce" and fades out when the character
## arrives or the run to it is abandoned (for example, the character is steered with the keys).

## What to show and fade out. If not set, the first child [GeometryInstance3D] is used.
@export var geometry: GeometryInstance3D:
	set(value):
		geometry = value
		update_configuration_warnings()

## How long the appearance lasts.
@export_range(0.0, 1.0, 0.01, "suffix:s") var appear_time := 0.18

## How long the fade-out lasts.
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_time := 0.3

## How far to raise the marker above the click point so that it does not sink into the ground.
@export_range(0.0, 0.5, 0.005, "suffix:m") var height_offset := 0.03

var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# The marker jumps to a new point instantly; physics interpolation would drag it from the old one.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if geometry == null:
		geometry = _find_child_geometry()
	assert(geometry != null, "ClickMarker needs a GeometryInstance3D child or the geometry property set.")
	visible = false


## Show the marker at [param point].
func show_at(point: Vector3) -> void:
	global_position = point + Vector3.UP * height_offset
	visible = true
	scale = Vector3.ONE * 1.8
	geometry.transparency = 1.0
	_restart_tween()
	_tween.set_parallel()
	_tween.tween_property(self, ^"scale", Vector3.ONE, appear_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(geometry, ^"transparency", 0.0, appear_time)


## Hide the marker smoothly.
func fade_out() -> void:
	if not visible:
		return
	_restart_tween()
	_tween.set_parallel()
	_tween.tween_property(geometry, ^"transparency", 1.0, fade_time)
	_tween.tween_property(self, ^"scale", Vector3.ONE * 0.4, fade_time).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()


func _find_child_geometry() -> GeometryInstance3D:
	for child: Node in get_children():
		if child is GeometryInstance3D:
			return child as GeometryInstance3D
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if geometry == null and _find_child_geometry() == null:
		warnings.append("Assign Geometry or add a GeometryInstance3D child.")
	return warnings
