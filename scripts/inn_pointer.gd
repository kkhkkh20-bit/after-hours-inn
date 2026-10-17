extends RefCounted
## One pointer gesture owns one result. GUI ownership is decided on press.
const DRAG_DISTANCE := 18.0
var host
var pressed := false
var origin := Vector2.ZERO
var last := Vector2.ZERO
var blocked := false
var dragged := false
var touch_id := -1
var fingers: Dictionary = {}
var pinching := false
var pinch_span := 0.0
var captured: Array = []
var completion: Dictionary = {}

func reset() -> void:
	pressed=false;blocked=false;dragged=false;touch_id=-1;fingers.clear();pinching=false;pinch_span=0;captured=[];completion={}

func start(point: Vector2, ui: bool) -> void:
	pressed=true;origin=point;last=point;blocked=ui;dragged=false;completion={}
	captured=[] if ui else host.selection_candidates(point)

func motion(point: Vector2) -> void:
	if not pressed or blocked or pinching:return
	if point.distance_to(origin)>=DRAG_DISTANCE:dragged=true
	if dragged:
		if not host.builder.active or host.builder.camera_pan:host.pan_camera(point-last)
		elif host.builder.active:host.builder.preview(point)
	last=point

func finish(point: Vector2) -> void:
	if pressed and not blocked and not dragged and not pinching:
		completion={"point":point,"candidates":captured.duplicate(true)}
	pressed=false

func observe(event: InputEvent, ui: bool) -> void:
	if event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:start(event.position,ui)
		else:finish(event.position)
	elif event is InputEventMouseMotion and event.device!=-1:
		motion(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index]=event.position
			if fingers.size()==1:
				touch_id=event.index;start(event.position,ui)
			else:
				pinching=true;dragged=true;completion={}
				var points=fingers.values();pinch_span=points[0].distance_to(points[1])
		else:
			if not pinching and event.index==touch_id:finish(event.position)
			fingers.erase(event.index)
			if fingers.is_empty():
				pinching=false;pinch_span=0;pressed=false;touch_id=-1
	elif event is InputEventScreenDrag and fingers.has(event.index):
		fingers[event.index]=event.position
		if pinching:
			if fingers.size()>=2:
				var points=fingers.values();var span: float=points[0].distance_to(points[1])
				if not blocked and pinch_span>20 and span>20:
					host.camera.size=clampf(host.camera.size*pinch_span/span,12,90);host.comfort.zoom=host.camera.size
				pinch_span=span
		elif event.index==touch_id:motion(event.position)

func take() -> Dictionary:
	var value=completion;completion={};return value
