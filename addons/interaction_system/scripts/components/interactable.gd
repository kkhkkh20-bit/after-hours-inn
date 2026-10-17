@tool
@icon("res://addons/interaction_system/assets/sprites/icons/interactable.svg")
class_name Interactable
extends Node

signal interacted

const META: String = "InteractFunction"

@export var enabled: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		get_tree().tree_changed.connect(update_configuration_warnings)
		return

	var parent: Node = get_parent()

	if parent == null:
		push_error("%s missing parent" % get_path())
		return

	parent.set_meta(META, interact)


func _get_configuration_warnings() -> PackedStringArray:
	var parent: Node = get_parent()

	if parent == null:
		return ["Interactable component should be a child of a node"]

	for child in parent.get_children():
		if child == self:
			continue

		if child is not Interactable:
			continue

		return ["Parent node should only have one Interactable component"]

	return []


func enable() -> void:
	enabled = true


func disable() -> void:
	enabled = false


func interact() -> void:
	if enabled: 
		interacted.emit()
