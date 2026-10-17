extends "res://third_party/kenney_city_builder/view.gd"
## Kenney's view rig drives the real camera; gestures remain in the touch router.
var host
func configure(h) -> void:
	host=h;var lens=Camera3D.new();lens.name="Camera";lens.current=false;add_child(lens)
func _ready() -> void:
	super._ready();set_process(false);snap()
func handle_input(_delta):pass
func _input(_event):pass
func _process(_delta):pass
func aim() -> void:
	camera_position=host.focus_position()+Vector3(host.camera_offset.x,0,host.camera_offset.y)
	var arm=host.camera_arm();var angles=Basis.looking_at(-arm.normalized(),Vector3.UP).get_euler()*180/PI
	# Keep target rotation on the nearest turn to avoid a 360-degree swing.
	camera_rotation=Vector3(rotation_degrees.x+wrapf(angles.x-rotation_degrees.x,-180,180),rotation_degrees.y+wrapf(angles.y-rotation_degrees.y,-180,180),0)
	zoom=arm.length()
func snap() -> void:
	aim();position=camera_position;rotation_degrees=camera_rotation;camera.position=Vector3(0,0,zoom);copy_to_camera()
func drive(delta: float) -> void:
	aim();super._process(minf(delta,.1));copy_to_camera()
func copy_to_camera() -> void:
	host.camera.global_transform=camera.global_transform;host.camera_focus=position

func capture() -> void:
	if not is_inside_tree() or camera==null:return
	position=host.camera_focus;rotation=host.camera.global_rotation
	camera_position=position;camera_rotation=rotation_degrees
	zoom=host.camera.global_position.distance_to(position);camera.position=Vector3(0,0,zoom)
