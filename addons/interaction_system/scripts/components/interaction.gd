@tool
@icon("res://addons/interaction_system/assets/sprites/icons/interaction.svg")
class_name Interaction
extends Node

@export var enabled: bool = true
@export_group("Nodes")
@export_node_path("RayCast2D", "RayCast3D") var raycast: NodePath:
	set(value):
		raycast = value

		if Engine.is_editor_hint(): 
			update_configuration_warnings()

var _ray = null


func _ready() -> void:
	if Engine.is_editor_hint(): 
		update_configuration_warnings()
		return

	_ray = get_node(raycast)


func _get_configuration_warnings() -> PackedStringArray:
	if raycast == NodePath(""):
		return ["Interaction component needs a reference to a Raycast3D. "
				+ "Assign one in the inspector"]

	return []


func enable() -> void:
	enabled = true


func disable() -> void:
	enabled = false


func interact() -> void:
	if not enabled:
		return

	if not _ray.enabled:
		_ray.force_raycast_update()

	var collider: Node = _ray.get_collider()

	if collider == null:
		return

	if not collider.has_meta(Interactable.META):
		return

	collider.get_meta(Interactable.META).call()
