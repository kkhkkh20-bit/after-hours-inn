class_name LocomotionSettings
extends Resource
## Running settings: speed, acceleration, braking and turning.
##
## A separate resource, so that the same settings can be given to several characters (for example, all NPCs of one
## type) and tuned in the inspector while the game is running.

## Running speed.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var max_speed := 5.5

## How many times faster the sprint is ([member NavigationMover.sprinting]). The character accelerates and brakes
## with the same acceleration as usual.
@export_range(1.0, 3.0, 0.05) var sprint_speed_multiplier := 1.5

## What fraction of the speed remains when the character walks backward (faces against the direction of movement, see
## [method NavigationMover.get_facing]): 1 means the same as forward. Diagonally backward the speed drops partially,
## sideways it does not.
@export_range(0.1, 1.0, 0.05) var backward_speed_multiplier := 0.7

## How many seconds the character takes to accelerate from a standstill to [member max_speed].
@export_range(0.01, 2.0, 0.01, "suffix:s") var acceleration_time := 0.18

## How many seconds the character takes to stop from [member max_speed].
## Braking distance from full speed: [code]max_speed * stop_time / 2[/code].
@export_range(0.01, 2.0, 0.01, "suffix:s") var stop_time := 0.22

## How fast the running direction turns while moving.
@export_range(30.0, 3600.0, 1.0, "radians_as_degrees") var turn_speed := deg_to_rad(720.0)

## How much to shed speed while the running direction has not yet turned toward the target:
## 0 means do not shed it (a wide arc), 1 means brake to zero when turning by 90° or more.
@export_range(0.0, 1.0, 0.01) var turn_slowdown := 0.75

## Below this speed the character turns instantly: from a standstill in any direction, with no arc and no delay.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var pivot_speed := 1.0

## How many times harder than usual the character may brake if the stopping point is set right in front of it while
## it runs.
@export_range(1.0, 10.0, 0.1) var max_braking_multiplier := 3.0


## Acceleration when speeding up, m/s².
func get_acceleration() -> float:
	return max_speed / acceleration_time


## Deceleration in a normal stop, m/s².
func get_braking() -> float:
	return max_speed / stop_time
