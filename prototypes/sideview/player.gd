extends CharacterBody2D
const RUN_SPEED = 210.0
const ACCELERATION = 1400.0
const GRAVITY = 1100.0
const JUMP_SPEED = -455.0
var axis = 0.0
var jump_requested = false
var jump_held = false
var crouch = false
var climbing = false
var climb_axis = 0.0
var facing = 1
var coyote = 0.0
var jump_buffer = 0.0
var active = true
var carrying = false
var ignore_platforms = 0.0
var sprite: Sprite2D
var animation_clock = 0.0

func _ready() -> void:
	collision_layer=2; collision_mask=1|4
	var shape = CollisionShape2D.new(); var rect = RectangleShape2D.new()
	rect.size=Vector2(24,54); shape.shape=rect; add_child(shape)
	sprite=Sprite2D.new(); sprite.texture=preload("res://assets/knight.png")
	sprite.hframes=8; sprite.vframes=8; sprite.scale=Vector2(3,3); sprite.position=Vector2(0,-9)
	add_child(sprite)
func _physics_process(delta: float) -> void:
	if not active: return
	coyote = 0.10 if is_on_floor() else maxf(0,coyote-delta)
	jump_buffer = 0.12 if jump_requested else maxf(0,jump_buffer-delta)
	jump_requested=false
	ignore_platforms=maxf(0,ignore_platforms-delta)
	set_collision_mask_value(3,ignore_platforms<=0 and not (climbing and climb_axis>0))
	var top_speed=RUN_SPEED*(0.43 if crouch else 1.0)*(0.55 if carrying else 1.0)
	velocity.x=move_toward(velocity.x,axis*top_speed,ACCELERATION*delta)
	if absf(axis)>0.05: facing=1 if axis>0 else -1
	if climbing and absf(climb_axis)>0.05:
		velocity.y=climb_axis*130
	else:
		velocity.y=minf(750,velocity.y+GRAVITY*delta)
	if jump_buffer>0 and (coyote>0 or climbing):
		velocity.y=JUMP_SPEED*(0.8 if carrying else 1.0); jump_buffer=0; coyote=0
	if not jump_held and velocity.y < -190: velocity.y=maxf(velocity.y,-190)
	move_and_slide()
	position.x=clampf(position.x,34,84*32-34)
	animation_clock+=delta
	var row=2 if absf(velocity.x)>10 else 0
	if not is_on_floor(): row=2
	sprite.frame=row*8+(int(animation_clock*(10 if row==2 else 4))%4)
	sprite.flip_h=facing<0
	sprite.modulate=Color("d6bd92") if crouch else Color.WHITE
func body_rect() -> Rect2:
	return Rect2(position-Vector2(12,27),Vector2(24,54))
func drop_down() -> void:
	ignore_platforms=0.24; position.y+=3
