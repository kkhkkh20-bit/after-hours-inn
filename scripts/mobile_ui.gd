extends CanvasLayer
## Compatibility adapter: gameplay actions live beside world objects.
var host
var root: Control
var drawer: Control
var controls: Dictionary={}
func setup(owner_) -> void:
	host=owner_; root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root); root.hide(); drawer=root
func refresh() -> void:
	pass
func blocks_point(point: Vector2) -> bool:
	return (host.object_context.blocks(point) or (host.mobile_scene.host!=null and host.mobile_scene.blocks(point))) if host.object_context!=null else point.y<152
func open_sheet(name_: String) -> void:
	host.object_context.open("system" if name_=="메뉴" else "counter")
func close_sheet() -> void:
	host.object_context.close()
