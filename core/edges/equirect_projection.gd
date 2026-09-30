class_name EquirectProjection
## Panorama-space direction <-> equirectangular UV, both ways.
##
## Matches Godot's own [PanoramaSkyMaterial] sampling convention exactly
## (`direction_to_panorama_uv` in the renderer's sky shader): [code]u=0.5,
## v=0[/code] is straight up, [code]v=1[/code] is straight down, and
## [code]u[/code] wraps around the horizon with [code]u=0[/code] at [code]-Z[/code].
## An [EdgeSource] built from the panorama texture has to embed its pixels on
## the sphere with this exact convention, not [ManualEdgeSource]'s
## yaw/pitch one, because the thing it has to agree with is what
## [PanoramaSkyMaterial] actually renders at that pixel, not how
## [PanoramaLookCamera] happens to parameterise its own rotation. The two
## conventions differ (this one turns the opposite way around the vertical
## axis), which is fine: both are just [Vector3] directions once embedded,
## and direction is all [PanoramaEdgePoint] promises.
##
## This is also where an image-based detector's pole distortion gets
## corrected, the same way [ManualEdgeSource]'s sphere embedding does it for
## hand-authored angles: a fixed [code]delta_u[/code] step turns into a
## shorter chord near a pole than at the equator purely from the trigonometry
## below, with no separate correction pass.


## Panorama-space unit direction for a point at [param uv] on the
## equirectangular image, [code]u[/code] and [code]v[/code] both in
## [code][0, 1][/code].
static func direction_for_uv(uv: Vector2) -> Vector3:
	var theta := uv.y * PI
	var phi := uv.x * TAU
	var sin_theta := sin(theta)
	return Vector3(sin_theta * sin(phi), cos(theta), -sin_theta * cos(phi))


## Inverse of [method direction_for_uv]: the equirectangular UV a panorama-space
## [param direction] projects to. [code]u[/code] wraps into [code][0, 1)[/code];
## [code]v[/code] is clamped to [code][0, 1][/code] since a direction's pitch
## never exceeds a pole.
static func uv_for_direction(direction: Vector3) -> Vector2:
	var d := direction.normalized()
	var phi := atan2(d.x, -d.z)
	if phi < 0.0:
		phi += TAU
	var theta := acos(clampf(d.y, -1.0, 1.0))
	return Vector2(phi / TAU, theta / PI)
