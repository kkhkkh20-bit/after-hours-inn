class_name GroundMotion
extends RefCounted
## Kinematics of running on the ground: speed and direction of movement in the horizontal plane.
##
## There are no nodes, physics or navigation here, only math. The input is where to run and how far it is to the
## point where the character must stand; the output is the horizontal velocity for this tick. So the class suits the
## player, NPCs and automated checks equally well.
##
## What it provides:
## - acceleration from a standstill and braking with constant acceleration from [LocomotionSettings];
## - stopping exactly at a given point: the speed is limited so that the character can still brake there in time;
## - a new target during braking: the speed is not reset, and acceleration continues from the current speed;
## - turning on the move with a limited angular speed, and an instant turn when standing.

## Acceleration, braking and turning settings. They can be changed on the fly.
var settings: LocomotionSettings

## Current speed, m/s.
var speed := 0.0

## Current direction of movement: a unit horizontal vector.
var heading := Vector3.FORWARD

## Factor by which to raise the speed limit [member LocomotionSettings.max_speed] (sprint).
## When the limit drops, the character sheds the excess speed with normal braking rather than with a jerk.
var speed_scale := 1.0


func _init(p_settings: LocomotionSettings) -> void:
	settings = p_settings


## Advances the movement by [param delta] seconds and returns the horizontal velocity.
## [param direction] is where to run: a horizontal unit vector, or [constant Vector3.ZERO] to stop.
## [param distance_left] is how far it is to the point where the character must stand, or [constant @GDScript.INF] if
## it does not need to stand anywhere.
func step(direction: Vector3, distance_left: float, delta: float) -> Vector3:
	if direction != Vector3.ZERO:
		_turn_towards(direction, delta)

	var target_speed := _get_target_speed(direction, distance_left)
	var rate := settings.get_acceleration() if target_speed > speed else _get_braking_rate(distance_left)
	speed = move_toward(speed, target_speed, rate * delta)
	# Do not overshoot the stopping point within one tick.
	if delta > 0.0:
		speed = minf(speed, distance_left / delta)

	return heading * speed


## Stops immediately, without braking. For teleports, stuns and arriving exactly at a point.
func halt() -> void:
	speed = 0.0


## Sets the direction without turning, for example when the character spawns.
func face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		heading = flat.normalized()


func _turn_towards(direction: Vector3, delta: float) -> void:
	# When standing or almost standing, turn at once: turning in place must not delay the start.
	if speed <= settings.pivot_speed:
		heading = direction
		return
	var angle := heading.signed_angle_to(direction, Vector3.UP)
	var max_angle := settings.turn_speed * delta
	heading = heading.rotated(Vector3.UP, clampf(angle, -max_angle, max_angle)).normalized()


func _get_target_speed(direction: Vector3, distance_left: float) -> float:
	if direction == Vector3.ZERO:
		return 0.0
	# With constant deceleration b, the braking distance from speed v is v² / 2b. Hence the speed from which the
	# character can still stop exactly at the point: v = √(2·b·d). The closer the point, the slower.
	var target := minf(settings.max_speed * speed_scale, sqrt(2.0 * settings.get_braking() * distance_left))
	# Until the heading has turned toward the target, shed speed: a turn without a wide arc.
	var alignment := clampf(heading.dot(direction), 0.0, 1.0)
	return target * lerpf(1.0, alignment, settings.turn_slowdown)


func _get_braking_rate(distance_left: float) -> float:
	var braking := settings.get_braking()
	if distance_left <= 0.0 or is_inf(distance_left):
		return braking
	# The deceleration that stops exactly at the point. Usually it is slightly above the normal one (the speed lags
	# behind the profile by a tick); if the point was set right in front of a running character, it is much higher:
	# then the character brakes harder, but not more sharply than the limit.
	var needed := speed * speed / (2.0 * distance_left)
	return clampf(needed, braking, braking * settings.max_braking_multiplier)
