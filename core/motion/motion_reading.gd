class_name MotionReading
extends RefCounted
## One sample of device motion, in device axes and metres per second squared.
##
## Sources own and reuse their reading rather than allocating a new one per
## frame, so copy anything you need to outlive the next poll.

## Gravity alone — which way is down, whatever the device is doing.
var gravity: Vector3 = Vector3.ZERO

## Motion the player caused, with gravity already taken out.
var acceleration: Vector3 = Vector3.ZERO

## False when the platform has no sensors, or has not reported yet.
var available: bool = false


func clear() -> void:
	gravity = Vector3.ZERO
	acceleration = Vector3.ZERO
	available = false


func copy_from(other: MotionReading) -> void:
	gravity = other.gravity
	acceleration = other.acceleration
	available = other.available
